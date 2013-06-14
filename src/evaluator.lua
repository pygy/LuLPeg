
-- Capture evaluators

local select, tonumber, tostring
    = select, tonumber, tostring

local s, t, u = require"string", require"table", require"util"
local s_sub, t_concat
    = s.sub, t.concat

local t_unpack
    = u.unpack

-- [[DBG]] local   expose = u.expose


local _ENV = u.noglobals() ----------------------------------------------------



return function(Builder, LL) -- Decorator wrapper

--[[DBG]] local cprint = LL.cprint

local evaluators, insert = {}

local
function evaluate (capture, subject, subj_i)
    -- [[DBG]] print("*** Eval", subj_i)
    -- [[DBG]] cprint(capture)
    local acc, val_i, _ = {}
    -- [[DBG]] LL.cprint(capture)
    val_i = insert(capture, subject, acc, subj_i, 1)
    return acc, val_i
end
LL.evaluate = evaluate


-- The evaluators and the `insert()` helper take as parameters:
-- * capture:  the current capture object.
-- * subject:  the subject string
-- * acc:      the value accumulator, whose unpacked values will be returned
--             by `pattern:match(...)`
-- * subj_i: the current position in the subject string.
-- * val_i: the position of the next value to be inserted in the value accumulator.


function insert (capture, subject, acc, subj_i, val_i)
    -- print("Insert", capture.start, capture.finish)
    for i = 1, capture.n - 1 do
        -- [[DBG]] print("Eval Insert: ", capture[i].type, capture[i].start, capture[i])
            val_i =
                evaluators[capture[i].type](capture[i], subject, acc, subj_i, val_i)
            subj_i = capture[i].finish
    end
    return val_i
end

local
function lookback(capture, tag, subj_i)
    local found
    repeat
        for i = subj_i - 1, 1, -1 do
            -- print("LB for",capture[i].type)
            if  capture[i].Ctag == tag then
                -- print"Found"
                found = capture[i]
                break
            end
        end
        capture, subj_i = capture.parent, capture.parent_i
    until found or not capture

    if found then
        return found
    else
        tag = type(tag) == "string" and "'"..tag.."'" or tostring(tag)
        error("back reference "..tag.." not found")
    end
end

evaluators["Cb"] = function (capture, subject, acc, subj_i, val_i)
    local ref, Ctag
    ref = lookback(capture.parent, capture.tag, capture.parent_i)
    ref.Ctag, Ctag = nil, ref.Ctag
    val_i = evaluators.Cg(ref, subject, acc, ref.start, val_i)
    ref.Ctag = Ctag
    return val_i
end


evaluators["Cf"] = function (capture, subject, acc, subj_i, val_i)
    if capture.n == 0 then
        error"No First Value"
    end

    local func, fold_acc, first_val_i = capture.aux, {}
    first_val_i = evaluators[capture[1].type](capture[1], subject, fold_acc, subj_i, 1)

    if first_val_i == 1 then
        error"No first value"
    end
    subj_i = capture[1].finish

    local result = fold_acc[1]

    for i = 2, capture.n - 1 do
        local fold_acc2 = {}
        local val_i = evaluators[capture[i].type](capture[i], subject, fold_acc2, subj_i, 1)
        subj_i = capture[i].finish
        result = func(result, t_unpack(fold_acc2, 1, val_i - 1))
    end
    acc[val_i] = result
    return val_i + 1
end


evaluators["Cg"] = function (capture, subject, acc, subj_i, val_i)
    local start, finish = capture.start, capture.finish
    local group_acc = {}

    if capture.Ctag ~= nil  then
        return val_i
    end

    local group_val_i = insert(capture, subject, group_acc, start, 1)
    if group_val_i == 1 then
        acc[val_i] = s_sub(subject, start, finish - 1)
        return val_i + 1
    else
        for i = 1, group_val_i - 1 do
            val_i, acc[val_i] = val_i + 1, group_acc[i]
        end
        return val_i
    end
end


evaluators["C"] = function (capture, subject, acc, subj_i, val_i)
    val_i, acc[val_i] = val_i + 1, s_sub(subject,capture.start, capture.finish - 1)
    local _
    val_i = insert(capture, subject, acc, capture.start, val_i)
    return val_i
end


evaluators["Cs"] = function (capture, subject, acc, subj_i, val_i)
    local start, finish, n = capture.start, capture.finish, capture.n
    if n == 1 then
        acc[val_i] = s_sub(subject, start, finish - 1)
    else
        local subst_acc, cap_i, subst_i = {}, 1, 1
        repeat
            local cap, tmp_acc = capture[cap_i], {}

            subst_acc[subst_i] = s_sub(subject, start, cap.start - 1)
            subst_i = subst_i + 1

            local tmp_i = evaluators[cap.type](cap, subject, tmp_acc, subj_i, 1)

            if tmp_i > 1 then
                subst_acc[subst_i] = tmp_acc[1]
                subst_i = subst_i + 1
                start = cap.finish
            else
                start = cap.start
            end

            cap_i = cap_i + 1
        until cap_i == n
        subst_acc[subst_i] = s_sub(subject, start, finish - 1)

        acc[val_i] = t_concat(subst_acc)
    end

    return val_i + 1
end


evaluators["Ct"] = function (capture, subject, acc, subj_i, val_i)
    local tbl_acc, new_val_i, _ = {}, 1

    for i = 1, capture.n - 1 do
        local cap = capture[i]

        if cap.Ctag ~= nil then
            local tmp_acc = {}

            insert(cap, subject, tmp_acc, cap.start, 1)
            local val = (#tmp_acc == 0 and s_sub(subject, cap.start, cap.finish - 1) or tmp_acc[1])
            tbl_acc[cap.Ctag] = val
        else
            new_val_i = evaluators[cap.type](cap, subject, tbl_acc, cap.start, new_val_i)
        end
    end
    acc[val_i] = tbl_acc
    return val_i + 1
end


evaluators["value"] = function (capture, subject, acc, subj_i, val_i)
    acc[val_i] = capture.value
    return val_i + 1
end


evaluators["values"] = function (capture, subject, acc, subj_i, val_i)
local these_values = capture.values
    for i = 1, these_values.n do
        val_i, acc[val_i] = val_i + 1, these_values[i]
    end
    return val_i
end


evaluators["/string"] = function (capture, subject, acc, subj_i, val_i)
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
                local val_i = evaluators[capture[d].type](capture[d], subject, tmp_acc, capture.start, 1)
                if val_i == 1 then error("no values in capture at index"..d.." in /string capture.") end
                cached[d] = tmp_acc[1]
            end
        end
        return cached[d]
    end)
    return val_i + 1
end


evaluators["/number"] = function (capture, subject, acc, subj_i, val_i)
    local new_acc = {}
    local new_val_i = insert(capture, subject, new_acc, capture.start, 1)
    if capture.aux >= new_val_i then error("no capture '"..capture.aux.."' in /number capture.") end
    acc[val_i] = new_acc[capture.aux]
    return val_i + 1
end


evaluators["/table"] = function (capture, subject, acc, subj_i, val_i)
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
evaluators["/function"] = function (capture, subject, acc, subj_i, val_i)
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
