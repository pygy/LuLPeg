local getmetatable, pairs, setmetatable 
    = getmetatable, pairs, setmetatable

local m_min, t_insert
    = math.min, table.insert

-------------------------------------------------------------------------------
--- Set
--

local u = require"util"
local all,   load,   map,   t_unpack
    = u.all, u.load, u.map, u.unpack

local byteset = table.concat{"return {[0]=false", (", false"):rep(255), "}"}

local set_mt = {}
local
function newset (t)
    local set
    -- optimization for binary sets.
    if all(map(t, function(e)return type(e) == number end))
    and m_min(t_unpack(t)) > 255 then
        set = load(byteset)
    else
        set = {}
    end
    setmetatable(set, set_mt)
    for i = 1, #t do set[t[i]] = true end
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

return {
    set = {
        new = newset
      , union = set_union
      , tolilst = set_tolist
      , isset = set_isset
    },
    range = {
        new = newrange
      , overlap = range_overlap
      , merge = range_merge
      , isrange = range_isrange
    }
}


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