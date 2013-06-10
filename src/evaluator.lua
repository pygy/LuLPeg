
-- Capture evaluators

return function(Builder, PL) -- Decorator wrapper

local cprint = PL.cprint

local pcall, select, setmetatable, tonumber, tostring
    = pcall, select, setmetatable, tonumber, tostring

local s, t, u = require"string", require"table", require"util"



local _ENV = u.noglobals() ----------------------------------------------------



local s_sub, t_concat
    = s.sub, t.concat

local expose, strip_mt, t_unpack
    = u.expose, u.strip_mt, u.unpack

local evaluators = {}

local
function evaluate (capture, subject, index)
    -- print("*** Eval", index)
    -- cprint(capture)
    local acc, val_i, _ = {}
    -- PL.cprint(capture)
    _, val_i = evaluators.insert(capture, subject, acc, index, 1)
    return acc, val_i
end
PL.evaluate = evaluate

--- Some accumulator types for the evaluator
--




local function insert (capture, subject, acc, index, val_i)
    -- print("Insert", capture.start, capture.finish)
    for i = 1, capture.n - 1 do
        -- print("Eval Insert: ", capture[i].type, capture[i].start, capture[i])
            local c 
            index, val_i =
                evaluators[capture[i].type](capture[i], subject, acc, index, val_i)
    end
    return index, val_i
end
evaluators["insert"] = insert

local
function lookback(capture, tag, index)
    local found
    repeat
        for i = index - 1, 1, -1 do
            -- print("LB for",capture[i].type)
            if  capture[i].Ctag == tag then
                -- print"Found"
                found = capture[i]
                break
            end
        end
        capture, index = capture.parent, capture.parent_i
    until found or not capture

    if found then 
        return found
    else 
        tag = type(tag) == "string" and "'"..tag.."'" or tostring(tag)
        error("back reference "..tag.." not found")
    end
end

evaluators["Cb"] = function (capture, subject, acc, index, val_i)
    local ref, Ctag, _ 
    ref = lookback(capture.parent, capture.tag, capture.parent_i)
    ref.Ctag, Ctag = nil, ref.Ctag
    _, val_i = evaluators.Cg(ref, subject, acc, ref.start, val_i)
    ref.Ctag = Ctag
    return index, val_i
end


evaluators["Cf"] = function (capture, subject, acc, index, val_i)
    if capture.n == 0 then
        error"No First Value"
    end

    local func, fold_acc, first_val_i, _ = capture.aux, {}
    index, first_val_i = evaluators[capture[1].type](capture[1], subject, fold_acc, index, 1)

    if first_val_i == 1 then 
        error"No first value"
    end
    
    local result = fold_acc[1]

    for i = 2, capture.n - 1 do
        local fold_acc2, vi = {}
        index, vi = evaluators[capture[i].type](capture[i], subject, fold_acc2, index, 1)
        result = func(result, t_unpack(fold_acc2, 1, vi - 1))
    end
    acc[val_i] = result
    return capture.finish, val_i + 1
end


evaluators["Cg"] = function (capture, subject, acc, index, val_i)
    local start, finish = capture.start, capture.finish
    local group_acc = {}

    if capture.Ctag ~= nil  then
        return start, val_i
    end

    local index, group_val_i = insert(capture, subject, group_acc, start, 1)
    if group_val_i == 1 then
        acc[val_i] = s_sub(subject, start, finish - 1)
        return finish, val_i + 1
    else
        for i = 1, group_val_i - 1 do
            val_i, acc[val_i] = val_i + 1, group_acc[i]
        end
        return capture.finish, val_i
    end
end


evaluators["C"] = function (capture, subject, acc, index, val_i)
    val_i, acc[val_i] = val_i + 1, s_sub(subject,capture.start, capture.finish - 1)
    local _
    _, val_i = insert(capture, subject, acc, capture.start, val_i)
    return capture.finish, val_i
end


evaluators["Cs"] = function (capture, subject, acc, index, val_i)
    local start, finish, n = capture.start, capture.finish, capture.n
    if n == 1 then
        acc[val_i] = s_sub(subject, start, finish - 1)
    else
        local subst_acc, cap_i, subst_i = {}, 1, 1
        repeat
            local cap, tmp_acc, tmp_i, _ = capture[cap_i], {}

            subst_acc[subst_i] = s_sub(subject, start, cap.start - 1)
            subst_i = subst_i + 1

            start, tmp_i = evaluators[cap.type](cap, subject, tmp_acc, index, 1)

            if tmp_i > 1 then
                subst_acc[subst_i] = tmp_acc[1]
                subst_i = subst_i + 1
            end

            cap_i = cap_i + 1
        until cap_i == n
        subst_acc[subst_i] = s_sub(subject, start, finish - 1)

        acc[val_i] = t_concat(subst_acc)
    end

    return capture.finish, val_i + 1
end


evaluators["Ct"] = function (capture, subject, acc, index, val_i)
    local tbl_acc, new_val_i, _ = {}, 1

    for i = 1, capture.n - 1 do
        local cap = capture[i]

        if cap.Ctag ~= nil then
            local tmp_acc = {}

            insert(cap, subject, tmp_acc, cap.start, 1)
            local val = (#tmp_acc == 0 and s_sub(subject, cap.start, cap.finish - 1) or tmp_acc[1])
            tbl_acc[cap.Ctag] = val
        else
            _, new_val_i = evaluators[cap.type](cap, subject, tbl_acc, cap.start, new_val_i)
        end
    end
    acc[val_i] = tbl_acc
    return capture.finish, val_i + 1
end


evaluators["value"] = function (capture, subject, acc, index, val_i)
    acc[val_i] = capture.value
    return capture.finish, val_i + 1
end


evaluators["values"] = function (capture, subject, acc, index, val_i)
local start, finish, values = capture.start, capture.finish, capture.values
    for i = 1, values.n do
        val_i, acc[val_i] = val_i + 1, values[i]
    end
    return finish, val_i
end


evaluators["/string"] = function (capture, subject, acc, index, val_i)
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
                local tmp_acc, _, vi = {}
                _, vi = evaluators[capture[d].type](capture[d], subject, tmp_acc, capture.start, 1)
                if vi == 1 then error("no values in capture at index"..d.."in /string capture.") end
                cached[d] = tmp_acc[1]
            end
        end
        return cached[d]
    end)
    return capture.finish, val_i + 1
end


evaluators["/number"] = function (capture, subject, acc, index, val_i)
    local new_acc, _, vi = {}
    _, vi = insert(capture, subject, new_acc, capture.start, 1)
    if capture.aux >= vi then error("no capture '"..capture.aux.."' in /number capture.") end
    acc[val_i] = new_acc[capture.aux]
    return capture.finish, val_i + 1
end


evaluators["/table"] = function (capture, subject, acc, index, val_i)
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
        return capture.finish, val_i + 1
    else
        return capture.start, val_i
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
evaluators["/function"] = function (capture, subject, acc, index, val_i)
    local func, params, new_val_i, _ = capture.aux
    if capture.n > 1 then
        params = {}
        _, new_val_i = insert(capture, subject, params, capture.start, 1)
    else
        new_val_i = 2
        params = {s_sub(subject, capture.start, capture.finish - 1)}
    end
    val_i = insert_divfunc_results(acc, val_i, func(t_unpack(params, 1, new_val_i - 1)))
    return capture.finish, val_i
end

end  -- Decorator wrapper


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg proto-library
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
