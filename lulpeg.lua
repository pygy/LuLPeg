-- LuLPeg, a pure Lua port of LPeg, Roberto Ierusalimschy's
-- Parsing Expression Grammars library.
-- 
-- Copyright (C) Pierre-Yves Gerardy.
-- Released under the Romantic WTF Public License (cf. the LICENSE
-- file or the end of this file, whichever is present).
-- 
-- See http://www.inf.puc-rio.br/~roberto/lpeg/ for the original.
-- 
-- The re.lua module and the test suite (tests/lpeg.*.*.tests.lua)
-- are part of the original LPeg distribution.
local _ENV,       loaded, packages, release, require_ 
    = _ENV or _G, {},     {},       true,    require

local function require(...)
    local lib = ...

    -- is it a private file?
    if loaded[lib] then 
        return loaded[lib]
    elseif packages[lib] then 
        loaded[lib] = packages[lib](lib)
        return loaded[lib]
    else
        return require_(lib)
    end
end

--=============================================================================
do local _ENV = _ENV
packages['analizer'] = function (...)

local u = require"util"
local nop, weakkey = u.nop, u.weakkey
local hasVcache, hasCmtcache , lengthcache
    = weakkey{}, weakkey{},    weakkey{}
return {
    hasV = nop,
    hasCmt = nop,
    length = nop,
    hasCapture = nop
}

end
end
--=============================================================================
do local _ENV = _ENV
packages['compiler'] = function (...)
local pairs, error, tostring, type
    = pairs, error, tostring, type
local s, t, u = require"string", require"table", require"util"
local _ENV = u.noglobals() ----------------------------------------------------
local s_byte, s_sub, t_concat, t_insert, t_remove, t_unpack
    = s.byte, s.sub, t.concat, t.insert, t.remove, u.unpack
local   load,   map,   map_all, t_pack
    = u.load, u.map, u.map_all, u.pack
return function(Builder, LL)
local evaluate, LL_ispattern =  LL.evaluate, LL.ispattern
local charset = Builder.charset
local compilers = {}
local
function compile(pt, ccache)
    if not LL_ispattern(pt) then
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
        pt.compiled = compilers[pt.ptype](pt, ccache)
    end
    return pt.compiled
end
LL.compile = compile
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
    compilers[k] = load(([=[
    local compile = ...
    return function (pt, ccache)
        local matcher, aux = compile(pt.pattern, ccache), pt.aux
        return function (subject, index, cap_acc, cap_i, state)
            local new_acc, nindex, success = {
                type = "XXXX",
                start = index,
                aux = aux,
                parent = cap_acc,
                parent_i = cap_i
            }
            success, index, new_acc.n
                = matcher(subject, index, new_acc, 1, state)
            if success then
                new_acc.finish = index
                cap_acc[cap_i] = new_acc
                cap_i = cap_i + 1
            end
            return success, index, cap_i
        end
    end]=]):gsub("XXXX", v), k.." compiler")(compile)
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
        cap_acc[cap_i] = {
            type = "Cb",
            start = index,
            finish = index,
            parent = cap_acc,
            parent_i = cap_i,
            tag = tag
        }
        return true, index, cap_i + 1
    end
end
compilers["Cc"] = function (pt, ccache)
    local values = pt.aux
    return function (subject, index, cap_acc, cap_i, state)
        cap_acc[cap_i] = {
            type = "values",
            values = values,
            start = index,
            finish = index,
            n = values.n
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
        local new_acc, success = {
            type = "Cg",
            start = index,
            Ctag = tag,
            parent = cap_acc,
            parent_i = cap_i
        }
        success, new_acc.finish, new_acc.n
            = matcher(subject, index, new_acc, 1, state)
        if success then
            cap_acc[cap_i] = new_acc
            cap_i = cap_i + 1
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
local function pack_Cmt_caps(i,...) return i, t_pack(...) end
compilers["Cmt"] = function (pt, ccache)
    local matcher, func = compile(pt.pattern, ccache), pt.aux
    return function (subject, index, cap_acc, cap_i, state)
        local tmp_acc = {
            type = "insert",
            parent = cap_acc,
            parent_i = cap_i
        }
        local success, nindex, tmp_i = matcher(subject, index, tmp_acc, 1, state)
        if not success then return false, index, cap_i end
        local captures, mt_cap_i
        if tmp_i == 1 then
            captures, mt_cap_i = {s_sub(subject, index, nindex - 1)}, 2
        else
            tmp_acc.n = tmp_i
            captures, mt_cap_i = evaluate(tmp_acc, subject, nindex)
        end
        local nnindex, values = pack_Cmt_caps(
            func(subject, nindex, t_unpack(captures, 1, mt_cap_i - 1))
        )
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
                    finish = nnindex,
                    n = values.n
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
compilers["string"] = function (pt, ccache)
    local S = pt.aux
    local N = #S
    return function(subject, index, cap_acc, cap_i, state)
        local in_1 = index - 1
        for i = 1, N do
            local c
            c = s_byte(subject,in_1 + i)
            if c ~= S[i] then
                return false, index, cap_i
            end
        end
        return true, index + N, cap_i
    end
end
compilers["char"] = function (pt, ccache)
    return load(([=[
        local s_byte = ...
        return function(subject, index, cap_acc, cap_i, state)
            local c, nindex = s_byte(subject, index), index + 1
            if c ~= __C0__ then
                return false, index, cap_i
            end
            return true, nindex, cap_i
        end]=]):gsub("__C0__", tostring(pt.aux)))(s_byte)
end
local
function truecompiled (subject, index, cap_acc, cap_i, state)
    return true, index, cap_i
end
compilers["true"] = function (pt)
    return truecompiled
end
local
function falsecompiled (subject, index, cap_acc, cap_i, state)
    return false, index, cap_i
end
compilers["false"] = function (pt)
    return falsecompiled
end
local
function eoscompiled (subject, index, cap_acc, cap_i, state)
    return index > #subject, index, cap_i
end
compilers["eos"] = function (pt)
    return eoscompiled
end
local
function onecompiled (subject, index, cap_acc, cap_i, state)
    local char, nindex = s_byte(subject, index), index + 1
    if char
    then return true, nindex, cap_i
    else return false, index, cap_i end
end
compilers["one"] = function (pt)
    return onecompiled
end
compilers["any"] = function (pt)
    local N = pt.aux
    if N == 1 then
        return onecompiled
    elseif not charset.binary then
        return function(subject, index, cap_acc, cap_i, state)
            local n, c, nindex = N
            while n > 0 do
                c, nindex = s_byte(subject, index), index + 1
                if not c then
                    return false, index, cap_i
                end
                n = n -1
            end
            return true, nindex, cap_i
        end
    else -- version optimized for byte-width encodings.
        N = pt.aux - 1
        return function(subject, index, cap_acc, cap_i, state)
            local n = index + N
            if n <= #subject then
                return true, n + 1, cap_i
            else
                return false, index, cap_i
            end
        end
    end
end
do
    local function checkpatterns(g)
        for k,v in pairs(g.aux) do
            if not LL_ispattern(v) then
                error(("rule 'A' is not a pattern"):gsub("A", tostring(k)))
            end
        end
    end
    compilers["grammar"] = function (pt, ccache)
        checkpatterns(pt)
        local gram = map_all(pt.aux, compile, ccache)
        local start = gram[1]
        return function (subject, index, cap_acc, cap_i, state)
            t_insert(state.grammars, gram)
            local success, nindex, cap_i = start(subject, index, cap_acc, cap_i, state)
            t_remove(state.grammars)
            return success, nindex, cap_i
        end
    end
end
compilers["behind"] = function (pt, ccache)
    local matcher, N = compile(pt.pattern, ccache), pt.aux
    return function (subject, index, cap_acc, cap_i, state)
        if index <= N then return false, index, cap_i end
        local success = matcher(subject, index - N, {type = "discard"}, cap_i, state)
        return success, index, cap_i
    end
end
compilers["range"] = function (pt)
    local ranges = pt.aux
    return function (subject, index, cap_acc, cap_i, state)
        local char, nindex = s_byte(subject, index), index + 1
        for i = 1, #ranges do
            local r = ranges[i]
            if char and r[char]
            then return true, nindex, cap_i end
        end
        return false, index, cap_i
    end
end
compilers["set"] = function (pt)
    local s = pt.aux
    return function (subject, index, cap_acc, cap_i, state)
        local char, nindex = s_byte(subject, index), index + 1
        if s[char]
        then return true, nindex, cap_i
        else return false, index, cap_i end
    end
end
compilers["range"] = compilers.set
compilers["ref"] = function (pt, ccache)
    local name = pt.aux
    local ref
    return function (subject, index, cap_acc, cap_i, state)
        if not ref then
            if #state.grammars == 0 then
                error(("rule 'XXXX' used outside a grammar"):gsub("XXXX", tostring(name)))
            elseif not state.grammars[#state.grammars][name] then
                error(("rule 'XXXX' undefined in given grammar"):gsub("XXXX", tostring(name)))
            end
            ref = state.grammars[#state.grammars][name]
        end
        return ref(subject, index, cap_acc, cap_i, state)
    end
end
local choice_tpl = [=[
            success, index, cap_i = XXXX(subject, index, cap_acc, cap_i, state)
            if success then
                return true, index, cap_i
            end]=]
compilers["choice"] = function (pt, ccache)
    local choices, n = map(pt.aux, compile, ccache), #pt.aux
    local names, chunks = {}, {}
    for i = 1, n do
        local m = "ch"..i
        names[#names + 1] = m
        chunks[ #names  ] = choice_tpl:gsub("XXXX", m)
    end
    local compiled = t_concat{
        "local ", t_concat(names, ", "), [=[ = ...
        return function (subject, index, cap_acc, cap_i, state)
            local success
            ]=],
            t_concat(chunks,"\n"),[=[
            return false, index, cap_i
        end]=]
    }
    return load(compiled, "Choice")(t_unpack(choices))
end
local sequence_tpl = [=[
            success, nindex, new_i = XXXX(subject, nindex, cap_acc, new_i, state)
            if not success then
                return false, index, cap_i
            end]=]
compilers["sequence"] = function (pt, ccache)
    local sequence, n = map(pt.aux, compile, ccache), #pt.aux
    local names, chunks = {}, {}
    for i = 1, n do
        local m = "seq"..i
        names[#names + 1] = m
        chunks[ #names  ] = sequence_tpl:gsub("XXXX", m)
    end
    local compiled = t_concat{
        "local ", t_concat(names, ", "), [=[ = ...
        return function (subject, index, cap_acc, cap_i, state)
            local nindex, new_i, success = index, cap_i
            ]=],
            t_concat(chunks,"\n"),[=[
            return true, nindex, new_i
        end]=]
    }
   return load(compiled, "Sequence")(t_unpack(sequence))
end
compilers["at most"] = function (pt, ccache)
    local matcher, n = compile(pt.pattern, ccache), pt.aux
    n = -n
    return function (subject, index, cap_acc, cap_i, state)
        local success = true
        for i = 1, n do
            success, index, cap_i = matcher(subject, index, cap_acc, cap_i, state)
        end
        return true, index, cap_i
    end
end
compilers["at least"] = function (pt, ccache)
    local matcher, n = compile(pt.pattern, ccache), pt.aux
    if n == 0 then
        return function (subject, index, cap_acc, cap_i, state)
            local success = true
            while success do
                success, index, cap_i = matcher(subject, index, cap_acc, cap_i, state)
            end
            return true, index, cap_i
        end
    elseif n == 1 then
        return function (subject, index, cap_acc, cap_i, state)
            local success = true
            success, index, cap_i = matcher(subject, index, cap_acc, cap_i, state)
            if not success then return false, index, cap_i end
            while success do
                success, index, cap_i = matcher(subject, index, cap_acc, cap_i, state)
            end
            return true, index, cap_i
        end
    else
        return function (subject, index, cap_acc, cap_i, state)
            local success = true
            for _ = 1, n do
                success, index, cap_i = matcher(subject, index, cap_acc, cap_i, state)
                if not success then return false, index, cap_i end
            end
            while success do
                success, index, cap_i = matcher(subject, index, cap_acc, cap_i, state)
            end
            return true, index, cap_i
        end
    end
end
compilers["unm"] = function (pt, ccache)
    if pt.ptype == "any" and pt.aux == 1 then
        return eoscompiled
    end
    local matcher = compile(pt.pattern, ccache)
    return function (subject, index, cap_acc, cap_i, state)
        local success, _, _ = matcher(subject, index, {type = "discard", parent = cap_acc, parent_i = cap_i}, 1, state)
        return not success, index, cap_i
    end
end
compilers["lookahead"] = function (pt, ccache)
    local matcher = compile(pt.pattern, ccache)
    return function (subject, index, cap_acc, cap_i, state)
        local success, _, _ = matcher(subject, index, {type = "discard", parent = cap_acc, parent_i = cap_i}, 1, state)
        return success, index, cap_i
    end
end
end

end
end
--=============================================================================
do local _ENV = _ENV
packages['datastructures'] = function (...)
local getmetatable, pairs, setmetatable, type
    = getmetatable, pairs, setmetatable, type
local m, t , u = require"math", require"table", require"util"
local compat = require"compat"
local ffi if compat.luajit then
    ffi = require"ffi"
end
local _ENV = u.noglobals() ----------------------------------------------------
local   extend,   load, u_max
    = u.extend, u.load, u.max
local m_max, t_concat, t_insert, t_sort
    = m.max, t.concat, t.insert, t.sort
local structfor = {}
local byteset_new, isboolset, isbyteset
local byteset_mt = {}
local
function byteset_constructor (upper)
    local set = setmetatable(load(t_concat{
        "return{ [0]=false",
        (", false"):rep(upper),
        " }"
    })(),
    byteset_mt)
    return set
end
if compat.jit then
    local struct, boolset_constructor = {v={}}
    function byteset_mt.__index(s,i)
        if i == nil or i > s.upper then return nil end
        return s.v[i]
    end
    function byteset_mt.__len(s)
        return s.upper
    end
    function byteset_mt.__newindex(s,i,v)
        s.v[i] = v
    end
    boolset_constructor = ffi.metatype('struct { int upper; bool v[?]; }', byteset_mt)
    function byteset_new (t)
        if type(t) == "number" then
            local res = boolset_constructor(t+1)
            res.upper = t
            return res
        end
        local upper = u_max(t)
        struct.upper = upper
        if upper > 255 then error"bool_set overflow" end
        local set = boolset_constructor(upper+1)
        set.upper = upper
        for i = 1, #t do set[t[i]] = true end
        return set
    end
    function isboolset(s) return type(s)=="cdata" and ffi.istype(s, boolset_constructor) end
    isbyteset = isboolset
else
    function byteset_new (t)
        if type(t) == "number" then return byteset_constructor(t) end
        local set = byteset_constructor(u_max(t))
        for i = 1, #t do set[t[i]] = true end
        return set
    end
    function isboolset(s) return false end
    function isbyteset (s)
        return getmetatable(s) == byteset_mt
    end
end
local
function byterange_new (low, high)
    high = ( low <= high ) and high or -1
    local set = byteset_new(high)
    for i = low, high do
        set[i] = true
    end
    return set
end
local
function byteset_union (a ,b)
    local upper = m_max(#a, #b)
    local res = byteset_new(upper)
    for i = 0, upper do
        res[i] = a[i] or b[i] or false
    end
    return res
end
local
function byteset_difference (a, b)
    local res = {}
    for i = 0, 255 do
        res[i] = a[i] and not b[i]
    end
    return res
end
local
function byteset_tostring (s)
    local list = {}
    for i = 0, 255 do
        list[#list+1] = (s[i] == true) and i or nil
    end
    return t_concat(list,", ")
end
structfor.binary = {
    set ={
        new = byteset_new,
        union = byteset_union,
        difference = byteset_difference,
        tostring = byteset_tostring
    },
    Range = byterange_new,
    isboolset = isboolset,
    isbyteset = isbyteset,
    isset = isbyteset
}
local set_mt = {}
local
function set_new (t)
    local set = setmetatable({}, set_mt)
    for i = 1, #t do set[t[i]] = true end
    return set
end
local -- helper for the union code.
function add_elements(a, res)
    for k in pairs(a) do res[k] = true end
    return res
end
local
function set_union (a, b)
    a, b = (type(a) == "number") and set_new{a} or a
         , (type(b) == "number") and set_new{b} or b
    local res = set_new{}
    add_elements(a, res)
    add_elements(b, res)
    return res
end
local
function set_difference(a, b)
    local list = {}
    a, b = (type(a) == "number") and set_new{a} or a
         , (type(b) == "number") and set_new{b} or b
    for el in pairs(a) do
        if a[el] and not b[el] then
            list[#list+1] = el
        end
    end
    return set_new(list)
end
local
function set_tostring (s)
    local list = {}
    for el in pairs(s) do
        t_insert(list,el)
    end
    t_sort(list)
    return t_concat(list, ",")
end
local
function isset (s)
    return (getmetatable(s) == set_mt)
end
local
function range_new (start, finish)
    local list = {}
    for i = start, finish do
        list[#list + 1] = i
    end
    return set_new(list)
end
structfor.other = {
    set = {
        new = set_new,
        union = set_union,
        tostring = set_tostring,
        difference = set_difference,
    },
    Range = range_new,
    isboolset = isboolset,
    isbyteset = isbyteset,
    isset = isset,
    isrange = function(a) return false end
}
return function(Builder, LL)
    local cs = (Builder.options or {}).charset or "binary"
    if type(cs) == "string" then
        cs = (cs == "binary") and "binary" or "other"
    else
        cs = cs.binary and "binary" or "other"
    end
    return extend(Builder, structfor[cs])
end

end
end
--=============================================================================
do local _ENV = _ENV
packages['charsets'] = function (...)

local s, t, u = require"string", require"table", require"util"
local _ENV = u.noglobals() ----------------------------------------------------
local copy = u.copy
local s_char, s_sub, s_byte, t_concat, t_insert
    = s.char, s.sub, s.byte, t.concat, t.insert
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
local
function utf8_validate (subject, start, finish)
    start = start or 1
    finish = finish or #subject
    local offset, char
        = 0
    for i = start,finish do
        local b = s_byte(subject,i)
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
local
function utf8_next_char (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    local offset = utf8_offset(s_byte(subject,i))
    return i + offset, i, s_sub(subject, i, i + offset)
end
local
function utf8_split_int (subject)
    local chars = {}
    for _, _, c in utf8_next_int, subject do
        t_insert(chars,c)
    end
    return chars
end
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
function split_generator (get)
    if not get then return end
    return function(subject)
        local res = {}
        local o, i = true
        while o do
            o,i = get(subject, i)
            res[#res] = o
        end
        return res
    end
end
local
function merge_generator (char)
    if not char then return end
    return function(ary)
        local res = {}
        for i = 1, #ary do
            t_insert(res,char(ary[i]))
        end
        return t_concat(res)
    end
end
local
function utf8_get_int2 (subject, i)
    local byte, b5, b4, b3, b2, b1 = s_byte(subject, i)
    if byte < 128 then return byte, i + 1
    elseif byte < 192 then
        error("Byte values between 0x80 to 0xBF cannot start a multibyte sequence")
    elseif byte < 224 then
        return (byte - 192)*64 + s_byte(subject, i+1), i+2
    elseif byte < 240 then
            b2, b1 = s_byte(subject, i+1, i+2)
        return (byte-224)*4096 + b2%64*64 + b1%64, i+3
    elseif byte < 248 then
        b3, b2, b1 = s_byte(subject, i+1, i+2, 1+3)
        return (byte-240)*262144 + b3%64*4096 + b2%64*64 + b1%64, i+4
    elseif byte < 252 then
        b4, b3, b2, b1 = s_byte(subject, i+1, i+2, 1+3, i+4)
        return (byte-248)*16777216 + b4%64*262144 + b3%64*4096 + b2%64*64 + b1%64, i+5
    elseif byte < 254 then
        b5, b4, b3, b2, b1 = s_byte(subject, i+1, i+2, 1+3, i+4, i+5)
        return (byte-252)*1073741824 + b5%64*16777216 + b4%64*262144 + b3%64*4096 + b2%64*64 + b1%64, i+6
    else
        error("Byte values between 0xFE and OxFF cannot start a multibyte sequence")
    end
end
local
function utf8_get_char(subject, i)
    if i > #subject then return end
    local offset = utf8_offset(s_byte(subject,i))
    return s_sub(subject, i, i + offset), i + offset + 1
end
local
function utf8_char(c)
    if     c < 128 then
        return                                                                               s_char(c)
    elseif c < 2048 then
        return                                                          s_char(192 + c/64, 128 + c%64)
    elseif c < 65536 then
        return                                         s_char(224 + c/4096, 128 + c/64%64, 128 + c%64)
    elseif c < 2097152 then
        return                      s_char(240 + c/262144, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
    elseif c < 67108864 then
        return s_char(248 + c/16777216, 128 + c/262144%64, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
    elseif c < 2147483648 then
        return s_char( 252 + c/1073741824,
                   128 + c/16777216%64, 128 + c/262144%64, 128 + c/4096%64, 128 + c/64%64, 128 + c%64)
    end
    error("Bad Unicode code point: "..c..".")
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
local charsets = {
    binary = {
        name = "binary",
        binary = true,
        validate   = binary_validate,
        split_char = binary_split_char,
        split_int  = binary_split_int,
        next_char  = binary_next_char,
        next_int   = binary_next_int,
        get_char   = binary_get_char,
        get_int    = binary_get_int,
        tochar    = s_char
    },
    ["UTF-8"] = {
        name = "UTF-8",
        validate   = utf8_validate,
        split_char = utf8_split_char,
        split_int  = utf8_split_int,
        next_char  = utf8_next_char,
        next_int   = utf8_next_int,
        get_char   = utf8_get_char,
        get_int    = utf8_get_int
    }
}
return function (Builder)
    local cs = Builder.options.charset or "binary"
    if charsets[cs] then
        Builder.charset = copy(charsets[cs])
        Builder.binary_split_int = binary_split_int
    else
        error("NYI: custom charsets")
    end
end

end
end
--=============================================================================
do local _ENV = _ENV
packages['re'] = function (...)

return function(Builder, LL)
local tonumber, type, print, error = tonumber, type, print, error
local setmetatable = setmetatable
local m = LL
local mm = m
local mt = getmetatable(mm.P(0))
local version = _VERSION
if version == "Lua 5.2" then _ENV = nil end
local any = m.P(1)
local Predef = { nl = m.P"\n" }
local mem
local fmem
local gmem
local function updatelocale ()
  mm.locale(Predef)
  Predef.a = Predef.alpha
  Predef.c = Predef.cntrl
  Predef.d = Predef.digit
  Predef.g = Predef.graph
  Predef.l = Predef.lower
  Predef.p = Predef.punct
  Predef.s = Predef.space
  Predef.u = Predef.upper
  Predef.w = Predef.alnum
  Predef.x = Predef.xdigit
  Predef.A = any - Predef.a
  Predef.C = any - Predef.c
  Predef.D = any - Predef.d
  Predef.G = any - Predef.g
  Predef.L = any - Predef.l
  Predef.P = any - Predef.p
  Predef.S = any - Predef.s
  Predef.U = any - Predef.u
  Predef.W = any - Predef.w
  Predef.X = any - Predef.x
  mem = {}    -- restart memoization
  fmem = {}
  gmem = {}
  local mt = {__mode = "v"}
  setmetatable(mem, mt)
  setmetatable(fmem, mt)
  setmetatable(gmem, mt)
end
updatelocale()
local function getdef (id, defs)
  local c = defs and defs[id]
  if not c then error("undefined name: " .. id) end
  return c
end
local function patt_error (s, i)
  local msg = (#s < i + 20) and s:sub(i)
                             or s:sub(i,i+20) .. "..."
  msg = ("pattern error near '%s'"):format(msg)
  error(msg, 2)
end
local function mult (p, n)
  local np = mm.P(true)
  while n >= 1 do
    if n%2 >= 1 then np = np * p end
    p = p * p
    n = n/2
  end
  return np
end
local function equalcap (s, i, c)
  if type(c) ~= "string" then return nil end
  local e = #c + i
  if s:sub(i, e - 1) == c then return e else return nil end
end
local S = (Predef.space + "--" * (any - Predef.nl)^0)^0
local name = m.R("AZ", "az", "__") * m.R("AZ", "az", "__", "09")^0
local arrow = S * "<-"
local seq_follow = m.P"/" + ")" + "}" + ":}" + "~}" + "|}" + (name * arrow) + -1
name = m.C(name)
local Def = name * m.Carg(1)
local num = m.C(m.R"09"^1) * S / tonumber
local String = "'" * m.C((any - "'")^0) * "'" +
               '"' * m.C((any - '"')^0) * '"'
local defined = "%" * Def / function (c,Defs)
  local cat =  Defs and Defs[c] or Predef[c]
  if not cat then error ("name '" .. c .. "' undefined") end
  return cat
end
local Range = m.Cs(any * (m.P"-"/"") * (any - "]")) / mm.R
local item = defined + Range + m.C(any)
local Class =
    "["
  * (m.C(m.P"^"^-1))    -- optional complement symbol
  * m.Cf(item * (item - "]")^0, mt.__add) /
                          function (c, p) return c == "^" and any - p or p end
  * "]"
local function adddef (t, k, exp)
  if t[k] then
    error("'"..k.."' already defined as a rule")
  else
    t[k] = exp
  end
  return t
end
local function firstdef (n, r) return adddef({n}, n, r) end
local function NT (n, b)
  if not b then
    error("rule '"..n.."' used outside a grammar")
  else return mm.V(n)
  end
end
local exp = m.P{ "Exp",
  Exp = S * ( m.V"Grammar"
            + m.Cf(m.V"Seq" * ("/" * S * m.V"Seq")^0, mt.__add) );
  Seq = m.Cf(m.Cc(m.P"") * m.V"Prefix"^0 , mt.__mul)
        * (#seq_follow + patt_error);
  Prefix = "&" * S * m.V"Prefix" / mt.__len
         + "!" * S * m.V"Prefix" / mt.__unm
         + m.V"Suffix";
  Suffix = m.Cf(m.V"Primary" * S *
          ( ( m.P"+" * m.Cc(1, mt.__pow)
            + m.P"*" * m.Cc(0, mt.__pow)
            + m.P"?" * m.Cc(-1, mt.__pow)
            + "^" * ( m.Cg(num * m.Cc(mult))
                    + m.Cg(m.C(m.S"+-" * m.R"09"^1) * m.Cc(mt.__pow))
                    )
            + "->" * S * ( m.Cg((String + num) * m.Cc(mt.__div))
                         + m.P"{}" * m.Cc(nil, m.Ct)
                         + m.Cg(Def / getdef * m.Cc(mt.__div))
                         )
            + "=>" * S * m.Cg(Def / getdef * m.Cc(m.Cmt))
            ) * S
          )^0, function (a,b,f) return f(a,b) end );
  Primary = "(" * m.V"Exp" * ")"
            + String / mm.P
            + Class
            + defined
            + "{:" * (name * ":" + m.Cc(nil)) * m.V"Exp" * ":}" /
                     function (n, p) return mm.Cg(p, n) end
            + "=" * name / function (n) return mm.Cmt(mm.Cb(n), equalcap) end
            + m.P"{}" / mm.Cp
            + "{~" * m.V"Exp" * "~}" / mm.Cs
            + "{|" * m.V"Exp" * "|}" / mm.Ct
            + "{" * m.V"Exp" * "}" / mm.C
            + m.P"." * m.Cc(any)
            + (name * -arrow + "<" * name * ">") * m.Cb("G") / NT;
  Definition = name * arrow * m.V"Exp";
  Grammar = m.Cg(m.Cc(true), "G") *
            m.Cf(m.V"Definition" / firstdef * m.Cg(m.V"Definition")^0,
              adddef) / mm.P
}
local pattern = S * m.Cg(m.Cc(false), "G") * exp / mm.P * (-any + patt_error)
local function compile (p, defs)
  if mm.type(p) == "pattern" then return p end   -- already compiled
  local cp = pattern:match(p, 1, defs)
  if not cp then error("incorrect pattern", 3) end
  return cp
end
local function match (s, p, i)
  local cp = mem[p]
  if not cp then
    cp = compile(p)
    mem[p] = cp
  end
  return cp:match(s, i or 1)
end
local function find (s, p, i)
  local cp = fmem[p]
  if not cp then
    cp = compile(p) / 0
    cp = mm.P{ mm.Cp() * cp * mm.Cp() + 1 * mm.V(1) }
    fmem[p] = cp
  end
  local i, e = cp:match(s, i or 1)
  if i then return i, e - 1
  else return i
  end
end
local function gsub (s, p, rep)
  local g = gmem[p] or {}   -- ensure gmem[p] is not collected while here
  gmem[p] = g
  local cp = g[rep]
  if not cp then
    cp = compile(p)
    cp = mm.Cs((cp / rep + 1)^0)
    g[rep] = cp
  end
  return cp:match(s)
end
local re = {
  compile = compile,
  match = match,
  find = find,
  gsub = gsub,
  updatelocale = updatelocale,
}
return re
end
end
end
--=============================================================================
do local _ENV = _ENV
packages['evaluator'] = function (...)

local select, tonumber, tostring
    = select, tonumber, tostring
local s, t, u = require"string", require"table", require"util"
local s_sub, t_concat
    = s.sub, t.concat
local t_unpack
    = u.unpack
local _ENV = u.noglobals() ----------------------------------------------------
return function(Builder, LL) -- Decorator wrapper
local evaluators, insert = {}
local
function evaluate (capture, subject, subj_i)
    local acc, val_i, _ = {}
    val_i = insert(capture, subject, acc, subj_i, 1)
    return acc, val_i
end
LL.evaluate = evaluate
function insert (capture, subject, acc, subj_i, val_i)
    for i = 1, capture.n - 1 do
            val_i =
                evaluators[capture[i].type](capture[i], subject, acc, subj_i, val_i)
            subj_i = capture[i].finish
    end
    return val_i
end
local
function lookback(capture, tag, subj_i)
    local found
    repeat
        for i = subj_i - 1, 1, -1 do
            if  capture[i].Ctag == tag then
                found = capture[i]
                break
            end
        end
        capture, subj_i = capture.parent, capture.parent_i
    until found or not capture
    if found then
        return found
    else
        tag = type(tag) == "string" and "'"..tag.."'" or tostring(tag)
        error("back reference "..tag.." not found")
    end
end
evaluators["Cb"] = function (capture, subject, acc, subj_i, val_i)
    local ref, Ctag
    ref = lookback(capture.parent, capture.tag, capture.parent_i)
    ref.Ctag, Ctag = nil, ref.Ctag
    val_i = evaluators.Cg(ref, subject, acc, ref.start, val_i)
    ref.Ctag = Ctag
    return val_i
end
evaluators["Cf"] = function (capture, subject, acc, subj_i, val_i)
    if capture.n == 0 then
        error"No First Value"
    end
    local func, fold_acc, first_val_i = capture.aux, {}
    first_val_i = evaluators[capture[1].type](capture[1], subject, fold_acc, subj_i, 1)
    if first_val_i == 1 then
        error"No first value"
    end
    subj_i = capture[1].finish
    local result = fold_acc[1]
    for i = 2, capture.n - 1 do
        local fold_acc2 = {}
        local val_i = evaluators[capture[i].type](capture[i], subject, fold_acc2, subj_i, 1)
        subj_i = capture[i].finish
        result = func(result, t_unpack(fold_acc2, 1, val_i - 1))
    end
    acc[val_i] = result
    return val_i + 1
end
evaluators["Cg"] = function (capture, subject, acc, subj_i, val_i)
    local start, finish = capture.start, capture.finish
    local group_acc = {}
    if capture.Ctag ~= nil  then
        return val_i
    end
    local group_val_i = insert(capture, subject, group_acc, start, 1)
    if group_val_i == 1 then
        acc[val_i] = s_sub(subject, start, finish - 1)
        return val_i + 1
    else
        for i = 1, group_val_i - 1 do
            val_i, acc[val_i] = val_i + 1, group_acc[i]
        end
        return val_i
    end
end
evaluators["C"] = function (capture, subject, acc, subj_i, val_i)
    val_i, acc[val_i] = val_i + 1, s_sub(subject,capture.start, capture.finish - 1)
    local _
    val_i = insert(capture, subject, acc, capture.start, val_i)
    return val_i
end
evaluators["Cs"] = function (capture, subject, acc, subj_i, val_i)
    local start, finish, n = capture.start, capture.finish, capture.n
    if n == 1 then
        acc[val_i] = s_sub(subject, start, finish - 1)
    else
        local subst_acc, cap_i, subst_i = {}, 1, 1
        repeat
            local cap, tmp_acc = capture[cap_i], {}
            subst_acc[subst_i] = s_sub(subject, start, cap.start - 1)
            subst_i = subst_i + 1
            local tmp_i = evaluators[cap.type](cap, subject, tmp_acc, subj_i, 1)
            if tmp_i > 1 then
                subst_acc[subst_i] = tmp_acc[1]
                subst_i = subst_i + 1
                start = cap.finish
            else
                start = cap.start
            end
            cap_i = cap_i + 1
        until cap_i == n
        subst_acc[subst_i] = s_sub(subject, start, finish - 1)
        acc[val_i] = t_concat(subst_acc)
    end
    return val_i + 1
end
evaluators["Ct"] = function (capture, subject, acc, subj_i, val_i)
    local tbl_acc, new_val_i, _ = {}, 1
    for i = 1, capture.n - 1 do
        local cap = capture[i]
        if cap.Ctag ~= nil then
            local tmp_acc = {}
            insert(cap, subject, tmp_acc, cap.start, 1)
            local val = (#tmp_acc == 0 and s_sub(subject, cap.start, cap.finish - 1) or tmp_acc[1])
            tbl_acc[cap.Ctag] = val
        else
            new_val_i = evaluators[cap.type](cap, subject, tbl_acc, cap.start, new_val_i)
        end
    end
    acc[val_i] = tbl_acc
    return val_i + 1
end
evaluators["value"] = function (capture, subject, acc, subj_i, val_i)
    acc[val_i] = capture.value
    return val_i + 1
end
evaluators["values"] = function (capture, subject, acc, subj_i, val_i)
local these_values = capture.values
    for i = 1, these_values.n do
        val_i, acc[val_i] = val_i + 1, these_values[i]
    end
    return val_i
end
evaluators["/string"] = function (capture, subject, acc, subj_i, val_i)
    local n, cached = capture.n, {}
    acc[val_i] = capture.aux:gsub("%%([%d%%])", function (d)
        if d == "%" then return "%" end
        d = tonumber(d)
        if not cached[d] then
            if d >= n then
                error("no capture at index "..d.." in /string capture.")
            end
            if d == 0 then
                cached[d] = s_sub(subject, capture.start, capture.finish - 1)
            else
                local tmp_acc = {}
                local val_i = evaluators[capture[d].type](capture[d], subject, tmp_acc, capture.start, 1)
                if val_i == 1 then error("no values in capture at index"..d.." in /string capture.") end
                cached[d] = tmp_acc[1]
            end
        end
        return cached[d]
    end)
    return val_i + 1
end
evaluators["/number"] = function (capture, subject, acc, subj_i, val_i)
    local new_acc = {}
    local new_val_i = insert(capture, subject, new_acc, capture.start, 1)
    if capture.aux >= new_val_i then error("no capture '"..capture.aux.."' in /number capture.") end
    acc[val_i] = new_acc[capture.aux]
    return val_i + 1
end
evaluators["/table"] = function (capture, subject, acc, subj_i, val_i)
    local key
    if capture.n > 1 then
        local new_acc = {}
        insert(capture, subject, new_acc, capture.start, 1)
        key = new_acc[1]
    else
        key = s_sub(subject, capture.start, capture.finish - 1)
    end
    if capture.aux[key] then
        acc[val_i] = capture.aux[key]
        return val_i + 1
    else
        return val_i
    end
end
local
function insert_divfunc_results(acc, val_i, ...)
    local n = select('#', ...)
    for i = 1, n do
        val_i, acc[val_i] = val_i + 1, select(i, ...)
    end
    return val_i
end
evaluators["/function"] = function (capture, subject, acc, subj_i, val_i)
    local func, params, new_val_i = capture.aux
    if capture.n > 1 then
        params = {}
        new_val_i = insert(capture, subject, params, capture.start, 1)
    else
        new_val_i = 2
        params = {s_sub(subject, capture.start, capture.finish - 1)}
    end
    val_i = insert_divfunc_results(acc, val_i, func(t_unpack(params, 1, new_val_i - 1)))
    return val_i
end
end  -- Decorator wrapper

end
end
--=============================================================================
do local _ENV = _ENV
packages['printers'] = function (...)
return function(Builder, LL)
local ipairs, pairs, print, tostring, type
    = ipairs, pairs, print, tostring, type
local s, t, u = require"string", require"table", require"util"
local _ENV = u.noglobals() ----------------------------------------------------
local s_char, t_concat
    = s.char, t.concat
local   expose,   load,   map
    = u.expose, u.load, u.map
local printers = {}
local
function LL_pprint (pt, offset, prefix)
    return printers[pt.ptype](pt, offset, prefix)
end
function LL.pprint (pt0)
    local pt = LL.P(pt0)
    print"\nPrint pattern"
    LL_pprint(pt, "", "")
    print"--- /pprint\n"
    return pt0
end
for k, v in pairs{
    string       = [[ "P( \""..pt.as_is.."\" )"       ]],
    char         = [[ "P( '"..to_char(pt.aux).."' )"         ]],
    ["true"]     = [[ "P( true )"                     ]],
    ["false"]    = [[ "P( false )"                    ]],
    eos          = [[ "~EOS~"                         ]],
    one          = [[ "P( one )"                      ]],
    any          = [[ "P( "..pt.aux.." )"            ]],
    set          = [[ "S( "..'"'..pt.as_is..'"'.." )" ]],
    ["function"] = [[ "P( "..pt.aux.." )"            ]],
    ref = [[
        "V( ",
            (type(pt.aux) == "string" and "\""..pt.aux.."\"")
                          or tostring(pt.aux)
        , " )"
        ]],
    range = [[
        "R( ",
            t_concat(map(
                pt.as_is,
                function(e) return '"'..e..'"' end), ", "
            )
        ," )"
        ]]
} do
    printers[k] = load(([==[
        local k, map, t_concat, to_char = ...
        return function (pt, offset, prefix)
            print(t_concat{offset,prefix,XXXX})
        end
    ]==]):gsub("XXXX", v), k.." printer")(k, map, t_concat, s_char)
end
for k, v in pairs{
    ["behind"] = [[ LL_pprint(pt.pattern, offset, "B ") ]],
    ["at least"] = [[ LL_pprint(pt.pattern, offset, pt.aux.." ^ ") ]],
    ["at most"] = [[ LL_pprint(pt.pattern, offset, pt.aux.." ^ ") ]],
    unm        = [[LL_pprint(pt.pattern, offset, "- ")]],
    lookahead  = [[LL_pprint(pt.pattern, offset, "# ")]],
    choice = [[
        print(offset..prefix.."+")
        map(pt.aux, LL_pprint, offset.." :", "")
        ]],
    sequence = [[
        print(offset..prefix.."*")
        map(pt.aux, LL_pprint, offset.." |", "")
        ]],
    grammar   = [[
        print(offset..prefix.."Grammar")
        for k, pt in pairs(pt.aux) do
            local prefix = ( type(k)~="string"
                             and tostring(k)
                             or "\""..k.."\"" )
            LL_pprint(pt, offset.."  ", prefix .. " = ")
        end
    ]]
} do
    printers[k] = load(([[
        local map, LL_pprint, ptype = ...
        return function (pt, offset, prefix)
            XXXX
        end
    ]]):gsub("XXXX", v), k.." printer")(map, LL_pprint, type)
end
for _, cap in pairs{"C", "Cs", "Ct"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap)
        LL_pprint(pt.pattern, offset.."  ", "")
    end
end
for _, cap in pairs{"Cg", "Ctag", "Cf", "Cmt", "/number", "/zero", "/function", "/table"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap.." "..tostring(pt.aux or ""))
        LL_pprint(pt.pattern, offset.."  ", "")
    end
end
printers["/string"] = function (pt, offset, prefix)
    print(offset..prefix..'/string "'..tostring(pt.aux or "")..'"')
    LL_pprint(pt.pattern, offset.."  ", "")
end
for _, cap in pairs{"Carg", "Cp"} do
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
local cprinters = {}
function LL.cprint (capture)
    print"\nCapture Printer\n===============\n"
    cprinters[capture.type](capture, "", "")
    print"\n/Cprinter -------\n"
end
cprinters["backref"] = function (capture, offset, prefix)
    print(offset..prefix.."Back: start = "..capture.start)
    cprinters[capture.ref.type](capture.ref, offset.."   ")
end
cprinters["value"] = function (capture, offset, prefix)
    print(offset..prefix.."Value: start = "..capture.start..", value = "..tostring(capture.value))
end
cprinters["values"] = function (capture, offset, prefix)
    print(offset..prefix.."Values: start = "..capture.start..", values = ")
    for _, c in pairs(capture.values) do
        print(offset.."   "..tostring(c))
    end
end
cprinters["insert"] = function (capture, offset, prefix)
    print(offset..prefix.."insert n="..capture.n)
    for i, subcap in ipairs(capture) do
        cprinters[subcap.type](subcap, offset.."|  ", i..". ")
    end
end
for _, capname in ipairs{
    "Cf", "Cg", "tag","C", "Cs",
    "/string", "/number", "/table", "/function"
} do
    cprinters[capname] = function (capture, offset, prefix)
        local message = offset..prefix..capname
            ..": start = "..capture.start
            ..", finish = "..capture.finish
            ..(capture.Ctag and " tag = "..capture.Ctag or "")
        if capture.aux then
            message = message .. ", aux = ".. tostring(capture.aux)
        end
        print(message)
        for i, subcap in ipairs(capture) do
            cprinters[subcap.type](subcap, offset.."   ", i..". ")
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
        cprinters[subcap.type](subcap, offset.."   ", i..". ")
    end
    for k,v in pairs(capture.hash or {}) do
        print(offset.."   "..k, "=", v)
        expose(v)
    end
end
cprinters["Cb"] = function (capture, offset, prefix)
    print(offset..prefix.."Cb: tag = "
        ..(type(capture.tag)~="string" and tostring(capture.tag) or "\""..capture.tag.."\"")
        )
end
return { pprint = LL.pprint,cprint = LL.cprint }
end -- module wrapper ---------------------------------------------------------

end
end
--=============================================================================
do local _ENV = _ENV
packages['compat'] = function (...)

local _, debug, jit
_, debug = pcall(require, "debug")
debug = _ and debug
_, jit = pcall(require, "jit")
jit = _ and jit
local compat = {
    debug = debug,
    lua51 = (_VERSION == "Lua 5.1") and not jit,
    lua52 = _VERSION == "Lua 5.2",
    luajit = jit and true or false,
    jit = jit and jit.status(),
    lua52_len = not #setmetatable({},{__len = function()end}),
    proxies = newproxy
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
if compat.lua52 then
    compat._goto = true
elseif compat.luajit then
    compat._goto = loadstring"::R::" and true or false
end
return compat

end
end
--=============================================================================
do local _ENV = _ENV
packages['factorizer'] = function (...)
local ipairs, pairs, print, setmetatable
    = ipairs, pairs, print, setmetatable
local u = require"util"
local   id,   setify,   arrayify
    = u.id, u.setify, u.arrayify
local V_hasCmt = u.nop
local _ENV = u.noglobals() ----------------------------------------------------
local
function process_booleans(lst, opts)
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
local unary = setify{
    "C", "Cf", "Cg", "Cs", "Ct", "/zero",
    "Ctag", "Cmt", "/string", "/number",
    "/table", "/function", "at least", "at most"
}
local unifiable = setify{"char", "set", "range"}
local
function mergeseqhead (p1, p2)
    local n, len = 0, m_min(#p1, p2)
    while n <= len do
        if pi[n + 1] == p2[n + 1] then n = n + 1
        else break end
    end
end
return function (Builder, LL) --------------------------------------------------
if Builder.options.factorize == false then
    print"No factorization"
    return {
        choice = arrayify,
        sequence = arrayify,
        lookahead = id,
        unm = id
    }
end
local -- flattens a choice/sequence (a * b) * (c * d) => a * b * c * d
function flatten(typ, ary)
    local acc = {}
    for _, p in ipairs(ary) do
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
local constructors, LL_P =  Builder.constructors, LL.P
local truept, falsept
    = constructors.constant.truept
    , constructors.constant.falsept
local --Range, Set,
    S_union
    = --Builder.Range, Builder.set.new,
    Builder.set.union
local type2cons = {
    ["/zero"] = "__div",
    ["/number"] = "__div",
    ["/string"] = "__div",
    ["/table"] = "__div",
    ["/function"] = "__div",
    ["at least"] = "__exp",
    ["at most"] = "__exp",
    ["Ctag"] = "Cg",
}
local
function choice (a,b, ...)
    local dest
    if b ~= nil then
        dest = flatten("choice", {a,b,...})
    else
        dest = flatten("choice", a)
    end
    dest = process_booleans(dest, { id = falsept, brk = truept })
    local changed
    local src
    repeat
        src, dest, changed = dest, {dest[1]}, false
        for i = 2,#src do
            local p1, p2 = dest[#dest], src[i]
            local type1, type2 = p1.ptype, p2.ptype
            if type1 == "set" and type2 == "set" then
                dest[#dest] = constructors.aux(
                    "set", S_union(p1.aux, p2.aux),
                    "Union( "..p1.as_is.." || "..p2.as_is.." )"
                )
                changed = true
            elseif ( type1 == type2 ) and unary[type1] and ( p1.aux == p2.aux ) then
                dest[#dest] = LL[type2cons[type1] or type1](p1.pattern + p2.pattern, p1.aux)
                changed = true
            elseif p1 ~= p2 or V_hasCmt(p1) then
                dest[#dest + 1] = p2
            end -- if identical and without Cmt, fold them into one.
        end
    until not changed
    return dest
end
local
function lookahead (pt)
    return pt
end
local
function append (acc, p1, p2)
    acc[#acc + 1] = p2
end
local
function seq_any_any (acc, p1, p2)
    acc[#acc] = LL_P(p1.aux + p2.aux)
end
local seq_optimize = {
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
local metaappend_mt = {
    __index = function()return append end
}
for _, v in pairs(seq_optimize) do
    setmetatable(v, metaappend_mt)
end
local metaappend = setmetatable({}, metaappend_mt)
setmetatable(seq_optimize, {
    __index = function() return metaappend end
})
local
function sequence(a, b, ...)
    local seq1
    if b ~=nil then
        seq1 = flatten("sequence", {a, b, ...})
    else
        seq1 = flatten("sequence", a)
    end
    seq1 = process_booleans(seq1, { id = truept, brk = falsept })
    local seq2 = {}
    seq2[1] = seq1[1]
    for i = 2,#seq1 do
        local p1, p2 = seq2[#seq2], seq1[i]
        seq_optimize[p1.ptype][p2.ptype](seq2, p1, p2)
    end
    return seq2
end
local
function unm (pt)
    if     pt == truept            then return falsept
    elseif pt == falsept           then return truept
    elseif pt.ptype == "unm"       then return #pt.pattern
    elseif pt.ptype == "lookahead" then return -pt.pattern
    end
end
return {
    choice = choice,
    lookahead = lookahead,
    sequence = sequence,
    unm = unm
}
end

end
end
--=============================================================================
do local _ENV = _ENV
packages['match'] = function (...)

local assert, error, print, select, type = assert, error, print, select, type
local u =require"util"
local _ENV = u.noglobals() ---------------------------------------------------
local t_unpack = u.unpack
return function(Builder, LL) -------------------------------------------------
local LL_compile, LL_evaluate, LL_P
    = LL.compile, LL.evaluate, LL.P
local function computeidex(i, len)
    if i == 0 or i == 1 or i == nil then return 1
    elseif type(i) ~= "number" then error"number or nil expected for the stating index"
    elseif i > 0 then return i > len and len + 1 or i
    else return len + i < 0 and 1 or len + i + 1
    end
end
function LL.match(pt, subject, index, ...)
    pt = LL_P(pt)
    assert(type(subject) == "string", "string expected for the match subject")
    index = computeidex(index, #subject)
    local matcher, cap_acc, state, success, cap_i, nindex
        = LL_compile(pt, {})
        , {type = "insert"}   -- capture accumulator
        , {grammars = {}, args = {n = select('#',...),...}, tags = {}}
        , 0 -- matcher state
    success, nindex, cap_i = matcher(subject, index, cap_acc, 1, state)
    if success then
        cap_acc.n = cap_i
        local cap_values, cap_i = LL_evaluate(cap_acc, subject, index)
        if cap_i == 1
        then return nindex
        else return t_unpack(cap_values, 1, cap_i - 1) end
    else
        return nil
    end
end
function LL.dmatch(pt, subject, index, ...)
    print("@!!! Match !!!@")
    pt = LL_P(pt)
    assert(type(subject) == "string", "string expected for the match subject")
    index = computeidex(index, #subject)
    print(("-"):rep(30))
    print(pt.ptype)
    LL.pprint(pt)
    local matcher, cap_acc, state, success, cap_i, nindex
        = LL_compile(pt, {})
        , {type = "insert"}   -- capture accumulator
        , {grammars = {}, args = {n = select('#',...),...}, tags = {}}
        , 0 -- matcher state
    success, nindex, cap_i = matcher(subject, index, cap_acc, 1, state)
    print("!!! Done Matching !!!")
    if success then
        cap_acc.n = cap_i
        print("cap_i = ",cap_i)
        print("= $$$ captures $$$ =", cap_acc)
        LL.cprint(cap_acc)
        local cap_values, cap_i = LL_evaluate(cap_acc, subject, index)
        if cap_i == 1
        then return nindex
        else return t_unpack(cap_values, 1, cap_i - 1) end
    else
        return nil
    end
end
end -- /wrapper --------------------------------------------------------------

end
end
--=============================================================================
do local _ENV = _ENV
packages['util'] = function (...)

local getmetatable, setmetatable, load, loadstring, next
    , pairs, print, rawget, rawset, select, tostring, type, unpack
    = getmetatable, setmetatable, load, loadstring, next
    , pairs, print, rawget, rawset, select, tostring, type, unpack
local m, s, t = require"math", require"string", require"table"
local m_max, s_match, s_gsub, t_concat, t_insert
    = m.max, s.match, s.gsub, t.concat, t.insert
local compat = require"compat"
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
else
    local t_unpack = util.unpack
    local safe_len = 1000
    function util.max(array)
        local len = #array
        if len == 0 then return -1 end -- FIXME: shouldn't this be `return -1`?
        local off = 1
        local off_end = safe_len
        local max = array[1] -- seed max.
        repeat
            if off_end > len then off_end = len end
            local seg_max = m_max(t_unpack(array, off, off_end))
            if seg_max > max then
                max = seg_max
            end
            off = off + safe_len
            off_end = off_end + safe_len
        until off >= len
        return max
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
function util.filter(ary,func)
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
util.dprint =  print
util.dprint =  nop
return util

end
end
--=============================================================================
do local _ENV = _ENV
packages['API'] = function (...)

local assert, error, ipairs, pairs, pcall, print
    , require, select, tonumber, type
    = assert, error, ipairs, pairs, pcall, print
    , require, select, tonumber, type
local t, u = require"table", require"util"
local _ENV = u.noglobals() ---------------------------------------------------
local t_concat = t.concat
local   copy,   fold,   load,   map,   setify, t_pack, t_unpack
    = u.copy, u.fold, u.load, u.map, u.setify, u.pack, u.unpack
local
function charset_error(index, charset)
    error("Character at position ".. index + 1
            .." is not a valid "..charset.." one.",
        2)
end
return function(Builder, LL) -- module wrapper -------------------------------
local cs = Builder.charset
local constructors, LL_ispattern
    = Builder.constructors, LL.ispattern
local truept, falsept, Cppt
    = constructors.constant.truept
    , constructors.constant.falsept
    , constructors.constant.Cppt
local    split_int,    tochar,    validate
    = cs.split_int, cs.tochar, cs.validate
local Range, Set, S_union, S_tostring
    = Builder.Range, Builder.set.new
    , Builder.set.union, Builder.set.tostring
local factorize_choice, factorize_lookahead, factorize_sequence, factorize_unm
local
function makechar(c)
    return constructors.aux("char", c)
end
local
function LL_P (v)
    if LL_ispattern(v) then
        return v
    elseif type(v) == "function" then
        return true and LL.Cmt("", v)
    elseif type(v) == "string" then
        local success, index = validate(v)
        if not success then
            charset_error(index, cs.name)
        end
        if v == "" then return LL_P(true) end
        return true and LL.__mul(map(makechar, split_int(v)))
    elseif type(v) == "table" then
        local g = copy(v)
        if g[1] == nil then error("grammar has no initial rule") end
        if not LL_ispattern(g[1]) then g[1] = LL.V(g[1]) end
        return
            constructors.none("grammar", g)
    elseif type(v) == "boolean" then
        return v and truept or falsept
    elseif type(v) == "number" then
        if v == 0 then
            return truept
        elseif v > 0 then
            return
                constructors.aux("any", v)
        else
            return
                - constructors.aux("any", -v)
        end
    end
end
LL.P = LL_P
local
function LL_S (set)
    if set == "" then
        return
            LL_P(false)
    else
        local success, index = validate(set)
        if not success then
            charset_error(index, cs.name)
        end
        return
            constructors.aux("set", Set(split_int(set)), set)
    end
end
LL.S = LL_S
local
function LL_R (...)
    if select('#', ...) == 0 then
        return LL_P(false)
    else
        local range = Range(1,0)--Set("")
        for _, r in ipairs{...} do
            local success, index = validate(r)
            if not success then
                charset_error(index, cs.name)
            end
            range = S_union ( range, Range(t_unpack(split_int(r))) )
        end
        local representation = t_concat(map(tochar,
                {load("return "..S_tostring(range))()}))
        return
            constructors.aux("set", range, representation)
    end
end
LL.R = LL_R
local
function LL_V (name)
    assert(name ~= nil)
    return
        constructors.aux("ref",  name)
end
LL.V = LL_V
do
    local one = setify{"set", "range", "one", "char"}
    local zero = setify{"true", "false", "lookahead", "unm"}
    local forbidden = setify{
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
    function LL.B (pt)
        pt = LL_P(pt)
        local len = fixedlen(pt)
        assert(len, "A 'behind' pattern takes a fixed length pattern as argument.")
        if len >= 260 then error("Subpattern too long in 'behind' pattern constructor.") end
        return
            constructors.both("behind", pt, len)
    end
end
local
function LL_choice (a, b, ...)
    if b ~= nil then
        a, b = LL_P(a), LL_P(b)
    end
    local ch = factorize_choice(a, b, ...)
    if #ch == 0 then
        return falsept
    elseif #ch == 1 then
        return ch[1]
    else
        return
            constructors.aux("choice", ch)
    end
end
LL.__add = LL_choice
local
function sequence (a, b, ...)
    if b ~= nil then
        a, b = LL_P(a), LL_P(b)
    end
    local seq = factorize_sequence(a, b, ...)
    if #seq == 0 then
        return truept
    elseif #seq == 1 then
        return seq[1]
    end
    return
        constructors.aux("sequence", seq)
end
LL.__mul = sequence
local
function LL_lookahead (pt)
    if pt == truept
    or pt == falsept
    or pt.ptype == "unm"
    or pt.ptype == "lookahead"
    then
        return pt
    end
    return
        constructors.subpt("lookahead", pt)
end
LL.__len = LL_lookahead
LL.L = LL_lookahead
local
function LL_unm(pt)
    return
        factorize_unm(pt)
        or constructors.subpt("unm", pt)
end
LL.__unm = LL_unm
local
function LL_sub (a, b)
    a, b = LL_P(a), LL_P(b)
    return LL_unm(b) * a
end
LL.__sub = LL_sub
local
function LL_repeat (pt, n)
    local success
    success, n = pcall(tonumber, n)
    assert(success and type(n) == "number",
        "Invalid type encountered at right side of '^'.")
    return constructors.both(( n < 0 and "at most" or "at least" ), pt, n)
end
LL.__pow = LL_repeat
for _, cap in pairs{"C", "Cs", "Ct"} do
    LL[cap] = function(pt)
        pt = LL_P(pt)
        return
            constructors.subpt(cap, pt)
    end
end
LL["Cb"] = function(aux)
    return
        constructors.aux("Cb", aux)
end
LL["Carg"] = function(aux)
    assert(type(aux)=="number", "Number expected as parameter to Carg capture.")
    assert( 0 < aux and aux <= 200, "Argument out of bounds in Carg capture.")
    return
        constructors.aux("Carg", aux)
end
local
function LL_Cp ()
    return Cppt
end
LL.Cp = LL_Cp
local
function LL_Cc (...)
    return
        constructors.none("Cc", t_pack(...))
end
LL.Cc = LL_Cc
for _, cap in pairs{"Cf", "Cmt"} do
    local msg = "Function expected in "..cap.." capture"
    LL[cap] = function(pt, aux)
    assert(type(aux) == "function", msg)
    pt = LL_P(pt)
    return
        constructors.both(cap, pt, aux)
    end
end
local
function LL_Cg (pt, tag)
    pt = LL_P(pt)
    if tag ~= nil then
        return
            constructors.both("Ctag", pt, tag)
    else
        return
            constructors.subpt("Cg", pt)
    end
end
LL.Cg = LL_Cg
local valid_slash_type = setify{"string", "number", "table", "function"}
local
function LL_slash (pt, aux)
    if LL_ispattern(aux) then
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
    return
        constructors.both(name, pt, aux)
end
LL.__div = LL_slash
local factorizer
    = Builder.factorizer(Builder, LL)
factorize_choice,  factorize_lookahead,  factorize_sequence,  factorize_unm =
factorizer.choice, factorizer.lookahead, factorizer.sequence, factorizer.unm
end -- module wrapper --------------------------------------------------------

end
end
--=============================================================================
do local _ENV = _ENV
packages['constructors'] = function (...)

local ipairs, newproxy, print, setmetatable
    = ipairs, newproxy, print, setmetatable
local t, u, compat
    = require"table", require"util", require"compat"
local t_concat = t.concat
local   copy,   getuniqueid,   id,   map
    ,   weakkey,   weakval
    = u.copy, u.getuniqueid, u.id, u.map
    , u.weakkey, u.weakval
local _ENV = u.noglobals() ----------------------------------------------------
local patternwith = {
    constant = {
        "Cp", "true", "false"
    },
    aux = {
        "string", "any",
        "char", "range", "set",
        "ref", "sequence", "choice",
        "Carg", "Cb"
    },
    subpt = {
        "unm", "lookahead", "C", "Cf",
        "Cg", "Cs", "Ct", "/zero"
    },
    both = {
        "behind", "at least", "at most", "Ctag", "Cmt",
        "/string", "/number", "/table", "/function"
    },
    none = "grammar", "Cc"
}
return function(Builder, LL) --- module wrapper.
local S_tostring = Builder.set.tostring
local newpattern do
    function LL.get_direct (p) return p end
    if compat.lua52_len then
        function newpattern(pt)
            return setmetatable(pt,LL)
        end
    elseif compat.proxies then 
        local d_setmetatable
            = compat.debug.setmetatable
        local proxycache = weakkey{}
        local __index_LL = {__index = LL}
        LL.proxycache = proxycache
        function newpattern(cons)
            local pt = newproxy()
            setmetatable(cons, __index_LL)
            proxycache[pt]=cons
            d_setmetatable(pt,LL)
            return pt
        end
        function LL:__index(k)
            return proxycache[self][k]
        end
        function LL:__newindex(k, v)
            proxycache[self][k] = v
        end
        function LL.get_direct(p) return proxycache[p] end
    else
        if LL.warnings then
            print("Warning: The `__len` metatethod won't work with patterns, "
                .."use `LL.L(pattern)` for lookaheads.")
        end
        function newpattern(pt)
            return setmetatable(pt,LL)
        end
    end
end
local ptcache, meta
local
function resetcache()
    ptcache, meta = {}, weakkey{}
    for _, p in ipairs(patternwith.aux) do
        ptcache[p] = weakval{}
    end
    for _, p in ipairs(patternwith.subpt) do
        ptcache[p] = weakval{}
    end
    for _, p in ipairs(patternwith.both) do
        ptcache[p] = {}
    end
    return ptcache
end
LL.resetptcache = resetcache
resetcache()
local constructors = {}
Builder.constructors = constructors
constructors["constant"] = {
    truept  = newpattern{ ptype = "true" },
    falsept = newpattern{ ptype = "false" },
    Cppt    = newpattern{ ptype = "Cp" }
}
local getauxkey = {
    string = function(aux, as_is) return as_is end,
    table = copy,
    set = function(aux, as_is)
        return S_tostring(aux)
    end,
    range = function(aux, as_is)
        return t_concat(as_is, "|")
    end,
    sequence = function(aux, as_is)
        return t_concat(map(getuniqueid, aux),"|")
    end
}
getauxkey.choice = getauxkey.sequence
constructors["aux"] = function(typ, aux, as_is)
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
constructors["none"] = function(typ, aux)
    return newpattern{
        ptype = typ,
        aux = aux
    }
end
constructors["subpt"] = function(typ, pt)
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
end -- module wrapper

end
end
--=============================================================================
do local _ENV = _ENV
packages['init'] = function (...)

local getmetatable, setmetatable, pcall
    = getmetatable, setmetatable, pcall
local u = require"util"
local   copy,   map,   nop, t_unpack
    = u.copy, u.map, u.nop, u.unpack
local API, charsets, compiler, constructors
    , datastructures, evaluator, factorizer
    , locale, match, printers, re
    = t_unpack(map(require,
    { "API", "charsets", "compiler", "constructors"
    , "datastructures", "evaluator", "factorizer"
    , "locale", "match", "printers", "re" }))
local _, package = pcall(require, "package")
local _ENV = u.noglobals() ----------------------------------------------------
local VERSION = "0.12"
local LuVERSION = "0.1.0"
local function global(self, env) setmetatable(env,{__index = self}) end
local function register(self, env)
    pcall(function()
        package.loaded.lpeg = self
        package.loaded.re = self.re
    end)
    if env then
        env.lpeg, env.re = self, self.re
    end
    return self
end
local
function LuLPeg(options)
    options = options and copy(options) or {}
    local Builder, LL
        = { options = options, factorizer = factorizer }
        , { new = LuLPeg
          , version = function () return VERSION end
          , luversion = function () return LuVERSION end
          , setmaxstack = nop --Just a stub, for compatibility.
          }
    LL.__index = LL
    local
    function LL_ispattern(pt) return getmetatable(pt) == LL end
    LL.ispattern = LL_ispattern
    function LL.type(pt)
        if LL_ispattern(pt) then
            return "pattern"
        else
            return nil
        end
    end
    LL.util = u
    LL.global = global
    LL.register = register
    ;-- Decorate the LuLPeg object.
    charsets(Builder, LL)
    datastructures(Builder, LL)
    printers(Builder, LL)
    constructors(Builder, LL)
    API(Builder, LL)
    evaluator(Builder, LL)
    ;(options.compiler or compiler)(Builder, LL)
    match(Builder, LL)
    locale(Builder, LL)
    LL.re = re(Builder, LL)
    return LL
end -- LuLPeg
local LL = LuLPeg()
return LL

end
end
--=============================================================================
do local _ENV = _ENV
packages['locale'] = function (...)

local extend = require"util".extend
local _ENV = require"util".noglobals() ----------------------------------------
return function(Builder, LL) -- Module wrapper {-------------------------------
local R, S = LL.R, LL.S
local locale = {}
locale["cntrl"] = R"\0\31" + "\127"
locale["digit"] = R"09"
locale["lower"] = R"az"
locale["print"] = R" ~" -- 0x20 to 0xee
locale["space"] = S" \f\n\r\t\v" -- \f == form feed (for a printer), \v == vtab
locale["upper"] = R"AZ"
locale["alpha"]  = locale["lower"] + locale["upper"]
locale["alnum"]  = locale["alpha"] + locale["digit"]
locale["graph"]  = locale["print"] - locale["space"]
locale["punct"]  = locale["graph"] - locale["alnum"]
locale["xdigit"] = locale["digit"] + R"af" + R"AF"
function LL.locale (t)
    return extend(t or {}, locale)
end
end -- Module wrapper --------------------------------------------------------}

end
end
--=============================================================================
do local _ENV = _ENV
packages['optimizer'] = function (...)
-- Nothing for now.
end
end
return require"init"



--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
-- 
-- 
--            Dear user,
-- 
--            The LuLPeg library
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
--                               / library...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      ','
--                        #######    ·
--                        #####
--                        ###
--                        #
-- 
--               -- Pierre-Yves
-- 
-- 
-- 
--            P.S.: Even though I poured my heart into this work, 
--                  I _cannot_ provide any warranty regarding 
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.
-- 
-- -----------------------------------------------------------------------------            
-- 
-- LuLPeg, Copyright (C) 2013 Pierre-Yves Gérardy.
-- 
-- The `re` module and lpeg.*.*.test.lua,
-- Copyright (C) 2013 Lua.org, PUC-Rio.
-- 
-- Permission is hereby granted, free of charge,
-- to any person obtaining a copy of this software and
-- associated documentation files (the "Software"),
-- to deal in the Software without restriction,
-- including without limitation the rights to use,
-- copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software,
-- and to permit persons to whom the Software is
-- furnished to do so,
-- subject to the following conditions:
-- 
-- The above copyright notice and this permission notice
-- shall be included in all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED,
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
-- DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

