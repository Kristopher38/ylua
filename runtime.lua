------------------------------------------------------------------
-- YLua: A Lua metacircular virtual machine written in lua
-- 
-- NOTE that bytecode parser was derived from ChunkSpy5.3 
--
-- kelthuzadx<1948638989@qq.com>  Copyright (c) 2019 kelthuyang
------------------------------------------------------------------
require("util")
runtime = {}

local function decode(code)
    local op_num = (code & 0x7f) -- 6bits for instruction id
    if util.opcode[op_num+1] == nil then error("invalid bytecode") end
    local k,v  = next(util.opcode[op_num+1])
    if v == iABC then
        print(code&0x3cf0)
        print(code&0x7fc0000)
        print(code&0xff800000)
    end
   return {instr_name=k,instr_id=op_num+1,}
end

function runtime.exec_bytecode(func)
    for i=1,func.code_size do
        decode(func.code[i])
    end
end

return runtime