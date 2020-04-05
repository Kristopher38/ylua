local a, b, c = "concatenation", 5, "test"
local d = a .. b .. c
assert(d == "concatenation5test")