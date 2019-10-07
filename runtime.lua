---------------------------------------------------------------------------------
-- Copyright (c) 2019 kelthuzadx<1948638989@qq.com>

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
---------------------------------------------------------------------------------
require("util")
runtime={}

function runtime.exec_bytecode(func,upvalue)
    -- execution environmnet
    local pc = 1
    local r ={}
    local const = {}
    local flow_stop = false
    local return_val = {}

    -- auxiliary functions(should factor to oop styles)
    local function a(instr) return instr.operand.a end
    local function b(instr) return instr.operand.b end
    local function c(instr) return instr.operand.c end
    local function bx(instr) return instr.operand.bx end
    local function ax(instr) return instr.operand.ax end
    local function sbx(instr) return instr.operand.sbx end
    local function rk(index) if index>=256 then return const[index-256] else return r[index] end end
    local function convert_sbx(code) return ((code>>14) & 0x3ffff) - (((1<<18)-1)>>1) end
    -- bytecode dispatch table
    local dispatch = {
        -- MOVE 
        [1] = function(instr) 
            r[a(instr)] = r[b(instr)]
        end,
        -- LOADK
        [2] = function(instr)
            r[a(instr)] = const[bx(instr)]
        end,
        -- LOADKX
        [3] = function(intsr)
            r[a(instr)] = const[bx(instr)]
            pc = pc + 1
        end,
        -- LOADBOOL
        [4] = function(instr)
            r[a(instr)] = (b(instr)~=0) 
            if c(instr) ~= 0 then
                pc = pc+1
            end
        end,
        -- LOADNIL
        [5] = function(instr)
            for i=a(instr),b(instr) do
                r[i] = nil
            end
        end,
        --GETUPVAL
        [6] = function(instr)
            local v = upvalue[b(instr)]
            r[a(instr)] =  v
        end,
        --GETTABUP
        [7] = function(instr)
            local v = upvalue[b(instr)][rk(c(instr))]
            r[a(instr)] = v
        end,
        --GETTABLE
        [8] = function(instr)
          r[a(instr)] = r[b(instr)][rk(c(instr))]
        end,
        --SETTABUP
        [9] = function(instr)
            upvalue[a(instr)][rk(b(instr))]  = rk(c(instr))
        end,
        --SETUPVAL
        [10] = function(instr)
            upvalue[b(instr)] = r[a(instr)]
        end,
        --SETTABLE
        [11] = function(instr)
            r[a(instr)][rk(b(instr))] = rk(c(instr))
        end,
        --NEWTABLE
        [12] = function(instr)
            r[a(instr)] = {}
        end,
        --SELF
        [13] = function(instr)
            r[a(instr)+1] = r[b(instr)]
            r[a(instr)] = r[b(instr)][rk(c(instr))]
        end,
        --ADD
        [14] = function(instr)
            r[a(instr)] = rk(b(instr)) + rk(c(instr))
        end,
        --SUB
        [15] = function(instr)
            r[a(instr)] = rk(b(instr)) - rk(c(instr))
        end,
        --MUL
        [16] = function(instr)
            r[a(instr)] = rk(b(instr)) * rk(c(instr))
        end,
        --MOD
        [17] = function(instr)
            r[a(instr)] = rk(b(instr)) % rk(c(instr))
        end,
        --POW
        [18] = function(instr)
            r[a(instr)] = rk(b(instr)) ^ rk(c(instr))
        end,
        --DIV
        [19] = function(instr)
            r[a(instr)] = rk(b(instr)) / rk(c(instr))
        end,
        --IDIV
        [20] = function(instr)
            r[a(instr)] = rk(b(instr)) // rk(c(instr))
        end,
        --BAND
        [21] = function(instr)
            r[a(instr)] = rk(b(instr)) & rk(c(instr))
        end,
        --BOR
        [22] = function(instr)
            r[a(instr)] = rk(b(instr)) | rk(c(instr))
        end,
        --BXOR
        [23] = function(instr)
            r[a(instr)] = rk(b(instr)) ~ rk(c(instr))
        end,
        --SHL
        [24] = function(instr)
            r[a(instr)] = rk(b(instr)) << rk(c(instr))
        end,
        --SHR
        [25] = function(instr)
            r[a(instr)] = rk(b(instr)) >> rk(c(instr))
        end,
        --UNM
        [26] = function(instr)
            r[a(instr)] = -r[b(instr)]
        end,
        --BNOT
        [27] = function(instr)
            r[a(instr)] = ~r[b(instr)]
        end,
        --NOT
        [28] = function(instr)
            r[a(instr)] = not r[b(instr)]
        end,
        -- LEN
        [29] = function(instr) 
            r[a(instr)] = #r[b(instr)]
        end,
        -- CONCAT
        [30] = function(instr) 
            local res = ""
            for i=b(instr),c(instr) do
                res = res..r[i]
            end
        end,
        -- JMP
        [31] = function(instr)
            pc = pc + sbx(instr)
        end,
        -- EQ
        [32] = function(instr)
            if (rk(b(instr)) == rk(c(instr))) ~= (a(instr)~=0) then
                pc = pc + 1 
            end
        end,
        -- LT
        [33] = function(instr)  
            if (rk(b(instr)) < rk(c(instr))) ~= (a(instr)~=0) then
                pc = pc + 1 
            end
        end,
        -- LE
        [34] = function(instr) 
            if (rb(b(instr)) <= rk(c(instr))) ~= (a(instr)~=0) then
                pc = pc + 1
            end
        end,
        -- TEST
        [35] = function(instr) error("not implemented yet") end,
        -- TESTSET
        [36] = function(instr) error("not implemented yet") end,
        -- CALL
        [37] = function(instr) 
            local nparam = b(instr)
            local nresult = c(instr)
            local param = {}
            if nparam ~= 1 then
                 -- there are (B-1) parameters
                local param_start = a(instr) + 1
                local param_end = (b(instr) == 0) and #r or (a(instr) + b(instr) - 1)
                assert(param_start<=param_end,"invalid parameter range")
                assert(r[a(instr)] ~= nil,"callee should not be null")
                for i=param_start,param_end do
                    table.insert(param,r[i])
                end            
            end

            if nresult == 0 then
                -- if nresult is 0, then multiple return results are saved
                local ret = r[a(instr)](table.unpack(param))
                for i=a(instr),a(instr)+#ret - 1 do
                    r[i] = ret[i-a(instr)+1]
                end
                for i=a(instr)+#ret,#r do
                    r[i] = nil
                end
            elseif nresult == 1 then
                -- if nresult is 1, no return results are saved
                r[a(instr)](table.unpack(param))
            else
                -- if nresult is 2 or more, return values are saved
                local result = r[a(instr)](table.unpack(param))
                r[a(instr)] = result[1]
            end
        end,
        -- TAILCALL
        [38] = function(instr) error("not implemented yet") end,
        -- RETURN
        [39] = function(instr) 
            local ret_start = a(instr)
            local ret_end = (b(instr)==0) and (#r) or (b(instr)+a(instr)-2)
            assert(ret_start<=ret_start,"invalid return result range")
            for i=ret_start,ret_end do
                table.insert(return_val,r[i])
            end
            flow_stop = true
        end,
        -- FORLOOP
        [40] = function(instr) 
            local step = r[a(instr)+2]
            local idx = r[a(instr)] + step
            local limit = r[a(instr)+1]
            if (0<step and idx<=limit ) or (step<0 and limit<=idx) then
                pc = pc +convert_sbx(func.code[pc])
                r[a(instr)] = idx
                r[a(instr)+3] = idx
            end
        end,
        -- FORPREP
        [41] = function(instr) 
            r[a(instr)] = r[a(instr)] - r[a(instr)+2]
            pc = pc + convert_sbx(func.code[pc])
        end,
        -- TFORCALL
        [42] = function(instr) error("not implemented yet") end,
        -- TFORLOOP
        [43] = function(instr) error("not implemented yet") end,
        -- SETLIST
        [44] = function(instr) 
            local nelement = b(instr)
            local c = c(instr)
            if c==0 then
                c = code[pc+1]
            end
            if nelement == 0 then
                for i=1,#r-a(instr) do
                    r[a(instr)][(c-1)*util.config.FPF+i] = r[a(instr)+i]
                end
            else
                for i=1,nelement do
                    r[a(instr)][(c-1)*util.config.FPF+i] = r[a(instr)+i]
                end
            end
        end,
        -- CLOSURE
        [45] = function(instr) 
            local proto = func.proto[bx(instr)]
            local newupvalue = setmetatable({
                [0]=upvalue[0]
            },{
                __index = function(o,i)
                    if func.upvalue[i-1].instack == 0 then
                        return r[func.upvalue[i-1].index]
                    else
                        return upvalue[func.upvalue[i-1].index]
                    end
                end,
                __newindex = function(o,i,v)
                    if func.upvalue[i-1].instack == 0 then
                        r[func.upvalue[i-1].index] = v
                    else
                        upvalue[func.upvalue[i-1].index] = v
                    end
                end
            })
            r[a(instr)] = function(...)
                proto.args = table.pack(...)
                return runtime.exec_bytecode(proto, newupvalue)
            end
        end,
        -- VARARG
        [46] = function(instr) error("not implemented yet") end,
        -- EXTRAARG
        [47] = function(instr) error("not implemented yet") end,
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