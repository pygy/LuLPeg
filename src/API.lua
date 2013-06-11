
-- API.lua

-- What follows is the core LPeg functions, the public API to create patterns.
-- Think P(), R(), pt1 + pt2, etc.
local assert, error, ipairs, pairs, pcall, print
    , require, select, tonumber, tostring, type
    = assert, error, ipairs, pairs, pcall, print
    , require, select, tonumber, tostring, type

local debug, s, t, u = require"debug", require"string", require"table", require"util"



local _ENV = u.noglobals() ---------------------------------------------------



local s_byte, t_concat, t_insert, t_sort
    = s.byte, t.concat, t.insert, t.sort

local   copy,   expose,   fold,   load,   map,   setify, t_pack, t_unpack 
    = u.copy, u.expose, u.fold, u.load, u.map, u.setify, u.pack, u.unpack

local 
function charset_error(index, charset)
    error("Character at position ".. index + 1 
            .." is not a valid "..charset.." one.",
        2)
end


------------------------------------------------------------------------------
return function(Builder, LL) -- module wrapper -------------------------------
------------------------------------------------------------------------------


local binary_split_int, cs = Builder.binary_split_int, Builder.charset

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

-- factorizers, defined at the end of the file.
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
            charset_error(index, charset)
        end
        if v == "" then return LL_P(true) end
        return true and LL.__mul(map(makechar, split_int(v)))
    elseif type(v) == "table" then
        -- private copy because tables are mutable.
        local g = copy(v)
        if g[1] == nil then error("grammar has no initial rule") end
        if not LL_ispattern(g[1]) then g[1] = LL.V(g[1]) end
        return 
            --[[DBG]] true and 
            constructors.none("grammar", g) 
    elseif type(v) == "boolean" then
        return v and truept or falsept
    elseif type(v) == "number" then
        if v == 0 then
            return truept
        elseif v > 0 then
            return
                --[[DBG]] true and 
                constructors.aux("any", v)
        else
            return
                --[[DBG]] true and 
                - constructors.aux("any", -v)
        end
    end
end
LL.P = LL_P

local
function LL_S (set)
    if set == "" then 
        return 
            --[[DBG]] true and
            LL_P(false)
    else 
        local success, index = validate(set)
        if not success then 
            charset_error(index, charset)
        end
        return
            --[[DBG]] true and 
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
        -- [[DBG]]expose(range)
        for _, r in ipairs{...} do
            local success, index = validate(r)
            if not success then 
                charset_error(index, charset)
            end
            range = S_union ( range, Range(t_unpack(split_int(r))) )
        end
        -- This is awful.
        local representation = t_concat(map(tochar, 
                {load("return "..S_tostring(range))()}))
        local p = constructors.aux("set", range, representation)
        return 
            --[[DBG]] true and 
            constructors.aux("set", range, representation)
    end
end
LL.R = LL_R

local
function LL_V (name)
    assert(name ~= nil)
    return 
        --[[DBG]] true and 
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
        -- [[DP]] print("Fixed Len",pt.ptype)
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
        -- [[DP]] print("LL.B")
        -- [[DP]] LL.pprint(pt)
        local len = fixedlen(pt)
        assert(len, "A 'behind' pattern takes a fixed length pattern as argument.")
        if len >= 260 then error("Subpattern too long in 'behind' pattern constructor.") end
        return
            --[[DBG]] true and
            constructors.both("behind", pt, len)
    end
end

 
-- pt*pt
local
function LL_choice (a, b, ...)
    -- [[DBG]] print("Choice =====", a, "b", b, "...", ...)
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
            --[[DBG]] true and
            constructors.aux("choice", ch)
    end
end
LL.__add = LL_choice


 -- pt+pt, 
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
        --[[DBG]] true and
        constructors.aux("sequence", seq)
end
LL.__mul = sequence


local
function LL_lookahead (pt)
    -- Simplifications
    if pt == truept
    or pt == falsept
    or pt.ptype == "unm"
    or pt.ptype == "lookahead" 
    then 
        return pt
    end
    -- -- The general case
    -- [[DB]] print("LL_lookahead", constructors.subpt("lookahead", pt))
    return 
        --[[DBG]] true and
        constructors.subpt("lookahead", pt)
end
LL.__len = LL_lookahead
LL.L = LL_lookahead

local
function LL_unm(pt)
    -- Simplifications
    local as_is
    pt, as_is = factorize_unm(pt)
    if as_is 
    then return pt
    else 
        return 
            --[[DBG]] true and
            constructors.subpt("unm", pt) end
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

-------------------------------------------------------------------------------
--- Captures
--
for __, cap in pairs{"C", "Cs", "Ct"} do
    LL[cap] = function(pt, aux)
        pt = LL_P(pt)
        return 
            --[[DBG]] true and
            constructors.subpt(cap, pt)
    end
end


LL["Cb"] = function(aux)
    return 
        --[[DBG]] true and
        constructors.aux("Cb", aux)
end


LL["Carg"] = function(aux)
    assert(type(aux)=="number", "Number expected as parameter to Carg capture.")
    assert( 0 < aux and aux <= 200, "Argument out of bounds in Carg capture.")
    return 
        --[[DBG]] true and
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
        --[[DBG]] true and
        constructors.none("Cc", t_pack(...))
end
LL.Cc = LL_Cc

for __, cap in pairs{"Cf", "Cmt"} do
    local msg = "Function expected in "..cap.." capture"
    LL[cap] = function(pt, aux)
    assert(type(aux) == "function", msg)
    pt = LL_P(pt)
    return 
        --[[DBG]] true and
        constructors.both(cap, pt, aux)
    end
end


local
function LL_Cg (pt, tag)
    pt = LL_P(pt)
    if tag then 
        return  
            --[[DBG]] true and
            constructors.both("Ctag", pt, tag)
    else
        return 
            --[[DBG]] true and
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
        --[[DBG]] true and
        constructors.both(name, pt, aux)
end
LL.__div = LL_slash

local factorizer
    = Builder.factorizer(Builder, LL)

-- These are declared as locals at the top of the wrapper.
factorize_choice,  factorize_lookahead,  factorize_sequence,  factorize_unm =
factorizer.choice, factorizer.lookahead, factorizer.sequence, factorizer.unm

end -- module wrapper --------------------------------------------------------


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
