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
require("util")
parser = {}

---------------------------------------------------------------------------------
-- Type converter
---------------------------------------------------------------------------------
local convert_from = {} 
local convert_to = {}

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

convert_from["double"] = convert_from_double

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

convert_from["single"] = convert_from_single

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

convert_from["int"] = function(x)
 	return convert_from_int(x, 4) 
end

convert_from["long long"] = convert_from_int

convert_to["double"] = function(x)
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

convert_to["single"] = function(x)
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

convert_to["int"] = function(x, size_int)
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

convert_to["long long"] = convert_to["int"]

---------------------------------------------------------------------------------
-- Main parsing logic
---------------------------------------------------------------------------------
function parser.parse_bytecode(chunk)
	local idx = 1
	local previdx, len

	local function read_byte()
		previdx = idx
		idx = idx + 1
		return string.byte(chunk, previdx)
	end


	local function read_buf(size, notreverse)
		previdx = idx
		idx = idx + size
		local b = string.sub(chunk, idx - size, idx - 1)
		if util.config.endianness == 1 or notreverse then
	  		return b
		else
	  		return string.reverse(b)
		end
	end

	-- magic number
	len = string.len("\27Lua")
	if string.sub(chunk, 1, len) ~= "\27Lua" then
		error("invalid lua bytecode file magic number")
	end
	idx = idx + len

	-- version 
	if read_byte() ~= 83 then
		error("invlaid version")
	end

	-- format 
	if read_byte() ~= 0 then
		error("invalid format")
	end

	-- lua data
	if read_buf(string.len("\25\147\r\n\26\n"), true)~= "\25\147\r\n\26\n" then
		error("luac_data incorrect")
	end

	-- size width
	if read_byte() ~= util.config.size_int then
		error("invalid size_int value")
	end

	if read_byte() ~= util.config.size_size_t then
		error("invalid size_t")
	end

	if read_byte() ~= util.config.size_instruction then
		error("invalid instruction")
	end

	if read_byte() ~= util.config.size_lua_Integer then
		error("invalid lua integer")
	end

	if read_byte() ~= util.config.size_lua_Number then
		error("invalid lua number")
	end

	-- endianness
	read_buf(8)

	-- float format
	read_buf(8)

	-- global closure nupvalues
	read_byte()

	local function read_function(funcname, level)
		local func = {
			stat={},
			source53 = {
				val=nil,
				len=nil,
				islngstr=nil,
			},
			line_defined=nil,
			last_line_defined=nil,

			num_params = nil,
			is_vararg = nil,
			max_stack = nil,
			args = {},

			code_size = nil,
			code = {},

			const_list_size = nil,
			const ={},

			upvalue_size = nil,
			upvalue = {},

			proto_size = nil,
			proto = {},

			line_size = nil,
			line = {},

			localvar_size = nil,
			localvar = {},
		}

		local function read_int()
		local x = read_buf(util.config.size_int)
		if not x then
			error("could not load integer")
		else
			local sum = 0
			for i = util.config.size_int, 1, -1 do
			sum = sum * 256 + string.byte(x, i)
			end

			if string.byte(x, util.config.size_int) > 127 then
			sum = sum - math.ldexp(1, 8 * util.config.size_int)
			end
			if sum < 0 then error("bad integer") end
			return sum
		end
		end

		local function read_size()
		local x = read_buf(util.config.size_size_t)
		if not x then
			return
		else
			local sum = 0
			for i = util.config.size_size_t, 1, -1 do
			sum = sum * 256 + string.byte(x, i)
			end
			return sum
		end
		end

		local function read_integer()
			local x = read_buf(util.config.size_lua_Integer)
			if not x then
				error("could not load lua_Integer")
			else
				local convert_func = convert_from[util.config.integer_type]
				if not convert_func then
					error("could not find conversion function for lua_Integer")
				end
				return convert_func(x)
			end
		end

		local function read_num()
			local x = read_buf(util.config.size_lua_Number)
			if not x then
				error("could not load lua_Number")
			else
				local convert_func = convert_from[util.config.number_type]
				if not convert_func then
					error("could not find conversion function for lua_Number")
				end
				return convert_func(x)
			end
		end

		local function read_string()
			local len = read_byte()
			local islngstr = nil
			if not len then
				error("could not load String")
				return
			end
			if len == 255 then
				len = read_size()
				islngstr = true
			end
			if len == 0 then     
				return nil, len, islngstr
			end
			if len == 1 then
				return "", len, islngstr
			end

			local s = string.sub(chunk, idx, idx + len - 2)
			idx = idx + len - 1
			return s, len, islngstr
		end

		local function read_string53()
			local str = {}
			str.val, str.len, str.islngstr = read_string()
			return str
		end

		local function get_const_val(t)
			-- nil
			if t == 0 then return nil
			-- bool
			elseif t == 1 then if read_byte() == 0 then return false else return true end
			-- float num
			elseif t == (3|(0<<4)) then return read_num()
			-- int num
			elseif t == (3|(1<<4)) then return read_integer()
			-- short/long um
			elseif t == (4|(0<<4)) or t == (4|(1<<4)) then return read_string53().val
			else error("bad constant type "..t.." at "..previdx)
			end
		end

		-- source file 
		func.source53 = read_string53()
		if func.source == nil and level == 1 then func.source = funcname end

		-- line where the function was defined
		func.line_defined = read_int()
		func.last_line_defined = read_int()

		-- parameters and varargs
		func.num_params = read_byte()
		func.is_vararg = read_byte()
		func.max_stack = read_byte()

		-- code
		func.code_size = read_int()
		for i = 1, func.code_size do
			local val = read_buf(util.config.size_instruction)
			assert(#val == 4 and type(val)=="string","expect 32 bits bytecode consumed")
			val =  	(string.byte(val,1) << 0)  | 
					(string.byte(val,2) << 8)  |
					(string.byte(val,3) << 16) |
					(string.byte(val,4) << 24)
			assert(type(val)=="number","require number but got"..type(val))
			func.code[i] = val			
		end   
		-- constant
		func.const_list_size = read_int()
		for i = 0, func.const_list_size-1 do
			local t = read_byte()
			func.const[i] = get_const_val(t)
		end 

		-- upvalue
		func.upvalue_size = read_int()
		for i = 0, func.upvalue_size-1 do
			func.upvalue[i] = {instack = read_byte(), index = read_byte(),name53 =nil}
		end

		-- prototype
		func.proto_size = read_int()
		for i = 0, func.proto_size-1 do
			func.proto[i] = read_function(func.source53.val, level + 1)
		end

		-- line
		func.line_size = read_int()
		for i=0, func.line_size-1 do
			func.line[i] = read_int()
		end

		-- local 
		func.size_localvar = read_int()
		for i = 0, func.size_localvar-1 do
			func.localvar[i] = {varname=read_string53(),start_pc = read_int(), end_pc =read_int()}
		end    

		-- upvalue name
		assert(read_int() == func.upvalue_size,"mismatch upvalue size and upvalue name size")
		for i = 0, func.upvalue_size-1 do
			func.upvalue[i].name53 = read_string53()
		end

		return func
	end

	local func = read_function("chunk", 1)
	if (#chunk+1) ~= idx then error("should eof") end
	return func
end


return parser