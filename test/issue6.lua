--[[local function loadrep (x, what)
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
  print(st, msg)
  assert(not st and string.find(msg, "too many lines"))
end
print('+')]]