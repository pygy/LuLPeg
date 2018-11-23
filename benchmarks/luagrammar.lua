-- Based on Patrick Donnelly LPeg recipe:
-- http://lua-users.org/wiki/LpegRecipes

local function Kollect()
  repeat
    local gic = collectgarbage"count"
    collectgarbage()
    local goc = collectgarbage"count"
  until gic == goc
end

local tic = os.clock()
local success, lpeg = pcall(require, arg[1])
local toc = (os.clock() - tic) * 100
local gic = collectgarbage("count")
Kollect()
local goc = collectgarbage("count")
print("loaded", toc, goc, gic - goc)

assert(success, "could not load"..tostring(arg[1]))

tic = os.clock()
lpeg.setmaxstack(10000)

local src = io.open(arg[2],"r"):read"*all"

local locale = lpeg.locale();

local P, S, V = lpeg.P, lpeg.S, lpeg.V;

local C, Cb, Cc, Cg, Cs, Cmt =
    lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cg, lpeg.Cs, lpeg.Cmt;

local lua

local defined = assert(pcall(function() --{ ------------------------------------------


local shebang = P "#" * (P(1) - P "\n")^0 * P "\n";

local function K (k) -- keyword
  return P(k) * -(locale.alnum + P "_");
end

lua = P {
  (shebang)^-1 * V "space" * V "chunk" * V "space" * -P(1);

  -- keywords

  keywords = K "and" + K "break" + K "do" + K "else" + K "elseif" +
             K "end" + K "false" + K "for" + K "function" + K "if" +
             K "in" + K "local" + K "nil" + K "not" + K "or" + K "repeat" +
             K "return" + K "then" + K "true" + K "until" + K "while";

  -- longstrings

  longstring = (P { -- from Roberto Ierusalimschy's lpeg examples
    V "open" * (P(1) - V "closeeq")^0 * V "close",

    open = "[" * Cg((P "=")^0, "init") * P "[" * (P "\n")^-1,
    close = "]" * C((P "=")^0) * "]",
    closeeq = Cmt(V "close" * Cb "init", function (s, i, a, b) return a == b end)
  })/0;

  -- comments & whitespace

  comment = P "--" * V "longstring" +
            P "--" * (P(1) - P "\n")^0 * (P "\n" + -P(1));

  space = (locale.space + V "comment")^0;

  -- Types and Comments

  Name = (locale.alpha + P "_") * (locale.alnum + P "_")^0 - V "keywords";
  Number = (P "-")^-1 * V "space" * P "0x" * locale.xdigit^1 *
               -(locale.alnum + P "_") +
           (P "-")^-1 * V "space" * locale.digit^1 *
               (P "." * locale.digit^1)^-1 * (S "eE" * (P "-")^-1 *
                   locale.digit^1)^-1 * -(locale.alnum + P "_") +
           (P "-")^-1 * V "space" * P "." * locale.digit^1 *
               (S "eE" * (P "-")^-1 * locale.digit^1)^-1 *
               -(locale.alnum + P "_");
  String = P "\"" * (P "\\" * P(1) + (1 - P "\""))^0 * P "\"" +
           P "'" * (P "\\" * P(1) + (1 - P "'"))^0 * P "'" +
           V "longstring";

  -- Lua Complete Syntax

  chunk = (V "space" * V "stat" * (V "space" * P ";")^-1)^0 *
              (V "space" * V "laststat" * (V "space" * P ";")^-1)^-1;

  block = V "chunk";

  stat = K "do" * V "space" * V "block" * V "space" * K "end" +
         K "while" * V "space" * V "exp" * V "space" * K "do" * V "space" *
             V "block" * V "space" * K "end" +
         K "repeat" * V "space" * V "block" * V "space" * K "until" *
             V "space" * V "exp" +
         K "if" * V "space" * V "exp" * V "space" * K "then" *
             V "space" * V "block" * V "space" *
             (K "elseif" * V "space" * V "exp" * V "space" * K "then" *
              V "space" * V "block" * V "space"
             )^0 *
             (K "else" * V "space" * V "block" * V "space")^-1 * K "end" +
         K "for" * V "space" * V "Name" * V "space" * P "=" * V "space" *
             V "exp" * V "space" * P "," * V "space" * V "exp" *
             (V "space" * P "," * V "space" * V "exp")^-1 * V "space" *
             K "do" * V "space" * V "block" * V "space" * K "end" +
         K "for" * V "space" * V "namelist" * V "space" * K "in" * V "space" *
             V "explist" * V "space" * K "do" * V "space" * V "block" *
             V "space" * K "end" +
         K "function" * V "space" * V "funcname" * V "space" *  V "funcbody" +
         K "local" * V "space" * K "function" * V "space" * V "Name" *
             V "space" * V "funcbody" +
         K "local" * V "space" * V "namelist" *
             (V "space" * P "=" * V "space" * V "explist")^-1 +
         V "varlist" * V "space" * P "=" * V "space" * V "explist" +
         V "functioncall";

  laststat = K "return" * (V "space" * V "explist")^-1 + K "break";

  funcname = V "Name" * (V "space" * P "." * V "space" * V "Name")^0 *
      (V "space" * P ":" * V "space" * V "Name")^-1;

  namelist = V "Name" * (V "space" * P "," * V "space" * V "Name")^0;

  varlist = V "var" * (V "space" * P "," * V "space" * V "var")^0;

  -- Let's come up with a syntax that does not use left recursion
  -- (only listing changes to Lua 5.1 extended BNF syntax)
  -- value ::= nil | false | true | Number | String | '...' | function |
  --           tableconstructor | functioncall | var | '(' exp ')'
  -- exp ::= unop exp | value [binop exp]
  -- prefix ::= '(' exp ')' | Name
  -- index ::= '[' exp ']' | '.' Name
  -- call ::= args | ':' Name args
  -- suffix ::= call | index
  -- var ::= prefix {suffix} index | Name
  -- functioncall ::= prefix {suffix} call

  -- Something that represents a value (or many values)
  value = K "nil" +
          K "false" +
          K "true" +
          V "Number" +
          V "String" +
          P "..." +
          V "function" +
          V "tableconstructor" +
          V "functioncall" +
          V "var" +
          P "(" * V "space" * V "exp" * V "space" * P ")";

  -- An expression operates on values to produce a new value or is a value
  exp = V "unop" * V "space" * V "exp" +
        V "value" * (V "space" * V "binop" * V "space" * V "exp")^-1;

  -- Index and Call
  index = P "[" * V "space" * V "exp" * V "space" * P "]" +
          P "." * V "space" * V "Name";
  call = V "args" +
         P ":" * V "space" * V "Name" * V "space" * V "args";

  -- A Prefix is a the leftmost side of a var(iable) or functioncall
  prefix = P "(" * V "space" * V "exp" * V "space" * P ")" +
           V "Name";
  -- A Suffix is a Call or Index
  suffix = V "call" +
           V "index";

  var = V "prefix" * (V "space" * V "suffix" * #(V "space" * V "suffix"))^0 *
            V "space" * V "index" +
        V "Name";
  functioncall = V "prefix" *
                     (V "space" * V "suffix" * #(V "space" * V "suffix"))^0 *
                 V "space" * V "call";

  explist = V "exp" * (V "space" * P "," * V "space" * V "exp")^0;

  args = P "(" * V "space" * (V "explist" * V "space")^-1 * P ")" +
         V "tableconstructor" +
         V "String";

  ["function"] = K "function" * V "space" * V "funcbody";

  funcbody = P "(" * V "space" * (V "parlist" * V "space")^-1 * P ")" *
                 V "space" *  V "block" * V "space" * K "end";

  parlist = V "namelist" * (V "space" * P "," * V "space" * P "...")^-1 +
            P "...";

  tableconstructor = P "{" * V "space" * (V "fieldlist" * V "space")^-1 * P "}";

  fieldlist = V "field" * (V "space" * V "fieldsep" * V "space" * V "field")^0
                  * (V "space" * V "fieldsep")^-1;

  field = P "[" * V "space" * V "exp" * V "space" * P "]" * V "space" * P "=" *
              V "space" * V "exp" +
          V "Name" * V "space" * P "=" * V "space" * V "exp" +
          V "exp";

  fieldsep = P "," +
             P ";";

  binop = K "and" + -- match longest token sequences first
          K "or" +
          P ".." +
          P "<=" +
          P ">=" +
          P "==" +
          P "~=" +
          P "+" +
          P "-" +
          P "*" +
          P "/" +
          P "^" +
          P "%" +
          P "<" +
          P ">";

  unop = P "-" +
         P "#" +
         K "not";
};
end)) -- }---------------------------------------------------------------------
toc = os.clock() - tic
gic = collectgarbage("count")
Kollect()
goc = collectgarbage("count")
print("\nDefined", toc, goc, gic - goc)

tic = os.clock()
lua:match""

toc = os.clock() - tic
gic = collectgarbage("count")
Kollect()
goc = collectgarbage("count")
print("\nCompile", toc, goc, gic - goc)


print""

src = "\nfunction foo()\n"..src.."\nend\n"
Kollect()

local END
assert(pcall(function()
  for i = 1, 32 do
    tic = os.clock()
    END = lua:match(src)
    local toc = os.clock()-tic
    local gic = collectgarbage("count")
    Kollect()
    goc = collectgarbage("count")
    print("Matched", toc, i, goc ,"", gic - goc)
    src = src .. src
    Kollect()
  end
end))

assert(END == #src/2+1, "premature end of parse. END:"..END.." len:"..#src)
print("Success", END)