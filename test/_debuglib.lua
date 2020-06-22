function foo (a,b)
  local x
  do local c = a - b end
  local a = 1
  local d
  print(debug.setlocal(1, 0, 15))
  local e = 43
  print(e)
  while true do
    local name, value = debug.getlocal(1, a)
    if not name then break end
    print(name, value)
    a = a + 1
  end
end

foo(10, 20)