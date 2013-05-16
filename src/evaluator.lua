---------------------------------------   ,---            |   ----------------
---------------------------------------   |__  .   , ,--. |   ----------------
-- Capture evaluators -----------------   |     \ /  ,--| |   ----------------
---------------------------------------   `---   v   `--' `-  ----------------

return function(Builder, PL) -- Decorator wrapper

local pcall, setmetatable, tostring
    = pcall, setmetatable, tostring
local s_sub, t_concat = string.sub, table.concat

local u = require"util"
local strip_mt, t_unpack, traceback
    = u.strip_mt, u.unpack, u.traceback

local evaluators = {}

local
function evaluate (capture, subject, index)
    local acc, index = {}
    -- PL.cprint(capture)
    evaluators.insert(capture, subject, acc, index)
    return acc
end
PL.evaluate = evaluate

--- Some accumulator types for the evaluator
--
local fold_mt, group_mt, subst_mt, table_mt = {}, {}, {}, {}

local function new_fold_acc  (t) return setmetatable(t, fold_mt)  end
local function new_group_acc (t) return setmetatable(t, group_mt) end
local function new_subst_acc (t) return setmetatable(t, subst_mt) end
local function new_table_acc (t) return setmetatable(t, table_mt) end

local function is_fold_acc  (t) return getmetatable(t) == fold_mt  end
local function is_group_acc (t) return getmetatable(t) == group_mt end
local function is_subst_acc (t) return getmetatable(t) == subst_mt end
local function is_table_acc (t) return getmetatable(t) == table_mt end

local
function insert_all_caps (capture, subject, acc, index, inserter)
    for i = 1, capture.n do
        index = evaluators[capture[i].type](capture[i], subject, acc, index, insert_all_caps)
    end
    return index
end

evaluators["insert"] = function (capture, subject, acc, index)
    -- print("Insert", capture.start, capture.finish)
    for i = 1, capture.n - 1 do
        -- print("Eval Insert: ", capture[i].type, capture[i].start, capture[i])
            local c 
            c, index = 
                evaluators[capture[i].type](capture[i], subject, acc, index)
            acc[#acc+1] = c
    end
    return nil, index
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

evaluators["Cb"] = function (capture, subject, acc, index, inserter)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end
    local ref, Ctag = lookback(capture.parent, capture.tag, capture.parent_i)
    ref.Ctag, Ctag = nil, ref.Ctag
    evaluators.Cg(ref, subject, acc, ref.start, inserter)
    ref.Ctag = Ctag
    return nil, index
end


evaluators["Cf"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end

    local func, fold_acc = capture.aux, new_fold_acc{}

    evaluators.insert(capture, subject, fold_acc, index)
    
    local result = fold_acc[1]
    if is_group_acc(result) then result = t_unpack(result) end

    for i = 2, #fold_acc do
        local val = fold_acc[i]
        if is_group_acc(val) then
            success, result = pcall(func, result, t_unpack(val))
        else
            success, result = pcall(func, result, val)
        end
    end
    if not success then result = nil end
    return result, capture.finish
end


evaluators["Cg"] = function (capture, subject, acc, index)
    local start, finish = capture.start, capture.finish
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, start - 1)
    end


    local group_acc = new_group_acc{}

    if capture.Ctag ~= nil  then
        if is_table_acc(acc) then 
            local _, index = evaluators.insert(capture, subject, group_acc, start)
            local val = (#group_acc == 0 and s_sub(subject, start, finish - 1) or group_acc[1])
            acc[capture.Ctag] = val
        end
        return nil, finish
    end

    local _, index = evaluators.insert(capture, subject, group_acc, start)

    if #group_acc == 0 then
        acc[#acc + 1] = s_sub(subject, start, finish - 1)
        return nil, finish
    elseif is_subst_acc(acc) then
        return group_acc[1], finish
    elseif is_fold_acc(acc) then
        return group_acc, finish
    else
        if #group_acc == 0 then
            acc[#acc + 1] = s_sub(subject, capture.start, capture.finish - 1)
        else
            for _, v in ipairs(group_acc) do
                acc[#acc+1]=v
            end 
        end
        return nil, capture.finish
        -- error"What else? See: GROUP CAPTURE"
        -- return group_acc[1], capture.finish
        -- or?
        -- fold(group_acc, t_insert, acc)
        -- return nil, capture.finish
    end

end


evaluators["C"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
        return s_sub(subject,capture.start, capture.finish - 1), capture.finish
    end

    acc[#acc+1] = s_sub(subject,capture.start, capture.finish - 1)

    evaluators.insert(capture, subject, acc, capture.start)

    return nil, capture.finish
end


evaluators["Cs"] = function (capture, subject, acc, index)
    -- print("SUB", capture.start, capture.finish)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end

    local subst_acc = new_subst_acc{}

    local _, index = evaluators.insert(capture, subject, subst_acc, capture.start)
    subst_acc[#subst_acc + 1] = s_sub(subject, index, capture.finish - 1)
    acc[#acc + 1] = t_concat(subst_acc)

    return nil, capture.finish
end


evaluators["Ct"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end

    local tbl_acc = new_table_acc{}
    evaluators.insert(capture, subject, tbl_acc, capture.start)
    
    return strip_mt(tbl_acc), capture.finish
end


evaluators["value"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end

    return capture.value, capture.finish
end


evaluators["values"] = function (capture, subject, acc, index)
local start, finish, values = capture.start, capture.finish, capture.values
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, start - 1)
    end
    if is_fold_acc(acc) then return new_group_acc(values), finish end

    for i = 1, #values do
        acc[#acc+1] = values[i]
    end
    return nil, finish
end


evaluators["/string"] = function (capture, subject, acc, index)
    -- print("/string", capture.start, capture.finish)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end
    local new_acc = {}
    evaluators.insert(capture, subject, new_acc, capture.start)

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
    return result, capture.finish
end


evaluators["/number"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end
    local new_acc = {}
    evaluators.insert(capture, subject, new_acc, capture.start)
    return new_acc[capture.aux], capture.finish
end


evaluators["/table"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end
    local key
    if #capture > 0 then
        local new_acc = {}
        evaluators.insert(capture, subject, new_acc, capture.start)
        key = new_acc[1]
    else
        key = s_sub(subject, capture.start, capture.finish - 1)
    end
    if capture.aux[key]
    then return capture.aux[key], capture.finish 
    else return nil, capture.start
    end --or s_sub(subject, capture.start, capture.finish - 1)
end


local
function insert_results(acc, ...)
    for i = 1, select('#', ...) do
        acc[#acc + 1] = select(i, ...)
    end
end
evaluators["/function"] = function (capture, subject, acc, index)
    if is_subst_acc(acc) then
        acc[#acc+1] = s_sub(subject, index, capture.start - 1)
    end

    local func, params = capture.aux
    if #capture > 0 then
        params = {}
        evaluators.insert(capture, subject, params, capture.start)
    else
        params = {s_sub(subject, capture.start, capture.finish - 1)}
    end
    insert_results(acc, func(unpack(params)))
    return nil, capture.finish
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