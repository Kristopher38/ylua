local x = "-- a comment\0\0\0\n  x = 10 + \n23; \
     local a = function () x = 'hi' end; \
     return '\0'"
function read1 (x)
  local i = 0
  return function ()
    collectgarbage()
    i=i+1
    return string.sub(x, i, i)
  end
end
function cannotload (msg, a,b)
  print(msg, a, b)
  assert(not a and string.find(b, msg))
end
a = assert(load(read1(x), "modname", "t", _G))
assert(a() == "\0" and _G.x == 33)
assert(debug.getinfo(a).source == "modname")
cannotload("attempt to load a text chunk", load(read1(x), "modname", "b", {})) -- cannot read text in binary mode
cannotload("attempt to load a text chunk", load(x, "modname", "b"))
a = assert(load(function () return nil end))
a()  -- empty chunk
assert(not load(function () return true end))