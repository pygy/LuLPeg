---------------------------------  ,--.                ,    ,--.            ---
---------------------------------  |__' ,  . ,--. ,--. |    |__' ,--. ,--.  ---
-- PureLPeg.lua -----------------  |    |  | |    |--' |    |    |--' `__|  ---
---------------------------------  '    `--' '    `--' `--- '    `--' .__'  ---

-- a WIP LPeg implementation in pure Lua, by Pierre-Yves Gérardy
-- released under the Romantic WTF Public License (see the end of the file).

-- Captures and locales are not yet implemented, but the rest works quite well.
-- UTF-8 is supported out of the box
--
--     PL.set_charset"UTF-8"
--     s = PL.S"ß∂ƒ©˙"
--     s:match"©" --> 3 (since © is two bytes wide).
-- 
-- More encodings can be easily added (see the charset section), by adding a 
-- few appropriate functions.

-- The LPeg version we emulate.
local VERSION = "0.12"

-- The PureLPeg version.
local PVERSION = "0.0.0"

local u = require"util"
local map, nop, t_unpack = u.map, u.nop, u.unpack

-- The module decorators.
local API, charsets, compiler, constructors
    , evaluator, locale, match, printers
    = t_unpack(map(require,
    { "API", "charsets", "compiler", "constructors"
    , "evaluator", "locale", "match", "printers" }))

local 
function PLPeg(options)
    options = options and copy(options) or {}

    -- PL is the module
    -- Builder keeps the state during the module decoration.
    local Builder, PL 
        = { options = options }
        , { new = PLPeg
          , version = function () return VERSION end
          , pversion = function () return PVERSION end
          , setmaxstack = nop --Just a stub, for compatibility.
          }

    PL.__index = PL

    local getmetatable = getmetatable
    local
    function PL_ispattern(pt) return getmetatable(pt) == PL end
    PL.ispattern = PL_ispattern

    function PL.type(pt)
        if PL_ispattern(pt) then 
            return "pattern"
        else
            return nil
        end
    end

    charsets(Builder, PL)
    printers(Builder, PL)
    constructors(Builder, PL)
    API(Builder, PL)
    evaluator(Builder, PL)
    compiler(Builder, PL)
    match(Builder, PL)
    locale(Builder, PL)


    return PL
end -- PLPeg

local PL = PLPeg()

return PL

--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The PureLPeg proto-library
--
--                                             \ 
--                                              '.,__
--                                           \  /
--                                            '/,__
--                                            /
--                                           /
--                                          /
--                       has been          / released
--                  ~ ~ ~ ~ ~ ~ ~ ~       ~ ~ ~ ~ ~ ~ ~ ~ 
--                under  the  Romantic   WTF Public License.
--               ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~`,´ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ 
--               I hereby grant you an irrevocable license to
--                ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
--                  do what the gentle caress you want to
--                       ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~  
--                           with   this   lovely
--                              ~ ~ ~ ~ ~ ~ ~ ~ 
--                               / thing...
--                              /  ~ ~ ~ ~
--                             /    Love,
--                        #   /      '.'
--                        #######      ·
--                        #####
--                        ###
--                        #
--
--            -- Pierre-Yves
--
--
--            P.S.: Even though I poured my heart into this work, 
--                  I _cannot_ provide any warranty regarding 
--                  its fitness for _any_ purpose. You
--                  acknowledge that I will not be held liable
--                  for any damage its use could incur.