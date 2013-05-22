---------------------------------------  .   ,      ,       ,     ------------
---------------------------------------  |\ /| ,--. |-- ,-- |__   ------------
-- Match ------------------------------  | v | ,--| |   |   |  |  ------------
---------------------------------------  '   ' `--' `-- `-- '  '  ------------
return function(Builder, PL)

local PL_compile, PL_cprint, PL_evaluate, PL_P, PL_pprint
    = PL.compile, PL.Cprint, PL.evaluate, PL.P, PL.pprint

local t_unpack = require"util".unpack

function PL.match(pt, subject, index, ...)
    -- [[DP]] print("@!!! Match !!!@")
    pt = PL_P(pt)
    if index == nil then
        index = 1
    elseif type(index) ~= "number" then
        error"The index must be a number"
    elseif index == 0 then
        -- return nil -- This allows to pass the test, but not suer if correct.
        error("Dunno what to do with a 0 index")
    elseif index < 0 then
        index = #subject + index + 1
        if index < 1 then index = 1 end
    end
    -- print(("-"):rep(30))
    -- print(pt.ptype)
    -- PL.pprint(pt)
    local matcher, cap_acc, state, success, cap_i, nindex
        = PL_compile(pt, {})
        , {type = "insert"}   -- capture accumulator
        , {grammars = {}, args = {n = select('#',...),...}, tags = {}}
        , 0 -- matcher state
    success, nindex, cap_i = matcher(subject, index, cap_acc, 1, state)
    -- [[DP]] print("!!! Done Matching !!!")
    if success then
        cap_acc.n = cap_i
        -- print("cap_i = ",cap_i)
        -- print("= $$$ captures $$$ =")
        -- PL.cprint(cap_acc)
        local captures = PL_evaluate(cap_acc, subject, index)
        if #captures == 0 
        then return nindex
        else return t_unpack(captures) end
    else 
        return nil 
    end
end

end