local ipairs, pairs, print, setmetatable, type
    = ipairs, pairs, print, setmetatable, type

local t_insert = require"table".insert

--[[DBG]] local debug = require "debug"
local u = require"util"

local   id,   setify,   arrayify
    = u.id, u.setify, u.arrayify

local V_hasCmt = u.nop


local _ENV = u.noglobals() ----------------------------------------------------

---- helpers
--


-- handle the id or break properties of P(true) and P(false) in sequences/arrays.
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


-- Some sequence factorizers. 
-- Those who depend on PL are defined in the wrapper.
local
function append (acc, p1, p2)
    acc[#acc + 1] = p2
end


local
function seq_unm_unm (acc, p1, p2)
    acc[#acc] = -(p1.pattern + p2.pattern)
end



-- patterns where `C(x) + C(y) => C(x + y)` apply.
local unary = setify{
    "C", "Cf", "Cg", "Cs", "Ct", "/zero",
    "Ctag", "Cmt", "/string", "/number",
    "/table", "/function", "at least", "at most"
}


local
function mergeseqhead (p1, p2)
    local n, len = 0, m_min(#p1, p2)
    while n <= len do
        if pi[n + 1] == p2[n + 1] then n = n + 1
        else break end
    end
end

return function (Builder, PL) --------------------------------------------------

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
        -- [[DBG]] if type(p) == "table" then print"expose" expose(p) else print"pprint"PL.pprint(p) end
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

local constructors, PL_P =  Builder.constructors, PL.P
local truept, falsept 
    = constructors.constant.truept
    , constructors.constant.falsept

local --Range, Set, 
    S_union
    = --Builder.Range, Builder.set.new, 
    Builder.set.union


-- sequence factorizers 2, back with a vengence.
local
function seq_str_str (acc, p1, p2)
    acc[#acc] = PL_P(p1.as_is .. p2.as_is)
end

local
function seq_any_any (acc, p1, p2)
    acc[#acc] = PL_P(p1.aux + p2.aux)
end

--- Lookup table for the sequence optimizers.
--
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

local type2cons = {
    ["/zero"] = PL.__div,
    ["/number"] = PL.__div,
    ["/string"] = PL.__div,
    ["/table"] = PL.__div,
    ["/function"] = PL.__div,
    ["at least"] = PL.__exp,
    ["at most"] = PL.__exp,
    ["Ctag"] = PL.Cg,
}

local
function choice (a,b, ...)
    -- [[DP]] print("Factorize CH", a, "b", b, "...", ...)
    -- 1. flatten  (a + b) + (c + d) => a + b + c + d
    local dest
    if b ~= nil then 
        dest = flatten("choice", {a,b,...})
    else
        dest = flatten("choice", a)
    end
    -- 2. handle P(true) and P(false)
    dest = process_booleans(dest, { id = falsept, brk = truept })
    -- ???? Concatenate `string` and `any` patterns.
    local changed
    local src
    repeat
        src, dest, changed = dest, {dest[1]}, false
        for i = 2,#src do
            local p1, p2 = dest[#dest], src[i]
            local type1, type2 = p1.ptype, p2.ptype
            if type1 == "set" and type2 == "set" then
                -- Merge character sets. S"abc" + S"ABC" => S"abcABC"
                dest[#dest] = constructors.aux(
                    "set", nil, 
                    S_union(p1.aux, p2.aux), 
                    "Union( "..p1.as_is.." || "..p2.as_is.." )"
                )
                changed = true
            elseif ( type1 == type2 ) and unary[type1] and ( p1.aux == p2.aux ) then
                -- C(a) + C(b) => C(a + b)
                dest[#dest] = PL[type2cons[type1] or type1](p1.pattern + p2.pattern, p1.aux)
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
        seq_optimize[p1.ptype][p2.ptype](seq2, p1, p2)
    end
    return seq2
end

local
function unm (pt)
    -- [[DP]] print("Factorize Unm")
    if     pt == truept            then return falsept, true
    elseif pt == falsept           then return truept, true
    elseif pt.ptype == "unm"       then return #pt.pattern, true
    elseif pt.ptype == "lookahead" then pt = pt.pattern
    end
    return pt
end

return {
    choice = choice,
    lookahead = lookahead,
    sequence = sequence,
    unm = unm
}
end