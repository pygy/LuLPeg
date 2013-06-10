
### Captures:

Try to use several buffers insetad of one for captures (less allocations).

- one array with the capture bounds (similar to the LPeg one). 
- one array of booleans indicating whether the given bound opens or closes a capture.
- one array for the types. (corresponding to both opening an closing tokens).
- one array for metadata, when present.

Try a cdata-based approach for LuaJIT.

### Compiler

- Drop the one function per pattern approach for one big function per non-grammar pattern/gammar rule.
- Add a Terra backend?

### Compatibility:

- Check for grammar errors:
-- bad references in grammars
-- references used outside grammars
-- infinite loops (true^0, left-recursive rules)

- Implement TCO.

- ? Be more strict with capture garbage during match time ?

### Cleanup:

- remove unused parameters/return values in the API+constructors and evaluator code.
- move some special cases from API.lua to compiler.lua (and refactor some of them, like repetitions).

### Speed:

- merge char sequences to strings? Probably pointless with the one function per rule compiler strategy.

### Unicode:

Restore the unicode functionality.

- fix datastructures.lua
- test and benchmark the various UTF-8 encoding/decoding strategies, including using the bit libraries when available.