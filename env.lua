local parser = require("parser")
local runtime = require("runtime")

local function deepcopy(obj, seen)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
  
    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do res[deepcopy(k, s)] = deepcopy(v, s) end
    return setmetatable(res, getmetatable(obj))
end

local env = {
    [0] = { _ENV }
}

--[[ local natives = {}

natives.load = load
env[0][1].load = function(chunk, chunkname, mode, environment)
    local chunkstr
    local chunknamestr
    environment = { [0] = { environment } } or env
    
    if type(chunk) == "string" then
        chunkstr = chunk
        chunknamestr = chunknamestr or "chunk"
    elseif type(chunk) == "function" then
        local function read(f)
            local chunkpiece = f()
            local chunkt = {}
            while chunkpiece ~= "" and chunkpiece ~= nil do
                assert(type(chunkpiece) == "string", "reader function must return a string")
                chunkt[#chunkt + 1] = chunkpiece
                chunkpiece = f()
            end
            return table.concat(chunkt)
        end
        local isok
        isok, chunkstr = pcall(read, chunk)
        if not isok then
            return nil, chunkstr
        end
        chunknamestr = chunknamestr or "=(load)"
    end
    
    mode = mode or "bt"
    if string.find(mode, "bt") or string.find(mode, "tb") then
        mode = string.sub(chunkstr, 1, 1) == "\27" and "b" or "t"
    end
    
    if mode == "t" then
        local errstr
        chunkstr, errstr = natives.load(chunkstr, chunkname, mode, environment)
        if not errstr then
            chunkstr = string.dump(chunkstr)
        else
            return nil, errstr
        end
    end

    local isok, func = pcall(parser.parse_bytecode, chunkstr)
    if isok then
        return function(...)
            func.args = table.pack(...)
            return runtime.exec_bytecode(func, environment)
        end
    else
        return nil, func
    end
end ]]

return env