require"purelpeg":CLI(_G or _ENV)

print"cache"

assert(P"a" == P"a")
assert(S"ab" == S"ab")
assert(R("ac","em") == R("ac","em"))
assert(P"a"^0 == P"a"^0)

print"booleans"

assert(P(true) + true + true == P(true))
assert(P(false) + false + false == P(false))
assert(P"" == P(true))
assert(S"" == P(false))
assert(R() == P(false))


print"unm"
assert(P(true) == -P(false))
assert(-P(true) == P(false))
assert(- -P"a" == #P"a")
assert(-#P"a" == -P"a")

print"strings"

assert(P"a" * P"b" == P"ab")
assert(P"" * "a" == P"a")
assert(P"a" * "" == P"a")



print"captures"
local e = _G or _ENV

for _, v in ipairs{"C", "Cg", "C"} do end