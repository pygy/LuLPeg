local pairs, error, tostring, kind
    = pairs, error, tostring, kind

--[[DBG]] local print = print

local s, t, u = require"string", require"table", require"util"



local _ENV = u.noglobals() ----------------------------------------------------



local s_byte, s_sub, t_concat, t_insert, t_remove, t_unpack
    = s.byte, s.sub, t.concat, t.insert, t.remove, u.unpack

local   load,   map,   map_all, t_pack
    = u.load, u.map, u.map_all, u.pack

--[[DBG]] local expose = u.expose

return function(Builder, LL)
local evaluate, LL_ispattern =  LL.evaluate, LL.ispattern
local charset = Builder.charset



local compilers = {}


local
function compile(pt, ccache)
    -- print("Compile", pt.pkind)
    if not LL_ispattern(pt) then
        --[[DBG]] expose(pt)
        error("pattern expected")
    end
    local typ = pt.pkind
    if typ == "grammar" then
        ccache = {}
    elseif typ == "ref" or typ == "choice" or typ == "sequence" then
        if not ccache[pt] then
            ccache[pt] = compilers[typ](pt, ccache)
        end
        return ccache[pt]
    end
    if not pt.compiled then
        -- [[DBG]] print("Not compiled:")
        -- [[DBG]] LL.pprint(pt)
        pt.compiled = compilers[pt.pkind](pt, ccache)
    end

    return pt.compiled
end
LL.compile = compile


local
function clear_captures(aux, si)
    for i = si, #aux do aux[i] = nil end
end

------------------------------------------------------------------------------
----------------------------------  ,--. ,--. ,--. |_  ,  , ,--. ,--. ,--.  --
--- Captures                        |    .--| |__' |   |  | |    |--' '--,
--                                  `--' `--' |    `-- `--' '    `--' `--'


-- These are all alike:


for _, v in pairs{ 
    "C", "Cf", "Cg", "Cs", "Ct", "Clb",
    "/string", "/table", "/number", "/function"
} do
    compilers[v] = load(([=[
    local compile = ...
    return function (pt, ccache)
        -- [[DBG]] print("Compiling", "XXXX")
        -- [[DBG]] expose(LL.get_direct(pt))
        -- [[DBG]] LL.pprint(pt)
        local matcher, aux = compile(pt.pattern, ccache), pt.aux
        return function (sj, si, caps, ci, state)
             -- [[DBG]] print("XXXX    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            local ref_ci = ci

            local kind, bounds, openclose, aux 
                = caps.kind, caps.bounds, caps.openclose, caps.aux

            kind      [ci] = "XXXX"
            bounds    [ci] = si
            -- openclose = 0 ==> bound is lower bound of the capture.
            openclose [ci] = 0
            aux       [ci] = aux or false

            local success

            success, si, ci
                = matcher(sj, si, caps, ci + 1, state)
            if success then
                if ci == ref_ci + 1 then
                    -- a full capture, ==> openclose > 0 == the closing bound.
                    caps.openclose[ref_ci] = si
                else
                    kind      [ci] = "XXXX"
                    bounds    [ci] = si
                    -- a closing bound. openclose < 0 
                    -- (offset in the capture stack between open and close)
                    openclose [ci] = ci - ref_ci
                    aux       [ci] = aux or false
                end
            end
            return success, si, ci
        end
    end]=]):gsub("XXXX", v), v.." compiler")(compile)
end




compilers["Carg"] = function (pt, ccache)
    local n = pt.aux
    return function (sj, si, caps, ci, state)
        if state.args.n < n then error("reference to absent argument #"..n) end
        caps.kind      [ci] = "value"
        caps.bounds    [ci] = si
        caps.openclose [ci] = si
        caps.aux       [ci] = state.args[n]
        -- trick to keep the aux a proper sequence, so that #aux behaves.
        -- if the value is nil, we set both openclose and aux to
        -- +infinity, and handle it appropriately when it is eventually evaluated.
        -- openclose holds a positive value ==> full capture.
        caps.openclose [ci] = state.args[n] ~= nil and si or 1/0
        caps.aux       [ci] = state.args[n] ~= nil and state.args[n] or 1/0
        return true, si, ci + 1
    end
end

for _, v in pairs{ 
    "Cb", "Cc", "Cp"
} do
    compilers[v] = load(([=[
    return function (pt, ccache)
        local aux = pt.aux
        return function (sj, si, caps, ci, state)
             -- [[DBG]] print("XXXX    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)

            caps.kind      [ci] = XXXX
            caps.bounds    [ci] = si
            caps.openclose [ci] = si
            caps.aux       [ci] = aux or false

            return true, si, ci + 1
        end
    end]=]):gsub("XXXX", v), v.." compiler")(compile)
end


compilers["/zero"] = function (pt, ccache)
    local matcher = compile(pt.pattern, ccache)
    return function (sj, si, caps, ci, state)
        local success, nsi = matcher(sj, si, caps, si, state)

        clear_captures(caps.aux, ci)

        return success, nsi, ci
    end
end


local function pack_Cmt_caps(i,...) return i, t_pack(...) end

compilers["Cmt"] = function (pt, ccache)
    local matcher, func = compile(pt.pattern, ccache), pt.aux
    return function (sj, si, caps, ci, state)
        local Cmt_acc = {
            kind = {},
            bounds = {},
            openclose = {},
            aux = {},
            parent = caps,
            parent_i = ci
        }
        local success, Cmt_si, Cmt_i = matcher(sj, si, Cmt_acc, 1, state)

        if not success then return false, si, ci end

        local final_si, values 

        if Cmt_i == 1 then
            final_si, values = pack_Cmt_caps(
                func(sj, Cmt_si, s_sub(sj, si, nsi - 1))
            )
        else
            final_si, values = pack_Cmt_caps(
                func(sj, Cmt_si, evaluate(Cmt_acc, sj))
            )
        end

        if not final_si then return false, si, ci end

        if final_si == true then final_si = Cmt_si end

        if type(final_nsi) == "number"
        and si <= final_si 
        and final_si <= #sj + 1 
        then
            local kind, bounds, openclose, aux 
                = caps.kind, caps.bounds, caps.openclose, caps.aux
            for i = 1, values.n do
                kind      [ci] = "value"
                bounds    [ci] = si
                -- See Carg for the rationale of 1/0.
                openclose [ci] = values[i] ~= nil and si     or 1/0
                aux       [ci] = values[i] ~= nil and values[i] or 1/0

                ci = ci + 1
            end
        elseif type(final_si) == "number" then
            error"Index out of bounds returned by match-time capture."
        else
            error("Match time capture must return a number, a boolean or nil"
                .." as first argument, or nothing at all.")
        end
        return true, final_si, si, ci
    end
end


------------------------------------------------------------------------------
------------------------------------  ,-.  ,--. ,-.     ,--. ,--. ,--. ,--. --
--- Other Patterns                    |  | |  | |  | -- |    ,--| |__' `--.
--                                    '  ' `--' '  '    `--' `--' |    `--'


compilers["string"] = function (pt, ccache)
    local S = pt.aux
    local N = #S
    return function(sj, si, caps, ci, state)
         -- [[DBG]] print("String    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
        local in_1 = si - 1
        for i = 1, N do
            local c
            c = s_byte(sj,in_1 + i)
            if c ~= S[i] then
         -- [[DBG]] print("%FString    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
                return false, si, ci
            end
        end
         -- [[DBG]] print("%SString    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
        return true, si + N, ci
    end
end


compilers["char"] = function (pt, ccache)
    return load(([=[
        local s_byte = ...
        return function(sj, si, caps, ci, state)
             -- [[DBG]] print("Char    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            local c, nsi = s_byte(sj, si), si + 1
            if c ~= __C0__ then
                return false, si, ci
            end
            return true, nsi, ci
        end]=]):gsub("__C0__", tostring(pt.aux)))(s_byte)
end


local
function truecompiled (sj, si, caps, ci, state)
     -- [[DBG]] print("True    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
    return true, si, ci
end
compilers["true"] = function (pt)
    return truecompiled
end


local
function falsecompiled (sj, si, caps, ci, state)
     -- [[DBG]] print("False   ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
    return false, si, ci
end
compilers["false"] = function (pt)
    return falsecompiled
end


local
function eoscompiled (sj, si, caps, ci, state)
     -- [[DBG]] print("EOS     ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
    return si > #sj, si, ci
end
compilers["eos"] = function (pt)
    return eoscompiled
end


local
function onecompiled (sj, si, caps, ci, state)
     -- [[DBG]] print("One     ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
    local char, nsi = s_byte(sj, si), si + 1
    if char
    then return true, nsi, ci
    else return false, si, ci end
end

compilers["one"] = function (pt)
    return onecompiled
end


compilers["any"] = function (pt)
    local N = pt.aux
    if N == 1 then
        return onecompiled
    elseif not charset.binary then
        return function (sj, si, caps, ci, state)
             -- [[DBG]] print("Any UTF-8",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            local n, c, nsi = N
            while n > 0 do
                c, nsi = s_byte(sj, si), si + 1
                if not c then
                     -- [[DBG]] print("%FAny    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
                    return false, si, ci
                end
                n = n -1
            end
             -- [[DBG]] print("%SAny    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            return true, nsi, ci
        end
    else -- version optimized for byte-width encodings.
        N = pt.aux - 1
        return function (sj, si, caps, ci, state)
             -- [[DBG]] print("Any byte",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            local n = si + N
            if n <= #sj then
                -- [[DBG]] print("%SAny    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
                return true, n + 1, ci
            else
                 -- [[DBG]] print("%FAny    ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
                return false, si, ci
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
        return function (sj, si, caps, ci, state)
             -- [[DBG]] print("Grammar ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            t_insert(state.grammars, gram)
            local success, nsi, ci = start(sj, si, caps, ci, state)
            t_remove(state.grammars)
             -- [[DBG]] print("%Grammar ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            return success, nsi, ci
        end
    end
end

local dummy_acc = {kind={}, bounds={}, openclose={}, aux={}}
compilers["behind"] = function (pt, ccache)
    local matcher, N = compile(pt.pattern, ccache), pt.aux
    return function (sj, si, caps, ci, state)
         -- [[DBG]] print("Behind  ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
        if si <= N then return false, si, ci end

        local success = matcher(sj, si - N, dummy_acc, ci, state)
        -- note that behid patterns cannot hold captures.
        dummy_acc.aux = {}
        return success, si, ci
    end
end

compilers["range"] = function (pt)
    local ranges = pt.aux
    return function (sj, si, caps, ci, state)
         -- [[DBG]] print("Range   ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
        local char, nsi = s_byte(sj, si), si + 1
        for i = 1, #ranges do
            local r = ranges[i]
            if char and r[char]
            then return true, nsi, ci end
        end
        return false, si, ci
    end
end

compilers["set"] = function (pt)
    local s = pt.aux
    return function (sj, si, caps, ci, state)
             -- [[DBG]] print("Set, Set!",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
        local char, nsi = s_byte(sj, si), si + 1
        if s[char]
        then return true, nsi, ci
        else return false, si, ci end
    end
end

-- hack, for now.
compilers["range"] = compilers.set

compilers["ref"] = function (pt, ccache)
    local name = pt.aux
    local ref
    return function (sj, si, caps, ci, state)
         -- [[DBG]] print("Reference",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
        if not ref then
            if #state.grammars == 0 then
                error(("rule 'XXXX' used outside a grammar"):gsub("XXXX", tostring(name)))
            elseif not state.grammars[#state.grammars][name] then
                error(("rule 'XXXX' undefined in given grammar"):gsub("XXXX", tostring(name)))
            end
            ref = state.grammars[#state.grammars][name]
        end
        -- print("Ref",caps, si) --, sj)
        return ref(sj, si, caps, ci, state)
    end
end



-- Unroll the loop using a template:
local choice_tpl = [=[
            success, si, ci = XXXX(sj, si, caps, ci, state)
            if success then
                 -- [[DBG]] print("%SChoice   ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
                return true, si, ci
            else
                clear_captures(aux, ci)
            end]=]
compilers["choice"] = function (pt, ccache)
    local choices, n = map(pt.aux, compile, ccache), #pt.aux
    local names, chunks = {}, {}
    for i = 1, n do
        local m = "ch"..i
        names[#names + 1] = m
        chunks[ #names  ] = choice_tpl:gsub("XXXX", m)
    end
    names[#names + 1] = "clear_captures"
    choices[ #names ] = clear_captures
    local compiled = t_concat{
        "local ", t_concat(names, ", "), [=[ = ...
        return function (sj, si, caps, ci, state)
             -- [[DBG]] print("Choice   ",caps, caps and caps.kind[ci] or "'nil'", ci, si, state) --, sj)
            local aux, success = caps.aux, false
            ]=],
            t_concat(chunks,"\n"),[=[
             -- [[DBG]] print("%FChoice   ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            return false, si, ci
        end]=]
    }
    -- print(compiled)
    return load(compiled, "Choice")(t_unpack(choices))
end



local sequence_tpl = [=[
             -- [[DBG]] print("XXXX", nsi, caps, new_i, state)
            success, nsi, new_i = XXXX(sj, nsi, caps, new_i, state)
            if not success then
                 -- [[DBG]] print("%FSequence",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
                clear_captures(caps.aux, ci)
                return false, si, ci
            end]=]
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
    names[#names + 1] = "clear_captures"
    sequence[ #names ] = clear_captures
    local compiled = t_concat{
        "local ", t_concat(names, ", "), [=[ = ...
        return function (sj, si, caps, ci, state)
             -- [[DBG]] print("Sequence",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            local nsi, new_i, success = si, ci
            ]=],
            t_concat(chunks,"\n"),[=[
             -- [[DBG]] print("%SSequence",caps, caps and caps.kind or "'nil'", new_i, si, state) --, sj)
             -- [[DBG]] print("NEW I:",new_i)
            return true, nsi, new_i
        end]=]
    }
    -- print(compiled)
   return load(compiled, "Sequence")(t_unpack(sequence))
end


compilers["at most"] = function (pt, ccache)
    local matcher, n = compile(pt.pattern, ccache), pt.aux
    n = -n
    return function (sj, si, caps, ci, state)
         -- [[DBG]] print("At most   ",caps, caps and caps.kind or "'nil'", si) --, sj)
        local success = true
        for i = 1, n do
            success, si, ci = matcher(sj, si, caps, ci, state)
            if not success then 
                clear_captures(caps.aux, ci)
                break
            end
        end
        return true, si, ci
    end
end

compilers["at least"] = function (pt, ccache)
    local matcher, n = compile(pt.pattern, ccache), pt.aux
    if n == 0 then
        return function (sj, si, caps, ci, state)
            -- [[DBG]] print("At least 0 ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            while true do
                local success
                -- [[DBG]] print("    rep "..N,caps, caps and caps.kind or "'nil'", ci, si, state)
                -- [[DBG]] N=N+1
                success, si, ci = matcher(sj, si, caps, ci, state)
                if not success then                     
                    break
                end
            end
            clear_captures(caps.aux, ci)
            return true, si, ci
        end
    elseif n == 1 then
        return function (sj, si, caps, ci, state)
            -- [[DBG]] print("At least 1 ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            local success = true
            success, si, ci = matcher(sj, si, caps, ci, state)
            if not success then
                clear_captures(caps.aux, ci)
                return false, si, ci
            end
            -- [[DBG]] local N = 1
            while success do
                -- [[DBG]] ("    rep "..N,caps, caps and caps.kind or "'nil'", ci, si, state)
                -- [[DBG]] N=N+1
                success, si, ci = matcher(sj, si, caps, ci, state)
            end
            clear_captures(caps.aux, ci)
            return true, si, ci
        end
    else
        return function (sj, si, caps, ci, state)
            -- [[DBG]] print("At least "..n.." ",caps, caps and caps.kind or "'nil'", ci, si, state) --, sj)
            local success = true
            for _ = 1, n do
                success, si, ci = matcher(sj, si, caps, ci, state)
                if not success then
                    clear_captures(caps.aux, ci)
                    return false, si, ci
                end
            end
            -- [[DBG]] local N = 1
            while success do
                -- [[DBG]] print("    rep "..N,caps, caps and caps.kind or "'nil'", ci, si, state)
                -- [[DBG]] N=N+1
                success, si, ci = matcher(sj, si, caps, ci, state)
            end
            clear_captures(caps.aux, ci)
            return true, si, ci
        end
    end
end

compilers["unm"] = function (pt, ccache)
    -- P(-1)
    if pt.pkind == "any" and pt.aux == 1 then
        return eoscompiled
    end
    local matcher = compile(pt.pattern, ccache)
    return function (sj, si, caps, ci, state)
         -- [[DBG]] print("Unm     ", caps, caps and caps.kind or "'nil'", ci, si, state)
        -- Throw captures away
        local success, _, _ = matcher(sj, si, caps, 1, state)
        clear_captures(caps.aux, ci)
        return not success, si, ci
    end
end

compilers["lookahead"] = function (pt, ccache)
    local matcher = compile(pt.pattern, ccache)
    return function (sj, si, caps, ci, state)
         -- [[DBG]] print("Lookahead", caps, caps and caps.kind or "'nil'", si, ci, state)
        -- Throw captures away
        local success, _, _ = matcher(sj, si, caps, 1, state)
         -- [[DBG]] print("%Lookahead", caps, caps and caps.kind or "'nil'", si, ci, state)
         clear_captures(caps.aux, ci)
        return success, si, ci
    end
end

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
