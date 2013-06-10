# LuLPeg

A pure Lua port of LPeg, Roberto Ierusalimschy's Parsing Expression Grammars library.

See http://www.inf.puc-rio.br/~roberto/lpeg/ for the original and its documentation.

It is inended as a drop-in replacement for LPeg, either as a fallback for LPeg libraries

## Usage:

The standalone `lulpeg.lua` found in the main directory is a drop-in replacement for LPeg.

```Lua
local lulpeg = require"lulpeg"
local re = lulpeg.re

-- from here use LuLPeg as you would use LPeg.
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

Bar bugs, all grammars accedpted by LPeg should work with LuLPeg, with the followong caveats:

- The LuLPeg stack is the Lua call stack. `lpeg.setmaxstack(n)` is a dummy function, present for compatibility. LuLPeg patterns are compiled to Lua functions. For example, `C(P"A" + P"B"):match"A"` pushes at most three functions on the call stack: one for the `C` capture, one for the `+` choice, and one for the `P"A"`. If P"A" had failed, it would have been popped and 

- LuLPeg doesn't do any tail call elimination at the moment. Grammars that implement finite automatons with long loops, that run fine with LPeg may trigger stack overflows. This point is high on my TODO list.

- During match time, LuLPeg may keep some garbage longer than needed, and certainly longer than what LPeg does, including the values produced by match-time captures (`Cmt()`). Not all garbage is kept around, though, and all of it is released after `match()` returns.

### `re.lua`

`re.lua` can be accessed as follows:

```Lua
lulpeg = require"lulpeg"
re = lulpeg.re
```

if you call `lulpeg:register()`, you can also `require"re"` as you would with LPeg.

### No auto-globals in Lua 5.1

In Lua 5.1, `require"lpeg"` and `require"re"` create globals, as per the `module()` pattern. You can emulate that behaviour by passing the global table to `lulpeg:register()`, or, obviously, by creating the globals yourself :).

### For Lua 5.1 sandboxes without proxies:

If you want to use LuLPeg in a Lua 5.1 sandbox that doesn't provide `newproxy()` and/or `debug.setmetatable()`, the `#pattern` syntax will not work for lookahead patterns. We provide the `L()` function as a fallback. Replace `#pattern` with `L(pattern)` in your grammar and it will work as expected.

### Global mode for expolration:

`LuLPeg:global(_G or _ENV)` sets LuLPeg as the __index of the the current environment, sparring you from aliasing each LPeg command manually. This is useful if you want to explore LPeg at the command line, for example.

### UTF-8

The preliminary version of this library supported UTF-8 out of the box, but bitrot crept in that part of the code. I can look into it on request, though.

## Performance:

LuLPeg with Lua 5.1 and 5.2 is ~100 times slower that the original. 

With LuaJIT in JIT mode, it is from ~2 to ~10 times slower. The exact performance is unpredictable. Tiny changes in code, not necessarily related to the grammar, or a different subject string, can have a 5x impact. LuaJIT uses speculative heuristics to chose what to compile. These are influenced by the memory layout, among other things. LPeg grammars are branchy, by nature, and this kind of code doesn't lend itself very well to JIT compilation.

LuaJIT in with the JIT compiler turned off is ~50 times slower than LPeg.

## License:

Copyright (C) Pierre-Yves Gerardy.
Released under the Romantif WTF Public License.

The re.lua module and the test suite (tests/lpeg.*.*.tests.lua) are part of the original LPeg distribution, released under the MIT license>

See the LICENSE file for the details.