------------------------------------------------------------------
-- YLua: A Lua metacircular virtual machine written in lua
-- 
-- NOTE that bytecode parser was derived from ChunkSpy5.3 
--
-- kelthuzadx<1948638989@qq.com>  Copyright (c) 2019 kelthuyang
------------------------------------------------------------------
require("parser")
require("runtime")
local file = io.open("test/test.luac","rb")
local func = parser.parse_bytecode(file:read("*all"))
file:close()
upvalue = {
    [0]={
       print = print
    }
}
runtime.exec_bytecode(func,upvalue)