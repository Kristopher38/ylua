------------------------------------------------------------------------------------------
-- YLua: A Lua metacircular virtual machine written in lua
-- 
-- NOTE that bytecode parser was derived from ChunkSpy5.3 
--
-- kelthuzadx<1948638989@qq.com>  Copyright (c) 2019 kelthuyang
-- ref: 
--  [1] http://luaforge.net/docman/83/98/ANoFrillsIntroToLua51VMInstructions.pdf
--  [2] http://files.catwell.info/misc/mirror/lua-5.2-bytecode-vm-dirk-laurie/lua52vm.html
------------------------------------------------------------------------------------------
require("parser")
local file = io.open("test/test.luac","rb")
local func = parser.parse_bytecode(file:read("*all"))
file:close()