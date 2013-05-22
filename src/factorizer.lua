local ipairs, pairs, print, setmetatable = ipairs, pairs, print, setmetatable

local t_insert = table.insert
local id = require"util".id

_ENV = nil

-- if pcall then 
--     pcall(setfenv, 2, setmetatable({},{ __index=error, __newindex=error }) )
-- end

local function arrayify(...) return {...} end

return function(Builder, PL)

if Builder.options.factorize == false then 
    print"No factorization"
    return {
        choice = arrayify,
        lookahead = arrayify,
        sequence = id,
        unm = id
    }
end

local constructors, PL_P =  Builder.constructors, PL.P
local truept, falsept 
    = constructors.constant.truept
    , constructors.constant.falsept

local --Range, Set, 
    S_union
    = --Builder.Range, Builder.set.new, 
    Builder.set.union


-- flattens a sequence (a * b) * (c * d) => a * b * c * d
local
function flatten(typ, a,b)
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

local
function append (acc, p1, p2)
    acc[#acc + 1] = p2
end

local
function seq_str_str (acc, p1, p2)
    acc[#acc] = PL_P(p1.as_is .. p2.as_is)
end

local
function seq_any_any (acc, p1, p2)
    acc[#acc] = PL_P(p1.aux + p2.aux)
end

local
function seq_unm_unm (acc, p1, p2)
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

local
function choice (a,b)
    -- [[DP]] print("Factorize Choice")
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
    return ch2
end

local
function lookahead (pt)
    return pt
end

local
function sequence(a,b)
    -- [[DP]] print("Factorize Sequence")
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
    return seq2
end

local
function unm (pt)
    -- [[DP]] print("Factorize Unm")
    if     pt == truept            then return -pt, true
    elseif pt == falsept           then return -pt, true
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