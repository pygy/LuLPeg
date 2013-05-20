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


------------------------------------------------------------------------------
return function(Builder, PL) -- module wrapper
--

local binary_split_int, cs = Builder.binary_split_int, Builder.charset

local constructors, PL_ispattern
    = PL.constructors, PL.ispattern

local truept, falsept, Cppt 
    = constructors.constant.truept
    , constructors.constant.falsept
    , constructors.constant.Cppt 

local t_insert, t_sort, type = table.insert, table.sort, type

local split_int, validate 
    = cs.split_int, cs.validate


local Range, Set, S_union
    = Builder.Range, Builder.set.new, Builder.set.union

local u = require"util"
local copy,   fold,   map,   t_pack, t_unpack 
    = u.copy, u.fold, u.map, u.pack, u.unpack

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
        return true and constructors.aux("set", nil, Set(split_int(set)), set)
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
            acc[#acc + 1] = Range(t_unpack(split_int(r)))
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
    local one = Set{"set", "range", "one"}
    local zero = Set{"true", "false", "lookahead", "unm"}
    local forbidden = Set{
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
                ch2[#ch2] = constructors.aux(
                    "set", nil, 
                    S_union(p1.aux, p2.aux), 
                    "Union( "..p1.as_is.." || "..p2.as_is.." )"
                )
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
    return true and constructors.none("Cc", nil, t_pack(...))
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


local valid_slash_type = Set{"string", "number", "table", "function"}
local
function PL_slash (pt, aux)
    if PL_ispattern(aux) then 
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

end -- module wrapper


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