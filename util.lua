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
util = {}

---------------------------------------------------------------------------------
-- Global configurations
---------------------------------------------------------------------------------
util.config = {
	endianness = 1, 
	size_int = 4,         
	size_size_t = 8,
	size_instruction = 4,
	size_lua_Integer = 8,
	integer_type = "long long",
	size_lua_Number = 8,     
	integral = 0,             
	number_type = "double", 
	debug = false,  
}

util.config.FPF          = 50

---------------------------------------------------------------------------------
-- Opcode table and corresponding operations
---------------------------------------------------------------------------------
util.iABC, util.iABx, util.iAsBx, util.iAx = 0, 1, 2, 3
util.opcode = { 
    [1] = { MOVE = util.iABC },
    [2] = { LOADK = util.iABx },
    [3] = { LOADKX = util.iABx },
    [4] = { LOADBOOL = util.iABC },
    [5] = { LOADNIL = util.iABC },
    [6] = { GETUPVAL = util.iABC },
    [7] = { GETTABUP = util.iABC },
    [8] = { GETTABLE = util.iABC },
    [9] = { SETTABUP = util.iABC },
    [10] = { SETUPVAL = util.iABC },
    [11] = { SETTABLE = util.iABC },
    [12] = { NEWTABLE = util.iABC },
    [13] = { SELF = util.iABC },
    [14] = { ADD = util.iABC },
    [15] = { SUB = util.iABC },
    [16] = { MUL = util.iABC },
    [17] = { MOD = util.iABC },
    [18] = { POW = util.iABC },
    [19] = { DIV = util.iABC }, 
    [20] = { IDIV = util.iABC },
    [21] = { BAND = util.iABC },
    [22] = { BOR = util.iABC },
    [23] = { BXOR = util.iABC },
    [24] = { SHL = util.iABC },
    [25] = { SHR = util.iABC },
    [26] = { UNM = util.iABC },
    [27] = { BNOT = util.iABC },
    [28] = { NOT = util.iABC },
    [29] = { LEN = util.iABC },
    [30] = { CONCAT = util.iABC },
    [31] = { JMP = util.iAsBx },
    [32] = { EQ = util.iABC },
    [33] = { LT = util.iABC },
    [34] = { LE = util.iABC },
    [35] = { TEST = util.iABC },
    [36] = { TESTSET = util.iABC },
    [37] = { CALL = util.iABC },
    [38] = { TAILCALL = util.iABC },
    [39] = { RETURN = util.iABC },
    [40] = { FORLOOP = util.iAsBx },
    [41] = { FORPREP = util.iAsBx },
    [42] = { TFORCALL = util.iABC },
    [43] = { TFORLOOP = util.iAsBx },
    [44] = { SETLIST = util.iABC },
    [45] = { CLOSURE = util.iABx },
    [46] = { VARARG = util.iABC },
    [47] = { EXTRAARG = util.iAx },
}

function util.decode_instr(code)
    local op_num = (code & 0x3f) -- 6bits for instruction id
    if util.opcode[op_num+1] == nil then error("invalid bytecode") end
    local k,v  = next(util.opcode[op_num+1])
    if v == util.iABC then
		local a, c, b = ((code>>6) & 0xff), ((code>>14) & 0x1ff), ((code>>23) & 0x1ff)
		if util.config.debug == true then 
			print(string.format("[%d]",op_num+1),k,a,b,c)		
		end
        return {instr_name=k,instr_id=op_num+1,mode="iABC",operand={a=a,b=b,c=c}}
    elseif v == util.iABx then
        local a,bx = ((code>>6) & 0xff), ((code>>14) & 0x3ffff)
		if util.config.debug == true then 
			print(string.format("[%d]",op_num+1),k,a,bx)
		end
		return {instr_name=k,instr_id=op_num+1,mode="iABx",operand={a=a,bx=bx}}
    elseif v == util.iAsBx then
        local a,sbx = ((code>>6) & 0xff), ((code>>14) & 0x3ffff) - (((1<<18)-1)>>1)
		if util.config.debug == true then 
			print(string.format("[%d]",op_num+1),k,a,sbx)
		end
		return {instr_name=k,instr_id=op_num+1,mode="iAsBx",operand={a=a,sbx=sbx}}
    elseif v == util.iAx then
        local ax = (code>>6) & 0x3ffffff
		if util.config.debug == true then 
			print(string.format("[%d]",op_num+1),k,ax)
		end
		return {instr_name=k,instr_id=op_num+1,mode="iAx",operand={ax=ax}}
    else
        error("invalid opcode mode")
    end
end

---------------------------------------------------------------------------------
-- Debug support
---------------------------------------------------------------------------------
util.print_upvalue = function(func)
	if util.config.debug == false then return end

	print("instack","index","name")
	for i=0,func.upvalue_size-1 do
		print(func.upvalue[i].instack,func.upvalue[i].index,func.upvalue[i].name53.val)
	end
end
util.print_const = function(func)
	if util.config.debug == false then return end

	print("const")
	for i=0,func.const_list_size-1 do
		print(func.const[i])
	end
end

return util