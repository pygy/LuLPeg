-- Demonstration of a bug in lulpeg.lua
-- Replace the next line by lpeg=require"lpeg" and there is no bug

-- Thanks to Dirk Laurie for the report and the test case.

local s_byte, s_sub, t_insert = string.byte, string.sub, table.insert

local
function utf8_offset (byte)
    if byte < 128 then return 0, byte
    elseif byte < 192 then
        error("Byte values between 0x80 to 0xBF cannot start a multibyte sequence")
    elseif byte < 224 then return 1, byte - 192
    elseif byte < 240 then return 2, byte - 224
    elseif byte < 248 then return 3, byte - 240
    elseif byte < 252 then return 4, byte - 248
    elseif byte < 254 then return 5, byte - 252
    else
        error("Byte values between 0xFE and OxFF cannot start a multibyte sequence")
    end
end

local
function utf8_next_char (subject, i)
    i = i and i+1 or 1
    if i > #subject then return end
    local offset = utf8_offset(s_byte(subject,i))
    return i + offset, i, s_sub(subject, i, i + offset)
end


-- Takes a string, returns an array of characters.
local
function utf8_split_char (subject)
    local chars = {}
    for _, _, c in utf8_next_char, subject do
        t_insert(chars,c)
    end
    return chars
end

local
function utflen(s) return #utf8_split_char(s) end

local lpeg=require(arg[1])
local C,     P,     R,     S,     V,     Cmt,     Cp = 
 lpeg.C,lpeg.P,lpeg.R,lpeg.S,lpeg.V,lpeg.Cmt,lpeg.Cp

-------- APL compiler

local load_apl
local apl_meta = {__call = function(apl,code) return load_apl(code) end }
local apl=setmetatable({},apl_meta)

local Monadic_functions, Monadic_operators, Dyadic_functions, 
   Dyadic_operators = {['∇']='Define'},{},{['|']='Mod'},{}
local _V = setmetatable({},{__index=_ENV})
local APL_ENV = {_V=_V}

local lookup = function(tbl) 
--- Cmt function that succeeds when key is in tbl, returning
-- the value, and fails otherwise. `subj` is provided by `Cmt`
-- but is not needed.
   return function(subj,pos,key)
      local v = tbl[key]
      if v then return pos,v end
   end
end

local numbers = function(str)
   str=str:gsub("¯","-")
   local v,n = str:gsub("%s+",',')
   if n==0 then return str else return '{'..v..'}' end
end

local _s = S" \t\n"                 -- one character of whitespace
local dec = R"09"^1                    -- positive decimal integer
local sign = P"¯"^-1                        -- optional high minus
local fixed = dec*P"."*dec^-1 + (dec^-1*P".")^-1*dec  -- %f number
local number = sign*fixed*(S"eE"*sign*dec)^-1         -- %e number 
local Vector = _s^0*number*(_s^1*number)^0

local first = R"az"+R"AZ"+"_"
local later = first+R"09"
local utc = R"\128\191"              -- UTF-8 continuation byte
local utf2 = R"\192\223"*utc         -- 2-byte codepoint
local utf3 = R"\224\240"*utc*utc     -- 3-byte codepoint
local utf = utf2 + utf3 - P"←"-P"¯"
local neutral = R"\033\126"-later-S"()[;]"  
local name = first*later^0 + utf + neutral

local Monadic_function = _s^0*Cmt(name,lookup(Monadic_functions))*_s^0
local Monadic_operator = _s^0*Cmt(name,lookup(Monadic_operators))*_s^0
local Dyadic_function = _s^0*Cmt(name,lookup(Dyadic_functions))*_s^0
local Dyadic_operator = _s^0*Cmt(name,lookup(Dyadic_operators))*_s^0
local operator = Monadic_operator + Dyadic_operator
local funcname = Monadic_function + Dyadic_function
local Param = _s^0*(P'⍺'/'_a' + P'⍵'/'_w')*_s^0 -- not to be looked up in _V
local Var = _s^0*C(first*later^0+utf-funcname-operator)*_s^0 - Param
local String = _s^0*"'"*(1-P"'")^0*"'"*_s^0 -- non-empty

local expr,   leftarg,   value,   index,   indices,   func_expr
   =V"expr",V"leftarg",V"value",V"index",V"indices",V"func_expr"
local monadic_func,    dyadic_func,    amphiadic_func 
  = V"monadic_func", V"dyadic_func", V"amphiadic_func"

local apl_expr = P{ "statement";
   statement = (_s^0*P'←'*expr)/"return %1" 
     + Param/1*'←'*expr/"%1=%2" 
     + Param/1*"["*indices*"]"*'←'*expr/"%1[%2]=%3"
     + expr;
   expr = '∇'*func_expr
     + Var*'←'*expr/"Assign(%2,'%1')" 
     + Var*"["*indices*"]"*'←'*expr/"Assign(%3,'%1',%2)" 
     + leftarg*dyadic_func*expr/"%2(%3,%1)" 
     + monadic_func*expr/"%1(%2)" 
     + leftarg;
   dyadic_func = amphiadic_func + Dyadic_function;
   monadic_func = amphiadic_func + Monadic_function;
   func_expr = '('*(dyadic_func+Monadic_function)*')'/1 
     + Dyadic_function + Monadic_function;
   amphiadic_func = func_expr*Monadic_operator/"%2(%1)"
      + func_expr*Dyadic_operator*func_expr/"%2(%1,%3)";
   leftarg = value + '('*expr*')'/1;
   value = Vector/numbers + String/1 +
      (Var*'['*indices*']'/"%1[%2]" + Var)/"_V.%1" + 
      (Param*'['*indices*']'/"%1[%2]" + Param)/1;
   index = expr+_s^0/"nil";
   indices = index*';'*index/"{%1;%2}" + expr;
   }

local apl2lua
apl2lua = function(apl)
   local i,j = apl:find"⋄"
   if j then 
      return apl2lua(apl:sub(1,i-1))..'; '..apl2lua(apl:sub(j+1)) 
   end
   local lua,pos = (apl_expr*_s^0*Cp()):dmatch(apl)
   pos = pos or 0
   if pos>#apl then return lua 
   else 
      print("Lua", lua)
      error("APL syntax error\n"..apl.."\n"..
      (" "):rep(utflen(apl:sub(1,pos))-1)..'↑')
   end
end

local classname={[1]="monadic function", [2]="dyadic function",
   [5]="monadic operator", [6]="dyadic operator"}
local classes={[1]=Monadic_functions, [2]=Dyadic_functions, [3]='either',
   [5]=Monadic_operators, [6]=Dyadic_operators, [7]='either'}
 
local preamble=[[local _w,_a=... 
]]

load_apl = function(_w)
   _w = _w:gsub("⍝[^\n]*\n"," ")  -- strip off APL comments
   local lua = apl2lua(_w)
   if select(2,_w:gsub('⋄',''))==0 then  
      lua="return "..lua 
      end
   local f,msg = loadstring(preamble..lua,nil,nil,APL_ENV)
   if not f then 
      error("Could not compile: ".._w.."\n Tried: "..lua.."\n"..msg) 
   end
   return f   
end

local function lua_code(_w)
-- Display Lua code of a function
   if type(_w)=='function' then 
      local source = debug.getinfo(_w).source
      if source:sub(1,#preamble)==preamble then 
          source=source:sub(#preamble+1)
      end
      return source
   else return "Not a function"
   end
end

apl.lua = lua_code

print(apl.lua(apl[[F←∇'⍺|⍵']]))  
