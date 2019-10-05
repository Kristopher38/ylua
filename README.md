# YLua VM 
**YLua VM** is yet another a metacircular [Lua VM](https://codeload.github.com/lua/lua/tar.gz/v5.3.0), it was written in Lua, and do not a lua compiler, you still need compile lua source code by a bootstrap [`lua`](https://www.lua.org/download.html) tool.

# Getting started
You can simply launch it by a bootstrap `lua`  and pass a file name as it's input
```bash
$ lua ylua.lua <filename>
$ lua ylua.lua <filename> --deubug
```
And you can run unit test to make sure YLua work well
```
$ ./runtest
```
Please feel free to issue any bugs or pull request to add new features.

# Reference
[1] http://luaforge.net/docman/83/98/ANoFrillsIntroToLua51VMInstructions.pdf

[2] http://files.catwell.info/misc/mirror/lua-5.2-bytecode-vm-dirk-laurie/lua52vm.html

[3] https://www.lua.org/manual/5.3/manual.html

[4] https://blog.tst.sh/lua-5-2-5-3-bytecode-reference-incomplete/