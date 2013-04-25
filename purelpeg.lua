-- PureLPeg.lua
-- a WIP LPeg implementation in pure Lua, by Pierre-Yves Gérardy
-- released under the Romantic WTF Public License (see the end of the file).

-- Captures and locales are not yet implemented, but the rest works quite well.
-- UTF-8 is supported out of the box
--
--     PL.set_charset"UTF-8"
--     s = PL.S"ß∂ƒ©˙"
--     s:match"©" --> 3 (since © is two bytes wide).
-- 
-- More encodings can be easily added (see the charset section), by adding a 
-- few appropriate functions.




-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Shorthands------------------------------------------------------------------
-------------------------------------------------------------------------------

local t_concat, t_insert, t_remove
    , t_sort, t_unpack 
    = table.concat, table.insert, table.remove
    , table.sort, table.unpack or unpack

local s_byte, s_char, s_sub
    = string.byte, string.char, string.sub

local m_max, m_min
    = math.max, math.min

local _ -- globally nil in the module, unless overloaded in a loop.

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Helpers --------------------------------------------------------------------
-------------------------------------------------------------------------------


if _VERSION == "Lua 5.1" and not jit then
    local old_load = load

   function load (ld, source, mode, env)
     -- dunno about mode, but
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
end

local function setmode(t,mode)
    local mt = getmetatable(t) or {}
    if mt.__mode then 
        error("The mode has already been set on table "..tostring(t)..".")
    end
    mt.__mode = mode
    return setmetatable(t, mt)
end


local
function weakboth (t)
    return setmode(t,"kv")
end

local
function weakkey (t)
    return setmode(t,"k")
end

local
function weakval (t)
    return setmode(t,"v")
end

local
function strip_mt (t)
    return setmetatable(t, nil)
end

local function expose(o)
    if type(o) ~= "table" then print(o)
    else
        print("{")
        for k,v in pairs(o) do
            print(k.." = "..tostring(v))
        end
        print"}"
    end
    return o
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

local function passprint(...) print(...) return ... end

--- Functional helpers
--

local
function map (ary, func, ...)
    local res = {}
    for i = 1,#ary do
        res[i] = func(ary[i], ...)
    end
    return res
end

local
function map_all (tbl, func, ...)
    local res = {}
    for k, v in next, tbl do
        res[k]=func(v, ...)
    end
    return res
end

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

local
function zip(a1, a2)
    local res, len = {}, m_max(#a1,#a2)
    for i = 1,len do
        res[i] = {a1[i], a2[i]}
    end
    return res
end

local
function zip_all(t1, t2)
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

local
function filter(a1,func)
    local res = {}
    for i = 1,#ary do
        if func(ary[i]) then 
            t_insert(res, ary[i])
        end
    end

end

local function id (...) return ... end
local function nop()end

local function AND (a,b) return a and b end
local function OR  (a,b) return a or b  end

local function copy (tbl) return map_all(tbl, id) end

local function all (ary) return fold(ary,AND) end
local function any (ary) return fold(ary,OR) end

local function get(field) 
    return function(tbl) return tbl[field] end 
end

local function lt(ref) 
    return function(val) return val < ref end
end

-- local function lte(ref) 
--     return function(val) return val <= ref end
-- end

-- local function gt(ref) 
--     return function(val) return val > ref end
-- end

-- local function gte(ref) 
--     return function(val) return val >= ref end
-- end

local function compose(f,g) 
    return function(...) return f(g(...)) end
end

local 
function extend (destination, ...)
    for i = 1, select('#', ...) do
        for k,v in pairs((select(i, ...))) do
            destination[k] = v
        end
    end
    return destination
end
--[[
dprint =  print
--[=[]]
dprint =  nop
--]=]
-------------------------------------------------------------------------------
--- Sets, From PiL:
--

local set_mt = {}

local
function newset (t)
    local set
    if all(map(t, function(e)return type(e) == number end))
    and m_min(t_unpack(t)) > 255 then
        set = loadstring(t_concat{"return {[0]=false", (", false"):rep(255), "}"})
    else
        set = {}
    end
    setmetatable(set, set_mt)
    for _, l in ipairs(t) do set[l] = true end
    return set
end

local
function set_union (a,b)
    local res = newset{}
    for k in pairs(a) do res[k] = true end
    for k in pairs(b) do res[k] = true end
    return res
end

local
function set_tolist (s)
    local list = {}
    for el in pairs(s) do
        t_insert(list,el)
    end
    return list
end

local
function set_isset (s)
    return getmetatable(s) == set_mt
end

-------------------------------------------------------------------------------
--- Ranges
--

local range_mt = {}
    
local 
function newrange (v1, v2)
    -- if v1>v2 then
    --     v1,v2 = v2,v1
    -- end
    return setmetatable({v1,v2}, range_mt)
end

local 
function range_overlap (r1, r2)
    return r1[1] <= r2[2] and r2[1] <= r1[2]
end

local
function range_merge (r1, r2)
    if not range_overlap(r1, r2) then return nil end
    local v1, v2 =
        r1[1] < r2[1] and r1[1] or r2[1],
        r1[2] > r2[2] and r1[2] or r2[2]
    return newrange(v1,v2)
end

local
function range_isrange (r)
    return getmetatable(r) == range_mt
end

---------------------------------------   .--. .                        '     -
---------------------------------------  /     |__  .--. .--. .--. .--. |--   -
-- Charset handling -------------------  \     |  | .--| |    '--. |--' |     -
---------------------------------------   '--' '  ' '--' '    '--' '--' '--'  -

-- We provide: 
-- * utf8_validate(subject, start, finish) -- validator
-- * utf8_split_int(subject)               --> table{int}
-- * utf8_split_char(subject)              --> table{char}
-- * utf8_next_int(subject, index)         -- iterator
-- * utf8_next_char(subject, index)        -- iterator
-- * utf8_get_int(subject, index)         -- Julia-style iterator
-- * utf8_get_char(subject, index)        -- Julia-style iterator
--
-- See each function for usage.


-------------------------------------------------------------------------------
--- UTF-8
--

-- Utility function.
-- Modified from code by Kein Hong Man <khman@users.sf.net>,
-- found at http://lua-users.org/wiki/SciteUsingUnicode.
local
function utf8_offset (byte)
    if byte < 128 then return 0, byte
    elseif byte < 192 then
        error("Byte values between 0x80 to 0xBF cannot start a multibyte sequence")
    elseif byte < 224 then return 1, byte - 192
    elseif byte < 240 then return 2, byte - 224
    elseif byte < 248 then return 3, byte - 240
    elseif byte < 252 then return 4, byte - 248
    elseif byte < 254 then return 5, byte - 252
    else
        error("Byte values between 0xFE and OxFF cannot start a multibyte sequence")
    end
end


--[[
validate a given (sub)string.
returns two values: 
* The first is either true, false or nil, respectively on success, error, or 
  incomplete subject.
* The second is the index of the last byte of the last valid char.
--]] 
local
function utf8_validate (subject, start, finish)
    start = start or 1
    finish = finish or #subject

    local offset, char
        = 0
    for i = start,finish do
        b = s_byte(subject,i)
        if offset == 0 then
            char = i
            success, offset = pcall(utf8_offset, b)
            if not success then return false, char - 1 end
        else
            if not (127 < b and b < 192) then
                return false, char - 1
            end
            offset = offset -1
        end
    end
    if offset ~= 0 then return nil, char - 1 end -- Incomplete input.
    return true, finish
end

--[[
Usage:
    for finish, start, cpt in utf8_next_int, "˙†ƒ˙©√" do
        print(cpt)
    end
`start` and `finish` being the bounds of the character, and `cpt` being the UTF-8 code point.
It produces:
    729
    8224
    402
    729
    169
    8730
--]]
local 
function utf8_next_int (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    local c = s_byte(subject, i)
    local offset, val = utf8_offset(c)
    for i = i+1, i+offset do
        c = s_byte(subject, i)
        val = val * 64 + (c-128)
    end
  return i + offset, i, val
end


--[[
Usage:
    for finish, start, cpt in utf8_next_int, "˙†ƒ˙©√" do
        print(cpt)
    end
`start` and `finish` being the bounds of the character, and `cpt` being the UTF-8 code point.
It produces:
    ˙
    †
    ƒ
    ˙
    ©
    √
--]]
local
function utf8_next_char (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    local offset = utf8_offset(s_byte(subject,i))
    return i + offset, i, s_sub(subject, i, i + offset)
end


--[[
Takes a string, returns an array of code points.
--]]
local
function utf8_split_int (subject)
    local chars = {}
    for _, _, c in utf8_next_int, subject do
        t_insert(chars,c)
    end
    return chars
end

--[[
Takes a string, returns an array of characters.
--]]
local
function utf8_split_char (subject)
    local chars = {}
    for _, _, c in utf8_next_char, subject do
        t_insert(chars,c)
    end
    return chars
end

local 
function utf8_get_int(subject, i)
    if i > #subject then return end
    local c = s_byte(subject, i)
    local offset, val = utf8_offset(c)
    for i = i+1, i+offset do
        c = s_byte(subject, i)
        val = val * 64 + ( c - 128 ) 
    end
    return val, i + offset + 1
end

local
function utf8_get_char(subject, i)
    if i > #subject then return end
    local offset = utf8_offset(s_byte(subject,i))
    return s_sub(subject, i, i + offset), i + offset + 1
end


-------------------------------------------------------------------------------
--- ASCII and binary.
--

-- See UTF-8 above for the API docs.

local
function ascii_validate (subject, start, finish)
    start = start or 1
    finish = finish or #subject

    for i = start,finish do
        b = s_byte(subject,i)
        if b > 127 then return false, i - 1 end
    end
    return true, finish
end

local
function printable_ascii_validate (subject, start, finish)
    start = start or 1
    finish = finish or #subject

    for i = start,finish do
        b = s_byte(subject,i)
        if 32 > b or b >127 then return false, i - 1 end
    end
    return true, finish
end

local
function binary_validate (subject, start, finish)
    start = start or 1
    finish = finish or #subject
    return true, finish
end

local 
function binary_next_int (subject, i)
    i = i and i+1 or 1
    if i >= #subject then return end
    return i, i, s_sub(subject, i, i)
end

local
function binary_next_char (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    return i, i, s_byte(subject,i)
end

local
function binary_split_int (subject)
    local chars = {}
    for i = 1, #subject do
        t_insert(chars, s_byte(subject,i))
    end
    return chars
end

local
function binary_split_char (subject)
    local chars = {}
    for i = 1, #subject do
        t_insert(chars, s_sub(subject,i,i))
    end
    return chars
end

local
function binary_get_int(subject, i)
    return s_byte(subject, i), i + 1
end

local
function binary_get_char(subject, i)
    return s_sub(subject, i, i), i + 1
end


-------------------------------------------------------------------------------
--- The table
--

local charsets = {
    binary = {
        validate   = binary_validate,
        split_char = binary_split_char,
        split_int  = binary_split_int,
        next_char  = binary_next_char,
        next_int   = binary_next_int,
        get_char   = binary_get_char,
        get_int    = binary_get_int
    },

    ASCII = {
        validate   = ascii_validate,
        split_char = binary_split_char,
        split_int  = binary_split_int,
        next_char  = binary_next_char,
        next_int   = binary_next_int,
        get_char   = binary_get_char,
        get_int    = binary_get_int
    },

    ["printable ASCII"] = {
        validate   = printable_ascii_validate,
        split_char = binary_split_char,
        split_int  = binary_split_int,
        next_char  = binary_next_char,
        next_int   = binary_next_int,
        get_char   = binary_get_char,
        get_int    = binary_get_int
    },

    ["UTF-8"] = {
        validate   = utf8_validate,
        split_char = utf8_split_char,
        split_int  = utf8_split_int,
        next_char  = utf8_next_char,
        next_int   = utf8_next_int,
        get_char   = utf8_get_char,
        get_int    = utf8_get_int
    }
}

local charset, validate, split_int, split_char
    , next_int, next_char, get_int, get_char
    = "binary"
    , binary_validate
    , binary_split_int
    , binary_split_char
    , binary_next_int
    , binary_next_char
    , binary_get_int
    , binary_get_char

local
function PL_set_charset(set)
    local s = charsets[set]
    if s then 
        charset, validate,   split_int,   split_char
        , next_int,   next_char,   get_int,   get_char
        = s,     s.validate, s.split_int, s.split_char
        , s.next_int, s.next_char, s.get_int, s.get_char
    else
        error("Bad Charset: " .. tostring(s)) 
    end
    function PL.set_charset()
        error("Charsets are forever (attempt to redefine the charset).")
    end
end


---------------------------------------  ,--. ,    ,--.            ------------
---------------------------------------  |__' |    |__' ,--. ,--.  ------------
-- The module -------------------------  |    |    |    |--' `__|  ------------
---------------------------------------  '    `--- '    `--' `__'  ------------

local function PLPeg(charset)

local PL = {}
PL.__index = PL
function PL.version () return "v0.0.0" end
PL.setmaxstack = nop --Just a stub, for compatibility.

local function PL_ispattern(pt) return getmetatable(pt) == PL end
local
function PL_type(pt)
    if PL_ispattern(pt) then 
        return "pattern"
    else
        return nil
    end
end

PL.ispattern = PL_ispattern
PL.type = PL_type
PL.set_charset = PL_set_charset
PL.charsets = charsets
PL.warnings = true


---------------------------------------   ,---                 ----------------
---------------------------------------  /     ,--. ,-.  ,--.  ----------------
-- Constructors -----------------------  \     |  | |  | `--.  ----------------
---------------------------------------   `--- `--' '  ' `--'  ----------------


--[[---------------------------------------------------------------------------
Patterns have the following, optional fields:

- type: the pattern type. ~1 to 1 correspondance with the pattern constructors
    described in the LPeg documentation.
- pattern: the one subpattern held by the pattern, like most captures, or 
    `#pt`, `-pt` and `pt^n`.
- aux: any other type of data associated to the pattern. Like the string of a
    `P"string"`, the range of an `R`, or the list of subpatterns of a `+` or
    `*` pattern. In some cases, the data is pre-processed. in that case,
    the `as_is` field holds the data as passed to the constructor.
- as_is: see aux.
- meta: A table holding meta information about patterns, like their
    minimal and maximal width, the form they can take when compiled, 
    whether they are terminal or not (no V patterns), and so on.
--]]---------------------------------------------------------------------------

-------------------------------------------------------------------------------
--- Base pattern constructor
--

local newpattern 
do 

function PL.get_direct (p) return p end
-- This deals with the Lua 5.1/5.2 compatibility, and restricted environements
-- without access to newproxy and/or debug.setmetatable.

    local proxies_are_available = (function()
        return newproxy
            and (function()
                local ran, result = pcall(newproxy)
                return ran and (type(result) == "userdata" )
            end)()
            and type(debug) == "table"
            and (function() 
                local ran, success = pcall(debug.setmetatable, {},{})
                return ran and success
            end)()
    end)()

    if #setmetatable({},{__len = function()return 10 end}) == 10 then
        -- Lua 5.2 or LuaJIT + 5.2 compat. No need to do the proxy dance.

        function newpattern(pt)
            return setmetatable(pt,PL) 
        end    
    elseif proxies_are_available then -- Lua 5.1 / LuaJIT without compat.

        local proxycache = weakkey{}
        local __index_PL = {__index = PL}
        PL.proxycache = proxycache
        function newpattern(cons) 
            local pt = newproxy()
            setmetatable(cons, __index_PL)
            proxycache[pt]=cons
            debug.setmetatable(pt,PL) 
            return pt
        end
        function PL:__index(k)
            return proxycache[self][k]
        end
        function PL:__newindex(k, v)
            proxycache[self][k] = v
        end
        function PL.get_direct(p) return proxycache[p] end
    else
        -- Fallback if neither __len(table) nor newproxy work 
        -- (is there such a Lua version?)
        if PL.warnings then
            print("Warning: The `__len` metatethod won't work with patterns, "
                .."use `PL.L(pattern)` for lookaheads.")
        end
        function newpattern(pt)
            return setmetatable(pt,PL) 
        end    
    end
end


-------------------------------------------------------------------------------
--- The caches
--

-- Warning regarding caches: if composite patterns are memoized,
-- their comiled version must not be stored in them if the
-- hold references. Currently they are thus always stored in
-- the compiler cache, not the pattern itself.



-- The type of cache for each pattern:
local classpt = {
    constant = {
        "Cp", "true", "false", "eos", "one"
    },
    -- only aux
    aux = {
        "string", "any",
        "range", "set", 
        "ref", "sequence", "choice",
        "Carg", "Cb"
    },
    -- only sub pattern
    subpt = {
        "unm", "lookahead", "C", "Cf", 
        "Cg", "Cs", "Ct", "/zero"
    }, 
    -- both
    both = {
        "behind", "at least", "at most", "Ctag", "Cmt",
        "/string", "/number", "/table", "/function"
    },
    none = "grammar", "Cc"
}

-- Singleton patterns
local truept, falsept, eospt, onept, Cppt = 
    newpattern{ptype = "true"},
    newpattern{ptype = "false"},
    newpattern{ptype = "eos"},
    newpattern{ptype = "one", aux = 1},
    newpattern{ptype = "Cp"}


-- -- reverse lookup
-- local ptclass = {}
-- for class, pts in pairs(classpt) do
--     for _, pt in pairs(pts) do
--         ptclass[pt] = class
--     end
-- end

local function resetcache()
    local ptcache = {}

    -- Patterns with aux only.
    for _, p in ipairs (classpt.aux) do
        ptcache[p] = weakval{}
    end

    -- Patterns with only one sub-pattern.
    for _, p in ipairs(classpt.subpt) do
        ptcache[p] = weakval{}
    end

    -- Patterns with both
    for _, p in ipairs(classpt.both) do
        ptcache[p] = {}
    end

    return ptcache
end

local ptcache = resetcache()

-------------------------------------------------------------------------------
--- Individual pattern constructor
--

local constructors = {}

-- data manglers that produce cache keys for each aux type.
-- `id()` for unspecified cases.
local getauxkey = {
    string = function(aux, as_is) return as_is end,
    table = copy,
    set = function(aux, as_is)
        local t = split_int(as_is)
        t_sort(t)
        return t_concat(t, "|")
    end,
    range = function(aux, as_is)
        return t_concat(as_is, "|")
    end,
    sequence = function(aux, as_is) return t_concat(map(aux, getuniqueid),"|") end
}
getauxkey.behind = getauxkey.string
getauxkey.choice = getauxkey.sequnce

constructors["aux"] = function(typ, _, aux, as_is)
     -- dprint("CONS: ", typ, pt, aux, as_is)
    local cache = ptcache[typ]
    local key = (getauxkey[typ] or id)(aux, as_is)
    if not cache[key] then
        cache[key] = newpattern{
            ptype = typ,
            aux = aux,
            as_is = as_is
        }
    end
    return cache[key]
end

-- no cache for grammars
constructors["none"] = function(typ, _, aux)
     -- dprint("CONS: ", typ, pt, aux)
    return newpattern{
        ptype = typ,
        aux = aux
    }
end

constructors["subpt"] = function(typ, pt)
     -- dprint("CONS: ", typ, pt, aux)
    local cache = ptcache[typ]
    if not cache[pt] then
        cache[pt] = newpattern{
            ptype = typ,
            pattern = pt
        }
    end
    return cache[pt]
end

constructors["both"] = function(typ, pt, aux)
     -- dprint("CONS: ", typ, pt, aux)
    local cache = ptcache[typ][aux]
    if not cache then
        ptcache[typ][aux] = weakval{}
        cache = ptcache[typ][aux]
    end
    if not cache[pt] then
        cache[pt] = newpattern{
            ptype = typ,
            pattern = pt,
            aux = aux,
            cache = cache -- needed to keep the cache as long as the pattern exists.
        }
    end
    return cache[pt]
end





---------------------------------------  ,--, ,--. -,-  ----------------------
---------------------------------------  |  | |__'  |   ----------------------
-- API --------------------------------  |- | |     |   ----------------------
---------------------------------------  '  ' '    -'-  ----------------------

-- What follows is the core LPeg functions, the public API to create patterns.
-- Think P(), R(), pt1 + pt2, etc.

--- Helpers
--

local function charset_error(index, charset)
    error("Character at position ".. index + 1 
            .." is not a valid "..charset.." one.",
        2)
end

local
function PL_P (v)
    if PL_ispattern(v) then
        return v 
    elseif type(v) == "function" then
        return true and PL.Cmt("", v)
    elseif type(v) == "string" then
        local success, index = validate(v)
        if not success then 
            charset_error(index, charset)
        end
        if v == "" then return PL_P(true) end

        return true and constructors.aux("string", nil, binary_split_int(v), v)
    elseif type(v) == "table" then
        -- private copy because tables are mutable.
        local g = copy(v)
        if g[1] == nil then error("grammar has no initial rule") end
        if not PL_ispattern(g[1]) then g[1] = PL.V(g[1]) end
        return true and constructors.none("grammar", nil, g) 
    elseif type(v) == "boolean" then
        return v and truept or falsept
    elseif type(v) == "number" then
        if v == 0 then
            return truept
        elseif v == 1 then
            return onept
        elseif v == -1 then
            return eospt
        elseif v > 0 then
            return true and constructors.aux("any", nil, v)
        else
            return true and - constructors.aux("any", nil, -v)
        end
    end
end
PL.P = PL_P

local
function PL_S (set)
    if set == "" then 
        return true and PL_P(false)
    else 
        local success, index = validate(set)
        if not success then 
            charset_error(index, charset)
        end
        return true and constructors.aux("set", nil, newset(split_int(set)), set)
    end
end
PL.S = PL_S

local
function PL_R (...)
    if select('#', ...) == 0 then
        return true and PL_P(false)
    else
        local rng = {...}
        local as_is, acc = rng, {}
        t_sort(rng)
        for _, r in ipairs(rng) do
            local success, index = validate(r)
            if not success then 
                charset_error(index, charset)
            end
            acc[#acc + 1] = newrange(t_unpack(split_int(r)))
        end

        return true and constructors.aux("range", nil, acc, rng)
    end
end
PL.R = PL_R

local
function PL_V (name)
    return constructors.aux("ref", nil,  name)
end
PL.V = PL_V



do 
    local one = newset{"set", "range", "one"}
    local zero = newset{"true", "false", "lookahead", "unm"}
    local forbidden = newset{
        "Carg", "Cb", "C", "Cf",
        "Cg", "Cs", "Ct", "/zero",
        "Ctag", "Cmt", "Cc", "Cp",
        "/string", "/number", "/table", "/function",
        "at least", "at most", "behind"
    }
    local function fixedlen(pt, gram, cycle)
        local typ = pt.ptype
        if forbidden[typ] then return false
        elseif one[typ]  then return 1
        elseif zero[typ] then return 0
        elseif typ == "string" then return #pt.as_is
        elseif typ == "any" then return pt.aux
        elseif typ == "choice" then
            return fold(map(pt.aux,fixedlen), function(a,b) return (a == b) and a end )
        elseif typ == "sequence" then
            return fold(map(pt.aux, fixedlen), function(a,b) return a and b and a + b end)
        elseif typ == "grammar" then
            if pt.aux[1].ptype == "ref" then
                return fixedlen(pt.aux[pt.aux[1].aux], pt.aux, {})
            else
                return fixedlen(pt.aux[1], pt.aux, {})
            end
        elseif typ == "ref" then
            if cycle[pt] then return false end
            cycle[pt] = true
            return fixedlen(gram[pt.aux], gram, cycle)
        else
            print(typ,"is not handled by fixedlen()")
        end
    end

    function PL.B (pt)
        pt = PL_P(pt)
        local len = fixedlen(pt)
        assert(len, "A 'behind' pattern takes a fixed length pattern as argument.")
        if len >= 260 then error("Subpattern too long in 'behind' pattern constructor.") end
        return constructors.both("behind", pt, len, str)
    end
end

local sequence, choice
do -- pt+pt, pt*pt and their optimisations.

    -- flattens a sequence (a * b) * (c * d) => a * b * c * d
    local function flatten(typ, a,b)
         local acc = {}
        for _, p in ipairs{a,b} do
            if p.ptype == typ then
                for _, q in ipairs(p.aux) do
                    acc[#acc+1] = q
                end
            else
                acc[#acc+1] = p
            end
        end
        return acc
    end
    local function process_booleans(lst, opts)
        local acc, id, brk = {}, opts.id, opts.brk
        for i = 1,#lst do
            local p = lst[i]
            if p ~= id then
                acc[#acc + 1] = p
            end
            if p == brk then
                break
            end
        end
        return acc
    end

    local function append (acc, p1, p2)
        acc[#acc + 1] = p2
    end

    local function seq_str_str (acc, p1, p2)
        acc[#acc] = PL_P(p1.as_is .. p2.as_is)
    end

    local function seq_any_any (acc, p1, p2)
        acc[#acc] = PL_P(p1.aux + p2.aux)
    end

    local function seq_unm_unm (acc, p1, p2)
        acc[#acc] = -(p1.pattern + p2.pattern)
    end


    -- Lookup table for the optimizers.
    local seq_optimize = {
        string = {string = seq_str_str},
        any = {
            any = seq_any_any,
            one = seq_any_any
        },
        one = {
            any = seq_any_any,
            one = seq_any_any
        },
        unm = { 
            unm = append -- seq_unm_unm 
        }
    }

    -- Lookup misses end up with append.
    local metaappend_mt = {
        __index = function()return append end
    }
    for k,v in pairs(seq_optimize) do
        setmetatable(v, metaappend_mt)
    end
    local metaappend = setmetatable({}, metaappend_mt) 
    setmetatable(seq_optimize, {
        __index = function() return metaappend end
    })
   
    function sequence (a,b)
        a,b = PL_P(a), PL_P(b)
        -- A few optimizations:
        -- 1. flatten the sequence (a * b) * (c * d) => a * b * c * d
        local seq1 = flatten("sequence", a, b)
        -- 2. handle P(true) and P(false)
        seq1 = process_booleans(seq1, { id = truept, brk = falsept })
        -- Concatenate `string` and `any` patterns.
        -- TODO: Repeat patterns?
        local seq2 = {}
        seq2[1] = seq1[1]
        for i = 2,#seq1 do
            local p1, p2 = seq2[#seq2], seq1[i]
            seq_optimize[p1.ptype][p2.ptype](seq2, p1, p2)
        end
        if #seq2 == 0 then
            return truept
        elseif #seq2 == 1 
        then return seq2[1] end

        return constructors.aux("sequence", nil, seq2)
    end
    PL.__mul = sequence

    local
    function PL_choice (a,b)
        a,b = PL_P(a), PL_P(b)
        -- PL.pprint(a)
        -- PL.pprint(b)
        -- A few optimizations:
        -- 1. flatten  (a + b) + (c + d) => a + b + c + d
        local ch1 = flatten("choice", a, b)
        -- 2. handle P(true) and P(false)
        ch1 = process_booleans(ch1, { id = falsept, brk = truept })
        -- Concatenate `string` and `any` patterns.
        -- TODO: Repeat patterns?
        local ch2 = {}
        -- 2. 
        -- Merge `set` patterns.
        -- TODO: merge captures who share the same structure?
        --       so that C(P1) + C(P2) become C(P1+P2)?
        ch2[1] = ch1[1]
        for i = 2,#ch1 do
            local p1, p2 = ch2[#ch2], ch1[i]
            if p1.ptype == "set" and p2.ptype == "set" then
                ch2[#ch2] = PL_S(p1.as_is..p2.as_is)
            else 
                t_insert(ch2,p2)
            end
        end
        if #ch2 == 1 
        then return ch2[1]
        else return constructors.aux("choice", nil, ch2) end
    end
    PL.__add = PL_choice

end

local
function PL_lookahead (pt)
    -- Simplifications
    if pt == truept
    or pt == falsept
    or pt.ptype == "unm"
    or pt.ptype == "lookahead" 
    then 
    -- print("Simplifying:", "LOOK")
    -- PL.pprint(pt)
    -- return pt
    end
    -- -- The general case
    return constructors.subpt("lookahead", pt)
end
PL.__len = PL_lookahead
PL.L = PL_lookahead

local
function PL_unm(pt)
    -- Simplifications
    if     pt == onept            then return eospt
    elseif pt == eospt            then return #onept
    elseif pt == truept           then return falsept
    elseif pt == falsept          then return truept
    elseif pt.ptype == "unm"       then return #pt.pattern 
    elseif pt.ptype == "lookahead" then pt = pt.pattern
    end
    -- The general case
    return constructors.subpt("unm", pt)
end
PL.__unm = PL_unm

local
function PL_sub (a, b)
        a, b = PL_P(a), PL_P(b)
        return PL_unm(b) * a
end
PL.__sub = PL_sub

local
function PL_repeat (pt, n)
    local success
    success, n = pcall(tonumber, n)
    assert(success and type(n) == "number",
        "Invalid type encountered at right side of '^'.")
    return constructors.both(( n < 0 and "at most" or "at least" ), pt, n)
end
PL.__pow = PL_repeat

-------------------------------------------------------------------------------
--- Captures
--
for __, cap in pairs{"C", "Cs", "Ct"} do
    PL[cap] = function(pt, aux)
        pt = PL_P(pt)
        return constructors.subpt(cap, pt)
    end
end


PL["Cb"] = function(aux)
    return constructors.aux("Cb", nil, aux)
end


PL["Carg"] = function(aux)
    assert(type(aux)=="number", "Number expected as parameter to Carg capture.")
    assert( 0 < aux and aux <= 200, "Argument out of bounds in Carg capture.")
    return constructors.aux("Carg", nil, aux)
end


local
function PL_Cp ()
    return Cppt
end
PL.Cp = PL_Cp

local
function PL_Cc (...)
    return true and constructors.none("Cc", nil, {...})
end
PL.Cc = PL_Cc

for __, cap in pairs{"Cf", "Cmt"} do
    local msg = "Function expected in "..cap.." capture"
    PL[cap] = function(pt, aux)
    assert(type(aux) == "function", msg)
    pt = PL_P(pt)
    return constructors.both(cap, pt, aux)
    end
end


local
function PL_Cg (pt, tag)
    pt = PL_P(pt)
    if tag then 
        return constructors.both("Ctag", pt, tag)
    else
        return constructors.subpt("Cg", pt)
    end
end
PL.Cg = PL_Cg


local valid_slash_type = newset{"string", "number", "table", "function"}
local
function PL_slash (pt, aux)
    if PL_type(aux) then 
        error"The right side of a '/' capture cannot be a pattern."
    elseif not valid_slash_type[type(aux)] then
        error("The right side of a '/' capture must be of type "
            .."string, number, table or function.")
    end
    local name
    if aux == 0 then 
        name = "/zero" 
    else 
        name = "/"..type(aux) 
    end
    return constructors.both(name, pt, aux)
end
PL.__div = PL_slash



---------------------------------------   ,---            |   ----------------
---------------------------------------   |__  .   , ,--. |   ----------------
-- Capture evaluators -----------------   |     \ /  ,--| |   ----------------
---------------------------------------   `---   v   `--' `-  ----------------



--- Some accumulator types for the evaluator
--
local fold_mt, group_mt, subst_mt, table_mt = {}, {}, {}, {}

local function new_fold_acc  (t) return setmetatable(t, fold_mt)  end
local function new_group_acc (t) return setmetatable(t, group_mt) end
local function new_subst_acc (t) return setmetatable(t, subst_mt) end
local function new_table_acc (t) return setmetatable(t, table_mt) end

local function is_fold_acc  (t) return getmetatable(t) == fold_mt  end
local function is_group_acc (t) return getmetatable(t) == group_mt end
local function is_subst_acc (t) return getmetatable(t) == subst_mt end
local function is_table_acc (t) return getmetatable(t) == table_mt end

local evaluators = {}

local
function evaluate (capture, subject, index)
    local acc, index = {}
    -- PL.cprint(capture)
    evaluators.insert(capture, subject, acc, index)
    return acc
end


evaluators["Cb"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end
    local ref, backref_acc = capture.data, {}
    local result = evaluators[ref.type](ref, subject, {}, ref.start)

    return result, index
end


evaluators["Cf"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end

    local func, fold_acc = capture.aux, new_fold_acc{}

    evaluators.insert(capture, subject, fold_acc, index)
    
    local result = fold_acc[1]
    if is_group_acc(result) then result = t_unpack(result) end

    for i = 2, #fold_acc do
        local val = fold_acc[i]
        if is_group_acc(val) then
            success, result = pcall(func, result, t_unpack(val))
        else
            success, result = pcall(func, result, val)
        end
    end
    if not success then result = nil end
    return result, capture.finish
end


evaluators["Cg"] = function (capture, subject, acc, index)
    local start, finish = capture.start, capture.finish
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, start - 1)
    end

    local group_acc = new_group_acc{}

    local _, index = evaluators.insert(capture, subject, group_acc, start)
    
    if #group_acc == 0 then
        acc[#acc + 1] = s_sub(subject, start, finish - 1)
        return nil, finish
    elseif is_subst_acc(acc) then
        return group_acc[1], finish
    elseif is_fold_acc(acc) then
        return group_acc, finish
    else
        if #group_acc == 0 then
            acc[#acc + 1] = s_sub(subject, capture.start, capture.finish - 1)
        else
            for _, v in ipairs(group_acc) do
                acc[#acc+1]=v
            end 
        end
        return nil, capture.finish
        -- error"What else? See: GROUP CAPTURE"
        -- return group_acc[1], capture.finish
        -- or?
        -- fold(group_acc, t_insert, acc)
        -- return nil, capture.finish
    end

end


evaluators["Cb"] = function (capture, subject, acc, index)
    local start, finish = capture.start, capture.finish
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, start - 1)
    end
    local _, _ = evaluators.Cg(capture.group, subject, acc, capture.group.start)

    return nil, index

end


evaluators["insert"] = function (capture, subject, acc, index)
    -- print("Insert", capture.start, capture.finish)
    for i = 1, capture.n - 1 do
        -- print(capture[i].type, capture[i].start, capture[i])
            local c 
            c, index = 
                evaluators[capture[i].type](capture[i], subject, acc, index)
            acc[#acc+1] = c
    end
    return nil, index
end


evaluators["C"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
        return s_sub(subject,capture.start, capture.finish - 1), capture.finish
    end

    acc[#acc+1] = s_sub(subject,capture.start, capture.finish - 1)

    evaluators.insert(capture, subject, acc, capture.start)

    return nil, capture.finish
end


evaluators["Cs"] = function (capture, subject, acc, index)
    -- print("SUB", capture.start, capture.finish)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end

    local subst_acc = new_subst_acc{}

    local _, index = evaluators.insert(capture, subject, subst_acc, capture.start)
    subst_acc[#subst_acc + 1] = s_sub(subject, index, capture.finish - 1)
    acc[#acc + 1] = t_concat(subst_acc)

    return nil, capture.finish
end


evaluators["Ct"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end

    local tbl_acc = new_table_acc{}

    evaluators.insert(capture, subject, tbl_acc, capture.start)
    for k, cap in pairs(capture.hash or {}) do
        local for_acc = {}
        evaluators[cap.type](cap, subject, for_acc, cap.start)
        tbl_acc[k]=for_acc[1]
    end

    
    return strip_mt(tbl_acc), capture.finish
end


evaluators["value"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end

    return capture.value, capture.finish
end


evaluators["values"] = function (capture, subject, acc, index)
local start, finish, values = capture.start, capture.finish, capture.values
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, start - 1)
    end
    if is_fold_acc(acc) then return new_group_acc(values), finish end

    for i = 1, #values do
        -- print(values[i])
        acc[#acc+1] = values[i]
    end
    return nil, finish
end


evaluators["/string"] = function (capture, subject, acc, index)
    -- print("/string", capture.start, capture.finish)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end
    local new_acc = {}
    evaluators.insert(capture, subject, new_acc, capture.start)

    local allmatch
    local result = capture.aux:gsub("%%([%d%%])", function(n)
        if n == "%" then return "%" end
        n = tonumber(n)
        if n == 0 then
            allmatch = allmatch or s_sub(subject, capture.start, capture.finish - 1)
            return allmatch
        else
            if n > #new_acc then error("No capture at index "..n.." in /string capture.") end
            return new_acc[n]
        end
    end)
    return result, capture.finish
end


evaluators["/number"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end
    local new_acc = {}
    evaluators.insert(capture, subject, new_acc, capture.start)
    return new_acc[capture.aux], capture.finish
end


evaluators["/table"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end
    local key
    if #capture > 0 then
        local new_acc = {}
        evaluators.insert(capture, subject, new_acc, capture.start)
        key = new_acc[1]
    else
        key = s_sub(subject, capture.start, capture.finish - 1)
    end
    if capture.aux[key]
    then return capture.aux[key], capture.finish 
    else return nil, capture.start
    end --or s_sub(subject, capture.start, capture.finish - 1)
end


local
function insert_results(acc, ...)
    for i = 1, select('#', ...) do
        acc[#acc + 1] = select(i, ...)
    end
end
evaluators["/function"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end

    local func, params = capture.aux
    if #capture > 0 then
        params = {}
        evaluators.insert(capture, subject, params, capture.start)
    else
        params = {s_sub(subject, capture.start, capture.finish - 1)}
    end
    insert_results(acc, func(unpack(params)))
    return nil, capture.finish
end



---------------------------------------   ,---                    -------------
---------------------------------------  /     ,--. ,-.,-.  ,--.  -------------
-- Compilers --------------------------  \     |  | |  |  | |__'  -------------
---------------------------------------   `--- `--' '  '  ' |     -------------

                                                                               
local compilers = {}


local function compile(pt, ccache)
    -- print("Compile", pt.ptype)
    if PL_type(pt) ~= "pattern" then 
        expose(pt)
        error("pattern expected") 
    end
    local typ = pt.ptype
    if typ == "grammar" then
        ccache = {}
    elseif typ == "ref" or typ == "choice" or typ == "sequence" then
        if not ccache[pt] then
            ccache[pt] = compilers[typ](pt, ccache)
        end
        return ccache[pt]
    end
    if not pt.compiled then
         -- dprint("Not compiled:")
        -- PL.pprint(pt)
        pt.compiled = compilers[pt.ptype](pt, ccache)
    end

    return pt.compiled
end


------------------------------------------------------------------------------
----------------------------------  ,--. ,--. ,--. |_  ,  , ,--. ,--. ,--.  --
--- Captures                        |    .--| |__' |   |  | |    |--' '--,
--                                  `--' `--' |    `-- `--' '    `--' `--'


-- These are all alike:


for k, v in pairs{
    ["C"] = "C", 
    ["Cf"] = "Cf", 
    ["Cg"] = "Cg", 
    ["Cs"] = "Cs",
    ["Ct"] = "Ct",
    ["/string"] = "/string",
    ["/table"] = "/table",
    ["/number"] = "/number",
    ["/function"] = "/function",
} do 
    compilers[k] = load(([[
    local compile = ...
    return function (pt, ccache)
        local matcher, aux = compile(pt.pattern, ccache), pt.aux
        return function (subject, index, cap_acc, cap_i, state)
             -- dprint("XXXX    ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
            local new_acc, nindex, success = {
                type = "XXXX",
                start = index,
                aux = aux
            }
            success, index, new_acc.n
                = matcher(subject, index, new_acc, 1, state)
            if success then 
                -- dprint("\n\nXXXX captured: start:"..new_acc.start.." finish: "..index.."\n")
                new_acc.finish = index
                cap_acc[cap_i] = new_acc
                cap_i = cap_i + 1
            end
            return success, index, cap_i
        end
    end]]):gsub("XXXX", v), k.." compiler")(compile)
end


compilers["Carg"] = function (pt, ccache)
    local n = pt.aux
    return function (subject, index, cap_acc, cap_i, state)
        if state.args.n < n then error("reference to absent argument #"..n) end
        cap_acc[cap_i] = {
            type = "value",
            value = state.args[n],
            start = index,
            finish = index
        }
        return true, index, cap_i + 1
    end
end


compilers["Cb"] = function (pt, ccache)
    local tag = pt.aux
    return function (subject, index, cap_acc, cap_i, state)
         -- dprint("Cb       ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
         -- dprint("TAG: " .. ((state.tags[tag] or {}).type or "NONE"))
        cap_acc[cap_i] = {
            type = "Cb",
            start = index,
            finish = index,
            group = state.tags[tag]
        }
        return success, index, cap_i + 1
    end
end


compilers["Cc"] = function (pt, ccache)
    local values = pt.aux
    return function (subject, index, cap_acc, cap_i, state)
        cap_acc[cap_i] = {
            type = "values", 
            values = values,
            start = index,
            finish = index
        } 
        return true, index, cap_i + 1
    end
end


compilers["Cp"] = function (pt, ccache)
    return function (subject, index, cap_acc, cap_i, state)
        cap_acc[cap_i] = {
            type = "value",
            value = index,
            start = index,
            finish = index
        }
        return true, index, cap_i + 1
    end
end


compilers["Ctag"] = function (pt, ccache)
    local matcher, tag = compile(pt.pattern, ccache), pt.aux
    return function (subject, index, cap_acc, cap_i, state)
        local new_acc = {
            type = "Cg", 
            start = index
        }
        success, new_acc.finish, new_acc.n 
            = matcher(subject, index, new_acc, 1, state)
        if success then
            state.tags[tag] = new_acc 
            if cap_acc.type == "Ct" then
                cap_acc.hash = cap_acc.hash or {}
                cap_acc.hash[tag] = new_acc[1]
            end
        end
        return success, new_acc.finish, cap_i
    end
end


compilers["/zero"] = function (pt, ccache)
    local matcher = compile(pt.pattern, ccache)
    return function (subject, index, cap_acc, cap_i, state)
        local success, nindex = matcher(subject, index, {type = "discard"}, 1, state)
        return success, nindex, cap_i
    end
end


local function pack_Cmt_caps(i,...) return i, {...} end

compilers["Cmt"] = function (pt, ccache)
    local matcher, func = compile(pt.pattern, ccache), pt.aux
    return function (subject, index, cap_acc, cap_i, state)
        local new_acc, success, nindex = {type = "insert"}

        success, nindex, new_acc.n = matcher(subject, index, new_acc, 1, state)

        if not success then return false, index, cap_i end

        local captures = #new_acc == 0 and {s_sub(subject, index, nindex - 1)}
                                       or  evaluate(new_acc, subject, nindex)
        local nnindex, values = pack_Cmt_caps(func(subject, nindex, t_unpack(captures)))

        if not nnindex then return false, index, cap_i end

        if nnindex == true then nnindex = nindex end

        if type(nnindex) == "number" 
        and index <= nnindex and nnindex <= #subject + 1
        then
            if #values > 0 then
                cap_acc[cap_i] = {
                    type = "values",
                    values = values, 
                    start = index,
                    finish = nnindex
                }
                cap_i = cap_i + 1
            end
        elseif type(nnindex) == "number" then
            error"Index out of bounds returned by match-time capture."
        else
            error("Match time capture must return a number, a boolean or nil"
                .." as first argument, or nothing at all.")
        end
        return true, nnindex, cap_i
    end
end


------------------------------------------------------------------------------
------------------------------------  ,-.  ,--. ,-.     ,--. ,--. ,--. ,--. --
--- Other Patterns                    |  | |  | |  | -- |    ,--| |__' `--.
--                                    '  ' `--' '  '    `--' `--' |    `--'


compilers["string"] = function (pt, ccache)
    local S = pt.aux
    local N = #S
    return function(subject, index, cap_acc, cap_i, state)
         -- dprint("String    ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
        local in_1 = index - 1
        for i = 1, N do
            local c
            c = s_byte(subject,in_1 + i)
            if c ~= S[i] then
         -- dprint("%FString    ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
                return false, index, cap_i
            end
        end
         -- dprint("%SString    ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
        return true, index + N, cap_i
    end
end


local 
function truecompiled (subject, index, cap_acc, cap_i, state)
     -- dprint("True    ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
    return true, index, cap_i
end
compilers["true"] = function (pt)
    return truecompiled
end


local
function falsecompiled (subject, index, cap_acc, cap_i, state)
     -- dprint("False   ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
    return false, index, cap_i
end
compilers["false"] = function (pt)
    return falsecompiled
end


local
function eoscompiled (subject, index, cap_acc, cap_i, state)
     -- dprint("EOS     ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
    return index > #subject, index, cap_i
end
compilers["eos"] = function (pt)
    return eoscompiled
end


local
function onecompiled (subject, index, cap_acc, cap_i, state)
     -- dprint("One     ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
    local char, nindex = get_int(subject, index)
    if char 
    then return true, nindex, cap_i
    else return flase, index, cap_i end
end
compilers["one"] = function (pt)
    return onecompiled
end


compilers["any"] = function (pt)
    if charset == "UTF-8" then
        local N = pt.aux         
        return function(subject, index, cap_acc, cap_i, state)
             -- dprint("Any UTF-8",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
            local n, c, nindex = N
            while n > 0 do
                c, nindex = get_int(subject, index)
                if not c then
                     -- dprint("%FAny    ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
                    return false, index, cap_i
                end
                n = n -1
            end
             -- dprint("%SAny    ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
            return true, nindex, cap_i
        end
    else -- version optimized for byte-width encodings.
        local N = pt.aux - 1
        return function(subject, index, cap_acc, cap_i, state)
             -- dprint("Any byte",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
            local n = index + N
            if n <= #subject then 
                -- dprint("%SAny    ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
                return true, n + 1, cap_i
            else
                 -- dprint("%FAny    ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
                return false, index, cap_i
            end
        end
    end
end


do
    local function checkpatterns(g)
        for k,v in pairs(g.aux) do
            if not PL_ispattern(v) then
                error(("rule 'A' is not a pattern"):gsub("A", tostring(k)))
            end
        end
    end

    compilers["grammar"] = function (pt, ccache)
        checkpatterns(pt)
        local gram = map_all(pt.aux, compile, ccache)
        local start = gram[1]
        return function (subject, index, cap_acc, cap_i, state)
             -- dprint("Grammar ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
            t_insert(state.grammars, gram)
            local success, nindex, cap_i = start(subject, index, cap_acc, cap_i, state)
            t_remove(state.grammars)
             -- dprint("%Grammar ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
            return success, nindex, cap_i
        end
    end
end

compilers["behind"] = function (pt, ccache)
    local matcher, N = compile(pt.pattern, ccache), pt.aux
    return function (subject, index, cap_acc, cap_i, state)
         -- dprint("Behind  ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
        if index <= N then return false, index, cap_i end

        local success = matcher(subject, index - N, {type = "discard"}, cap_i, state)
        return success, index, cap_i
    end
end

compilers["range"] = function (pt)
    local ranges = pt.aux
    return function (subject, index, cap_acc, cap_i, state)
         -- dprint("Range   ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
        local char, nindex = get_int(subject, index)
        for i = 1, #ranges do
            local r = ranges[i]
            if char and r[1] <= char and char <= r[2] 
            then return true, nindex, cap_i end
        end
        return false, index, cap_i
    end
end

compilers["set"] = function (pt)
    local s = pt.aux
    return function (subject, index, cap_acc, cap_i, state)
             -- dprint("Set, Set!",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
        local char, nindex = get_int(subject, index, cap_acc, cap_i, state)
        if s[char] 
        then return true, nindex, cap_i
        else return false, index, cap_i end
    end
end

compilers["ref"] = function (pt, ccache)
    local name = pt.aux
    local ref
    return function (subject, index, cap_acc, cap_i, state)
         -- dprint("Reference",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
        if not ref then 
            if #state.grammars == 0 then
                error(("rule 'XXXX' used outside a grammar"):gsub("XXXX", tostring(name)))
            elseif not state.grammars[#state.grammars][name] then
                error(("rule 'XXXX' undefined in given grammar"):gsub("XXXX", tostring(name)))
            end                
            ref = state.grammars[#state.grammars][name]
        end
        -- print("Ref",cap_acc, index) --, subject)
        return ref(subject, index, cap_acc, cap_i, state)
    end
end



-- Unroll the loop using a template:
local choice_tpl = [[
            success, index, cap_i = XXXX(subject, index, cap_acc, cap_i, state)
            if success then
                 -- dprint("%SChoice   ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
                return true, index, cap_i
            end]]
compilers["choice"] = function (pt, ccache)
    local choices, n = map(pt.aux, compile, ccache), #pt.aux
    local names, chunks = {}, {}
    for i = 1, n do
        local m = "ch"..i
        names[#names + 1] = m
        chunks[ #names  ] = choice_tpl:gsub("XXXX", m)
    end
    local compiled = t_concat{
        "local ", t_concat(names, ", "), [[ = ...
        return function (subject, index, cap_acc, cap_i, state)
             -- dprint("Choice   ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
            local success
            ]],
            t_concat(chunks,"\n"),[[
             -- dprint("%FChoice   ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
            return false, index, cap_i
        end]]
    }
    -- print(compiled)
    return load(compiled, "Choice")(unpack(choices))
end



local sequence_tpl = [[
             -- dprint("XXXX", nindex, cap_acc, new_i, state)
            success, nindex, new_i = XXXX(subject, nindex, cap_acc, new_i, state)
            if not success then
                 -- dprint("%FSequence",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
                return false, index, cap_i
            end]]
compilers["sequence"] = function (pt, ccache)
    local sequence, n = map(pt.aux, compile, ccache), #pt.aux
    local names, chunks = {}, {}
    -- print(n)
    -- for k,v in pairs(pt.aux) do print(k,v) end
    for i = 1, n do
        local m = "seq"..i
        names[#names + 1] = m
        chunks[ #names  ] = sequence_tpl:gsub("XXXX", m)
    end
    local compiled = t_concat{
        "local ", t_concat(names, ", "), [[ = ...
        return function (subject, index, cap_acc, cap_i, state)
             -- dprint("Sequence",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
            local nindex, new_i, success = index, cap_i
            ]],
            t_concat(chunks,"\n"),[[
             -- dprint("%SSequence",cap_acc, cap_acc and cap_acc.type or "'nil'", new_i, index, state) --, subject)
             -- dprint("NEW I:",new_i)
            return true, nindex, new_i
        end]]
    }
    -- print(compiled)
   return load(compiled, "Sequence")(unpack(sequence))
end


compilers["at most"] = function (pt, ccache)
    local matcher, n = compile(pt.pattern, ccache), pt.aux
    n = -n
    return function (subject, index, cap_acc, cap_i, state)
         -- dprint("At most   ",cap_acc, cap_acc and cap_acc.type or "'nil'", index) --, subject)
        local success = true
        for i = 1, n do
            success, index, cap_i = matcher(subject, index, cap_acc, cap_i, state)
        end
        return true, index, cap_i             
    end
end

compilers["at least"] = function (pt, ccache)
    local matcher, n = compile(pt.pattern, ccache), pt.aux
    return function (subject, index, cap_acc, cap_i, state)
         -- dprint("At least  ",cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state) --, subject)
        local success = true
        for i = 1, n do
            success, index, cap_i = matcher(subject, index, cap_acc, cap_i, state)
            if not success then return false, index, cap_i end
        end
        local N = 1
        while success do
             -- dprint("    rep "..N,cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state)
            N=N+1
            success, index, cap_i = matcher(subject, index, cap_acc, cap_i, state)
        end
        return true, index, cap_i
    end
end

compilers["unm"] = function (pt, ccache)
    local matcher = compile(pt.pattern, ccache)
    return function (subject, index, cap_acc, cap_i, state)
         -- dprint("Unm     ", cap_acc, cap_acc and cap_acc.type or "'nil'", cap_i, index, state)
        -- Throw captures away
        local success, _, _ = matcher(subject, index, {type = "discard"}, 1, state)
        return not success, index, cap_i
    end
end

compilers["lookahead"] = function (pt, ccache)
    local matcher = compile(pt.pattern, ccache)
    return function (subject, index, cap_acc, cap_i, state)
         -- dprint("Lookahead", cap_acc, cap_acc and cap_acc.type or "'nil'", index, cap_i, state)
        -- Throw captures away
        local success, _, _ = matcher(subject, index, {type = "discard"}, 1, state)
         -- dprint("%Lookahead", cap_acc, cap_acc and cap_acc.type or "'nil'", index, cap_i, state)
        return success, index, cap_i
    end
end



---------------------------------------  .   ,      ,       ,     ------------
---------------------------------------  |\ /| ,--. |-- ,-- |__   ------------
-- Match ------------------------------  | v | ,--| |   |   |  |  ------------
---------------------------------------  '   ' `--' `-- `-- '  '  ------------


local
function PL_match(pt, subject, index, ...)
    pt = PL_P(pt)
    if index == nil then
        index = 1
    elseif type(index) ~= "number" then
        error"The index must be a number"
    elseif index == 0 then
        -- return nil -- This allows to pass the test, but not suer if correct.
        error("Dunno what to do with a 0 index")
    elseif index < 0 then
        index = #subject + index + 1
        if index < 1 then index = 1 end
    end
    -- print(("-"):rep(30))
    -- print(pt.ptype)
    -- PL.pprint(pt)
    local matcher, cap_acc, state, success, cap_i, nindex
        = compile(pt, {})
        , {type = "insert"}   -- capture accumulator
        , {grammars = {}, args = {n = select('#',...),...}, tags = {}}
        , 0 -- matcher state
    success, nindex, cap_i = matcher(subject, index, cap_acc, 1, state)
    if success then
        cap_acc.n = cap_i
        -- print("cap_i = ",cap_i)
        -- print("= $$$ captures $$$ =")
        -- PL.cprint(cap_acc)
        local captures = evaluate(cap_acc, subject, index)
        if #captures == 0 
        then return nindex
        else return t_unpack(captures) end
    else 
        return nil 
    end
end
PL.match = PL_match



---------------------------------------  ,--.     º      |     ---------------
---------------------------------------  |__' ,-- , ,-.  |--   ---------------
-- Print ------------------------------  |    |   | |  | |     ---------------
---------------------------------------  '    '   ' '  ' `--  ---------------

local printers, PL_pprint = {}

function PL_pprint (pt, offset, prefix)
    return printers[pt.ptype](pt, offset, prefix)
end

function PL.pprint (pt)
    pt = PL_P(pt)
    return PL_pprint(pt, "", "")
end

for k, v in pairs{
    string       = [[ "P( \""..pt.as_is.."\" )"       ]],
    ["true"]     = [[ "P( true )"                     ]],
    ["false"]    = [[ "P( false )"                    ]],
    eos          = [[ "~EOS~"                         ]],
    one          = [[ "P( one )"                      ]],
    any          = [[ "P( "..pt.aux.." )"            ]],
    set          = [[ "S( "..'"'..pt.as_is..'"'.." )" ]],
    ["function"] = [[ "P( "..pt.aux.." )"            ]],
    ref = [[
        "V( "
            ..(type(pt.aux)~="string" and tostring(pt.aux) or "\""..pt.aux.."\"")
            .." )"
        ]],
    range = [[
        "R( "
            ..t_concat(map(pt.as_is, function(e)return '"'..e..'"' end), ", ")
            .." )"
        ]]
} do
    printers[k] = load(([[
        local map, t_concat = ...
        return function (pt, offset, prefix)
            print(offset..prefix..XXXX)
        end
    ]]):gsub("XXXX", v), k.." printer")(map, t_concat)
end


for k, v in pairs{
    ["behind"] = [[ PL_pprint(pt.pattern, offset, "B ") ]],
    ["at least"] = [[ PL_pprint(pt.pattern, offset, pt.aux.." ^ ") ]],
    ["at most"] = [[ PL_pprint(pt.pattern, offset, pt.aux.." ^ ") ]],
    unm        = [[PL_pprint(pt.pattern, offset, "- ")]],
    lookahead  = [[PL_pprint(pt.pattern, offset, "# ")]],
    choice = [[
        print(offset..prefix.."+")
        -- dprint"Printer for choice"
        map(pt.aux, PL_pprint, offset.." :", "")
        ]],
    sequence = [[
        print(offset..prefix.."*")
        -- dprint"Printer for Seq"
        map(pt.aux, PL_pprint, offset.." |", "")
        ]],
    grammar   = [[
        print(offset..prefix.."Grammar")
        -- dprint"Printer for Grammar"
        for k, pt in pairs(pt.aux) do
            local prefix = ( type(k)~="string" 
                             and tostring(k)
                             or "\""..k.."\"" )
            PL_pprint(pt, offset.."  ", prefix .. " = ")
        end
    ]]
} do
    printers[k] = load(([[
        local map, PL_pprint, ptype = ...
        return function (pt, offset, prefix)
            XXXX
        end
    ]]):gsub("XXXX", v), k.." printer")(map, PL_pprint, type)
end

-------------------------------------------------------------------------------
--- Captures patterns
--

-- for __, cap in pairs{"C", "Cs", "Ct"} do
-- for __, cap in pairs{"Carg", "Cb", "Cp"} do
-- function PL_Cc (...)
-- for __, cap in pairs{"Cf", "Cmt"} do
-- function PL_Cg (pt, tag)
-- local valid_slash_type = newset{"string", "number", "table", "function"}


for __, cap in pairs{"C", "Cs", "Ct"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap)
        PL_pprint(pt.pattern, offset.."  ", "")
    end
end

for __, cap in pairs{"Cg", "Ctag", "Cf", "Cmt", "/number", "/zero", "/function", "/table"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap.." "..tostring(pt.aux or ""))
        PL_pprint(pt.pattern, offset.."  ", "")
    end
end

printers["/string"] = function (pt, offset, prefix)
    print(offset..prefix..'/string "'..tostring(pt.aux or "")..'"')
    PL_pprint(pt.pattern, offset.."  ", "")
end

for __, cap in pairs{"Carg", "Cp"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap.."( "..tostring(pt.aux).." )")
    end
end

printers["Cb"] = function (pt, offset, prefix)
    print(offset..prefix.."Cb( \""..pt.aux.."\" )")
end

printers["Cc"] = function (pt, offset, prefix)
    print(offset..prefix.."Cc(" ..t_concat(map(pt.aux, tostring),", ").." )")
end


-------------------------------------------------------------------------------
--- Capture objects
--

local cprinters = {}

function PL.cprint (capture)
    print"Capture Printer\n==============="
    print(capture)
    -- expose(capture)
    -- expose(capture[1])
    cprinters[capture.type](capture, "", "")
    print"/Cprinter -------"
end

cprinters["backref"] = function (capture, offset, prefix)
    print(offset..prefix.."Back: start = "..capture.start)
    cprinters[capture.ref.type](capture.ref, offset.."  ")
end

-- cprinters["string"] = function (capture, offset, prefix)
--     print(offset..prefix.."String: start = "..capture.start..", finish = "..capture.finish)
-- end
cprinters["value"] = function (capture, offset, prefix)
    print(offset..prefix.."Value: start = "..capture.start..", value = "..tostring(capture.value))
end

cprinters["values"] = function (capture, offset, prefix)
    -- expose(capture)
    print(offset..prefix.."Values: start = "..capture.start..", values = ")
    for _, c in pairs(capture.values) do
        print(offset.."  "..tostring(c))
    end
end

cprinters["insert"] = function (capture, offset, prefix)
    print(offset..prefix.."insert n="..capture.n)
    for i, subcap in ipairs(capture) do
        -- dprint("insertPrinter", subcap.type)
        cprinters[subcap.type](subcap, offset.."| ", i..". ")
    end

end

for __, capname in ipairs{
    "Cf", "Cg", "tag","C", "Cs", 
    "/string", "/number", "/table", "/function" 
} do 
    cprinters[capname] = function (capture, offset, prefix)
        local message = offset..prefix..capname..": start = "..capture.start ..", finish = "..capture.finish
        if capture.aux then 
            message = message .. ", aux = ".. tostring(capture.aux)
        end
        print(message)
        for i, subcap in ipairs(capture) do
            cprinters[subcap.type](subcap, offset.."  ", i..". ")
        end

    end
end


cprinters["Ct"] = function (capture, offset, prefix)
    local message = offset..prefix.."Ct: start = "..capture.start ..", finish = "..capture.finish
    if capture.aux then 
        message = message .. ", aux = ".. tostring(capture.aux)
    end
    print(message)
    for i, subcap in ipairs(capture) do
        print ("Subcap type",subcap.type)
        cprinters[subcap.type](subcap, offset.."  ", i..". ")
    end
    for k,v in pairs(capture.hash or {}) do 
        print(offset.."  "..k, "=", v)
        expose(v)
    end

end

cprinters["Cb"] = function (capture, offset, prefix)
    local message = offset..prefix.."Ct: start = "..capture.start ..", finish = "..capture.finish
    cprinters.Cg(capture.group, offset.."  ", "")
end





---------------------------------------  |                  |        ----------
---------------------------------------  |    ,--. ,-- ,--. |  ,--.  ----------
-- Locale -----------------------------  |    |  | |   ,--| |  |--'  ----------
---------------------------------------  +--- `--' `-- `--' `- `--'  ----------


-- We'll limit ourselves to the standard C locale for now.
-- see http://wayback.archive.org/web/20120310215042/http://www.utas.edu.au...
-- .../infosys/info/documentation/C/CStdLib.html#ctype.h

local R, S = PL_R, PL_S

local locale = {}
locale["cntrl"] = R"\0\31" + "\127"
locale["digit"] = R"09"
locale["lower"] = R"az"
locale["print"] = R" ~" -- 0x20 to 0xee
locale["space"] = S" \f\n\r\t\v" -- \f == form feed (for a printer), \v == vtab
locale["upper"] = R"AZ"

locale["alpha"]  = locale["lower"] + locale["upper"]
-- PL.pprint(locale.alpha)
locale["alnum"]  = locale["alpha"] + locale["digit"]
locale["graph"]  = locale["print"] - locale["space"]
locale["punct"]  = locale["graph"] - locale["alnum"]
locale["xdigit"] = locale["digit"] + R"af" + R"AF"


function PL.locale (t)
    return extend(t or {}, locale)
end






---------------------------------------  ----- ,           ,---         ,  ----
---------------------------------------    |   |__  ,--.   |__  ,-.   __|  ----
---------------------------------------    |   |  | |--'   |    |  | |  |  ----
---------------------------------------    '   '  ' `--'   `--- '  ' `--'  ----

return PL

end -- PLPeg

local PL = PLPeg("binary")
PL.PLPeg = PLPeg

return PL

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