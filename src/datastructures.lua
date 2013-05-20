local getmetatable, pairs, setmetatable, t
    = getmetatable, pairs, setmetatable, table

local m_min   , t_concat, t_insert, t_sort
    = math.min, t.concat, t.insert, t.sort


local u = require"util"
local all,   extend,   load,   map,   map_all
    ,   t_unpack
    = u.all, u.extend, u.load, u.map, u.map_all
    , u.unpack

local ffi
if jit and jit.status() then ffi = require"ffi" end


local datafor = {}

--------------------------------------------------------------------------------
--- Byte sets
--

-- Byte sets are sets whose elements are comprised between 0 and 255.
-- We provide two implemetations. One based on Lua tables, and the
-- other based on a FFI bool array.

local byteset_new, isboolset, isbyteset
local byteset_mt = {}
local
function byteset_constructor (n)
    return setmetatable(load(table.concat{ 
        "{ [0]=false", 
        (", false"):rep(n), 
        " }"
    }),
    byteset_mt) 
end

if ffi then
    local struct, boolset_constructor = {}

    function byteset_mt.__index(s,i)
        return s.v[i]
    end
    function byteset_mt.__newindex(s,i,v)
        s.v[i] = v
    end

    boolset_constructor = ffi.metatype('struct { bool v[256]; }', byteset_mt)

    function byteset_new (t)
        local set = byteset_constructor(255)
        for _, el in pairs(t) do
            if el > 255 then error"value out of bounds" end
            set[el] = true
        end
        struct.v = set
        return boolset_constructor(struct)
    end

    function isboolset(s) return ffi.istype(s, byteset_constructor) end
    isbyteset = isbootset
else
    function byteset_new (t)
        local set = byteset_constructor(m_max(t))
        for i = 1, #t do set[t[i]] = true end
        return set
    end

    function isboolset(s) return false end
    function isbyteset (s)
        return getmetatable(s) == set_mt 
    end
end

local
function byterange_new (low, high)
    local set = setmetatable(byteset_constructor(), byteset_mt)
    for i = low, high do
        set[i] = true
    end
    return set
end

local
function byteset_union (a ,b)
    local res = byteset_new{}
    for i in 0, 255 do res[k] = a[i] or b[i] end
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
        list[#list] = (s[i] == true) and i
    end
    return t_concat(list,", ")
end

local function byteset_has(set, elem)
    if elem > 255 then return false end
    return set[elem]
end




datafor.binary = {
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

print(datafor.binary.set.new)
--------------------------------------------------------------------------------
--- Bit sets: TODO? to try, at least.
--

-- From Mike Pall's suggestion found at 
-- http://lua-users.org/lists/lua-l/2011-08/msg00382.html

-- local bit = require("bit")
-- local band, bor = bit.band, bit.bor
-- local lshift, rshift, rol = bit.lshift, bit.rshift, bit.rol

-- local function bitnew(n)
--   return ffi.new("int32_t[?]", rshift(n+31, 5))
-- end

-- -- Note: the index 'i' is zero-based!
-- local function bittest(b, i)
--   return band(rshift(b[rshift(i, 5)], i), 1) ~= 0
-- end

-- local function bitset(b, i)
--   local x = rshift(i, 5); b[x] = bor(b[x], lshift(1, i))
-- end

-- local function bitclear(b, i)
--   local x = rshift(i, 5); b[x] = band(b[x], rol(-2, i))
-- end



-------------------------------------------------------------------------------
--- General case:
--

-- Set
--

local set_mt = {}

local
function set_new (t)
    -- optimization for byte sets.
    if all(map_all(t, function(e)return type(e) == number end))
    and m_min(t_unpack(t)) > 255 then
        return byteset_new(t)
    end

    local set = setmetatable({}, set_mt)
    for i = 1, #t do set[t[i]] = true end
    return set
end

local -- helper for the union code.
function add_elements(a, res)
        if isbyteset(a) then
        for i = 0, 255 do
            if a[i] then res[i] = true end
        end
    else 
        for k in pairs(a) do res[k] = true end
    end
    return res
end

local
function set_union (a, b)
    if isbyteset(a) and isbyteset(b) then 
        return byteset_union(a,b)
    end
    a, b = (type(a) == number) and newset{a} or a
         , (type(b) == number) and newset{b} or b
    local res = set_new{}
    add_elements(a, res)
    add_elements(b, res)
    return res
end

local
function set_difference(a, b)
    local list = {}
    if isbyteset(a) and isbyteset(b) then 
        return byteset_difference(a,b)
    end
    a, b = (type(a) == number) and newset{a} or a
         , (type(b) == number) and newset{b} or b

    if isbyteset(a) then
        for i = 0, 255 do
            if a[i] and not b[i] then
                list[#list+1] = i
            end
        end
    elseif isbyteset(b) then
        for el in pairs(a) do
            if not byteset_has(b, el) then
                list[#list + 1] = i
            end
        end
    else
        for el in pairs(a) do
            if a[i] and not b[i] then
                list[#list+1] = i
            end            
        end
    end
    return set_new(list)
end

local
function set_tostring (s)
    if isbyteset(s) then return byteset_tostring(s) end
    local list = {}
    for el in pairs(s) do
        t_insert(list,el)
    end
    table.sort(list)
    return t_concat(list, ",")
end

local
function isset (s)
    return (getmetatable(s) == set_mt) or isbyteset(s)
end


-- Range
--

-- For now emulated using sets.

local range_mt = {}
    
local 
function range_new (start, finish)
    local list = {}
    for i = start, finish do
        list[#list + 1] = i
    end
    return set_new(list)
end

-- local 
-- function range_overlap (r1, r2)
--     return r1[1] <= r2[2] and r2[1] <= r1[2]
-- end

-- local
-- function range_merge (r1, r2)
--     if not range_overlap(r1, r2) then return nil end
--     local v1, v2 =
--         r1[1] < r2[1] and r1[1] or r2[1],
--         r1[2] > r2[2] and r1[2] or r2[2]
--     return newrange(v1,v2)
-- end

-- local
-- function range_isrange (r)
--     return getmetatable(r) == range_mt
-- end

datafor.other = {
    set = {
        new = newset,
        union = set_union,
        tolilst = set_tolist,
        isset = set_isset,
        isbyteset = byteset_isset
    },
    range = {
        new = newrange,
        overlap = range_overlap,
        merge = range_merge,
        isrange = range_isrange
    }
}

datafor.binary = {
    set ={
        new = set_new,
        union = set_union,
        difference = set_difference,
        tostring = set_tostring
    },
    Range = range_new,
    isboolset = isboolset,
    isbyteset = isbyteset,
    isset = byteset,
    isrange = function(a) return false end
}

return function(Builder, PL)
    local cs = Builder.options.charset or "binary"
    if type(cs) == "string" then
        cs = (cs == "binary") and "binary" or "other"
    else
        cs = cs.binary and "binary" or "other"
    end
    extend(Builder, datafor[cs])
end


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