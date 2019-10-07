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
runtime={
    debug = false,
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

function runtime.exec_bytecode(func,upvalue)
    -- execution environmnet
    local pc = 1
    local r ={}
    local const = {}
    local flow_stop = false
    local return_val = {}

    -- auxiliary functions(should factor to oop styles)
    local function rk(index) if index>=256 then return const[index-256] else return r[index] end end
    local function convert_sbx(code) return ((code>>14) & 0x3ffff) - (((1<<18)-1)>>1) end
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
            r[a] = const[bx]
            pc = pc + 1
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
            for i=a,b do
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
            r[a] = rk(b) * rk(c)
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
            local res = ""
            for i=b,c do
                res = res..r[i]
            end
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
            if not (r[a]~= c) then
                pc = pc + 1
            end
        end,
        -- TESTSET
        [36] = function(a,b,c)
            if r[b] ~= c then
                r[a] = r[b]
            else
                pc = pc +1
            end
        end,
        -- CALL
        [37] = function(a,b,c) 
            local nparam = b
            local nresult = c
            local param = {}
            if nparam ~= 1 then
                 -- there are (B-1) parameters
                local param_start = a + 1
                local param_end = (b == 0) and #r or (a + b - 1)
                assert(param_start<=param_end,"invalid parameter range")
                assert(r[a] ~= nil,"callee should not be null")
                for i=param_start,param_end do
                    table.insert(param,r[i])
                end            
            end

            if nresult == 0 then
                -- if nresult is 0, then multiple return results are saved
                local ret = r[a](table.unpack(param))
                for i=a,a+#ret - 1 do
                    r[i] = ret[i-a+1]
                end
                for i=a+#ret,#r do
                    r[i] = nil
                end
            elseif nresult == 1 then
                -- if nresult is 1, no return results are saved
                r[a](table.unpack(param))
            else
                -- if nresult is 2 or more, return values are saved
                local result = r[a](table.unpack(param))
                r[a] = result[1]
            end
        end,
        -- TAILCALL
        [38] = function(a,b,c) error("not implemented yet") end,
        -- RETURN
        [39] = function(a,b,c) 
            local ret_start = a
            local ret_end = (b==0) and (#r) or (b+a-2)
            assert(ret_start<=ret_start,"invalid return result range")
            for i=ret_start,ret_end do
                table.insert(return_val,r[i])
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
                c = code[pc+1]
            end
            if nelement == 0 then
                for i=1,#r-a do --FPF 50
                    r[a][(c-1)*50+i] = r[a+i]
                end
            else
                for i=1,nelement do
                    r[a][(c-1)*50+i] = r[a+i]
                end
            end
        end,
        -- CLOSURE
        [45] = function(a,bx) 
            local proto = func.proto[bx]
            local newupvalue = setmetatable({
                [0]=upvalue[0]
            },{
                __index = function(o,i)
                    if func.upvalue[i-1].instack == 0 then
                        return r[func.upvalue[i-1].index]
                    else
                        return upvalue[func.upvalue[i-1].index]
                    end
                end,
                __newindex = function(o,i,v)
                    if func.upvalue[i-1].instack == 0 then
                        r[func.upvalue[i-1].index] = v
                    else
                        upvalue[func.upvalue[i-1].index] = v
                    end
                end
            })
            r[a] = function(...)
                proto.args = table.pack(...)
                return runtime.exec_bytecode(proto, newupvalue)
            end
        end,
        -- VARARG
        [46] = function(a,b,c) error("not implemented yet") end,
        -- EXTRAARG
        [47] = function(ax) error("not implemented yet") end,
    }

    -- setup environment
    for i=0,func.const_list_size-1 do
        const[i] = func.const[i]
    end
    assert(func.num_params == #func.args, "unexpect arguments passed")
    for i=0, func.num_params-1 do
        r[i] = func.args[i+1]
    end

    -- do execution
    while pc <= func.code_size do
        local instr = decode_instr(func.code[pc])
        if instr.mode == "iABC" then
            dispatch[instr.instr_id](instr.operand.a,instr.operand.b,instr.operand.c)
        elseif instr.mode == "iABx" then
            dispatch[instr.instr_id](instr.operand.a,instr.operand.bx)
        elseif instr.mode == "iAsBx" then
            dispatch[instr.instr_id](instr.operand.a,instr.operand.sbx)
        elseif instr.mode == "iAx" then
            dispatch[instr.instr_id](instr.operand.ax)
        else
            error("should never reach here:(")    
        end
        
        if flow_stop then
            return return_val
        end
        pc = pc + 1
    end

    return nil
end

return runtime