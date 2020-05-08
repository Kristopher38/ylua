# YLua VM 
**YLua VM** is yet another a metacircular [Lua VM](https://codeload.github.com/lua/lua/tar.gz/v5.3.0), it was written in Lua, you still need compile lua source code by a bootstrap [`lua`](https://www.lua.org/download.html).

# Getting started
You can simply launch it by a bootstrap `lua`  and feed a binary bytecode file into it:
```bash
# Enjoy it! 
$ lua ylua.lua <bytecode_file>
# Trace bytecode execution flow with --debug option
$ lua ylua.lua <bytecode_file> --help
YLuaVM - A metacircular Lua VM written in Lua itself
Usage: lua ylua.lua <bytecode_file>
    --help|-h : show help message
    --debug|-d : trace bytecode execution flow
# Run unit test to make sure it works well
$ ./runtest
```

# Contributing
All standard Lua VM opcodes are implemented and work *most of the time* but not in all circumstances, as YLua doesn't pass [the official Lua tests](https://github.com/lua/lua/tree/v5.3/testes). Any help with fixing the bugs which are detected by those tests is appreciated. Please feel free to issue any bugs or pull request to fix those or add new features.

# References, resources and tools
[0] **Primary** https://github.com/dibyendumajumdar/ravi/blob/master/readthedocs/lua_bytecode_reference.rst

[1] http://luaforge.net/docman/83/98/ANoFrillsIntroToLua51VMInstructions.pdf

[2] http://files.catwell.info/misc/mirror/lua-5.2-bytecode-vm-dirk-laurie/lua52vm.html

[3] https://www.lua.org/manual/5.3/manual.html

[4] https://blog.tst.sh/lua-5-2-5-3-bytecode-reference-incomplete/

[5] https://www.lua.org/source/5.3/lvm.c.html

[6] https://www.lua.org/source/5.3/ldo.c.html

[7] https://luac.nl

[8] https://craftinginterpreters.com/closures.html
