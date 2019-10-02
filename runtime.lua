------------------------------------------------------------------
-- YLua: A Lua metacircular virtual machine written in lua
-- 
-- NOTE that bytecode parser was derived from ChunkSpy5.3 
--
-- kelthuzadx<1948638989@qq.com>  Copyright (c) 2019 kelthuyang
------------------------------------------------------------------
require("util")
runtime={}

function runtime.exec_bytecode(func)
    -- execution environmnet
    pc = 1
    r ={}
    const = {}

    -- auxiliary functions(should factor to oop styles)
    local function arg_a(instr) return instr.operand.a end
    local function arg_b(instr) return instr.operand.b end
    local function arg_c(instr) return instr.operand.c end
    local function arg_bx(instr) return instr.operand.bx end
    local function arg_ax(instr) return instr.operand.ax end
    local function arg_sbx(instr) return instr.operand.sbx end

    -- bytecode dispatch table
    dispatch = {
        -- MOVE 
        [1] = function(instr) 
            r[arg_a(instr)] = r[arg_b(instr)]
            print(string.format("%s r[%d]=%d",instr.instr_name,arg_a(instr),arg_b(instr)))
        end,
        -- LOADK
        [2] = function(instr)
            r[arg_a(instr)] = const[arg_bx(instr)]
            print(string.format("%s r[%d]=%d",instr.instr_name,arg_a(instr),arg_bx(xinstr)))
        end,
        -- LOADKX
        [3] = function(intsr)
            r[arg_a(instr)] = const[arg_bx(instr)]
            pc = pc + 1
            print(string.format("%s r[%d]=%d",instr.instr_name,arg_a(instr),arg_bx(xinstr)))
        end,
        -- LOADBOOL
        [4] = function(instr)
            r[arg_a(instr)] = (arg_b(instr)~=0) 
            if arg_c(instr) ~= 0 then
                pc = pc+1
                print(string.format("%s r[%d]=%d skip=1",instr.instr_name,arg_a(instr),arg_b(xinstr)))
            else
                print(string.format("%s r[%d]=%d",instr.instr_name,arg_a(instr),arg_b(xinstr)))    
            end
        end,
        -- LOADNIL
        [5] = function(instr)
            for i=arg_a(instr),arg_b(instr) do
                r[i] = nil
            end
            print(string.format("%s r[%d],..,r[%d] = nil",instr.instr_name,arg_a(instr),arg_b(xinstr)))
        end,
        --GETUPVAL
        [6] = function(instr)
            
        end,
        --GETTABUP
        [7] = function(instr)
            
        end,
        --GETTABLE
        [8] = function(instr)
            
        end,
        --SETTABUP
        [9] = function(instr)
            
        end,
        --SETUPVAL
        [10] = function(instr)
            
        end,
        --SETTABLE
        [11] = function(instr)
            
        end,
        --NEWTABLE
        [12] = function(instr)
            
        end,
        --SELF
        [13] = function(instr)
            
        end,
        --ADD
        [14] = function(instr)
            
        end,
        --SUB
        [15] = function(instr)
            
        end,
        --MUL
        [16] = function(instr)
            
        end,
        --MOD
        [17] = function(instr)
            
        end,
        --POW
        [18] = function(instr)
            
        end,
        --DIV
        [19] = function(instr)
            
        end,
        --IDIV
        [20] = function(instr)
            
        end,
        --BAND
        [21] = function(instr)
            
        end,
        --BOR
        [22] = function(instr)
            
        end,
        --BXOR
        [23] = function(instr)
            
        end,
        --SHL
        [24] = function(instr)
            
        end,
        --SHR
        [25] = function(instr)
            
        end,
        --UNM
        [26] = function(instr)
            
        end,
        --BNOT
        [27] = function(instr)
            
        end,
        --NOT
        [28] = function(instr)
            
        end,
        -- LEN
        [29] = function(instr) end,
        -- CONCAT
        [30] = function(instr) end,
        -- JMP
        [31] = function(instr) end,
        -- EQ
        [32] = function(instr) end,
        -- LT
        [33] = function(instr) end,
        -- LE
        [34] = function(instr) end,
        -- TEST
        [35] = function(instr) end,
        -- TESTSET
        [36] = function(instr) end,
        -- CALL
        [37] = function(instr) end,
        -- TAILCALL
        [38] = function(instr) end,
        -- RETURN
        [39] = function(instr) end,
        -- FORLOOP
        [40] = function(instr) end,
        -- FORPREP
        [41] = function(instr) end,
        -- TFORCALL
        [42] = function(instr) end,
        -- TFORLOOP
        [43] = function(instr) end,
        -- SETLIST
        [44] = function(instr) end,
        -- CLOSURE
        [45] = function(instr) end,
        -- VARARG
        [46] = function(instr) end,
        -- EXTRAARG
        [47] = function(instr) end,
    }
    
    -- do execution
    const = func.const
    upvalue = func.upvalue
    while pc <= func.code_size do
        local instr = func.code[pc]
        dispatch[1]({instr_name="move",operand={a=2,b=2,c=2}})
        pc = pc + 1
    end
end

return runtime