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

local function errorfmt(index, funcname, msg)
    return string.format("bad argument #%u to '%s' (%s)", index, funcname, msg)
end

local env = {
    [0] = { _ENV }
}

local natives = {}

local debuglib = {}
natives.debug = debug
env[0][1].debug = debuglib

function debuglib.getlocal(f, index)
    assert(type(f) ~= "thread", errorfmt(1, "getlocal", "thread argument not yet supported"))
    assert(type(f) == "number" or type(f) == "function", errorfmt(1, "getlocal", "number expected, got " .. type(f)))
    assert(type(index) == "number", errorfmt(2, "getlocal", "number expected, got " .. type(index)))

    if type(f) == "function" then
        assert(runtime.closures[f], errorfmt(1, "getlocal", "function has to be a Lua function"))
        local proto = runtime.closures[f].proto
        if index > 0 and proto.localvar[index - 1] and proto.localvar[index - 1].start_pc == 0 then
            return proto.localvar[index - 1].varname.val
        else
            return nil
        end
    else -- type(f) == "number"
        assert(f ~= 0, errorfmt(1, "getlocal", "introspection of call stack at level 0 not supported"))
        assert(f > 0 and f <= runtime.current_stacklevel, errorfmt(1, "getlocal", "level out of range"))
        local stacklevel = runtime.current_stacklevel - f + 1
        local pc = runtime.currentpc[stacklevel]
        local proto = runtime.protos[stacklevel]
        local varname, varvalue
        local varinfo
        local protos_index = 0
        local i = 0

        if index > 0 then
            -- iterate over the the localvar table, skipping variables out of scope to get the variable name at a proper index
            while protos_index < index and i <= #proto.localvar do
                varinfo = proto.localvar[i]
                if varinfo.start_pc < pc and varinfo.end_pc >= pc then
                    protos_index = protos_index + 1
                end
                i = i + 1
            end
            -- if we didn't exhaust the localvar list in the loop before
            if protos_index == index then
                varname = varinfo.varname.val
                varvalue = runtime.registers[stacklevel][index - 1]
            end
        elseif index < 0 then
            error(errorfmt(2, "getlocal", "negative indices not yet supported"))
        end -- if index is 0, getlocal will return nil

        -- return single nil when no variable found
        if varname then
            return varname, varvalue
        else
            return nil
        end
    end
end

function debug.setlocal(level, index, value)
    assert(type(level) ~= "thread", errorfmt(1, "setlocal", "thread argument not yet supported"))
    assert(type(level) == "number", errorfmt(1, "setlocal", "number expected, got " .. type(level)))
    assert(type(index) == "number", errorfmt(2, "setlocal", "number expected, got " .. type(index)))
    assert(level ~= 0, errorfmt(1, "setlocal", "modifying call stack at level 0 not supported"))
    assert(level > 0 and level <= runtime.current_stacklevel, errorfmt(1, "setlocal", "level out of range"))

    local stacklevel = runtime.current_stacklevel - level + 1
    local proto = runtime.protos[stacklevel]
    runtime.registers[stacklevel][index - 1] = value
end

--[[ natives.load = load
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