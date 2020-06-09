function deep (n) 
    if n>0 then 
        return deep(n-1) 
    else 
        return 101 
    end 
end
assert(deep(30000) == 101)

a = {}
function a:deep (n) 
    if n>0 then 
        return self:deep(n-1) 
    else return 101 
    end 
end
assert(a:deep(30000) == 101)