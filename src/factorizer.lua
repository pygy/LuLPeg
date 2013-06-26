local ipairs, pairs, print, setmetatable
    = ipairs, pairs, print, setmetatable

--[[DBG]] local debug = require "debug"
local u = require"util"

local   id,   setify,   arrayify
    = u.id, u.setify, u.arrayify

local V_hasCmt = u.nop



local _ENV = u.noglobals() ----------------------------------------------------



---- helpers
--

-- handle the identity or break properties of P(true) and P(false) in
-- sequences/arrays.
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



-- patterns where `C(x) + C(y) => C(x + y)` apply.
local unary = setify{
    "C", "Cf", "Cg", "Cs", "Ct", "/zero",
    "Clb", "Cmt", "div_string", "div_number",
    "div_table", "div_function", "at least", "at most"
}

-- patterns where p1 + p2 == p1 U p2
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
        -- [[DBG]] print("flatten")
        -- [[DBG]] if type(p) == "table" then print"expose" expose(p) else print"pprint"LL.pprint(p) end
        if p.pkind == typ then
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

local mergeable = setify{"char", "set"}


local type2cons = {
    ["/zero"] = "__div",
    ["div_number"] = "__div",
    ["div_string"] = "__div",
    ["div_table"] = "__div",
    ["div_function"] = "__div",
    ["at least"] = "__exp",
    ["at most"] = "__exp",
    ["Clb"] = "Cg",
}
--[[DBG]] local level = 0
local
function choice (a,b, ...)
    -- 1. flatten  (a + b) + (c + d) => a + b + c + d
    local dest
    if b ~= nil then
        dest = flatten("choice", {a,b,...})
    else
        dest = flatten("choice", a)
    end
    -- 2. handle P(true) and P(false)
    dest = process_booleans(dest, { id = falsept, brk = truept })

    local changed
    local src
    repeat
        -- [[DBG]] print"REP"
        src, dest, changed = dest, {dest[1]}, false
        for i = 2,#src do
            local p1, p2 = dest[#dest], src[i]
            local type1, type2 = p1.pkind, p2.pkind
            -- [[DBG]] print("Optimizing", type1, type2)
            if mergeable[type1] and mergeable[type2] then
                dest[#dest] = constructors.aux("set", S_union(p1.aux, p2.aux))
                changed = true
            elseif mergeable[type1] and type2 == "any" and p2.aux == 1
            or     mergeable[type2] and type1 == "any" and p1.aux == 1 then
                -- [[DBG]] print("=== Folding "..type1.." and "..type2..".")
                dest[#dest] = type1 == "any" and p1 or p2
                changed = true
            elseif type1 == type2 then
                -- C(a) + C(b) => C(a + b)
                if unary[type1] and ( p1.aux == p2.aux ) then
                    dest[#dest] = LL[type2cons[type1] or type1](p1.pattern + p2.pattern, p1.aux)
                    changed = true
                -- elseif ( type1 == type2 ) and type1 == "sequence" then
                --     -- "abd" + "acd" => "a" * ( "b" + "c" ) * "d"
                --     if p1[1] == p2[1]  then
                --         mergeseqheads(p1,p2, dest)
                --         changed = true
                --     elseif p1[#p1] == p2[#p2]  then
                --         dest[#dest] = mergeseqtails(p1,p2)
                --         changed = true
                --     end
                elseif p1 == p2 then
                    changed = true
                else
                    dest[#dest + 1] = p2
                end
            else
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



-- Some sequence factorizers.
-- Those who depend on LL are defined in the wrapper.
local
function append (acc, p1, p2)
    acc[#acc + 1] = p2
end

local
function seq_any_any (acc, p1, p2)
    acc[#acc] = LL_P(p1.aux + p2.aux)
end

--- Lookup table for the sequence optimizers.
--
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

-- Lookup misses end up with append.
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
    -- [[DP]] print("Factorize Sequence")
    -- A few optimizations:
    -- 1. flatten the sequence (a * b) * (c * d) => a * b * c * d
    local seq1
    if b ~=nil then
        seq1 = flatten("sequence", {a, b, ...})
    else
        seq1 = flatten("sequence", a)
    end
    -- 2. handle P(true) and P(false)
    seq1 = process_booleans(seq1, { id = truept, brk = falsept })
    -- Concatenate `string` and `any` patterns.
    -- TODO: Repeat patterns?
    local seq2 = {}
    seq2[1] = seq1[1]
    for i = 2,#seq1 do
        local p1, p2 = seq2[#seq2], seq1[i]
        seq_optimize[p1.pkind][p2.pkind](seq2, p1, p2)
    end
    return seq2
end

local
function unm (pt)
    -- [[DP]] print("Factorize Unm")
    if     pt == truept            then return falsept
    elseif pt == falsept           then return truept
    elseif pt.pkind == "unm"       then return #pt.pattern
    elseif pt.pkind == "lookahead" then return -pt.pattern
    end
end

return {
    choice = choice,
    lookahead = lookahead,
    sequence = sequence,
    unm = unm
}
end

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
