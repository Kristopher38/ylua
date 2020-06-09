function fibonacci(n)
    if n<3 then
        return 1
    else
        return fibonacci(n-1) + fibonacci(n-2)
    end
end
local fstart = os.clock()
io.write(fibonacci(5).."\n")
local fend = os.clock()
io.write("execution time: "..fend-fstart.."\n")
