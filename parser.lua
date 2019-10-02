------------------------------------------------------------------
-- YLua: A Lua metacircular virtual machine written in lua
-- 
-- NOTE that bytecode parser was derived from ChunkSpy5.3 
--
-- kelthuzadx<1948638989@qq.com>  Copyright (c) 2019 kelthuyang
------------------------------------------------------------------

-- Binary bytecode file format
-- file:  
--     1b 4C 75 61       | Lua bytecode signature
--     [u8 version]      | Version number (0x52 for Lua 5.2, etc)
--     [u8 impl]         | Implementation (0 for reference impl)
--     [u8 endian]       | Big-endian flag
--     [u8 intsize]      | Size of integers (usually 4)
--     [u8 size_t]       | Size of pointers
--     [u8 instsize]     | Size of instructions (always 4)
--     [u8 numsize]      | Size of Lua numbers (usually 8)
--     [u8 use_int]      | Use integers instead of floats (usually for embedded)
--     19 93 0D 0A 1A 0A | Lua magic (used to detect presence of EOL conversion)
--     [func main]
-- string:  
--     [size_t size]
--     ... data
--     00
-- func:  
--     [int line_start] | debug info
--     [int line_end]   | debug info
--     [u8 nparams]
--     [u8 varargflags]
--     [u8 nregisters]
--     [int ninstructions]
--     ... instructions:
--         [instsize instruction]
--     [int nconsts]
--     ... consts:
--         [u8 type]
--         type 0: | nil
--         type 1: | bool
--             [u8 value]
--         type 3: | number
--             [numsize value]
--         type 4: | string
--             [string value]
--     [int nprimitives]
--     ... primitives:
--         [func primitive]
--     [int nupvals]
--     ... upvals:
--         [u8 stack]
--         [u8 register]
--     [string source] | debug info
--     [int nlines]
--     ... lines:
--         [int line]
--     [int nlocals]
--     ... locals:
--         [string name] | debug info
--         [int startpc]
--         [int endpc]
--     [int nupvalnames]
--     ... upvalnames:
--         [string name] | debug info
require("util")
parser = {}

local function decode(code)
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
	len = string.len(util.config.SIGNATURE)
	if string.sub(chunk, 1, len) ~= util.config.SIGNATURE then
		error("invalid lua bytecode file magic number")
	end
	idx = idx + len

	-- version 
	if read_byte() ~= util.config.VERSION then
		error("invlaid version")
	end

	-- format 
	if read_byte() ~= util.config.FORMAT then
		error("invalid format")
	end

	if read_buf(string.len(util.config.LUAC_DATA), true)~= util.config.LUAC_DATA then
		error("luac_data incorrect")
	end

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
				local convert_func = util.convert_from[util.config.integer_type]
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
				local convert_func = util.convert_from[util.config.number_type]
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
			if t == util.config.LUA_TNIL then
				return nil
			elseif t == util.config.LUA_TBOOLEAN then
				if read_byte() == 0 then return false else return true end
			elseif t == util.config.LUA_TNUMFLT then
				return read_num()
			elseif t == util.config.LUA_TNUMINT then
				return read_integer()
			elseif t == util.config.LUA_TSHRSTR or t == util.config.LUA_TLNGSTR then
				return read_string53()
			else
				error("bad constant type "..t.." at "..previdx)
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
			assert(#val == 4 and type(val)=="string",
			"expect 32 bits bytecode consumed")
			val =  	(string.byte(val,1) << 0)  | 
					(string.byte(val,2) << 8)  |
					(string.byte(val,3) << 16) |
					(string.byte(val,4) << 24)
			assert(type(val)=="number")
			func.code[i] = decode(val)			
		end   
		print("-------")
		-- constant
		func.const_list_size = read_int()
		for i = 1, func.const_list_size do
			local t = read_byte()
			func.const[i] = {type = t,val = get_const_val(t)}
		end 

		-- upvalue
		func.upvalue_size = read_int()
		for i = 1, func.upvalue_size do
			func.upvalue[i] = {instack = read_byte(), index = read_byte(),name53 =nil}
		end

		-- prototype
		func.proto_size = read_int()
		for i = 1, func.proto_size do
			func.proto[i] = read_function(func.source53.val, level + 1)
		end

		-- line
		func.line_size = read_int()
		for i=1,func.line_size do
			func.line[i] = read_int()
		end

		-- local 
		func.size_localvar = read_int()
		for i = 1, func.size_localvar do
			func.localvar[i] = {varname=read_string53(),start_pc = read_int(), end_pc =read_int()}
		end    

		-- upvalue name
		assert(read_int() == func.upvalue_size,"mismatch upvalue size and upvalue name size")
		for i = 1, func.upvalue_size do
			func.upvalue[i].name53 = read_string53()
		end

		return func
	end

	local func = read_function("chunk", 1)
	if (#chunk+1) ~= idx then error("should eof") end
	return func
end


return parser