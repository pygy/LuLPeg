local _, debug, jit

_, debug = pcall(require, "debug")
if not _ then debug = nil end

_, jit = pcall(require, "jit")
if not _ then jit = nil end

local compat = {
    debug = debug,

    lua52 = _VERSION == "Lua 5.2",
    lua52_len = not #setmetatable({},{__len = nop}), 
    luajit = jit and true or false,
    jit = (jit and jit.status()),
    proxies --= false local FOOO
        = newproxy
        and (function()
            local ok, result = pcall(newproxy)
            return ok and (type(result) == "userdata" )
        end)()
        and type(debug) == "table"
        and (function() 
            local prox, mt = newproxy(), {}
            local pcall_ok, db_setmt_ok = pcall(debug.setmetatable, prox, mt)
            return pcall_ok and db_setmt_ok and (getmetatable(prox) == mt)
        end)()
}

compat.lua51 = (_VERSION == "Lua 5.1") and not luajit
-- [[DB]] print("compat")
-- [[DB]] for k, v in pairs(compat) do print(k,v) end

return compat