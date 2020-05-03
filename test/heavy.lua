-- $Id: heavy.lua,v 1.4 2016/11/07 13:11:28 roberto Exp $
--[[
*****************************************************************************
* Copyright (C) 1994-2016 Lua.org, PUC-Rio.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*****************************************************************************
]]

print("creating a string too long")
do
  local st, msg = pcall(function ()
    local a = "x"
    while true do
      a = a .. a.. a.. a.. a.. a.. a.. a.. a.. a
       .. a .. a.. a.. a.. a.. a.. a.. a.. a.. a
       .. a .. a.. a.. a.. a.. a.. a.. a.. a.. a
       .. a .. a.. a.. a.. a.. a.. a.. a.. a.. a
       .. a .. a.. a.. a.. a.. a.. a.. a.. a.. a
       .. a .. a.. a.. a.. a.. a.. a.. a.. a.. a
       .. a .. a.. a.. a.. a.. a.. a.. a.. a.. a
       .. a .. a.. a.. a.. a.. a.. a.. a.. a.. a
       .. a .. a.. a.. a.. a.. a.. a.. a.. a.. a
       .. a .. a.. a.. a.. a.. a.. a.. a.. a.. a
       print(string.format("string with %d bytes", #a))
    end
  end)
  assert(not st and
    (string.find(msg, "string length overflow") or
     string.find(msg, "not enough memory")))
end
print('+')


local function loadrep (x, what)
  local p = 1<<20
  local s = string.rep(x, p)
  local count = 0
  local function f()
    count = count + p
    if count % (0x80*p) == 0 then
      io.stderr:write("(", string.format("0x%x", count), ")")
    end
    return s
  end
  local st, msg = load(f, "=big")
  print(string.format("\ntotal: 0x%x %s", count, what))
  return st, msg
end


print("loading chunk with too many lines")
do
  local st, msg = loadrep("\n", "lines")
  assert(not st and string.find(msg, "too many lines"))
end
print('+')


print("loading chunk with huge identifier")
do
  local st, msg = loadrep("a", "chars")
  assert(not st and 
    (string.find(msg, "lexical element too long") or
     string.find(msg, "not enough memory")))
end
print('+')


print("loading chunk with too many instructions")
do
  local st, msg = loadrep("a = 10; ", "instructions")
  print(st, msg)
end
print('+')


print "OK"
