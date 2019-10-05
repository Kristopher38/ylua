------------------------------------------------------------------
-- YLua: A Lua metacircular virtual machine written in lua
-- 
-- NOTE that bytecode parser was derived from ChunkSpy5.3 
--
-- kelthuzadx<1948638989@qq.com>  Copyright (c) 2019 kelthuyang
------------------------------------------------------------------
require("util")
runtime={}

function runtime.exec_bytecode(func,upval)
    -- execution environmnet
    pc = 1
    r ={}    
    const = {}
    func_stop = false
    return_val = {}

    -- auxiliary functions(should factor to oop styles)
    local function arg_a(instr) return instr.operand.a end
    local function arg_b(instr) return instr.operand.b end
    local function arg_c(instr) return instr.operand.c end
    local function arg_bx(instr) return instr.operand.bx end
    local function arg_ax(instr) return instr.operand.ax end
    local function arg_sbx(instr) return instr.operand.sbx end
    local function rk(index) if index>=256 then return const[index-256] else return r[index] end end
    local function sbx(code) return ((code>>14) & 0x3ffff) - (((1<<18)-1)>>1) end
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
            local c = rk(arg_c(instr))
            local b = arg_b(instr)
            local a = arg_a(instr)
            r[a] = upvalue[b][c]
            --r[arg_a(instr)] = upvalue[rk(arg_b(instr))][rk(arg_c(instr))]
        end,
        --GETTABLE
        [8] = function(instr)
          
        end,
        --SETTABUP
        [9] = function(instr)
            local c = rk(arg_c(instr))
            local b = rk(arg_b(instr))
            local a = arg_a(instr)
            upvalue[a][b]  = c
        end,
        --SETUPVAL
        [10] = function(instr)
            
        end,
        --SETTABLE
        [11] = function(instr)
            
        end,
        --NEWTABLE
        [12] = function(instr)
            r[arg_a(instr)] = {}
            print(string.format("%s r[%d]={}",instr.instr_name,arg_a(instr)))
        end,
        --SELF
        [13] = function(instr)
            
        end,
        --ADD
        [14] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) + rk(arg_c(instr))
            print(string.format("%s r[%d]= %d + %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --SUB
        [15] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) - rk(arg_c(instr))
            print(string.format("%s r[%d]= %d - %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --MUL
        [16] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) * rk(arg_c(instr))
            print(string.format("%s r[%d]= %d * %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --MOD
        [17] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) % rk(arg_c(instr))
            print(string.format("%s r[%d]= %d % %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --POW
        [18] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) ^ rk(arg_c(instr))
            print(string.format("%s r[%d]= %d ^ %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --DIV
        [19] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) / rk(arg_c(instr))
            print(string.format("%s r[%d]= %d ^ %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --IDIV
        [20] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) // rk(arg_c(instr))
            print(string.format("%s r[%d]= %d ^ %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --BAND
        [21] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) & rk(arg_c(instr))
            print(string.format("%s r[%d]= %d & %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --BOR
        [22] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) | rk(arg_c(instr))
            print(string.format("%s r[%d]= %d | %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --BXOR
        [23] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) ~ rk(arg_c(instr))
            print(string.format("%s r[%d]= %d ~ %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --SHL
        [24] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) << rk(arg_c(instr))
            print(string.format("%s r[%d]= %d << %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --SHR
        [25] = function(instr)
            r[arg_a(instr)] = rk(arg_b(instr)) >> rk(arg_c(instr))
            print(string.format("%s r[%d]= %d >> %d",instr.instr_name,arg_a(instr),rk(arg_b(instr)),rk(arg_c(instr))))
        end,
        --UNM
        [26] = function(instr)
            r[arg_a(instr)] = -r[arg_b(instr)]
            print(string.format("%s r[%d]= %d",instr.instr_name,arg_a(instr),-r[arg_b(instr)]))
        end,
        --BNOT
        [27] = function(instr)
            r[arg_a(instr)] = ~r[arg_b(instr)]
            print(string.format("%s r[%d]= %d",instr.instr_name,arg_a(instr),~r[arg_b(instr)]))
        end,
        --NOT
        [28] = function(instr)
            r[arg_a(instr)] = not r[arg_b(instr)]
            print(string.format("%s r[%d]= %d",instr.instr_name,arg_a(instr),not r[arg_b(instr)]))
        end,
        -- LEN
        [29] = function(instr) 
            r[arg_a(instr)] = #r[arg_b(instr)]
            print(string.format("%s r[%d]= %d",instr.instr_name,arg_a(instr),#r[arg_b(instr)]))
        end,
        -- CONCAT
        [30] = function(instr) 
            local res = ""
            for i=arg_b(instr),arg_c(instr) do
                res = res..r[i]
            end
            print(string.format("%s r[%d]= %s",instr.instr_name,arg_a(instr),res))
        end,
        -- JMP
        [31] = function(instr) 
        
        end,
        -- EQ
        [32] = function(instr)
            if (rb(arg_b(instr)) == rb(arg_c(instr))) ~= arg_a(instr) then
                pc = pc + 1 
            else
                pc = pc + 1 + sbx(func.code[pc])
            end
        end,
        -- LT
        [33] = function(instr)  
            if (rk(arg_b(instr)) < rk(arg_c(instr))) ~= arg_a(instr) then
                pc = pc + 1 
            else
                pc = pc + 1+ sbx(func.code[pc])
            end
        end,
        -- LE
        [34] = function(instr) 
            if (rb(arg_b(instr)) <= rk(arg_c(instr))) ~= arg_a(instr) then
                pc = pc + 1 + sbx(func.code[pc])
            else
                pc = pc + 1
            end
        end,
        -- TEST
        [35] = function(instr) end,
        -- TESTSET
        [36] = function(instr) end,
        -- CALL
        [37] = function(instr) 
            local nparam = arg_b(instr)
            local nresult = arg_c(instr)
            if nparam == 1 then
                -- the function has no parameter
                if arg_c(instr) == 1 then
                    r[arg_a(instr)]()
                elseif arg_c(instr) == 2 then
                    local return_val = {r[arg_a(instr)]()}
                    -- update stack values
                    for i=arg_a(instr),arg_a(instr)+#return_val do
                        r[i]  = return_val[i-arg_a(instr)]
                    end
                end
            else 
                -- there are (B-1) parameters
                local param_start = arg_a(instr) + 1
                local param_end = (arg_b(instr) == 0) and #r or (arg_a(instr) + arg_b(instr) - 1)
                assert(param_start<=param_end,"invalid parameter range")
                assert(r[arg_a(instr)] ~= nil,"callee should not be null")
                if nresult == 0 then
                    -- if nresult is 0, then multiple return results are saved
                    local ret = r[arg_a(instr)](table.unpack(r, param_start, param_end))
                    print(ret)
                elseif nresult == 1 then
                    -- if nresult is 1, no return results are saved
                    r[arg_a(instr)](table.unpack(r, param_start, param_end))
                else
                    -- if nresult is 2 or more, return values are saved
                    r[arg_a(instr)] = r[arg_a(instr)](table.unpack(r, param_start, param_end))
                end 

            end
        end,
        -- TAILCALL
        [38] = function(instr) end,
        -- RETURN
        [39] = function(instr) 
            local ret_start = arg_a(instr)
            local ret_end = (arg_b(instr)==0) and (#r) or (arg_b(instr)+arg_a(instr)-2)
            assert(ret_start<=ret_start,"invalid return result range")
            for i=ret_start,ret_end do
                table.insert(return_val,r[i])
            end
            flow_stop = true
        end,
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
        [45] = function(instr) 
            local proto = func.proto[arg_bx(instr)]
            local upvalue = {
                [0]={
                    print = print
                }
            }
            r[arg_a(instr)] = function(...)
                proto.args = table.pack(...)
                return runtime.exec_bytecode(proto, upvalue)
            end
        end,
        -- VARARG
        [46] = function(instr) end,
        -- EXTRAARG
        [47] = function(instr) end,
    }

    -- setup environment
    for i=0,func.const_list_size-1 do
        const[i] = func.const[i]
    end
    assert(func.num_params == #func.args, "unexpect arguments passed")
    for i=0, func.num_params-1 do
        r[i] = func.args[i+1]
    end

    -- do execution
    while pc <= func.code_size do
        local instr = util.decode_instr(func.code[pc])
        dispatch[instr.instr_id](instr)
        if flow_stop then
            return return_val
        end
        pc = pc + 1
    end

    return nil
end

return runtime