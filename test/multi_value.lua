function multi_values()
    return "1",2,{n=3},{[0]=1}
end
local t = table.pack(multi_values())
print(multi_values())
print(t[1], t[2], t[3], t[4])