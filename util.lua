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
        print(string.format("[%d]",op_num+1),k,a,b,c)
        return {instr_name=k,instr_id=op_num+1,mode="iABC",operand={a=a,b=b,c=c}}
    elseif v == util.iABx then
        local a,bx = ((code>>6) & 0xff), ((code>>14) & 0x3ffff)
        print(string.format("[%d]",op_num+1),k,a,bx)
        return {instr_name=k,instr_id=op_num+1,mode="iABx",operand={a=a,bx=bx}}
    elseif v == util.iAsBx then
        local a,sbx = ((code>>6) & 0xff), ((code>>14) & 0x3ffff) - (((1<<18)-1)>>1)
        print(string.format("[%d]",op_num+1),k,a,sbx)
        return {instr_name=k,instr_id=op_num+1,mode="iAsBx",operand={a=a,sbx=sbx}}
    elseif v == util.iAx then
        local ax = (code>>6) & 0x3ffffff
        print(string.format("[%d]",op_num+1),k,ax)
        return {instr_name=k,instr_id=op_num+1,mode="iAx",operand={ax=ax}}
    else
        error("invalid opcode mode")
    end
end

---------------------------------------------------------------------------------
-- Type converter
---------------------------------------------------------------------------------
util.convert_from = {} 
util.convert_to = {}

function grab_byte(v)
  	return math.floor(v / 256), string.char(math.floor(v) % 256)
end

local function convert_from_double(x)
	local sign = 1
	local mantissa = string.byte(x, 7) % 16
	for i = 6, 1, -1 do mantissa = mantissa * 256 + string.byte(x, i) end
	if string.byte(x, 8) > 127 then sign = -1 end
	local exponent = (string.byte(x, 8) % 128) * 16 +
					math.floor(string.byte(x, 7) / 16)
	if exponent == 0 then return 0.0 end
	mantissa = (math.ldexp(mantissa, -52) + 1.0) * sign
	return math.ldexp(mantissa, exponent - 1023)
end

util.convert_from["double"] = convert_from_double

local function convert_from_single(x)
	local sign = 1
	local mantissa = string.byte(x, 3) % 128
	for i = 2, 1, -1 do mantissa = mantissa * 256 + string.byte(x, i) end
	if string.byte(x, 4) > 127 then sign = -1 end
	local exponent = (string.byte(x, 4) % 128) * 2 +
					math.floor(string.byte(x, 3) / 128)
	if exponent == 0 then return 0.0 end
	mantissa = (math.ldexp(mantissa, -23) + 1.0) * sign
	return math.ldexp(mantissa, exponent - 127)
end

util.convert_from["single"] = convert_from_single

local function convert_from_int(x, size_int)
	size_int = size_int or 8
	local sum = 0
	local highestbyte = string.byte(x, size_int)
	-- test for negative number
	if highestbyte <= 127 then
		sum = highestbyte
	else
		sum = highestbyte - 256
	end
	for i = size_int-1, 1, -1 do
		sum = sum * 256 + string.byte(x, i)
	end
	return sum
end

util.convert_from["int"] = function(x)
 	return convert_from_int(x, 4) 
end

util.convert_from["long long"] = convert_from_int

util.convert_to["double"] = function(x)
	local sign = 0
	if x < 0 then sign = 1; x = -x end
	local mantissa, exponent = math.frexp(x)
	if x == 0 then -- zero
		mantissa, exponent = 0, 0
	else
		mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, 53)
		exponent = exponent + 1022
	end
	local v, byte = "" -- convert to bytes
	x = mantissa
	for i = 1,6 do
		x, byte = grab_byte(x); v = v..byte -- 47:0
	end
	x, byte = grab_byte(exponent * 16 + x); v = v..byte -- 55:48
	x, byte = grab_byte(sign * 128 + x); v = v..byte -- 63:56
	return v
end

util.convert_to["single"] = function(x)
	local sign = 0
	if x < 0 then sign = 1; x = -x end
	local mantissa, exponent = math.frexp(x)
	if x == 0 then -- zero
		mantissa = 0; exponent = 0
	else
		mantissa = (mantissa * 2 - 1) * math.ldexp(0.5, 24)
		exponent = exponent + 126
	end
	local v, byte = "" -- convert to bytes
	x, byte = grab_byte(mantissa); v = v..byte -- 7:0
	x, byte = grab_byte(x); v = v..byte -- 15:8
	x, byte = grab_byte(exponent * 128 + x); v = v..byte -- 23:16
	x, byte = grab_byte(sign * 128 + x); v = v..byte -- 31:24
	return v
end

util.convert_to["int"] = function(x, size_int)
	size_int = size_int or config.size_lua_Integer or 4
	local v = ""
	x = math.floor(x)
	if x >= 0 then
		for i = 1, size_int do
			v = v..string.char(x % 256); x = math.floor(x / 256)
		end
	else-- x < 0
		x = -x
		local carry = 1
		for i = 1, size_int do
			local c = 255 - (x % 256) + carry
			if c == 256 then c = 0; carry = 1 else carry = 0 end
			v = v..string.char(c); x = math.floor(x / 256)
		end
	end
	return v
end

util.convert_to["long long"] = util.convert_to["int"]

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
}

util.config.SIGNATURE    = "\27Lua"
util.config.LUAC_DATA    = "\25\147\r\n\26\n" 
util.config.LUA_TNIL     = 0
util.config.LUA_TBOOLEAN = 1
util.config.LUA_TNUMBER  = 3
util.config.LUA_TNUMFLT  = util.config.LUA_TNUMBER | (0 << 4)
util.config.LUA_TNUMINT  = util.config.LUA_TNUMBER | (1 << 4)
util.config.LUA_TSTRING  = 4
util.config.LUA_TSHRSTR  = util.config.LUA_TSTRING | (0 << 4)
util.config.LUA_TLNGSTR  = util.config.LUA_TSTRING | (1 << 4)
util.config.VERSION      = 83
util.config.FORMAT       = 0 
util.config.FPF          = 50

---------------------------------------------------------------------------------
-- Debug support
---------------------------------------------------------------------------------
util.print_upvalue = function(func)
	print("instack","index","name")
	for i=0,func.upvalue_size-1 do
		print(func.upvalue[i].instack,func.upvalue[i].index,func.upvalue[i].name53.val)
	end
end

return util