local filesystem = require("filesystem")
local yluaPath = "/home/ylua/"
local testsPath = yluaPath .. "test/"

for filename, _ in filesystem.list(testsPath) do
    if string.match(filename, ".+%.lua$") then
        print(filename)
        local fileToProcess = loadfile(testsPath .. filename)
        local bytecodeFile = testsPath .. filename .. "c"
        local fileHandle = filesystem.open(bytecodeFile, "w")
        fileHandle:write(string.dump(fileToProcess))
        fileHandle:close()
        os.execute(yluaPath .. "ylua" .. " " .. bytecodeFile)
    end
end