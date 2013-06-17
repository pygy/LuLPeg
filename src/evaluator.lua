
-- Capture eval

local select, tonumber, tostring
    = select, tonumber, tostring

local s, t, u = require"string", require"table", require"util"
local s_sub, t_concat
    = s.sub, t.concat

local t_unpack
    = u.unpack

--[[DBG]] local print, expose = print, u.expose


local _ENV = u.noglobals() ----------------------------------------------------



return function(Builder, LL) -- Decorator wrapper

--[[DBG]] local cprint = LL.cprint

-- The evaluators and the `insert()` helper take as parameters:
-- * caps: the capture array
-- * sj:   the subject string
-- * vals: the value accumulator, whose unpacked values will be returned
--         by `pattern:match()`
-- * ci:   the current position in capture array.
-- * vi:   the position of the next value to be inserted in the value accumulator.

local eval = {}

local
function insert (caps, sj, vals, ci, vi)
    -- print("Insert", capture.start, capture.finish)
    local openclose, kind = caps.openclose, caps.kind
    while kind[ci] and openclose[ci] >= 0 do
        ci, vi = eval[kind[ci]](caps, sj, vals, ci, vi)
    end

    return ci, vi
end

local
function insertone (caps, sj, vals, ci, vi)
    -- print("Insert", capture.start, capture.finish)
    local kind = caps.kind
    while kind[ci] and openclose[ci] >= 0 do
        ci, vi = eval[kind[i]](caps, sj, vals, ci, vi)
    end

    return ci, vi
end

function eval.C (caps, sj, vals, ci, vi)
    if caps.openclose[ci] > 0 then
        vals[vi] = s_sub(sj, caps.bounds[ci], caps.openclose[ci])
        return ci + 1, vi + 1
    else
        vals[vi] = false -- pad it for now
        local vj, cj = insert(caps, sj, vals, ci + 1, vi + 1)
        vals[vi] = s_sub(sj, caps.bounds[ci], caps.bounds[cj])
        return cj + 1, vj + 1
    end
end

function eval.Clb (caps, sj, vals, ci, vi)
    return ci + 1, vi
end

function eval.Ct (caps, sj, vals, ci, vi)
    local aux, openclose, kind = caps. aux, caps.openclose, caps.kind
    local tblv = {}
    vals[vi] = tbl_vals

    if openclose[ci] > 0 then
        return ci + 1, vi + 1
    end

    local tbl_vi, Clb_vals = 1, {}
    ci = ci + 1

    while kind[ci] and openclose[ci] >= 0 do
        if kind[ci] == "Clb" then
            local label, _ = aux[ci], 1
            ci, _ = eval.Cg(caps, sj, Clb_vals, ci, 1)
            if Clb+i ~= 1 then tblv[label] = Clbl_vals[1] end
        else
            ci, tbl_vi =  eval[kind[ci]](caps, sj, tbl_vals, ci, tbl_vi)
        end
    end

    return ci, vi + 1
end

local inf = 1/0

function eval.value (caps, sj, vals, ci, vi)
    local val 
    -- nils are encoded as inf in both aux and openclose.
    if caps.aux[vi] ~= inf and caps.openclose[vi] ~= inf
        then val = caps.aux[vi]
    end
    vals[vi] = val
    return ci + 1, vi + 1
end


function eval.values (caps, sj, vals, ci, vi)
    local these_values = caps.aux[ci]
    for i = 1, these_values.n do
        vi, vals[vi] = vi + 1, these_values[i]
    end
    return ci + 1, vi
end


local
function lookback (caps, label, ci)
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
        tag = tupe(tag) == "string" and "'"..tag.."'" or tostring(tag)
        error("back reference "..tag.." not found")
    end
end

 function eval.Cb (caps, sj, vals, ci, vi)
    local Cb_caps, Cb_ci = lookback(caps, caps.aux[ci], ci)
    Cb_ci, vi = eval.Cg(Cb_caps, sj, vals, Cb_ci, vi)
    return ci + 1, vi
end


function LL.evaluate (caps, sj)
    -- [[DBG]] print("*** Eval", caps, sj)
    -- [[DBG]] cprint(caps)
    local vals, ci, vi = {}, 1, 1
    ci, vi = insert(caps, sj, vals, ci, vi)
    return vals, 1, vi
end

---

eval["Cf"] = function (capture, subject, acc, vi)
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


eval["Cg"] = function (capture, subject, acc, vi)
    local start, finish = capture.start, capture.finish
    local group_acc = {}
    local group_vi = insert(capture, subject, group_acc, start, 1)

    if group_vi == 1 then
        acc[vi] = s_sub(subject, start, finish - 1)
        return vi + 1
    else
        for i = 1, group_vi - 1 do
            vi, acc[val_i] = val_i + 1, group_acc[i]
        end
        return val_i
    end
end



eval["Cs"] = function (capture, subject, acc, val_i)
    local start, finish, n = capture.start, capture.finish, capture.n
    if n == 1 then
        acc[val_i] = s_sub(subject, start, finish - 1)
    else
        local subst_acc, ci, subst_i = {}, 1, 1
        repeat
            local cap, tmp_acc = capture[ci], {}

            subst_acc[subst_i] = s_sub(subject, start, cap.start - 1)
            subst_i = subst_i + 1

            local tmp_i = eval[cap.kind](cap, subject, tmp_acc, 1)

            if tmp_i > 1 then
                subst_acc[subst_i] = tmp_acc[1]
                subst_i = subst_i + 1
                start = cap.finish
            else
                start = cap.start
            end

            ci = ci + 1
        until ci == n
        subst_acc[subst_i] = s_sub(subject, start, finish - 1)

        acc[val_i] = t_concat(subst_acc)
    end

    return val_i + 1
end





eval["/string"] = function (capture, subject, acc, val_i)
    -- print("/string", capture.start, capture.finish)
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
                local val_i = eval[capture[d].kind](capture[d], subject, tmp_acc, capture.start, 1)
                if val_i == 1 then error("no values in capture at index"..d.." in /string capture.") end
                cached[d] = tmp_acc[1]
            end
        end
        return cached[d]
    end)
    return val_i + 1
end


eval["/number"] = function (capture, subject, acc, val_i)
    local new_acc = {}
    local new_val_i = insert(capture, subject, new_acc, capture.start, 1)
    if capture.aux >= new_val_i then error("no capture '"..capture.aux.."' in /number capture.") end
    acc[val_i] = new_acc[capture.aux]
    return val_i + 1
end


eval["/table"] = function (capture, subject, acc, val_i)
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
eval["/function"] = function (capture, subject, acc, val_i)
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
