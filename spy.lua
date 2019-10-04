------------------------------------------------------------------------------------------
-- ylua: A Lua metacircular virtual machine written in lua
-- 
-- NOTE that bytecode parser was derived from ChunkSpy5.3
--
-- author: kelthuzadx<1948638989@qq.com>
-- date: 2019/9/29
------------------------------------------------------------------------------------------

config = {
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

config.SIGNATURE    = "\27Lua"
config.LUAC_DATA    = "\25\147\r\n\26\n" 
config.LUA_TNIL     = 0
config.LUA_TBOOLEAN = 1
config.LUA_TNUMBER  = 3
config.LUA_TNUMFLT  = config.LUA_TNUMBER | (0 << 4)
config.LUA_TNUMINT  = config.LUA_TNUMBER | (1 << 4)
config.LUA_TSTRING  = 4
config.LUA_TSHRSTR  = config.LUA_TSTRING | (0 << 4)
config.LUA_TLNGSTR  = config.LUA_TSTRING | (1 << 4)
config.VERSION      = 83 -- 0x53
config.FORMAT       = 0  -- LUAC_FORMAT (new in 5.1)
config.FPF          = 50 -- LFIELDS_PER_FLUSH
config.SIZE_OP      = 6  -- instruction field bits
config.SIZE_A       = 8
config.SIZE_B       = 9
config.SIZE_C       = 9

config.LUA_FIRSTINDEX = 1

config.typestr = {
	[config.LUA_TNIL] = "LUA_TNIL",
	[config.LUA_TBOOLEAN] = "LUA_TBOOLEAN",
	[config.LUA_TNUMFLT] = "LUA_TNUMFLT",
	[config.LUA_TNUMINT] = "LUA_TNUMINT",
	[config.LUA_TSHRSTR] = "LUA_TSHRSTR",
	[config.LUA_TLNGSTR] = "LUA_TLNGSTR",
}

config.DISPLAY_FLAG = true              -- global listing output on/off
config.DISPLAY_BRIEF = nil              -- brief listing style
config.DISPLAY_INDENT = nil             -- indent flag for brief style
config.STATS = nil                      -- set if always display stats
config.DISPLAY_OFFSET_HEX = true        -- use hexadecimal for position
config.DISPLAY_SEP = "  "               -- column separator
config.DISPLAY_COMMENT = "; "           -- comment sign
config.DISPLAY_HEX_DATA = true          -- show hex data column
config.WIDTH_HEX = 8                    -- width of hex data column
config.WIDTH_OFFSET = nil               -- width of position column
config.DISPLAY_LOWERCASE = true         -- lower-case operands
config.WIDTH_OPCODE = nil               -- width of opcode field
config.VERBOSE_TEST = false             -- more verbosity for --test


other_files = {}        -- non-chunks (may be source listings)
arg_other = {}          -- other arguments (for --run option)


convert_from = {}       -- tables for number conversion function lookup
convert_to = {}

function grab_byte(v)
  return math.floor(v / 256), string.char(math.floor(v) % 256)
end
LUANUMBER_ID = {
  ["80"] = "double",         -- IEEE754 double
  ["40"] = "single",         -- IEEE754 single
  ["41"] = "int",            -- int
  ["81"] = "long long",      -- long long
}

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
convert_from["int"] = function(x) return convert_from_int(x, 4) end
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

function WidthOf(n) return string.len(tostring(n)) end
function LeftJustify(s, width) return s..string.rep(" ", width - string.len(s)) end
function ZeroPad(s, width) return string.rep("0", width - string.len(s))..s end

function DisplayInit(chunk_size)
  if not config.WIDTH_OFFSET then config.WIDTH_OFFSET = 0 end
  if config.DISPLAY_OFFSET_HEX then
    local w = string.len(string.format("%X", chunk_size))
    if w > config.WIDTH_OFFSET then config.WIDTH_OFFSET = w end
    if (config.WIDTH_OFFSET % 2) == 1 then
      config.WIDTH_OFFSET = config.WIDTH_OFFSET + 1
    end
  else
    config.WIDTH_OFFSET = string.len(tonumber(chunk_size))
  end

  if config.WIDTH_OFFSET < 4 then config.WIDTH_OFFSET = 4 end
  if not config.DISPLAY_SEP then config.DISPLAY_SEP = "  " end
  if config.DISPLAY_HEX_DATA == nil then config.DISPLAY_HEX_DATA = true end
  if not config.WIDTH_HEX then config.WIDTH_HEX = 8 end
  config.BLANKS_HEX_DATA = string.rep(" ", config.WIDTH_HEX * 2 + 1)

  if not WriteLine then WriteLine = print end
end


function EscapeString(s, quoted)
  local v = ""
  for i = 1, string.len(s) do
    local c = string.byte(s, i)
    -- other escapees with values > 31 are "(34), \(92)
    if c < 32 or c == 34 or c == 92 or c > 126 then
      if c >= 7 and c <= 13 then
        c = string.sub("abtnvfr", c - 6, c - 6)
      elseif c == 34 or c == 92 then
        c = string.char(c)
      end
      v = v.."\\"..c
    else -- 32 <= v <= 126
      v = v..string.char(c)
    end
  end
  if quoted then return string.format("\"%s\"", v) end
  return v
end


-----------------------------------------------------------------------
-- description-only line, no position or hex data
-----------------------------------------------------------------------
function DescLine(desc)
  if not config.DISPLAY_FLAG or config.DISPLAY_BRIEF then return end
  WriteLine(string.rep(" ", config.WIDTH_OFFSET)..config.DISPLAY_SEP
            ..config.BLANKS_HEX_DATA..config.DISPLAY_SEP
            ..desc)
end


-----------------------------------------------------------------------
-- returns position, i uses string index (starts from 1)
-----------------------------------------------------------------------
function FormatPos(i)
  local pos
  if config.DISPLAY_OFFSET_HEX then
    pos = string.format("%X", i - 1)
  else
    pos = tonumber(i - 1)
  end
  return ZeroPad(pos, config.WIDTH_OFFSET)
end

--[[-------------------------------------------------------------------
-- Instruction decoder functions (changed in Lua 5.1)
-- * some fixed decode data is placed in the config table
-- * these function are quite flexible, they can accept non-standard
--   instruction field sizes as long as the arrangement is the same.
-----------------------------------------------------------------------
  Visually, an instruction can be represented as one of:
   31      |     |     |         0  bit position
    +-----+-----+-----+----------+
    |  B  |  C  |  A  |  Opcode  |  iABC format
    +-----+-----+-----+----------+
    -  9  -  9  -  8  -    6     -  field sizes (standard Lua)
    +-----+-----+-----+----------+
    |   [s]Bx   |  A  |  Opcode  |  iABx | iAsBx format
    +-----+-----+-----+----------+
    |        Ax       |  Opcode  |  iAx format new in 5.2
    +-----+-----+-----+----------+
  The signed argument sBx is represented in excess K, with the range
  of -max to +max represented by 0 to 2*max.
  For RK(x) constants, MSB is set and constant number is in the rest
  of the bits.
--]]-------------------------------------------------------------------

local iABC, iABx, iAsBx, iAx = 0, 1, 2, 3
-----------------------------------------------------------------------
-- instruction decoder initialization
-----------------------------------------------------------------------
function DecodeInit()
  ---------------------------------------------------------------
  -- calculate masks
  ---------------------------------------------------------------
  config.SIZE_Bx = config.SIZE_B + config.SIZE_C
  config.SIZE_Ax = config.SIZE_A + config.SIZE_B + config.SIZE_C
  local MASK_OP = 1 << config.SIZE_OP
  local MASK_A  = 1 << config.SIZE_A
  local MASK_B  = 1 << config.SIZE_B
  local MASK_C  = 1 << config.SIZE_C
  local MASK_Bx = 1 << config.SIZE_Bx
  local MASK_Ax = 1 << config.SIZE_Ax
  config.MAXARG_sBx = (MASK_Bx - 1) >> 1
  config.BITRK = 1 << (config.SIZE_B - 1)

  ---------------------------------------------------------------
  -- iABC instruction segment tables
  ---------------------------------------------------------------
  config.iABC = {       -- tables allows field sequence to be extracted
    config.SIZE_OP,     -- using a loop; least significant field first
    config.SIZE_A,      -- additional lookups below, kludgy
    config.SIZE_C,
    config.SIZE_B,
  }
  config.mABC = { MASK_OP, MASK_A, MASK_C, MASK_B, }
  config.nABC = { "OP", "A", "C", "B", }

  ---------------------------------------------------------------
  -- opcode name table
  ---------------------------------------------------------------
  local op = [[
    MOVE LOADK LOADKX LOADBOOL LOADNIL 
    GETUPVAL GETTABUP GETTABLE SETTABUP SETUPVAL 
    SETTABLE NEWTABLE SELF ADD SUB 
    MUL MOD POW DIV IDIV 
    BAND BOR BXOR SHL SHR 
    UNM BNOT NOT LEN CONCAT 
    JMP EQ LT LE TEST 
    TESTSET CALL TAILCALL RETURN FORLOOP 
    FORPREP TFORCALL TFORLOOP SETLIST CLOSURE 
    VARARG EXTRAARG 
  ]]

  iABC=0; iABx=1; iAsBx=2; iAx=3
  config.opmode = {
    [0]=iABC,iABx,iABx,iABC,iABC,
    iABC,iABC,iABC,iABC,iABC,
    iABC,iABC,iABC,iABC,iABC,
    iABC,iABC,iABC,iABC,iABC,
    iABC,iABC,iABC,iABC,iABC,
    iABC,iABC,iABC,iABC,iABC,
    iAsBx,iABC,iABC,iABC,iABC,
    iABC,iABC,iABC,iABC,iAsBx,
    iAsBx,iABC,iAsBx,iABC,iABx,
    iABC,iAx
  }

  ---------------------------------------------------------------
  -- build opcode name table
  ---------------------------------------------------------------
  config.opnames = {}
  config.opcodes = {}
  config.NUM_OPCODES = 0
  if not config.WIDTH_OPCODE then config.WIDTH_OPCODE = 0 end
  for v in string.gmatch(op, "[^%s]+") do
    if config.DISPLAY_LOWERCASE then v = string.lower(v) end
    config.opnames[config.NUM_OPCODES] = v
    config.opcodes[v] = config.NUM_OPCODES
    local vlen = string.len(v)
    -- find maximum opcode length
    if vlen > config.WIDTH_OPCODE then
      config.WIDTH_OPCODE = vlen
    end
    config.NUM_OPCODES = config.NUM_OPCODES + 1
  end

  config.operators={
    [config.opcodes["add"]]="+",
    [config.opcodes["sub"]]="-",
    [config.opcodes["mul"]]="*",
    [config.opcodes["div"]]="/",
    [config.opcodes["mod"]]="%",
    [config.opcodes["pow"]]="^",
    [config.opcodes["unm"]]="-",
    [config.opcodes["not"]]="not ",
    [config.opcodes["len"]]="#",
    [config.opcodes["eq"]]="==",
    [config.opcodes["lt"]]="<",
    [config.opcodes["le"]]="<=",
    [config.opcodes["idiv"]]="//",
    [config.opcodes["band"]]="&",
    [config.opcodes["bor"]]="|",
    [config.opcodes["bxor"]]="~",
    [config.opcodes["shl"]]="<<",
    [config.opcodes["shr"]]=">>",
    [config.opcodes["bnot"]]="~",
  }
  ---------------------------------------------------------------
  -- initialize text widths and formats for display
  ---------------------------------------------------------------
  config.WIDTH_A = WidthOf(MASK_A)
  config.WIDTH_B = WidthOf(MASK_B)
  config.WIDTH_C = WidthOf(MASK_C)
  config.WIDTH_Bx = WidthOf(MASK_Bx) + 1 -- with minus sign
  config.WIDTH_Ax = WidthOf(MASK_Ax)
  config.FORMAT_A = string.format("%%-%dd", config.WIDTH_A)
  config.FORMAT_B = string.format("%%-%dd", config.WIDTH_B)
  config.FORMAT_C = string.format("%%-%dd", config.WIDTH_C)
  config.PAD_Bx = config.WIDTH_A + config.WIDTH_B + config.WIDTH_C + 2
                  - config.WIDTH_Bx
  if config.PAD_Bx > 0 then
    config.PAD_Bx = string.rep(" ", config.PAD_Bx)
  else
    config.PAD_Bx = ""
  end
  config.PAD_Ax = config.WIDTH_A + config.WIDTH_B + config.WIDTH_C + 2
                  - config.WIDTH_Ax
  if config.PAD_Ax > 0 then
    config.PAD_Ax = string.rep(" ", config.PAD_Ax)
  else
    config.PAD_Ax = ""
  end
  config.FORMAT_Bx  = string.format("%%-%dd", config.WIDTH_Bx)
  config.FORMAT_AB  = string.format("%s %s %s", config.FORMAT_A, config.FORMAT_B, string.rep(" ", config.WIDTH_C))
  config.FORMAT_ABC = string.format("%s %s %s", config.FORMAT_A, config.FORMAT_B, config.FORMAT_C)
  config.FORMAT_AC  = string.format("%s %s %s", config.FORMAT_A, string.rep(" ", config.WIDTH_B), config.FORMAT_C)
  config.FORMAT_ABx = string.format("%s %s", config.FORMAT_A, config.FORMAT_Bx)
  config.FORMAT_A1  = string.format("%s %s %s", config.FORMAT_A, string.rep(" ", config.WIDTH_B), string.rep(" ", config.WIDTH_C))
  config.FORMAT_Ax = string.format("%%-%dd", config.WIDTH_Ax)
end

-----------------------------------------------------------------------
-- instruction decoder
-- * decoder loops starting from the least-significant byte, this allow
--   a field to be extracted using % operations
-- * returns a table populated with the appropriate fields
-- * WARNING B,C arrangement is hard-coded here for calculating [s]Bx
-----------------------------------------------------------------------
function DecodeInst(code, iValues)
  local iSeq, iMask = config.iABC, config.mABC
  local cValue, cBits, cPos = 0, 0, 1
  -- decode an instruction
  for i = 1, #iSeq do
    -- if need more bits, suck in a byte at a time
    while cBits < iSeq[i] do
      cValue = string.byte(code, cPos) * (1 << cBits) + cValue
      cPos = cPos + 1; cBits = cBits + 8
    end
    -- extract and set an instruction field
    iValues[config.nABC[i]] = cValue % iMask[i]
    cValue = cValue // iMask[i]
    cBits = cBits - iSeq[i]
  end
  iValues.opname = config.opnames[iValues.OP]   -- get mnemonic
  iValues.opmode = config.opmode[iValues.OP]
  if iValues.opmode == iABx then                 -- set Bx or sBx
    iValues.Bx = iValues.B * iMask[3] + iValues.C
  elseif iValues.opmode == iAsBx then
    iValues.sBx = iValues.B * iMask[3] + iValues.C - config.MAXARG_sBx
  elseif iValues.opmode == iAx then
    iValues.Ax = iValues.B * iMask[3] * iMask[2] + iValues.C * iMask[2] + iValues.A
  end
  return iValues
end

-----------------------------------------------------------------------
-- encodes an instruction into a little-endian byte string
-- * encodes from OP/A/B/C fields, to enable bit field size changes
-----------------------------------------------------------------------
function EncodeInst(inst)
  local v, i = "", 0
  local cValue, cBits, cPos = 0, 0, 1
  -- encode an instruction
  while i < config.size_instruction do
    -- if need more bits, suck in a field at a time
    while cBits < 8 do
      cValue = inst[config.nABC[cPos]] << cBits + cValue
      cBits = cBits + config.iABC[cPos]; cPos = cPos + 1
    end
    -- extract bytes to instruction string
    while cBits >= 8 do
      v = v..string.char(cValue % 256)
      cValue = math.floor(cValue / 256)
      cBits = cBits - 8; i = i + 1
    end
  end
  return v
end


function DescribeInst(inst, pos, func)
  local Operand
  local Comment = ""
  local CommentArg = ""
  local CommentRtn = ""


  local function OperandAB(i)   return string.format(config.FORMAT_AB, i.A, i.B) end
  local function OperandABC(i)  return string.format(config.FORMAT_ABC, i.A, i.B, i.C) end
  local function OperandAC(i)   return string.format(config.FORMAT_AC, i.A, i.C) end
  local function OperandABx(i)  return string.format(config.FORMAT_ABx, i.A, i.Bx) end
  local function OperandAsBx(i) return string.format(config.FORMAT_ABx, i.A, i.sBx) end
  local function OperandA1(i)   return string.format(config.FORMAT_A1, i.A) end
  local function OperandAx(i)   return string.format(config.FORMAT_Ax, i.Ax) end


  local function CommentLoc(sbx, cond)
    local loc = string.format("pc+=%d (goto [%d])", sbx, pos + 1 + sbx)
    if cond then loc = loc..cond end
    return loc
  end

  local function IS_CONSTANT(r)
    return (r >= config.BITRK)
  end
  local function Kst(index, quoted)
    local typec = func.typek[index + 1]
    local c = func.k[index + 1]
    if typec == config.LUA_TSHRSTR or typec == config.LUA_TLNGSTR then
      return EscapeString(c.val, quoted)
    elseif type(c) == "number" or type(c) == "boolean" then
      return tostring(c)
    else
      return "nil"
    end
  end
  local function K(index)
    return "K"..tostring(index).."(="..Kst(index, true)..")"
  end

  ---------------------------------------------------------------
  -- R(x)
  ---------------------------------------------------------------
  local function RName(index)
    -- can we get local vaname using index and pos ?
    -- func.locals[?].varname .startpc .endpc
    return nil
  end
  local function R(index)
    local name = RName(index)
    if name and name ~= "" then
      return "R"..tostring(index).."(="..name..")"
    else
      return "R"..tostring(index)
    end
  end

  ---------------------------------------------------------------
  -- RK(x) == if BITRK then Kst(x&~BITRK) else R(x)
  ---------------------------------------------------------------
  local function RK(index)
    if IS_CONSTANT(index) then
      return K(index - config.BITRK)
    else
      return R(index)
    end
  end

  ---------------------------------------------------------------
  -- comments for Upvalue
  ---------------------------------------------------------------
  local function UName(x)
    local upvalue = func.upvalues[x + 1]
    if upvalue and upvalue.name then
      return EscapeString(upvalue.name)
    else
      return nil
    end
  end
  local function U(x)
    local name = UName(x)
    if name and name ~= "" then
      return 'U'..tostring(x).."(="..name..")"
    else
      return 'U'..tostring(x)
    end
  end

  ---------------------------------------------------------------
  -- comments for Reg list
  ---------------------------------------------------------------
  local function RList(start,num)
    if (num>2) then
      return "R"..start.." to R"..(start+num-1)
    elseif (num==2) then
      return "R"..start..", R"..(start+1)
    elseif (num==1) then
      return "R"..start
    elseif (num==0) then
      return ""
    else
      return "R"..start.." to top"
    end
  end

  ---------------------------------------------------------------
  -- floating point byte conversion
  -- bit positions: mmmmmxxx, actual: (1xxx) * 2^(m-1)
  ---------------------------------------------------------------
  local function fb2int(x)
    local e = math.floor(x / 8) % 32
    if e == 0 then return x end
    return math.ldexp((x % 8) + 8, e - 1)
  end

  local a=inst.A
  local b=inst.B
  local c=inst.C
  local bx=inst.Bx
  local sbx=inst.sBx
  local ax=inst.Ax
  local o=inst.OP
  local pc=pos
  
  local isop_opc = config.opcodes
  local isop_lower = string.lower
  local function isop(opname)
    return o == isop_opc[isop_lower(opname)]
  end
  ---------------------------------------------------------------
  -- yeah, I know this is monstrous...
  -- * see the descriptions in lopcodes.h for more information
  ---------------------------------------------------------------
  if inst.prev then -- continuation of SETLIST
    Operand = string.format(config.FORMAT_Ax, inst.Ax)..config.PAD_Ax
  ---------------------------------------------------------------
  elseif isop("MOVE") then -- MOVE A B
    Operand = OperandAB(inst)
    Comment = string.format("%s := %s",R(a),R(b))
  ---------------------------------------------------------------
  elseif isop("LOADK") then -- LOADK A Bx
    Operand = OperandABx(inst)
    Comment = string.format("%s := %s",R(a),K(bx))
  ---------------------------------------------------------------
  elseif isop("LOADKX") then -- LOADKX A
    Operand = OperandA1(inst)
    Comment = string.format("%s :=",R(a))
  ---------------------------------------------------------------
  elseif isop("EXTRAARG") then -- EXTRAARG Ax
    Operand = OperandAx(inst)
    Comment = K(ax)
  ---------------------------------------------------------------
  elseif isop("LOADBOOL") then -- LOADBOOL A B C
    Operand = OperandABC(inst)
    local v
    if b == 0 then v = "false" else v = "true" end
    if c > 0 then
      Comment = string.format("%s := %s; %s",R(a),v,CommentLoc(1));
    else
      Comment = string.format("%s := %s",R(a),v)
    end
    v=nil
  ---------------------------------------------------------------
  elseif isop("LOADNIL") then -- LOADNIL A B
    Operand = OperandAB(inst)
    Comment = RList(a,b+1).." := nil"
  ---------------------------------------------------------------
  elseif isop("GETUPVAL") then -- GETUPVAL A B
    Operand = OperandAB(inst)
    Comment = string.format("%s := %s", R(a), U(b));
  ---------------------------------------------------------------
  elseif isop("SETUPVAL") then -- SETUPVAL A B
    Operand = OperandAB(inst)
    Comment = string.format("%s := %s", U(b), R(a))
  ---------------------------------------------------------------
  elseif isop("GETTABUP") then -- GETTABUP A B C
    Operand = OperandABC(inst)
    Comment = string.format("%s := %s[%s]", R(a), U(b), RK(c))
  ---------------------------------------------------------------  
  elseif isop("SETTABUP") then -- SETTABUP A B C
    Operand = OperandABC(inst)
    Comment = string.format("%s[%s] := %s", U(a), RK(b), RK(c))
  ---------------------------------------------------------------
  elseif isop("GETTABLE") then -- GETTABLE A B C
    Operand = OperandABC(inst)
    Comment = string.format("%s := %s[%s]",R(a),R(b),RK(c))
  ---------------------------------------------------------------
  elseif isop("SETTABLE") then -- SETTABLE A B C
    Operand = OperandABC(inst)
    Comment = string.format("%s[%s] := %s",R(a),RK(b),RK(c))
  ---------------------------------------------------------------
  elseif isop("NEWTABLE") then -- NEWTABLE A B C
    Operand = OperandABC(inst)
    local ar = fb2int(b)  -- array size
    local hs = fb2int(c)  -- hash size
    Comment = string.format("%s := {} , array_size=%d, hash_size=%d",R(a),ar,hs)
  ---------------------------------------------------------------
  elseif isop("SELF") then -- SELF A B C
    Operand = OperandABC(inst)
    Comment = string.format("R%d := %s; %s := %s[%s]",a+1,R(b),R(a),R(b),RK(c))
  ---------------------------------------------------------------
  elseif isop("ADD") or   -- ADD A B C
         isop("SUB") or   -- SUB A B C
         isop("MUL") or   -- MUL A B C
         isop("DIV") or   -- DIV A B C
         isop("MOD") or   -- MOD A B C
         isop("POW") or   -- POW A B C
         isop("IDIV") or  -- IDIV A B C
         isop("BAND") or  -- BAND A B C
         isop("BOR") or   -- BOR A B C
         isop("BXOR") or  -- BXOR A B C
         isop("SHL") or   -- SHL A B C
         isop("SHR") then -- SHR A B C
    Operand = OperandABC(inst)
    Comment = string.format("%s := %s %s %s",R(a),RK(b),config.operators[inst.OP],RK(c))
  ---------------------------------------------------------------
  elseif isop("UNM") or    -- UNM A B
         isop("NOT") or    -- NOT A B
         isop("LEN") or    -- LEN A B
         isop("BNOT") then -- BNOT A B
    Operand = OperandAB(inst)
    Comment = string.format("%s := %s %s",R(a),config.operators[inst.OP],RK(b))
  ---------------------------------------------------------------
  elseif isop("CONCAT") then -- CONCAT A B C
    Operand = OperandABC(inst)
    Comment = string.format("%s := %s",R(a),RList(b,c-b+1))
  ---------------------------------------------------------------
  elseif isop("JMP") then -- JMP A sBx
    Operand = OperandAsBx(inst)
    if a>0 then
      Comment="close all upvalues >= R"..(a-1).."; "
    else
      Comment=""
    end
    Comment = Comment..CommentLoc(sbx)
  ---------------------------------------------------------------
  elseif isop("EQ") or   -- EQ A B C
         isop("LT") or   -- LT A B C
         isop("LE") then -- LE A B C
    Operand = OperandABC(inst)
    Comment = string.format("%s %s %s, ",RK(b),config.operators[inst.OP],RK(c))
    local sense = " if false"
    if inst.A == 0 then sense = " if true" end
    Comment = Comment..CommentLoc(1, sense)
  elseif isop("TESTSET") then -- TESTSET A B C
    Operand = OperandABC(inst)
    local sense = " "
    if c == 0 then sense = " not " end
    Comment = string.format("if%s%s then %s = %s else ",sense,R(b),R(a),R(b))
    Comment = Comment..CommentLoc(1)
  elseif isop("TEST") then -- TEST A C
    Operand = OperandAC(inst)
    local sense = " not "
    if c == 0 then sense = " " end
    Comment = string.format("if%s%s then ",sense,R(a))
    Comment = Comment..CommentLoc(1)
  ---------------------------------------------------------------
  elseif isop("CALL") or   -- CALL A B C
         isop("TAILCALL") then -- TAILCALL A B C
    Operand = OperandABC(inst)
    CommentArg = RList(a+1,b-1)
    CommentRtn = RList(a,c-1)
    Comment = string.format("%s := %s(%s)",CommentRtn,R(a),CommentArg);
  ---------------------------------------------------------------
  elseif isop("RETURN") then -- RETURN A B
    Operand = OperandAB(inst)
    CommentRtn = RList(a,b-1)
    Comment = "return "..CommentRtn
  ---------------------------------------------------------------
  elseif isop("FORLOOP") then -- FORLOOP A sBx
    Operand = OperandAsBx(inst)
    Comment = string.format("R%d += R%d; if R%d <= R%d then { R%d := R%d; %s }",a,a+2,a,a+1,a+3,a,CommentLoc(sbx));
  ---------------------------------------------------------------
  elseif isop("FORPREP") then -- FORPREP A sBx
    Operand = OperandAsBx(inst)
    Comment = string.format("R%d -= R%d; %s",a,a+2,CommentLoc(sbx));
  ---------------------------------------------------------------
  elseif isop("TFORCALL") then -- TFORCALL A C
    Operand = OperandAC(inst)
    if (c>0) then
      CommentRtn = RList(a+3,c)
    else
      CommentRtn = "Error Regs"
    end
    Comment = string.format("%s := R%d(R%d,R%d)", CommentRtn, a, a+1,a+2);
  ---------------------------------------------------------------
  elseif isop("TFORLOOP") then -- TFORLOOP A sBx
    Operand = OperandAsBx(inst)
    Comment = string.format("if R%d ~= nil then { R%d := R%d; %s", a+1,a, a+1, CommentLoc(sbx));
  ---------------------------------------------------------------
  elseif isop("SETLIST") then -- SETLIST A B C
    Operand = OperandABC(inst)
    -- R(A)[(C-1)*FPF+i] := R(A+i), 1 <= i <= B
    if c == 0 then
      -- grab next inst when index position is large
      local ninst = {}
      DecodeInst(func.code[pos + 1], ninst)
      c = ninst.Ax
      func.inst[pos + 1].prev = true
    end
    local start = (c - 1) * config.FPF + 1
    local last = start + b - 1
    CommentArg = start.." to "
    local EndReg
    if b ~= 0 then
      CommentArg = CommentArg..last
      EndReg = "R"..(a+last)
    else
      CommentArg = CommentArg.."top"
      EndReg = "top"
    end
    Comment = string.format("%s[%s] := R%d to %s",R(a),CommentArg,a+1,EndReg)
  ---------------------------------------------------------------
  elseif isop("CLOSURE") then -- CLOSURE A Bx
    Operand = OperandABx(inst)
    -- lets user know how many following instructions are significant
    Comment = func.p[bx + 1].sizeupvalues.." upvalues"
    Comment = string.format("%s := closure(function[%d]) %s",R(a),bx,Comment)
  ---------------------------------------------------------------
  elseif isop("VARARG") then -- VARARG A B
    Operand = OperandAB(inst)
    CommentRtn = RList(a,b-1)
    if ( b==1 or b<0 ) then
      CommentRtn = "Error Regs"
    end
    Comment = CommentRtn.." := ..."
  ---------------------------------------------------------------
  else
    -- add your VM extensions here
    Operand = string.format("OP %d %s", inst.OP, config.opnames[inst.OP])
  end

  ---------------------------------------------------------------
  -- compose operands and comments
  ---------------------------------------------------------------
  if Comment and Comment ~= "" then
    Operand = Operand..config.DISPLAY_SEP
              ..config.DISPLAY_COMMENT..Comment
  end
  return LeftJustify(inst.opname, config.WIDTH_OPCODE)
         ..config.DISPLAY_SEP..Operand
end



function SourceMark(func)
  if not config.source then return end
  if func.sizelineinfo == 0 then return end
  for i = 1, func.sizelineinfo do
    if i <= config.srcsize then
      config.srcmark[func.lineinfo[i]] = true
    end
  end
end

function SourceMerge(func, pc)
  if not config.source or not config.DISPLAY_FLAG then return end
  local lnum = func.lineinfo[pc]
  -- don't print anything new if instruction is on the same line
  if config.srcprev == lnum then return end
  config.srcprev = lnum
  if config.srcsize < lnum then return end      -- something fishy
  local lfrom = lnum
  config.srcmark[lnum] = true
  while lfrom > 1 and config.srcmark[lfrom - 1] == false do
    lfrom = lfrom - 1
    config.srcmark[lfrom] = true
  end
  for i = lfrom, lnum do
    WriteLine(config.DISPLAY_COMMENT
              .."("..ZeroPad(i, config.DISPLAY_SRC_WIDTH)..")"
              ..config.DISPLAY_SEP..config.srcline[i])
  end
end





function parse_bytecode(chunk_name, chunk)

  local idx = 1
  local previdx, len
  local result = {}   
  local stat = {}
  result.chunk_name = chunk_name or ""

  local function read_byte()
    previdx = idx
    idx = idx + 1
    return string.byte(chunk, previdx)
  end


  local function read_buf(size, notreverse)
    previdx = idx
    idx = idx + size
    local b = string.sub(chunk, idx - size, idx - 1)
    if config.endianness == 1 or notreverse then
      return b
    else
      return string.reverse(b)
    end
  end

  function FormatLine(size, desc, index, segment)
    if not config.DISPLAY_FLAG or config.DISPLAY_BRIEF then return end
    if config.DISPLAY_HEX_DATA then
      -- nicely formats binary chunk data in multiline hexadecimal
      if size == 0 then
        WriteLine(FormatPos(index)..config.DISPLAY_SEP
                  ..config.BLANKS_HEX_DATA..config.DISPLAY_SEP
                  ..desc)
      else
        -- split hex data into config.WIDTH_HEX byte strings
        while size > 0 do
          local d, dlen = "", size
          if size > config.WIDTH_HEX then dlen = config.WIDTH_HEX end
          -- build hex data digits
          for i = 0, dlen - 1 do
            d = d..string.format("%02X", string.byte(chunk, index + i))
          end
          -- add padding or continuation indicator
          d = d..string.rep("  ", config.WIDTH_HEX - dlen)
          if segment or size > config.WIDTH_HEX then
            d = d.."+"; size = size - config.WIDTH_HEX
          else
            d = d.." "; size = 0
          end
          -- description only on first line of a multiline
          if desc then
            WriteLine(FormatPos(index)..config.DISPLAY_SEP
                      ..d..config.DISPLAY_SEP
                      ..desc)
            desc = nil
          else
            WriteLine(FormatPos(index)..config.DISPLAY_SEP..d)
          end
          index = index + dlen
        end--while
      end--if size
    else--no hex data mode
      WriteLine(FormatPos(index)..config.DISPLAY_SEP..desc)
    end
    -- end of FormatLine
  end

  DisplayInit(string.len(chunk))

  -- magic number
  len = string.len(config.SIGNATURE)
  if string.sub(chunk, 1, len) ~= config.SIGNATURE then
    error("invalid lua bytecode file magic number")
  end
  idx = idx + len

  -- version 
  if read_byte() ~= config.VERSION then
    error("invlaid version")
  end

  -- format 
  if read_byte() ~= config.FORMAT then
    error("invalid format")
  end

  if read_buf(string.len(config.LUAC_DATA), true)~= config.LUAC_DATA then
    error("luac_data incorrect")
  end

  if read_byte() ~= config.size_int then
  	error("invalid size_int value")
  end

  if read_byte() ~= config.size_size_t then
  	error("invalid size_t")
  end

  if read_byte() ~= config.size_instruction then
  	error("invalid instruction")
  end

  if read_byte() ~= config.size_lua_Integer then
  	error("invalid lua integer")
  end

  if read_byte() ~= config.size_lua_Number then
  	error("invalid lua number")
  end

  DecodeInit()

  -- endianness
  read_buf(8)

  -- float format
  read_buf(8)

  -- global closure nupvalues
  read_byte()

  stat.header = idx - 1

  local function LoadFunction(funcname, num, level)
  	local func = {
    	stat={},
    	
    }

    local function LoadInt()
      local x = read_buf(config.size_int)
      if not x then
        error("could not load integer")
      else
        local sum = 0
        for i = config.size_int, 1, -1 do
          sum = sum * 256 + string.byte(x, i)
        end
        -- test for negative number
        if string.byte(x, config.size_int) > 127 then
          sum = sum - math.ldexp(1, 8 * config.size_int)
        end
        -- from the looks of it, integers needed are positive
        if sum < 0 then error("bad integer") end
        return sum
      end
    end

    local function LoadSize()
      local x = read_buf(config.size_size_t)
      if not x then
        --error("could not load size_t") handled in LoadString()
        return
      else
        local sum = 0
        for i = config.size_size_t, 1, -1 do
          sum = sum * 256 + string.byte(x, i)
        end
        return sum
      end
    end

    local function LoadInteger()
      local x = read_buf(config.size_lua_Integer)
      if not x then
        error("could not load lua_Integer")
      else
        local convert_func = convert_from[config.integer_type]
        if not convert_func then
          error("could not find conversion function for lua_Integer")
        end
        return convert_func(x)
      end
    end


    local function LoadNumber()
      local x = read_buf(config.size_lua_Number)
      if not x then
        error("could not load lua_Number")
      else
        local convert_func = convert_from[config.number_type]
        if not convert_func then
          error("could not find conversion function for lua_Number")
        end
        return convert_func(x)
      end
    end

    local function LoadString()
      local len = read_byte()
      local islngstr = nil
      if not len then
        error("could not load String")
        return
      end
      if len == 255 then
        len = LoadSize()
        islngstr = true
      end
      if len == 0 then        -- there is no error, return a nil
        return nil, len, islngstr
      end
      if len == 1 then
        return "", len, islngstr
      end
    
      local s = string.sub(chunk, idx, idx + len - 2)
      idx = idx + len - 1
      return s, len, islngstr
    end

    local function LoadString53()
      local str = {}
      str.val, str.len, str.islngstr = LoadString()
      return str
    end

    local function LoadLines()
      local size = LoadInt()
      func.pos_lineinfo = previdx
      func.lineinfo = {}
      func.sizelineinfo = size
      for i = 1, size do
        func.lineinfo[i] = LoadInt()
      end
    end

    local function LoadLocals()
      local n = LoadInt()
      func.pos_locvars = previdx
      func.locvars = {}
      func.sizelocvars = n
      for i = 1, n do
        local locvar = {}
        locvar.varname53 = LoadString53()
        locvar.varname = locvar.varname53.val
        locvar.pos_varname = previdx
        locvar.startpc = LoadInt()
        locvar.pos_startpc = previdx
        locvar.endpc = LoadInt()
        locvar.pos_endpc = previdx
        func.locvars[i] = locvar
      end
    end

    local function LoadUpvalues()
      local n = LoadInt()
      func.pos_upvalues = previdx
      func.upvalues = {}
      func.sizeupvalues = n
      for i = 1, n do
        local upvalue = {}
        upvalue.instack = read_byte()
        upvalue.pos_instack = previdx
        upvalue.idx = read_byte()
        upvalue.pos_idx = previdx
        func.upvalues[i] = upvalue
      end
    end

    local function LoadConstants()
      local n = LoadInt()
      func.pos_ks = previdx
      func.k = {}
      func.typek = {}
      func.sizek = n
      func.posk = {}
      for i = 1, n do
        local t = read_byte()
        func.typek[i] = t
        func.posk[i] = previdx
        if t == config.LUA_TNIL then
          func.k[i] = nil
        elseif t == config.LUA_TBOOLEAN then
          local b = read_byte()
          if b == 0 then b = false else b = true end
          func.k[i] = b
        elseif t == config.LUA_TNUMFLT then
          func.k[i] = LoadNumber()
        elseif t == config.LUA_TNUMINT then
          func.k[i] = LoadInteger()
        elseif t == config.LUA_TSHRSTR or t == config.LUA_TLNGSTR then
          func.k[i] = LoadString53()
        else
          error("bad constant type "..t.." at "..previdx)
        end
      end--for
    end

    local function LoadProtos()
      local n = LoadInt()
      func.pos_ps = previdx
      func.p = {}
      func.sizep = n
      for i = 1, n do
        -- recursive call back on itself, next level
        func.p[i] = LoadFunction(func.source, i - 1, level + 1)
      end
    end

    local function LoadCode()
      local size = LoadInt()
      func.pos_code = previdx
      func.code = {}
      func.sizecode = size
      for i = 1, size do
        func.code[i] = read_buf(config.size_instruction)
      end
    end

    local function LoadUpvalueNames()
      local n = LoadInt()
      if n > func.sizeupvalues then
        error(string.format("bad upvalue_names: read %d, expected %d", n, func.sizeupvalues))
        return
      end
      func.size_upvalue_names = n
      func.pos_upvalue_names = previdx
      for i = 1, n do
        local upvalue = func.upvalues[i]
        upvalue.name53 = LoadString53()
        upvalue.name = upvalue.name53.val
        upvalue.pos_name = previdx
      end
    end


    local start = idx
    local function SetStat(item)
      func.stat[item] = idx - start
      start = idx
    end

    -- source file 
    func.source53 = LoadString53()
    func.source = func.source53.val
    func.pos_source = previdx
    if func.source == nil and level == 1 then func.source = funcname end

    -- line where the function was defined
    func.linedefined = LoadInt()
    func.pos_linedefined = previdx
    func.lastlinedefined = LoadInt()
    func.pos_lastlinedefined = previdx

    -- parameters and varargs
    func.numparams = read_byte()
    func.is_vararg = read_byte()
    func.maxstacksize = read_byte()
    SetStat("header")

    LoadCode()       SetStat("code")
    LoadConstants()  SetStat("consts")
    LoadUpvalues()   SetStat("upvalues")
    LoadProtos()     SetStat("funcs")

    LoadLines()          SetStat("lines")
    LoadLocals()         SetStat("locals")
    LoadUpvalueNames()   SetStat("upvalue_names")

    return func
  end

  function DescFunction(func, num, level, funcnumstr)
 
    local function BriefLine(desc)
      if not config.DISPLAY_FLAG or not config.DISPLAY_BRIEF then return end
      if DISPLAY_INDENT then
        WriteLine(string.rep(config.DISPLAY_SEP, level - 1)..desc)
      else
        WriteLine(desc)
      end
    end

    local function DescString(str, pos)
      local len = str.len
      local s = str.val
      if str.islngstr then
        FormatLine(1 + config.size_size_t, string.format("long string size (%d)", len), pos)
        pos = pos + 1 + config.size_size_t
      else
        FormatLine(1, string.format("string size (%d)", len), pos)
        pos = pos + 1
      end
      if len == 0 then return end
      len = len - 1
      if len <= config.WIDTH_HEX then
        FormatLine(len, EscapeString(s, 1), pos)
      else
        -- split up long strings nicely, easier to view
        while len > 0 do
          local seg_len = config.WIDTH_HEX
          if len < seg_len then seg_len = len end
          local seg = string.sub(s, 1, seg_len)
          s = string.sub(s, seg_len + 1)
          len = len - seg_len
          FormatLine(seg_len, EscapeString(seg, 1), pos, len > 0)
          pos = pos + seg_len
        end
      end
    end

    local function DescLines()
      local size = func.sizelineinfo
      local pos = func.pos_lineinfo
      DescLine("* lines:")
      FormatLine(config.size_int, "sizelineinfo ("..size..")", pos)
      pos = pos + config.size_int
      local WIDTH = WidthOf(size)
      DescLine("[pc] (line)")
      for i = 1, size do
        local s = string.format("[%s] (%s)", ZeroPad(i, WIDTH), func.lineinfo[i])
        FormatLine(config.size_int, s, pos)
        pos = pos + config.size_int
      end
      -- mark significant lines in source listing
      SourceMark(func)
    end


    local function DescLocals()
      local n = func.sizelocvars
      DescLine("* locals:")
      FormatLine(config.size_int, "sizelocvars ("..n..")", func.pos_locvars)
      for i = 1, n do
        local locvar = func.locvars[i]
        DescString(locvar.varname53, locvar.pos_varname)
        DescLine("local ["..(i - 1).."]: "..EscapeString(locvar.varname))
        FormatLine(config.size_int, "  startpc ("..locvar.startpc..")", locvar.pos_startpc)
        FormatLine(config.size_int, "  endpc   ("..locvar.endpc..")",locvar.pos_endpc)
        BriefLine(".local"..config.DISPLAY_SEP..EscapeString(locvar.varname, 1)
                  ..config.DISPLAY_SEP..config.DISPLAY_COMMENT..(i - 1))
      end
    end

    local function DescUpvaluesAll()
      local n = func.sizeupvalues
      for i = 1, n do
        local upvalue = func.upvalues[i]
        local name = upvalue.name or ''
        BriefLine(".upvalue"..config.DISPLAY_SEP..EscapeString(name, 1)
                  ..config.DISPLAY_SEP..tostring(upvalue.instack)
                  ..config.DISPLAY_SEP..tostring(upvalue.idx)
                  ..config.DISPLAY_SEP..config.DISPLAY_COMMENT..(i - 1)
                  ..config.DISPLAY_SEP.."instack="..tostring(upvalue.instack)
                  ..config.DISPLAY_SEP.."idx="..tostring(upvalue.idx))
      end
    end

    local function DescUpvalues()
      local n = func.sizeupvalues
      DescLine("* upvalues:")
      FormatLine(config.size_int, "sizeupvalues ("..n..")", func.pos_upvalues)
      for i = 1, n do
        local upvalue = func.upvalues[i]
        local name = upvalue.name or ''
        DescLine("upvalue ["..(i - 1).."]: "..EscapeString(name))
        FormatLine(1, "  instack ("..upvalue.instack..")", upvalue.pos_instack)
        FormatLine(1, "  idx     ("..upvalue.idx..")",upvalue.pos_idx)
      end
    end

    local function DescUpvalueNames()
      local n = func.size_upvalue_names
      DescLine("* upvalue names:")
      FormatLine(config.size_int, "size_upvalue_names ("..n..")", func.pos_upvalue_names)
      for i = 1, n do
        local upvalue = func.upvalues[i]
        DescLine("upvalue ["..(i - 1).."]: "..EscapeString(upvalue.name))
        DescString(upvalue.name53, upvalue.pos_name)
      end
    end

    local function DescConstants()
      local n = func.sizek
      local pos = func.pos_ks
      DescLine("* constants:")
      FormatLine(config.size_int, "sizek ("..n..")", pos)
      for i = 1, n do
        local posk = func.posk[i]
        local CONST = "const ["..(i - 1).."]: "
        local CONSTB = config.DISPLAY_SEP..config.DISPLAY_COMMENT..(i - 1)
        local k = func.k[i]
        local typek = func.typek[i]
        local typestrk = config.typestr[typek]
        FormatLine(1, "const type "..typestrk, posk)
        if typek == config.LUA_TNUMFLT then
          FormatLine(config.size_lua_Number, CONST.."("..k..")", posk + 1)
          BriefLine(".const"..config.DISPLAY_SEP..k..CONSTB)
        elseif typek == config.LUA_TNUMINT then
          FormatLine(config.size_lua_Integer, CONST.."("..k..")", posk + 1)
          BriefLine(".const"..config.DISPLAY_SEP..k..CONSTB)
        elseif typek == config.LUA_TBOOLEAN then
          FormatLine(1, CONST.."("..tostring(k)..")", posk + 1)
          BriefLine(".const"..config.DISPLAY_SEP..tostring(k)..CONSTB)
        elseif typek == config.LUA_TSHRSTR or typek == config.LUA_TLNGSTR then
          DescString(k, posk + 1)
          DescLine(CONST..EscapeString(k.val, 1))
          BriefLine(".const"..config.DISPLAY_SEP..EscapeString(k.val, 1)..CONSTB)
        elseif typek == config.LUA_TNIL then
          DescLine(CONST.."nil")
          BriefLine(".const"..config.DISPLAY_SEP.."nil"..CONSTB)
        end
      end--for
    end

    local function DescProtos()
      local n = func.sizep
      DescLine("* functions:")
      FormatLine(config.size_int, "sizep ("..n..")", func.pos_ps)
      for i = 1, n do
        -- recursive call back on itself, next level
        local newfuncnumstr = funcnumstr..'_'..(i - 1)
        DescFunction(func.p[i], i - 1, level + 1, newfuncnumstr)
      end
    end


    local function DescCode()
      local size = func.sizecode
      local pos = func.pos_code
      DescLine("* code:")
      FormatLine(config.size_int, "sizecode ("..size..")", pos)
      pos = pos + config.size_int
      func.inst = {}
      local ISIZE = WidthOf(size)
      for i = 1, size do
        func.inst[i] = {}
      end
      for i = 1, size do
        DecodeInst(func.code[i], func.inst[i])
        local inst = func.inst[i]
        -- compose instruction: opcode operands [; comments]
        local d = DescribeInst(inst, i, func)
        d = string.format("[%s] %s", ZeroPad(i, ISIZE), d)
        -- source code insertion
        SourceMerge(func, i)
        FormatLine(config.size_instruction, d, pos)
        BriefLine(d)
        pos = pos + config.size_instruction
      end
    end

	DescCode()
	DescConstants()
	DescUpvaluesAll()  
	DescProtos()
	DescLines()
	DescLocals()
	DescUpvalueNames()
  end


  local func = LoadFunction("(chunk)", 0, 1)
  DescFunction(func, 0, 1, "0")


  result.stat = stat
  return result

end



parse_bytecode("test/test.luac",io.open("test/test.luac","rb"):read("*all"))