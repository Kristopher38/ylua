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
package.loaded.parser = nil
package.loaded.runtime = nil
local parser = require("parser")
local runtime = require("runtime")
local customenv = require("env")

local arg = arg
if component then -- check if running inside OC
    arg = {...}
end

local help = 
[[YLuaVM - A metacircular Lua VM written in Lua itself
Usage: lua ylua.lua <bytecode_file>
    --help|-h : show help message
    --debug|-d : trace bytecode execution flow
]]

local filename = nil
for i=1,#arg do
    if string.match(arg[i],"-+") ~= nil then
        if arg[i] == "--help" or arg[i] == "-h" then
            print(help)
            os.exit(0)
        elseif arg[i] == "--debug" or arg[i] == "-d" then
            runtime.debug = true
        end
    else
        filename = arg[i]
    end
end

if filename then
    local file = io.open(filename,"rb")
    if file==nil then
        error("can not open file "..arg[1])
    end
    local func = parser.parse_bytecode(file:read("*all"))
    file:close()
    local ok, msg = pcall(runtime.exec_bytecode, func, customenv)
    if not ok then
        io.stderr:write(string.format("%s\n", msg))
        for i = #runtime.stacktrace, 1, -1 do
            io.stderr:write(string.format("Line: %u\n", runtime.stacktrace[i]))
        end
        io.stderr:write("\n")
    end
else
    print(help)
end