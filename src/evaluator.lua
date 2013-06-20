
-- Capture eval

local select, tonumber, tostring, type
    = select, tonumber, tostring, type

local s, t, u = require"string", require"table", require"util"
local s_sub, t_concat
    = s.sub, t.concat

local t_unpack
    = u.unpack

--[[DBG]] local error, print, expose = error, print, u.expose


local _ENV = u.noglobals() ----------------------------------------------------



return function(Builder, LL) -- Decorator wrapper

--[[DBG]] local cprint = LL.cprint

-- The evaluators and the `insert()` helper take as parameters:
-- * caps: the capture array
-- * sbj:  the subject string
-- * vals: the value accumulator, whose unpacked values will be returned
--         by `pattern:match()`
-- * ci:   the current position in capture array.
-- * vi:   the position of the next value to be inserted in the value accumulator.

local eval = {}

local
function insert (caps, sbj, vals, ci, vi)
    -- print("Insert", capture.start, capture.finish)
    local openclose, kind = caps.openclose, caps.kind
    while kind[ci] and openclose[ci] >= 0 do
        ci, vi = eval[kind[ci]](caps, sbj, vals, ci, vi)
    end

    return ci, vi
end

local
function insertone (caps, sbj, vals, ci, vi)
    -- print("Insert", capture.start, capture.finish)
    local kind = caps.kind
    while kind[ci] and openclose[ci] >= 0 do
        ci, vi = eval[kind[i]](caps, sbj, vals, ci, vi)
    end

    return ci, vi
end

function eval.C (caps, sbj, vals, ci, vi)
    if caps.openclose[ci] > 0 then
        vals[vi] = s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
        return ci + 1, vi + 1
    end

    vals[vi] = false -- pad it for now
    local cj, vj = insert(caps, sbj, vals, ci + 1, vi + 1)
    vals[vi] = s_sub(sbj, caps.bounds[ci], caps.bounds[cj] - 1)
    return cj + 1, vj
end


function eval.Cg (caps, sbj, vals, ci, vi)
    if caps.openclose[ci] > 0 then
        vals[vi] = s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
        return ci + 1, vi + 1
    end

    local cj, vj = insert(caps, sbj, vals, ci + 1, vi)
    return cj + 1, vj
end


function eval.Clb (caps, sbj, vals, ci, vi)
    return ci + 1, vi
end

function eval.Ct (caps, sbj, vals, ci, vi)
    local aux, openclose, kind = caps. aux, caps.openclose, caps.kind
    local tbl_vals = {}
    vals[vi] = tbl_vals

    if openclose[ci] > 0 then
        return ci + 1, vi + 1
    end

    local tbl_vi, Clb_vals = 1, {}
    ci = ci + 1

    while kind[ci] and openclose[ci] >= 0 do
        if kind[ci] == "Clb" then
            local label, Clb_vi = aux[ci], 1
            ci, Clb_vi = eval.Cg(caps, sbj, Clb_vals, ci, 1)
            if Clb_vi ~= 1 then tbl_vals[label] = Clb_vals[1] end
        else
            ci, tbl_vi =  eval[kind[ci]](caps, sbj, tbl_vals, ci, tbl_vi)
        end
    end
    return ci + 1, vi + 1
end

local inf = 1/0

function eval.value (caps, sbj, vals, ci, vi)
    local val 
    -- nils are encoded as inf in both aux and openclose.
    if caps.aux[vi] ~= inf and caps.openclose[vi] ~= inf
        then val = caps.aux[vi]
    end
    vals[vi] = val
    return ci + 1, vi + 1
end


function eval.Cc (caps, sbj, vals, ci, vi)
    local these_values = caps.aux[ci]
    -- [[DBG]] print"Eval Cc"; expose(these_values)
    for i = 1, these_values.n do
        vi, vals[vi] = vi + 1, these_values[i]
    end
    return ci + 1, vi
end


function eval.Cp (caps, sbj, vals, ci, vi)
    vals[vi] = caps.bounds[ci]
    return ci + 1, vi + 1
end


local
function lookback (caps, label, ci)
    --[[DBG]] print"lookback()"; expose(caps)
    local aux, openclose, kind, found, oc
    repeat
        aux, openclose, kind = caps.aux, caps.openclose, caps.kind
        repeat 
            ci = ci - 1
            oc = openclose[ci]
            if oc < 0 then ci = ci + oc end -- a closing 
            if kind[ci] == "Clabel" and label == aux[ci] then found = true; break end
        until ci == 1

        if found then break end
        caps, ci = caps.parent, caps.parent_i

    until not caps

    if found then
        return caps, ci
    else
        label = type(label) == "string" and "'"..label.."'" or tostring(label)
        error("back reference "..label.." not found")
    end
end

 function eval.Cb (caps, sbj, vals, ci, vi)
    local Cb_caps, Cb_ci = lookback(caps, caps.aux[ci], ci)
    Cb_ci, vi = eval.Cg(Cb_caps, sbj, vals, Cb_ci, vi)
    return ci + 1, vi
end

function eval.Cs (caps, sbj, vals, ci, vi)
    if caps.openclose[ci] > 0 then
        vals[vi] = s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
    else
        local bounds, kind, openclose = caps.bounds, caps.kind, caps.openclose
        local start, buffer, Cs_vals, bi, Cs_vi = bounds[ci], {}, {}, 1, 1
        local last
        ci = ci + 1
        -- [[DBG]] print"eval.CS, openclose: "; expose(openclose)
        -- [[DBG]] print("eval.CS, ci =", ci)
        while openclose[ci] >= 0 do
            last = bounds[ci]
            buffer[bi] = s_sub(sbj, start, last - 1)
            bi = bi + 1

            ci, Cs_vi = eval[kind[ci]](caps, sbj, Cs_vals, ci, 1)

            if Cs_vi > 1 then
                buffer[bi] = Cs_vals[1]
                bi = bi + 1
                start = openclose[ci-1] > 0 and openclose[ci-1] or bounds[ci-1]
            else
                start = last
            end

        -- [[DBG]] print("eval.CS while, ci =", ci)
        end
        buffer[bi] = s_sub(sbj, start, bounds[ci])

        vals[vi] = t_concat(buffer)
    end

    return ci + 1, vi + 1
end


local
function insert_divfunc_results(acc, val_i, ...)
    local n = select('#', ...)
    for i = 1, n do
        val_i, acc[val_i] = val_i + 1, select(i, ...)
    end
    return val_i
end

function eval.div_function (caps, sbj, vals, ci, vi)
    local func = caps.aux[ci]
    local params, divF_vi

    if caps.openclose[ci] > 0 then
        params, divF_vi = {s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)}, 2
    else
        divF_vals = {}
        ci, divF_vi = insert(caps, sbj, params, ci + 1, 1)
    end

    ci = ci + 1 -- skip the closed or closing node.
    vi = insert_divfunc_results(vals, vi, func(t_unpack(params, 1, divF_vi - 1)))
    return ci, vi
end


function eval.div_number (caps, sbj, vals, ci, vi)
    local this_aux = caps.aux[ci]
    local divN_vals, divN_vi

    if caps.openclose[ci] > 0 then
        divN_vals, divN_vi = {s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)}, 2
    else
        divN_vals = {}
        ci, divN_vi = insert(caps, sbj, divN_vals, ci + 1, 1)
    end
    ci = ci + 1 -- skip the closed or closing node.

    if this_aux >= divN_vi then error("no capture '"..this_aux.."' in /number capture.") end
    vals[vi] = divN_vals[this_aux]
    return ci, vi + 1
end


local function div_str_cap_refs (caps, ci)
    local openclose, refs, depth = caps.openclose, {open=caps.bounds[ci]}, 0
    if openclose[ci] > 0 then 
        refs.close = openclose[ci]
        ci = ci + 1
        return ci, refs
    end
    ci = ci + 1
    while openclose[ci] < 0 or depth > 0 do
        if openclose[ci] < 0 then
            depth = depth - 1
        else
            refs[#refs+1] = ci
            if openclose[ci] == 0 then
                depth = depth + 1
                ci = ci + 1
            end
        end
        ci = ci + 1
    end
    refs.close = caps.bounds[ci]
    return ci, refs
end

function eval.div_string (caps, sbj, vals, ci, vi)
    -- print("div_string", capture.start, capture.finish)
    local cached, n, refs
    local the_string, divS_vals = caps.aux[ci], {}
    ci, refs = div_str_cap_refs(caps, ci)
    n = #refs
    vals[vi] = the_string:gsub("%%([%d%%])", function (d)
        if d == "%" then return "%" end
        d = tonumber(d)
        if not cached[d] then
            if d > n then
                error("no capture at index "..d.." in /string capture.")
            end
            if d == 0 then
                cached[d] = s_sub(subject, refs.open, refs.close)
            else
                local _, vi = eval[kind[refs[d]]](caps, sbj, divS_vals, refs[d], 1)
                if vi == 1 then error("no values in capture at index"..d.." in /string capture.") end
                cached[d] = divS_vals[1]
            end
        end
        return cached[d]
    end)
    return ci, vi + 1
end


function eval.div_table (caps, sbj, vals, ci, vi)
    local this_aux = caps.aux[ci]
    local key

    if caps.openclose[ci] > 0 then
        key =  s_sub(sbj, caps.bounds[ci], caps.openclose[ci] - 1)
    else
        local divT_vals, _ = {}
        ci, _ = insert(caps, sbj, divT_vals, ci + 1, 1)
        key = divT_vals[1]
    end

    ci = ci + 1
    if this_aux[key] then
        vals[vi] = this_aux[key]
        return ci, vi + 1
    else
        return ci, vi
    end
end



function LL.evaluate (caps, sbj, ci)
    -- [[DBG]] print("*** Eval", caps, sbj)
    -- [[DBG]] expose(caps)
    -- [[DBG]] cprint(caps)
    local vals = {}
    local _,  vi = insert(caps, sbj, vals, ci, 1)
    return vals, 1, vi
end

---

eval["Cf"] = function() error("NYI: Cf") end

local _ = function (capture, subject, acc, vi)
    if capture.n == 0 then
        error"No First Value"
    end

    local func, fold_acc, first_vi = capture.aux, {}
    first_vi = eval[capture[1].kind](capture[1], subject, fold_acc, 1)

    if first_vi == 1 then
        error"No first value"
    end

    local result = fold_acc[1]

    for i = 2, capture.n - 1 do
        local fold_acc2 = {}
        local vi = eval[capture[i].kind](capture[i], subject, fold_acc2, 1)
        result = func(result, t_unpack(fold_acc2, 1, vi - 1))
    end
    acc[vi] = result
    return vi + 1
end





end  -- Decorator wrapper


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
