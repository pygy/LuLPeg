local l = require(arg[1])
pcall(function()lpeg:register() end)

local p = arg[0]
p = p:sub(1, (p:find"[^/]*%.lua") - 1)

package.path = p.."?.lua;"..package.path

local json = require"dkjson"

local subject = io.open(arg[2],"r"):read"*all"
-- print(subject)
print"Subject loaded"
tic = os.clock()
for _ = 1, 1 do
    json.decode(subject)
end

print("Json", os.clock()-tic)