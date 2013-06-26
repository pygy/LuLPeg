-- Taken from https://github.com/moteus/lua-pop3/
-- Copyright (C) 2013 Alexey Melnichuk.
-- See the license at the end of this file.

local lpeg = require(arg[1]):register()

local get_address_list do

-- local function prequire(...)
--   local ok, mod = pcall(require, ...)
--   return ok and mod, mod
-- end

local re = lpeg.re

if re then

local function try_load_get_address_list()
  -- @todo unquot quoted name
  local mail_pat = re.compile[[
    groups            <- (group (%s* ([,;] %s*)+ group)*) -> {}
    group             <- (
                            {:name: <phrase> :} %s* <addr>                  /
                            {:name: <uq_phrase> :} %s* "<" <addr_spec> ">"  /
                            <addr> %s* {:name: <phrase> :}                  /
                            "<" <addr_spec> ">" %s* {:name: <uq_phrase> :}  /
                            <addr>                                          /
                            {:name: <phrase> :}                              
                          ) -> {}

    uq_phrase          <- <uq_atom> (%s+ <uq_atom>)*
    uq_atom            <- [^<>,; ]+

    phrase            <- <word> ([%s.]+ <word>)* /  <quoted_string>
    word              <- <atom> ! <domain_addr>

    atom              <- [^] %c()<>@,;:\".[]+
    quoted_string     <- '"' ([^"\%nl] / "\" .)*  '"'

    addr              <- <addr_spec> / "<" <addr_spec> ">"
    addr_spec         <- {:addr: <addr_chars> <domain_addr> :}
    domain_addr       <- "@" <addr_chars>
    addr_chars        <- [_%a%d][-._%a%d]*
  ]]

  return function(str)
    if (not str) or (str == '') then
      return nil
    end
    return mail_pat:match(str)
  end
end

local ok, fn = pcall(try_load_get_address_list)

if ok then get_address_list = fn end

if get_address_list then -- test --
local cmp_t

local function cmp_v(v1,v2)
  local flag = true
  if type(v1) == 'table' then
    flag = (type(v2) == 'table') and cmp_t(v1, v2)
  else
    flag = (v1 == v2)
  end
  return flag
end

function cmp_t(t1,t2)
  for k in pairs(t2)do
    if t1[k] == nil then
      return false
    end
  end
  for k,v in pairs(t1)do
    if not cmp_v(t2[k],v) then 
      return false 
    end
  end
  return true
end

local tests = {}
local tests_index={}

local test = function(str, result) 
  local t 
  if type(result) == 'string' then
    local res = assert(tests_index[str])
    t = {result, result = res.result}
    assert(result ~= str)
    tests_index[result] = t;
  else
    t = {str,result=result}
    tests_index[str] = t;
  end
  return table.insert(tests,t)
end

assert(get_address_list() == nil)
assert(get_address_list('') == nil)

test([[aaa@mail.ru]],
  {{
      addr = "aaa@mail.ru"
  }}
)
test([[aaa@mail.ru]],[[<aaa@mail.ru>]])

test([["aaa@mail.ru"]],
  {{
      name = '"aaa@mail.ru"'
  }}
)

test([[Subscriber YPAG.RU <aaa@mail.ru>]],
  {{
      name = "Subscriber YPAG.RU",
      addr = "aaa@mail.ru"
  }}
)

test([[Subscriber YPAG.RU <aaa@mail.ru>]], [[<aaa@mail.ru> Subscriber YPAG.RU]])

test([["Subscriber YPAG.RU" <aaa@mail.ru>]],
  {{
      name = '"Subscriber YPAG.RU"',
      addr = "aaa@mail.ru"
  }}
)
test([["Subscriber YPAG.RU" <aaa@mail.ru>]],[[<aaa@mail.ru> "Subscriber YPAG.RU"]])

test([["Subscriber ;,YPAG.RU" <aaa@mail.ru>]],
  {{
      name = '"Subscriber ;,YPAG.RU"',
      addr = "aaa@mail.ru"
  }}
)

test([[Subscriber ;,YPAG.RU <aaa@mail.ru>]],
  {
    {
      name = "Subscriber"
    },
    {
      name = "YPAG.RU",
      addr = "aaa@mail.ru"
    }
  }
)

test([["Subscriber ;,YPAG.RU" <aaa@mail.ru>]],[[<aaa@mail.ru> "Subscriber ;,YPAG.RU"]])

test([[info@arenda-a.com, travel@mama-africa.ru; info@some.mail.domain.ru ]],
  {
    {
      addr = "info@arenda-a.com"
    },
    {
      addr = "travel@mama-africa.ru"
    },
    {
      addr = "info@some.mail.domain.ru"
    }
  }
)
test([[info@arenda-a.com, travel@mama-africa.ru; info@some.mail.domain.ru ]],
     [[<info@arenda-a.com>, travel@mama-africa.ru; info@some.mail.domain.ru ]])

test([["name@some.mail.domain.ru" <addr@some.mail.domain.ru>]],
  {
    {
      name = "\"name@some.mail.domain.ru\"",
      addr = "addr@some.mail.domain.ru"
    }
  }
)
test([[name@some.mail.domain.ru <addr@some.mail.domain.ru>]],
  {
    {
      name = "name@some.mail.domain.ru",
      addr = "addr@some.mail.domain.ru"
    }
  }
)

test([[MailList: рассылка номер 78236 <78236-response@maillist.ru>]],
  {
    {
      name = "MailList: рассылка номер 78236",
      addr = "78236-response@maillist.ru"
    }
  }
)

test([[<aaa@mail.ru>, "Info Mail List" <bbb@mail.ru>, Сакен Матов <saken@from.kz>, "Evgeny Zhembrovsky \(ezhembro\)" <ezhembro@cisco.com> ]],
  {
    {
      addr = "aaa@mail.ru"
    },
    {
      name = "\"Info Mail List\"",
      addr = "bbb@mail.ru"
    },
    {
      name = "Сакен Матов",
      addr = "saken@from.kz"
    },
    {
      name = "\"Evgeny Zhembrovsky \\(ezhembro\\)\"",
      addr = "ezhembro@cisco.com"
    }
  }
)

  for _,test_case in ipairs(tests)do
    local res = get_address_list(test_case[1])
    if not cmp_v(res, test_case.result ) then
      -- require "pprint"
      print"----------------------------------------------"
      print("ERROR:", test_case[1])
      print"EXPECTED:"
      -- pprint(test_case.result)
      print"RESULT:"
      -- pprint(res)
    end
  end
end -- test --

end -- require "re" --
end -- get_address_list --
-------------------------------------------------------------------------

-- Copyright (C) 2013 Alexey Melnichuk.

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
-- ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
-- TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
-- PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
-- SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
-- ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
-- ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
-- OR OTHER DEALINGS IN THE SOFTWARE.