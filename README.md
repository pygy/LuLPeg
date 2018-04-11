# LuLPeg

`/ˈluːɛlpɛɡ/` https://github.com/pygy/LuLPeg/

A pure Lua port of LPeg, Roberto Ierusalimschy's Parsing Expression Grammars library.

This version of LuLPeg emulates LPeg v0.12.

See http://www.inf.puc-rio.br/~roberto/lpeg/ for the original and its documentation.

Feedback most welcome.

## Usage:

`lulpeg.lua` is a drop-in replacement for _LPeg_ and _re_.

```Lua
local lulpeg = require"lulpeg"
local re = lulpeg.re

-- from here use LuLPeg as you would use LPeg.

pattern = lulpeg.C(lulpeg.P"A" + "B") ^ 0
print(pattern:match"ABA") --> "A" "B" "A"
```

If you plan to fall back on LuLPeg when LPeg is not present, putting the following at the top level of your program will make the substitution transparent:

```Lua
local success, lpeg = pcall(require, "lpeg")
lpeg = success and lpeg or require"lulpeg":register(not _ENV and _G)
```

`:register(tbl)` sets `package.loaded.lpeg` and `package.loaded.re` to their LuLPeg couterparts. If a table is provided, it will also populate it with the `lpeg` and `re` fields.

## Compatibility:

Lua 5.1, 5.2 and LuaJIT are supported.

## Main differences with LPeg:

This section assumes that you are familiar with LPeg and its official documentation.

LuLPeg passes most of the LPeg test suite: 6093 assertions succeed, 70 fail. 

None of the failures are caused by semantic differences. They are related to grammar and pattern error checking, stack handling, and garbage collection of Cmt capture values.

LuLPeg does not check for infinite loops in patterns, reference errors in grammars and stray references outside of grammars. It should not be used for grammar developement at the moment if you want that kind of feedback, just for substitution, once you got the grammar right.

Bar bugs, all grammars accedpted by LPeg should work with LuLPeg, with the following caveats:

- The LuLPeg stack is the Lua call stack. `lpeg.setmaxstack(n)` is a dummy function, present for compatibility. LuLPeg patterns are compiled to Lua functions, using a parser combinators approach. For example, `C(P"A" + P"B"):match"A"` pushes at most three functions on the call stack: one for the `C` capture, one for the `+` choice, and one for the `P"A"`. If `P"A"` had failed, it would have been popped and `P"B"` would be pushed.

- LuLPeg doesn't do any tail call elimination at the moment. Grammars that implement finite automatons with long loops, that run fine with LPeg, may trigger stack overflows. This point is high on my TODO list.

The next example works fine in LPeg, but blows up in LuLPeg.

```Lua
-- create a grammar for a simple DFA for even number of 0s and 1s
--
--  ->1 <---0---> 2
--    ^           ^
--    |           |
--    1           1
--    |           |
--    V           V
--    3 <---0---> 4
--
-- this grammar should keep no backtracking information

p = m.P{
  [1] = '0' * m.V(2) + '1' * m.V(3) + -1,
  [2] = '0' * m.V(1) + '1' * m.V(4),
  [3] = '0' * m.V(4) + '1' * m.V(1),
  [4] = '0' * m.V(3) + '1' * m.V(2),
}

assert(p:match(string.rep("00", 10000)))
assert(p:match(string.rep("01", 10000)))
assert(p:match(string.rep("011", 10000)))
assert(not p:match(string.rep("011", 10000) .. "1"))
assert(not p:match(string.rep("011", 10001)))
```

- During match time, LuLPeg may keep some garbage longer than needed, and certainly longer than what LPeg does, including the values produced by match-time captures (`Cmt()`). Not all garbage is kept around, though, and all of it is released after `match()` returns. In all cases, `pattern / 0` and `Cmt(pattern, function() return true end)` discard all captures made by `pattern`.

### Locales

LuLPeg only supports the basic C locale, defined as follows (in LPeg terms):

```Lua
locale["cntrl"] = R"\0\31" + "\127"
locale["digit"] = R"09"
locale["lower"] = R"az"
locale["print"] = R" ~" -- 0x20 to 0xee
locale["space"] = S" \f\n\r\t\v" -- \f == form feed (for a printer), \v == vtab
locale["upper"] = R"AZ"

locale["alpha"]  = locale["lower"] + locale["upper"]
locale["alnum"]  = locale["alpha"] + locale["digit"]
locale["graph"]  = locale["print"] - locale["space"]
locale["punct"]  = locale["graph"] - locale["alnum"]
locale["xdigit"] = locale["digit"] + R"af" + R"AF"
```

### Pattern identity and factorization:

The following is true with LuLPeg, but not with LPeg:

```Lua
assert( P"A" == P"A" )

assert( P"A"*"B" == P"AB" )

assert( C(P"A") == C(P"A") )

assert( C(P"A") + C(P"B") == C(P"A" + "B") )
```

### `re.lua`:

`re.lua` can be accessed as follows:

```Lua
lulpeg = require"lulpeg"
re = lulpeg.re
```

if you call `lulpeg:register()`, you can also `require"re"` as you would with LPeg.

### No auto-globals in Lua 5.1:

In Lua 5.1, LPeg creates globals when `require"lpeg"` and `require"re"` are called, as per the `module()` pattern. You can emulate that behaviour by passing the global table to `lulpeg:register()`, or, obviously, by creating the globals yourself :).

### For Lua 5.1 sandboxes without proxies:

If you want to use LuLPeg in a Lua 5.1 sandbox that doesn't provide `newproxy()` and/or `debug.setmetatable()`, the `#pattern` syntax will not work for lookahead patterns. We provide the `L()` function as a fallback. Replace `#pattern` with `L(pattern)` in your grammar and it will work as expected.

### "Global" mode for exploration:

`LuLPeg:global(_G or _ENV)` sets LuLPeg as the __index of the the current environment, sparring you from aliasing each LPeg command manually. This is useful if you want to explore LPeg at the command line, for example.

```Lua
require"lulpeg":global(_G or _ENV)

pattern = Ct(C(P"A" + "B") ^ 0)
pattern:match"BABAB" --> {"B", "A", "B", "A", "B"} 

```

### UTF-8

The preliminary version of this library supported UTF-8 out of the box, but bitrot crept in that part of the code. I can look into it on request, though.

## Performance:

LuLPeg with Lua 5.1 and 5.2 is ~100 times slower than the original. 

With LuaJIT in JIT mode, it is from ~2 to ~10 times slower. The exact performance is unpredictable. Tiny changes in code, not necessarily related to the grammar, or a different subject string, can have a 5x impact. LPeg grammars are branchy, by nature, and this kind of code doesn't lend itself very well to tracing JIT compilation. Furthermore, LuaJIT uses probabilistic/speculative heuristics to chose what to compile. These are influenced by the memory layout, among other things, hence the unpredictability.

LuaJIT in with the JIT compiler turned off is ~50 times slower than LPeg.

## License:

Copyright (C) Pierre-Yves Gerardy.
Released under the Romantic WTF Public License.

The re.lua module and the test suite (tests/lpeg.*.*.tests.lua) are part of the original LPeg distribution, released under the MIT license.

See the LICENSE file for the details.
