function unpacknils (t, n, i)
    i = i or 1
    if (i <= n) then
        return t[i], unpacknils(t, n, i+1)
    end
end

print(unpacknils({4, 7, 3}, 3))
print(unpacknils({5, nil, 7}, 3))
print(unpacknils({6, 3, 7, nil, nil}, 5))
