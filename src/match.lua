---------------------------------------  .   ,      ,       ,     ------------
---------------------------------------  |\ /| ,--. |-- ,-- |__   ------------
-- Match ------------------------------  | v | ,--| |   |   |  |  ------------
---------------------------------------  '   ' `--' `-- `-- '  '  ------------

local assert, error, select, type = assert, error, select, type

local u =require"util"



local _ENV = u.noglobals() ---------------------------------------------------



local t_unpack = u.unpack


return function(Builder, LL) -------------------------------------------------

--[[DBG]] local LL_cprint, LL_pprint = LL.cprint, LL.pprint

local LL_compile, LL_evaluate, LL_P
    = LL.compile, LL.evaluate, LL.P

local function computeidex(i, len)
    if i == 0 or i == 1 or i == nil then return 1
    elseif type(i) ~= "number" then error"number or nil expected for the stating index"
    elseif i > 0 then return i > len and len + 1 or i
    else return len + i < 0 and 1 or len + i + 1
    end
end


function LL.match(pt, subject, index, ...)
    pt = LL_P(pt)
    assert(type(subject) == "string", "string expected for the match subject")
    index = computeidex(index, #subject)
    local matcher, cap_acc, state, success, cap_i, nindex
        = LL_compile(pt, {})
        , {type = "insert"}   -- capture accumulator
        , {grammars = {}, args = {n = select('#',...),...}, tags = {}}
        , 0 -- matcher state
    success, nindex, cap_i = matcher(subject, index, cap_acc, 1, state)
    if success then
        cap_acc.n = cap_i
        local cap_values, cap_i = LL_evaluate(cap_acc, subject, index)
        if cap_i == 1
        then return nindex
        else return t_unpack(cap_values, 1, cap_i - 1) end
    else
        return nil
    end
end

-- With some debug info.
function LL.dmatch(pt, subject, index, ...)
    --[[DBG]] print("@!!! Match !!!@")
    pt = LL_P(pt)
    assert(type(subject) == "string", "string expected for the match subject")
    index = computeidex(index, #subject)
    --[[DBG]] print(("-"):rep(30))
    --[[DBG]] print(pt.ptype)
    --[[DBG]] LL.pprint(pt)
    local matcher, cap_acc, state, success, cap_i, nindex
        = LL_compile(pt, {})
        , {type = "insert"}   -- capture accumulator
        , {grammars = {}, args = {n = select('#',...),...}, tags = {}}
        , 0 -- matcher state
    success, nindex, cap_i = matcher(subject, index, cap_acc, 1, state)
    --[[DBG]] print("!!! Done Matching !!!")
    if success then
        cap_acc.n = cap_i
        --[[DBG]] print("cap_i = ",cap_i)
        --[[DBG]] print("= $$$ captures $$$ =", cap_acc)
        --[[DBG]] LL.cprint(cap_acc)
        local cap_values, cap_i = LL_evaluate(cap_acc, subject, index)
        if cap_i == 1
        then return nindex
        else return t_unpack(cap_values, 1, cap_i - 1) end
    else
        return nil
    end
end

end -- /wrapper --------------------------------------------------------------

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
