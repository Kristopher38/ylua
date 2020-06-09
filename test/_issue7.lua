function read1 (x)
  local i = 0
  return function ()
    collectgarbage()
    i=i+1
    return string.sub(x, i, i)
  end
end

function cannotload (msg, a,b)
  assert(not a and string.find(b, msg))
end

x = string.dump(load("return 1"))
a = assert(load(x, nil, "b"))
assert(a() == 1)
--[[cannotload("attempt to load a binary chunk", load(read1(x), nil, "t"))
cannotload("attempt to load a binary chunk", load(x, nil, "t"))

assert(not pcall(string.dump, print))  -- no dump of C functions

cannotload("unexpected symbol", load(read1("*a = 123")))
cannotload("unexpected symbol", load("*a = 123"))
cannotload("hhi", load(function () error("hhi") end))

-- any value is valid for _ENV
assert(load("return _ENV", nil, nil, 123)() == 123)]]