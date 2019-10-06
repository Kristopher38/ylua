function multi_values()
    return "1",2,{n=3},{[0]=1}
end
local t = table.pack(multi_values())
print(multi_values())
print(t)