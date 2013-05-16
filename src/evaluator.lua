---------------------------------------   ,---            |   ----------------
---------------------------------------   |__  .   , ,--. |   ----------------
-- Capture evaluators -----------------   |     \ /  ,--| |   ----------------
---------------------------------------   `---   v   `--' `-  ----------------

return function(Builder, PL) -- Decorator wrapper

local pcall, setmetatable, tostring
    = pcall, setmetatable, tostring
local s_sub, t_concat = string.sub, table.concat

local u = require"util"
local expose, strip_mt, t_unpack
    = u.expose, u.strip_mt, u.unpack

local evaluators = {}

local
function evaluate (capture, subject, index)
    local acc, val_i, _ = {}
    -- PL.cprint(capture)
    _, _, val_i = evaluators.insert(capture, subject, acc, index, 1)
    return acc, val_i
end
PL.evaluate = evaluate

--- Some accumulator types for the evaluator
--
local fold_mt, group_mt, subst_mt, table_mt = {}, {}, {}, {}

local function new_group_acc (t) return setmetatable(t, group_mt) end
local function new_table_acc (t) return setmetatable(t, table_mt) end

local function is_table_acc (t) return getmetatable(t) == table_mt end


evaluators["insert"] = function (capture, subject, acc, index, val_i)
    -- print("Insert", capture.start, capture.finish)
    for i = 1, capture.n - 1 do
        -- print("Eval Insert: ", capture[i].type, capture[i].start, capture[i])
            local c 
            c, index, val_i = 
                evaluators[capture[i].type](capture[i], subject, acc, index, val_i)
    end
    return nil, index, val_i
end

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
    local ref, Ctag = lookback(capture.parent, capture.tag, capture.parent_i)
    ref.Ctag, Ctag = nil, ref.Ctag
    _, _, val_i = evaluators.Cg(ref, subject, acc, ref.start, val_i)
    ref.Ctag = Ctag
    return nil, index, val_i
end


evaluators["Cf"] = function (capture, subject, acc, index, val_i)
    if capture.n == 0 then 
        error"No First Value"
    end
    
    local func, fold_acc, first_val_i, _ = capture.aux, {}
    _, index, first_val_i = evaluators[capture[1].type](capture[1], subject, fold_acc, index, 1)

    if first_val_i == 1 then 
        error"No first value"
    end
    
    local result = fold_acc[1]

    for i = 2, capture.n - 1 do
        local fold_acc2, vi = {}
        _, index, vi = evaluators[capture[i].type](capture[i], subject, fold_acc2, index, 1)
        result = func(result, t_unpack(fold_acc2, 1, vi - 1))
    end
    acc[val_i] = result
    return nil, capture.finish, val_i + 1
end


evaluators["Cg"] = function (capture, subject, acc, index, val_i)
    local start, finish = capture.start, capture.finish
    local group_acc = new_group_acc{}

    if capture.Ctag ~= nil  then
        if is_table_acc(acc) then 
            local _, index, val_i = evaluators.insert(capture, subject, group_acc, start, 1)
            local val = (#group_acc == 0 and s_sub(subject, start, finish - 1) or group_acc[1])
            acc[capture.Ctag] = val
        end
        return nil, start, val_i
    end

    local _, index, group_val_i = evaluators.insert(capture, subject, group_acc, start, 1)
    if group_val_i == 1 then
        acc[val_i] = s_sub(subject, start, finish - 1)
        return nil, finish, val_i + 1
    else
        for i = 1, group_val_i - 1 do
            val_i, acc[val_i] = val_i + 1, group_acc[i]
        end 
        return nil, capture.finish, val_i
    end
end


evaluators["C"] = function (capture, subject, acc, index, val_i)
    val_i, acc[val_i] = val_i + 1, s_sub(subject,capture.start, capture.finish - 1)
    local _
    _, _, val_i = evaluators.insert(capture, subject, acc, capture.start, val_i)
    return nil, capture.finish, val_i
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

            _, start, tmp_i = evaluators[cap.type](cap, subject, tmp_acc, index, 1)

            if tmp_i > 1 then 
                subst_acc[subst_i] = tmp_acc[1]
                subst_i = subst_i + 1
            end

            cap_i = cap_i + 1
        until cap_i == n
        subst_acc[subst_i] = s_sub(subject, start, finish - 1)

        acc[val_i] = t_concat(subst_acc)
    end

    return nil, capture.finish, val_i + 1
end


evaluators["Ct"] = function (capture, subject, acc, index, val_i)
    local tbl_acc = new_table_acc{}
    evaluators.insert(capture, subject, tbl_acc, capture.start, 1)
    acc[val_i] = strip_mt(tbl_acc)
    return nil, capture.finish, val_i + 1
end


evaluators["value"] = function (capture, subject, acc, index, val_i)
    acc[val_i] = capture.value
    return nil, capture.finish, val_i + 1
end


evaluators["values"] = function (capture, subject, acc, index, val_i)
local start, finish, values = capture.start, capture.finish, capture.values
    for i = 1, values.n do
        val_i, acc[val_i] = val_i + 1, values[i]
    end
    return nil, finish, val_i
end


evaluators["/string"] = function (capture, subject, acc, index, val_i)
    -- print("/string", capture.start, capture.finish)
    local new_acc = {}
    local _, _, new_val_i = evaluators.insert(capture, subject, new_acc, capture.start, 1)

    local allmatch
    local result = capture.aux:gsub("%%([%d%%])", function(n)
        if n == "%" then return "%" end
        n = tonumber(n)
        if n == 0 then
            allmatch = allmatch or s_sub(subject, capture.start, capture.finish - 1)
            return allmatch
        else
            if n > #new_acc then error("No capture at index "..n.." in /string capture.") end
            return new_acc[n]
        end
    end)
    acc[val_i] = result
    return nil, capture.finish, val_i + 1
end


evaluators["/number"] = function (capture, subject, acc, index, val_i)
    local new_acc = {}
    evaluators.insert(capture, subject, new_acc, capture.start, 1)
    acc[val_i] = new_acc[capture.aux]
    return nil, capture.finish, val_i + 1
end


evaluators["/table"] = function (capture, subject, acc, index, val_i)
    local key
    if capture.n > 1 then
        local new_acc = {}
        evaluators.insert(capture, subject, new_acc, capture.start, 1)
        key = new_acc[1]
    else
        key = s_sub(subject, capture.start, capture.finish - 1)
    end

    if capture.aux[key] then 
        acc[val_i] = capture.aux[key]
        return nil, capture.finish, val_i + 1
    else 
        return nil, capture.start, val_i
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
    local func, params, new_val_i = capture.aux
    if capture.n > 1 then
        params = {}
        _, _, new_val_i = evaluators.insert(capture, subject, params, capture.start, 1)
    else
        new_val_i = 2
        params = {s_sub(subject, capture.start, capture.finish - 1)}
    end
    val_i = insert_divfunc_results(acc, val_i, func(t_unpack(params, 1, new_val_i - 1)))
    return nil, capture.finish, val_i
end

end  -- Decorator wrapper


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