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
    stacktrace = {}
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

local function shallowCompare(obj1, obj2)
	for k, v in pairs(obj1) do
		if obj2[k] == nil or obj2[k] ~= v then
			return false
		end
	end
	return true
end

local closures_data = {}
function runtime.exec_bytecode(func, upvalues, stacklevel)
    -- execution environmnet
    local pc = 1
    func.r = setmetatable({ isupval = {}, data = {} }, {
        __index = function(self, idx)
            if self.isupval[idx] then
                if self.data[idx] then
                    return self.data[idx][1]
                else
                    return nil
                end
            else
                return self.data[idx]
            end
        end,
        __newindex = function(self, idx, val)
            if self.isupval[idx] then
                if self.data[idx] then
                    self.data[idx][1] = val
                else
                    self.data[idx] = {val}
                end
            else
                self.data[idx] = val
            end
        end,
    })
    local r = func.r

    -- set up which variables on the stack should be upvalues
    for i, proto in pairs(func.proto) do
        for _, upvalue in pairs(proto.upvalue) do
            if upvalue.instack == 1 then
                r.isupval[upvalue.index] = true
            end
        end
    end

    local const = {}
    local flow_stop = false
    local return_val = { n = 0 }
    local top = func.max_stack
    local st = runtime.stacktrace
    stacklevel = stacklevel or 1

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
        -- if b == 0 param_end can be 1 less than param_start signifying no vararg parameters so it shouldn't throw an assertion
        if b ~= 0 then
            assert(param_start<=param_end,"invalid parameter range")
        end
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
            for i = 1, nparam do
                param[i] = r[i + param_start - 1]
            end
        elseif b == 1 then
            nparam = 0
        end

        -- workaround for builtin functions
        local results = table.pack(r[a](unpack_with_nils(param, nparam)))
        -- don't save any values for nresult == 1
        if nresult == 0 then
            -- if nresult is 0, then multiple return results are saved
            for i=a,a+results.n - 1 do
                r[i] = results[i-a+1]
            end
            if results.n == 0 then
                top = a - 1
            else
                top = math.max(a + results.n - 1, 0)
            end
            -- clear the registers which follow the returned values since if we're tailcalling C function we don't know how many values it returns,
            -- but values in registers following the call instruction shouldn't (?) be reused so it's safe (?) to clear them
            for i = a+results.n, top do
                r[i] = nil
            end
        elseif nresult > 1 then
            -- if nresult is 2 or more, nresult - 1 return values are saved
            for i = 0, nresult - 2 do
                r[a+i] = results[i+1]
            end
        end
        if nresult >= 1 then
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
                pc = pc + 1
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
            r[a] =  upvalues[b][1]
        end,
        --GETTABUP
        [7] = function(a,b,c)
            r[a] = upvalues[b][1][rk(c)]
        end,
        --GETTABLE
        [8] = function(a,b,c)
          r[a] = r[b][rk(c)]
        end,
        --SETTABUP
        [9] = function(a,b,c)
            upvalues[a][1][rk(b)] = rk(c)
        end,
        --SETUPVAL
        [10] = function(a,b,c)
            upvalues[b][1] = r[a]
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
            top = func.max_stack
        end,
        -- JMP
        [31] = function(a,sbx)
            pc = pc + sbx
            -- close (in our case, reset registers) upvalues >= A - 1
            if a ~= 0 then
                for i = a - 1, top do
                    r.data[i] = nil
                end
            end
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
                upvalues = closures_data[r[a]].upvalues
                func.args = {}

                if b ~= 1 then
                    -- there are (B-1) parameters
                    local param_start, param_end = get_param_range(a, b)
                    local nparam = param_end - param_start
                    -- replace registers on the stack with function arguments
                    for i = 0, nparam do
                        r[i] = r[param_start + i]
                        func.args[i + 1] = r[param_start + i]
                    end
                    func.args.n = nparam + 1
                    for i = nparam + 1, top do
                        r[i] = nil
                    end
                end
                -- update or reset the execution variables

                pc = 0 -- this will be incremented in the main loop so PC at the next instruction will be 1
                const = {}
                return_val = { n = 0 }
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
                local ret_n = ret_end - ret_start + 1
                if b ~= 0 then
                    assert(ret_start<=ret_end,"invalid return result range")
                end
                for i = 1, ret_n do
                    return_val[i] = r[i + ret_start - 1]
                end
                return_val.n = ret_n
            end
            if b > 0 then
                top = func.max_stack
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
        [42] = function(a,b,c)
            local results = {r[a](r[a + 1], r[a + 2])}
            for i = 1, c do
                r[a + i + 2] = results[i]
            end
            top = func.max_stack
        end,
        -- TFORLOOP
        [43] = function(a,sbx)
            if r[a + 1] then
              r[a] = r[a + 1]
              pc = pc + sbx
            end
        end,
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
            top = func.max_stack
        end,
        -- CLOSURE
        [45] = function(a,bx) 
            local proto = func.proto[bx]
            local newupvalue = {}
            proto.parent = func

            for i, upvalue in pairs(proto.upvalue) do
                if upvalue.instack == 1 then
                    newupvalue[i] = r.data[upvalue.index]
                else
                    newupvalue[i] = upvalues[upvalue.index]
                end
            end

            -- test if we've got a cached closure already
            for cached_closure, closure_data in pairs(closures_data) do
                -- cached closure must have the same prototype and the same set of upvalues
                if closure_data.proto == proto and shallowCompare(closure_data.upvalues, newupvalue) then
                    r[a] = cached_closure
                    return
                end
            end

            r[a] = function(...)
                proto.args = table.pack(...)
                return runtime.exec_bytecode(proto, newupvalue, stacklevel + 1)
            end
            closures_data[r[a]] = {proto = proto, upvalues = newupvalue}
        end,
        -- VARARG
        [46] = function(a,b,c)
            local varargn = func.args.n - func.num_params -- number of variable arguments
            if varargn < 0 then
                varargn = 0
            end
            if b == 0 then
                b = varargn
                top = a + varargn - 1
            end
            for i = 0, b - 1 do
                r[a + i] = func.args[func.num_params + i + 1]
            end
        end,
        -- EXTRAARG - shouldn't ever be reached in normal execution as it's essentially used as an
        -- extra data opcode, not an instruction opcode, and is emitted only after SETLIST if C == 0
        [47] = function(ax) error("EXTRAARG executed as normal instruction") end,
    }

    -- setup environment
    for i=0,func.const_list_size-1 do
        const[i] = func.const[i]
    end

    for i=0, func.args.n-1 do
        r[i] = func.args[i+1]
    end

    -- do execution
    while pc <= func.code_size do
        st[stacklevel] = func.line[pc - 1]
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
            return unpack_with_nils(return_val, return_val.n)
        end
        pc = pc + 1
    end

    return nil
end

return runtime