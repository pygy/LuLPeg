### Frontend:

Finish de factorizer/analyzer.

### Compatibility:

- Implement TCO.

- Check for grammar errors:
-- bad references in grammars
-- references used outside grammars
-- infinite loops (true^0, left-recursive rules)

- ? Be more strict with capture garbage during match time ?

### Captures:

Try to use several buffers insetad of one for captures (less allocations).

- one array with the capture bounds (similar to the LPeg one). 
- one array of booleans indicating whether the given bound opens or closes a capture, or the end bound for a "full" capture.
- one array for the types. (corresponding to both opening an closing tokens).
- one array for metadata, when present.

on pattern failure, only clear the metadata array, and reset the index.

Try a cdata-based approach for LuaJIT? It may be the basis of a generic capture backend.

### Compiler

- Drop the one function per pattern approach for one big function per non-grammar pattern/gammar rule.
- use false loops and break to simulate goto (and goto in 5.2?).
- Add a more backends? Terra? Lua bytecode?

### Unicode:

Restore the unicode functionality, via P8(), S8() and R8() constructors.

- fix datastructures.lua
- test and benchmark the various UTF-8 encoding/decoding strategies, including using the bit libraries when available.