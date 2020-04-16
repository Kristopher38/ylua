---------------------------------------------------------------------------------
-- Copyright (c) 2019 kelthuzadx<1948638989@qq.com>

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
---------------------------------------------------------------------------------
local runtime={
    debug = false,
    fpf = 50, -- LFIELDS_PER_FLUSH from lopcodes.h
}

---------------------------------------------------------------------------------
-- Opcode table and corresponding mode
---------------------------------------------------------------------------------
local iABC, iABx, iAsBx, iAx = 0, 1, 2, 3
local opcode = { 
    [1] = { MOVE = iABC },
    [2] = { LOADK = iABx },
    [3] = { LOADKX = iABx },
    [4] = { LOADBOOL = iABC },
    [5] = { LOADNIL = iABC },
    [6] = { GETUPVAL = iABC },
    [7] = { GETTABUP = iABC },
    [8] = { GETTABLE = iABC },
    [9] = { SETTABUP = iABC },
    [10] = { SETUPVAL = iABC },
    [11] = { SETTABLE = iABC },
    [12] = { NEWTABLE = iABC },
    [13] = { SELF = iABC },
    [14] = { ADD = iABC },
    [15] = { SUB = iABC },
    [16] = { MUL = iABC },
    [17] = { MOD = iABC },
    [18] = { POW = iABC },
    [19] = { DIV = iABC }, 
    [20] = { IDIV = iABC },
    [21] = { BAND = iABC },
    [22] = { BOR = iABC },
    [23] = { BXOR = iABC },
    [24] = { SHL = iABC },
    [25] = { SHR = iABC },
    [26] = { UNM = iABC },
    [27] = { BNOT = iABC },
    [28] = { NOT = iABC },
    [29] = { LEN = iABC },
    [30] = { CONCAT = iABC },
    [31] = { JMP = iAsBx },
    [32] = { EQ = iABC },
    [33] = { LT = iABC },
    [34] = { LE = iABC },
    [35] = { TEST = iABC },
    [36] = { TESTSET = iABC },
    [37] = { CALL = iABC },
    [38] = { TAILCALL = iABC },
    [39] = { RETURN = iABC },
    [40] = { FORLOOP = iAsBx },
    [41] = { FORPREP = iAsBx },
    [42] = { TFORCALL = iABC },
    [43] = { TFORLOOP = iAsBx },
    [44] = { SETLIST = iABC },
    [45] = { CLOSURE = iABx },
    [46] = { VARARG = iABC },
    [47] = { EXTRAARG = iAx },
}

---------------------------------------------------------------------------------
-- Execution engine
---------------------------------------------------------------------------------
local function decode_instr(code)
    local op_num = (code & 0x3f) -- 6bits for instruction id
    if opcode[op_num+1] == nil then error("invalid bytecode") end
    local k,v  = next(opcode[op_num+1])
    if v == iABC then
		local a, c, b = ((code>>6) & 0xff), ((code>>14) & 0x1ff), ((code>>23) & 0x1ff)
		if runtime.debug == true then 
			print(string.format("[%d]",op_num+1),k,a,b,c)		
		end
        return {instr_name=k,instr_id=op_num+1,mode="iABC",operand={a=a,b=b,c=c}}
    elseif v == iABx then
        local a,bx = ((code>>6) & 0xff), ((code>>14) & 0x3ffff)
		if runtime.debug == true then 
			print(string.format("[%d]",op_num+1),k,a,bx)
		end
		return {instr_name=k,instr_id=op_num+1,mode="iABx",operand={a=a,bx=bx}}
    elseif v == iAsBx then
        local a,sbx = ((code>>6) & 0xff), ((code>>14) & 0x3ffff) - (((1<<18)-1)>>1)
		if runtime.debug == true then 
			print(string.format("[%d]",op_num+1),k,a,sbx)
		end
		return {instr_name=k,instr_id=op_num+1,mode="iAsBx",operand={a=a,sbx=sbx}}
    elseif v == iAx then
        local ax = (code>>6) & 0x3ffffff
		if runtime.debug == true then 
			print(string.format("[%d]",op_num+1),k,ax)
		end
		return {instr_name=k,instr_id=op_num+1,mode="iAx",operand={ax=ax}}
    else
        error("invalid opcode mode")
    end
end

local closures_data = {}
function runtime.exec_bytecode(func,upvalue)
    -- execution environmnet
    local pc = 1
    local r ={}
    local const = {}
    local flow_stop = false
    local return_val = {}
    local top = func.max_stack

    -- auxiliary functions(should factor to oop styles)
    local function rk(index) if index>=256 then return const[index-256] else return r[index] end end
    local function convert_sbx(code) return ((code>>14) & 0x3ffff) - (((1<<18)-1)>>1) end
    local function unpack_with_nils (t, n, i)
        i = i or 1
        if (i <= n) then
            return t[i], unpack_with_nils(t, n, i+1)
        end
    end
    local function get_param_range(a, b)
        local param_start = a + 1
        local param_end = (b == 0) and top or (a + b - 1)
        assert(param_start<=param_end,"invalid parameter range")
        assert(r[a] ~= nil,"callee should not be null")
        return param_start, param_end
    end
    local function call(a, b, c)
        local nresult = c
        local param = {}
        local nparam
        if b ~= 1 then
            -- there are (B-1) parameters
            local param_start, param_end = get_param_range(a, b)
            nparam = param_end - param_start + 1
            for i=param_start,param_end do
                table.insert(param,r[i])
            end
        elseif b == 1 then
            nparam = 0
        end

        -- workaround for builtin functions
        local results = {r[a](unpack_with_nils(param, nparam))}
        -- don't save any values for nresult == 1
        if nresult == 0 then
            -- if nresult is 0, then multiple return results are saved
            for i=a,a+#results - 1 do
                r[i] = results[i-a+1]
            end
            top = a + #results - 1 -- set top to last register
        elseif nresult > 1 then
            -- if nresult is 2 or more, nresult - 1 return values are saved
            for i = 0, nresult - 2 do
                r[a+i] = results[i+1]
            end
            top = func.max_stack
        end
    end
    -- bytecode dispatch table
    local dispatch = {
        -- MOVE 
        [1] = function(a,b,c) 
            r[a] = r[b]
        end,
        -- LOADK
        [2] = function(a,bx)
            r[a] = const[bx]
        end,
        -- LOADKX
        [3] = function(a,bx)
            pc = pc + 1
            r[a] = const[decode_instr(func.code[pc]).operand.ax] -- index has to be AX of next instruction (which is EXTRAARG)
        end,
        -- LOADBOOL
        [4] = function(a,b,c)
            r[a] = (b~=0) 
            if c ~= 0 then
                pc = pc+1
            end
        end,
        -- LOADNIL
        [5] = function(a,b,c)
            for i=a,a+b do
                r[i] = nil
            end
        end,
        --GETUPVAL
        [6] = function(a,b,c)
            r[a] =  upvalue[b]
        end,
        --GETTABUP
        [7] = function(a,b,c)
            r[a] = upvalue[b][rk(c)]
        end,
        --GETTABLE
        [8] = function(a,b,c)
          r[a] = r[b][rk(c)]
        end,
        --SETTABUP
        [9] = function(a,b,c)
            upvalue[a][rk(b)]  = rk(c)
        end,
        --SETUPVAL
        [10] = function(a,b,c)
            upvalue[b] = r[a]
        end,
        --SETTABLE
        [11] = function(a,b,c)
            r[a][rk(b)] = rk(c)
        end,
        --NEWTABLE
        [12] = function(a,b,c)
            r[a] = {}
        end,
        --SELF
        [13] = function(a,b,c)
            r[a+1] = r[b]
            r[a] = r[b][rk(c)]
        end,
        --ADD
        [14] = function(a,b,c)
            r[a] = rk(b) + rk(c)
        end,
        --SUB
        [15] = function(a,b,c)
            r[a] = rk(b) - rk(c)
        end,
        --MUL
        [16] = function(a,b,c)
            r[a] = rk(b) * rk(c)
        end,
        --MOD
        [17] = function(a,b,c)
            r[a] = rk(b) % rk(c)
        end,
        --POW
        [18] = function(a,b,c)
            r[a] = rk(b) ^ rk(c)
        end,
        --DIV
        [19] = function(a,b,c)
            r[a] = rk(b) / rk(c)
        end,
        --IDIV
        [20] = function(a,b,c)
            r[a] = rk(b) // rk(c)
        end,
        --BAND
        [21] = function(a,b,c)
            r[a] = rk(b) & rk(c)
        end,
        --BOR
        [22] = function(a,b,c)
            r[a] = rk(b) | rk(c)
        end,
        --BXOR
        [23] = function(a,b,c)
            r[a] = rk(b) ~ rk(c)
        end,
        --SHL
        [24] = function(a,b,c)
            r[a] = rk(b) << rk(c)
        end,
        --SHR
        [25] = function(a,b,c)
            r[a] = rk(b) >> rk(c)
        end,
        --UNM
        [26] = function(a,b,c)
            r[a] = -r[b]
        end,
        --BNOT
        [27] = function(a,b,c)
            r[a] = ~r[b]
        end,
        --NOT
        [28] = function(a,b,c)
            r[a] = not r[b]
        end,
        -- LEN
        [29] = function(a,b,c) 
            r[a] = #r[b]
        end,
        -- CONCAT
        [30] = function(a,b,c)
            r[a] = table.concat(r, "", b, c)
        end,
        -- JMP
        [31] = function(a,sbx)
            pc = pc + sbx
        end,
        -- EQ
        [32] = function(a,b,c)
            if (rk(b) == rk(c)) ~= (a~=0) then
                pc = pc + 1 
            end
        end,
        -- LT
        [33] = function(a,b,c)  
            if (rk(b) < rk(c)) ~= (a~=0) then
                pc = pc + 1 
            end
        end,
        -- LE
        [34] = function(a,b,c) 
            if (rk(b) <= rk(c)) ~= (a~=0) then
                pc = pc + 1
            end
        end,
        -- TEST
        [35] = function(a,b,c)
            -- Lua bytecode reference on OP_TEST is wrong, see https://github.com/dibyendumajumdar/ravi/issues/184
            if (r[a] and 1 or 0) ~= c then
                pc = pc + 1
            end
        end,
        -- TESTSET
        [36] = function(a,b,c)
            -- Lua bytecode reference on OP_TESTSET is wrong, see https://github.com/dibyendumajumdar/ravi/issues/184
            if (r[b] and 1 or 0) ~= c then
                pc = pc + 1
            else
                r[a] = r[b]
            end
        end,
        -- CALL
        [37] = call,
        -- TAILCALL
        [38] = function(a,b,c)
            -- dealing with builtin/foreign functions, no closure data associated with a function
            if closures_data[r[a]] == nil then
                call(a, b, c) -- make a normal call since we can't process that function
            else
                func = closures_data[r[a]].proto
                upvalue = closures_data[r[a]].upvalue

                if b ~= 1 then
                    -- there are (B-1) parameters
                    local param_start, param_end = get_param_range(a, b)
                    local nparam = param_end - param_start
                    -- replace registers on the stack with function arguments
                    for i = 0, nparam do
                        r[i] = r[param_start + i]
                    end
                    for i = nparam + 1, top do
                        r[i] = nil
                    end
                end
                -- update or reset the execution variables

                pc = 0 -- this will be incremented in the main loop so PC at the next instruction will be 1
                const = {}
                return_val = {}
                top = func.max_stack
                for i=0,func.const_list_size-1 do
                    const[i] = func.const[i]
                end
            end
        end,
        -- RETURN
        [39] = function(a,b,c) 
            if b ~= 1 then
                local ret_start = a
                local ret_end = (b==0) and (top) or (b+a-2)
                assert(ret_start<=ret_end,"invalid return result range")
                for i=ret_start,ret_end do
                    table.insert(return_val,r[i])
                end
            end
            flow_stop = true
        end,
        -- FORLOOP
        [40] = function(a,sbx) 
            local step = r[a+2]
            local idx = r[a] + step
            local limit = r[a+1]
            if (0<step and idx<=limit ) or (step<0 and limit<=idx) then
                pc = pc + sbx
                r[a] = idx
                r[a+3] = idx
            end
        end,
        -- FORPREP
        [41] = function(a,sbx) 
            r[a] = r[a] - r[a+2]
            pc = pc + sbx
        end,
        -- TFORCALL
        [42] = function(instr) error("not implemented yet") end,
        -- TFORLOOP
        [43] = function(instr) error("not implemented yet") end,
        -- SETLIST
        [44] = function(a,b,c) 
            local nelement = b
            local c = c
            if c==0 then
                pc = pc + 1
                c = decode_instr(func.code[pc]).operand.ax -- c has to be AX of next instruction (which is EXTRAARG)
            end
            local fpf = runtime.fpf -- fields per flush (default 50)
            if nelement == 0 then
                for i=1,top-a do
                    r[a][(c-1)*fpf+i] = r[a+i]
                end
            else
                for i=1,nelement do
                    r[a][(c-1)*fpf+i] = r[a+i]
                end
            end
        end,
        -- CLOSURE
        [45] = function(a,bx) 
            local proto = func.proto[bx]
            local newupvalue = setmetatable({}, {
                __index = function(o,i)
                    if proto.upvalue[i].instack == 1 then
                        return r[proto.upvalue[i].index]
                    else
                        return upvalue[proto.upvalue[i].index]
                    end
                end,
                __newindex = function(o,i,v)
                    if proto.upvalue[i].instack == 1 then
                        r[proto.upvalue[i].index] = v
                    else
                        upvalue[proto.upvalue[i].index] = v
                    end
                end
            })
            r[a] = function(...)
                proto.args = table.pack(...)
                return runtime.exec_bytecode(proto, newupvalue)
            end
            closures_data[r[a]] = {proto = proto, upvalue = newupvalue}
        end,
        -- VARARG
        [46] = function(a,b,c) error("not implemented yet") end,
        -- EXTRAARG - shouldn't ever be reached in normal execution as it's essentially used as an
        -- extra data opcode, not an instruction opcode, and is emitted only after SETLIST if C == 0
        [47] = function(ax) error("EXTRAARG executed as normal instruction") end,
    }

    -- setup environment
    for i=0,func.const_list_size-1 do
        const[i] = func.const[i]
    end

    for i=0, #func.args-1 do
        r[i] = func.args[i+1]
    end

    -- do execution
    while pc <= func.code_size do
        local instr = decode_instr(func.code[pc])
        local ok, err
        if instr.mode == "iABC" then
            ok, err = pcall(dispatch[instr.instr_id],instr.operand.a,instr.operand.b,instr.operand.c)
        elseif instr.mode == "iABx" then
            ok, err = pcall(dispatch[instr.instr_id],instr.operand.a,instr.operand.bx)
        elseif instr.mode == "iAsBx" then
            ok, err = pcall(dispatch[instr.instr_id],instr.operand.a,instr.operand.sbx)
        elseif instr.mode == "iAx" then
            ok, err = pcall(dispatch[instr.instr_id],instr.operand.ax)
        else
            error("should never reach here:(")    
        end
        
        if not ok then
          error("line " .. func.line[pc] .. "(" .. (err and err or "") .. ")")
        end

        if flow_stop then
            return table.unpack(return_val)
        end
        pc = pc + 1
    end

    return nil
end

return runtime