-- A collection of general purpose helpers.

--[[DGB]] local debug = require"debug"

local getmetatable, setmetatable, ipairs, load, loadstring, next
    , pairs, print, rawget, rawset, select, table, tostring, type, unpack
    = getmetatable, setmetatable, ipairs, load, loadstring, next
    , pairs, print, rawget, rawset, select, table, tostring, type, unpack

local m, s, t = require"math", require"string", require"table"

local m_max, s_match, s_gsub, t_concat, t_insert
    = m.max, s.match, s.gsub, t.concat, t.insert

local compat = require"compat"


-- No globals definition:

local
function nop () end

local noglobals, getglobal, setglobal if pcall and not compat.lua52 and not release then
    local function errR (_,i)
        error("illegal global read: " .. tostring(i), 2)
    end
    local function errW (_,i, v)
        error("illegal global write: " .. tostring(i)..": "..tostring(v), 2)
    end
    local env = setmetatable({}, { __index=errR, __newindex=errW })
    noglobals = function()
        pcall(setfenv, 3, env)
    end
    function getglobal(k) rawget(env, k) end
    function setglobal(k, v) rawset(env, k, v) end
else
    noglobals = nop
end



local _ENV = noglobals() ------------------------------------------------------



local util = {
    nop = nop,
    noglobals = noglobals,
    getglobal = getglobal,
    setglobal = setglobal
}

util.unpack = t.unpack or unpack
util.pack = t.pack or function(...) return { n = select('#', ...), ... } end


if compat.lua51 then
    local old_load = load

   function util.load (ld, source, mode, env)
     -- We ignore mode. Both source and bytecode can be loaded.
     local fun
     if type (ld) == 'string' then
       fun = loadstring (ld)
     else
       fun = old_load (ld, source)
     end
     if env then
       setfenv (fun, env)
     end
     return fun
   end
else
    util.load = load
end

if compat.luajit and compat.jit then
    local function _fold(len, ary, func) 
        local acc = ary[1] 
        for i = 2, len do acc =func(acc, ary[i]) end 
        return acc 
    end
    function util.max (ary)
        local max = 0
        for i = 1, #ary do 
            max = m_max(max,ary[i])
        end
        return max        
    end
elseif compat.luajit then
    local t_unpack = util.unpack
    function util.max (ary)
     local len = #ary
        if len <=30 or len > 10240 then
            local max = 0
            for i = 1, #ary do 
                local j = ary[i] 
                if j > max then max = j end 
            end
            return max
        else
            return m_max(t_unpack(ary))
        end
    end
elseif compat.lua52 then
    local t_unpack = util.unpack
    function util.max (ary)
        local len = #ary
        if len == 0 
            then return 0
        elseif len <=20 or len > 10240 then
            local max = ary[1]
            for i = 2, len do 
                if ary[i] > max then max = ary[i] end 
            end
            return max
        else
            return m_max(t_unpack(ary))
        end
    end
else
    local t_unpack = util.unpack
    function util.max (ary)
        -- [[DB]] util.expose(ary)
        -- [[DB]] print(debug.traceback())
        local len = #ary
        if len == 0 then 
            return 0
        elseif len <=20 or len > 10240 then
            local max = ary[1]
            for i = 2, len do 
                if ary[i] > max then max = ary[i] end 
            end
            return max
        else
            return m_max(t_unpack(ary))
        end
    end
end            


local
function setmode(t,mode)
    local mt = getmetatable(t) or {}
    if mt.__mode then 
        error("The mode has already been set on table "..tostring(t)..".")
    end
    mt.__mode = mode
    return setmetatable(t, mt)
end

util.setmode = setmode

function util.weakboth (t)
    return setmode(t,"kv")
end

function util.weakkey (t)
    return setmode(t,"k")
end

function util.weakval (t)
    return setmode(t,"v")
end

function util.strip_mt (t)
    return setmetatable(t, nil)
end

local getuniqueid
do
    local N, index = 0, {}
    function getuniqueid(v)
        if not index[v] then
            N = N + 1
            index[v] = N
        end
        return index[v]
    end
end
util.getuniqueid = getuniqueid

do
    local counter = 0
    function util.gensym () 
        counter = counter + 1
        return "___SYM_"..counter
    end
end

function util.passprint (...) print(...) return ... end

local val_to_str_, key_to_str, table_tostring, cdata_to_str, t_cache
local multiplier = 2

local
function val_to_string (v, indent)
    indent = indent or 0
    t_cache = {} -- upvalue.
    local acc = {}
    val_to_str_(v, acc, indent, indent)
    local res = t_concat(acc, "")
    return res
end
util.val_to_str = val_to_string

function val_to_str_ ( v, acc, indent, str_indent )
    str_indent = str_indent or 1
    if "string" == type( v ) then
        v = s_gsub( v, "\n",  "\n" .. (" "):rep( indent * multiplier + str_indent ) )
        if s_match( s_gsub( v,"[^'\"]",""), '^"+$' ) then
            acc[#acc+1] = t_concat{ "'", "", v, "'" }
        else
            acc[#acc+1] = t_concat{'"', s_gsub(v,'"', '\\"' ), '"' }
        end
    elseif "cdata" == type( v ) then 
            cdata_to_str( v, acc, indent )
    elseif "table" == type(v) then
        if t_cache[v] then 
            acc[#acc+1] = t_cache[t]
        else
            t_cache[v] = tostring( v )
            table_tostring( v, acc, indent )
        end
    else
        acc[#acc+1] = tostring( v )
    end
end

function key_to_str ( k, acc, indent )
    if "string" == type( k ) and s_match( k, "^[_%a][_%a%d]*$" ) then
        acc[#acc+1] = s_gsub( k, "\n", (" "):rep( indent * multiplier + 1 ) .. "\n" )
    else
        acc[#acc+1] = "[ "
        val_to_str_( k, acc, indent )
        acc[#acc+1] = " ]"
    end
end

function cdata_to_str(v, acc, indent)
    acc[#acc+1] = ( " " ):rep( indent * multiplier )
    acc[#acc+1] = "["
    print(#acc)
    for i = 0, #v do
        if i % 16 == 0 and i ~= 0 then
            acc[#acc+1] = "\n"
            acc[#acc+1] = (" "):rep(indent * multiplier + 2)
        end
        acc[#acc+1] = v[i] and 1 or 0
        acc[#acc+1] = i ~= #v and  ", " or ""
    end
    print(#acc, acc[1], acc[2])
    acc[#acc+1] = "]"
end

function table_tostring ( tbl, acc, indent )
    -- acc[#acc+1] = ( " " ):rep( indent * multiplier )
    acc[#acc+1] = t_cache[tbl]
    acc[#acc+1] = "{\n"
    for k, v in pairs( tbl ) do
        local str_indent = 1
        acc[#acc+1] = (" "):rep((indent + 1) * multiplier)
        key_to_str( k, acc, indent + 1)

        if acc[#acc] == " ]"
        and acc[#acc - 2] == "[ " 
        then str_indent = 8 + #acc[#acc - 1]
        end

        acc[#acc+1] = " = "
        val_to_str_( v, acc, indent + 1, str_indent)
        acc[#acc+1] = "\n"
    end
    acc[#acc+1] = ( " " ):rep( indent * multiplier )
    acc[#acc+1] = "}"
end

function util.expose(v) print(val_to_string(v)) return v end
-------------------------------------------------------------------------------
--- Functional helpers
--

function util.map (ary, func, ...)
    if type(ary) == "function" then ary, func = func, ary end
    local res = {}
    for i = 1,#ary do
        res[i] = func(ary[i], ...)
    end
    return res
end

function util.selfmap (ary, func, ...)
    if type(ary) == "function" then ary, func = func, ary end
    for i = 1,#ary do
        ary[i] = func(ary[i], ...)
    end
    return ary
end

local
function map_all (tbl, func, ...)
    if type(tbl) == "function" then tbl, func = func, tbl end
    local res = {}
    for k, v in next, tbl do
        res[k]=func(v, ...)
    end
    return res
end

util.map_all = map_all

local
function fold (ary, func, acc)
    local i0 = 1
    if not acc then
        acc = ary[1]
        i0 = 2
    end
    for i = i0, #ary do
        acc = func(acc,ary[i])
    end
    return acc
end
util.fold = fold

local
function map_fold(ary, mfunc, ffunc, acc)
    local i0 = 1
    if not acc then
        acc = mfunc(ary[1])
        i0 = 2
    end
    for i = i0, #ary do
        acc = ffunc(acc,mfunc(ary[i]))
    end
    return acc
end
util.map_fold = map_fold

function util.zip(a1, a2)
    local res, len = {}, m_max(#a1,#a2)
    for i = 1,len do
        res[i] = {a1[i], a2[i]}
    end
    return res
end

function util.zip_all(t1, t2)
    local res = {}
    for k,v in pairs(t1) do
        res[k] = {v, t2[k]}
    end
    for k,v in pairs(t2) do
        if res[k] == nil then
            res[k] = {t1[k], v}
        end
    end
    return res
end

function util.filter(a1,func)
    local res = {}
    for i = 1,#ary do
        if func(ary[i]) then 
            t_insert(res, ary[i])
        end
    end

end

local
function id (...) return ... end
util.id = id



local function AND (a,b) return a and b end
local function OR  (a,b) return a or b  end

function util.copy (tbl) return map_all(tbl, id) end

function util.all (ary, mfunc) 
    if mfunc then 
        return map_fold(ary, mfunc, AND)
    else
        return fold(ary, AND)
    end
end

function util.any (ary, mfunc)
    if mfunc then 
        return map_fold(ary, mfunc, OR)
    else
        return fold(ary, OR)
    end
end

function util.get(field) 
    return function(tbl) return tbl[field] end 
end

function util.lt(ref) 
    return function(val) return val < ref end
end

-- function util.lte(ref) 
--     return function(val) return val <= ref end
-- end

-- function util.gt(ref) 
--     return function(val) return val > ref end
-- end

-- function util.gte(ref) 
--     return function(val) return val >= ref end
-- end

function util.compose(f,g) 
    return function(...) return f(g(...)) end
end

function util.extend (destination, ...)
    for i = 1, select('#', ...) do
        for k,v in pairs((select(i, ...))) do
            destination[k] = v
        end
    end
    return destination
end

function util.setify (t)
    local set = {}
    for i = 1, #t do
        set[t[i]]=true
    end
    return set
end

function util.arrayify (...) return {...} end

--[[
util.dprint =  print
--[=[]]
util.dprint =  nop
--]=]
return util

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The PureLPeg proto-library
--
--                                             \ 
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~ 
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ 
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~  
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~ 
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work, 
--                  I _cannot_ provide any warranty regarding 
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.