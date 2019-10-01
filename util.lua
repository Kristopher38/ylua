------------------------------------------------------------------
-- YLua: A Lua metacircular virtual machine written in lua
-- 
-- NOTE that bytecode parser was derived from ChunkSpy5.3 
--
-- kelthuzadx<1948638989@qq.com>  Copyright (c) 2019 kelthuyang
------------------------------------------------------------------
util = {}


------------------------------------------------------------------
-- Opcode table
------------------------------------------------------------------
util.iABC, util.iABx, util.iAsBx, util.iAx, isJ = 0, 1, 2, 3 , 4
util.opcode = { 
	[1]={ OP_MOVE =   iABC },
	[2]={ OP_LOADI =   iAsBx },
	[3]={ OP_LOADF =   iAsBx },
	[4]={ OP_LOADK =   iABx },
	[5]={ OP_LOADKX =   iABx },
	[6]={ OP_LOADBOOL =   iABC },
	[7]={ OP_LOADNIL =   iABC },
	[8]={ OP_GETUPVAL =   iABC },
	[9]={ OP_SETUPVAL =   iABC },
	[10]={ OP_GETTABUP =   iABC },
	[11]={ OP_GETTABLE =   iABC },
	[12]={ OP_GETI =   iABC },
	[13]={ OP_GETFIELD =   iABC },
	[14]={ OP_SETTABUP =   iABC },
	[15]={ OP_SETTABLE =   iABC },
	[16]={ OP_SETI =   iABC },
	[17]={ OP_SETFIELD =   iABC },
	[18]={ OP_NEWTABLE =   iABC },
	[19]={ OP_SELF =   iABC },
	[20]={ OP_ADDI =   iABC },
	[21]={ OP_ADDK =   iABC },
	[22]={ OP_SUBK =   iABC },
	[23]={ OP_MULK =   iABC },
	[24]={ OP_MODK =   iABC },
	[25]={ OP_POWK =   iABC },
	[26]={ OP_DIVK =   iABC },
	[27]={ OP_IDIVK =   iABC },
	[28]={ OP_BANDK =   iABC },
	[29]={ OP_BORK =   iABC },
	[30]={ OP_BXORK =   iABC },
	[31]={ OP_SHRI =   iABC },
	[32]={ OP_SHLI =   iABC },
	[33]={ OP_ADD =   iABC },
	[34]={ OP_SUB =   iABC },
	[35]={ OP_MUL =   iABC },
	[36]={ OP_MOD =   iABC },
	[37]={ OP_POW =   iABC },
	[38]={ OP_DIV =   iABC },
	[39]={ OP_IDIV =   iABC },
	[40]={ OP_BAND =   iABC },
	[41]={ OP_BOR =   iABC },
	[42]={ OP_BXOR =   iABC },
	[43]={ OP_SHL =   iABC },
	[44]={ OP_SHR =   iABC },
	[45]={ OP_MMBIN =   iABC },
	[46]={ OP_MMBINI=   iABC },
	[47]={ OP_MMBINK=   iABC },
	[48]={ OP_UNM =   iABC },
	[49]={ OP_BNOT =   iABC },
	[50]={ OP_NOT =   iABC },
	[51]={ OP_LEN =   iABC },
	[52]={ OP_CONCAT =   iABC },
	[53]={ OP_CLOSE =   iABC },
	[54]={ OP_TBC =   iABC },
	[55]={ OP_JMP =   isJ  },
	[56]={ OP_EQ =   iABC },
	[57]={ OP_LT =   iABC },
	[58]={ OP_LE =   iABC },
	[59]={ OP_EQK =   iABC },
	[60]={ OP_EQI =   iABC },
	[61]={ OP_LTI =   iABC },
	[62]={ OP_LEI =   iABC },
	[63]={ OP_GTI =   iABC },
	[64]={ OP_GEI =   iABC },
	[65]={ OP_TEST =   iABC },
	[66]={ OP_TESTSET =   iABC },
	[67]={ OP_CALL =   iABC },
	[68]={ OP_TAILCALL =   iABC },
	[69]={ OP_RETURN =   iABC },
	[70]={ OP_RETURN0 =   iABC },
	[71]={ OP_RETURN1 =   iABC },
	[72]={ OP_FORLOOP =   iABx },
	[73]={ OP_FORPREP =   iABx },
	[74]={ OP_TFORPREP =   iABx },
	[75]={ OP_TFORCALL =   iABC },
	[76]={ OP_TFORLOOP=   iABx },
	[77]={ OP_SETLIST =   iABC },
	[78]={ OP_CLOSURE =   iABx },
	[79]={ OP_VARARG =   iABC },
	[80]={ OP_VARARGPREP =   iABC },
	[81]={ OP_EXTRAARG =   iAx  },
}

------------------------------------------------------------------
-- Code converter
------------------------------------------------------------------
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

------------------------------------------------------------------
-- Global configurations
------------------------------------------------------------------
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

return util