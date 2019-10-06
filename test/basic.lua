a = {2,4,6,8,10}
for i=1,#a do
    print("time",a[i])
    assert(a[i]==i*2,"ok")
end

local a,b,_ = 2,4,nil
assert(a==2,"ok")
assert(b==4,"ok")
print("a,b",a,b,_)
