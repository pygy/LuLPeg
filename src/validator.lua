local u = require"util"
local nop, weakkey = u.nop, u.weakkey

local hasVcache, hasCmtcache , lengthcache
    = weakkey{}, weakkey{},    weakkey{}

return {
    hasV = nop,
    hasCmt = nop,
    length = nop
}