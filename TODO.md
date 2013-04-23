Adapt the capture generation/evaluation process to correctly handle 
* nil
* Cb

Git branch, and try to use several buffers insetad of one for captures (less allocations for most of them).

Drop the recursive descent approach for one big function per gammar rule/non-grammar pattern.

Attempt a CPS version?

Implement cut semantics.

Simplify the leaf patterns for the binary version (mimic the LPeg charsets).