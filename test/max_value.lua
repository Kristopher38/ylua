function max(a, b)
  if (a>b) then
    return a
  else
    return b
  end
end
assert(max(-111,-1)==-1,"ok")
assert(max(2,3)==3,"ok")
print("max value of 5,4 is ", max(5,4))
