return function(Builder, PL)

-- Print

local ipairs, pairs, print, tostring, type 
    = ipairs, pairs, print, tostring, type

local s, t, u = require"string", require"table", require"util"



local _ENV = u.noglobals() ----------------------------------------------------



local s_char, t_concat 
    = s.char, t.concat

local   expose,   load,   map
    = u.expose, u.load, u.map

local printers = {}

local
function PL_pprint (pt, offset, prefix)
    -- [[DP]] print("PRINT -", pt)
    -- [[DP]] print("PRINT +", pt.ptype)
    -- [[DP]] expose(PL.proxycache[pt])
    return printers[pt.ptype](pt, offset, prefix)
end

function PL.pprint (pt0)
    local pt = PL.P(pt0)
    print"\nPrint pattern"
    PL_pprint(pt, "", "")
    print"--- /pprint\n"
    return pt0
end

for k, v in pairs{
    string       = [[ "P( \""..pt.as_is.."\" )"       ]],
    char         = [[ "P( '"..to_char(pt.aux).."' )"         ]],
    ["true"]     = [[ "P( true )"                     ]],
    ["false"]    = [[ "P( false )"                    ]],
    eos          = [[ "~EOS~"                         ]],
    one          = [[ "P( one )"                      ]],
    any          = [[ "P( "..pt.aux.." )"            ]],
    set          = [[ "S( "..'"'..pt.as_is..'"'.." )" ]],
    ["function"] = [[ "P( "..pt.aux.." )"            ]],
    ref = [[
        "V( ",
            (type(pt.aux) == "string" and "\""..pt.aux.."\"")
                          or tostring(pt.aux) 
        , " )"
        ]],
    range = [[
        "R( ",
            t_concat(map(
                pt.as_is, 
                function(e) return '"'..e..'"' end), ", "
            )
        ," )"
        ]]
} do
    printers[k] = load(([==[
        local k, map, t_concat, to_char = ...
        return function (pt, offset, prefix)
            print(t_concat{offset,prefix,XXXX})
        end
    ]==]):gsub("XXXX", v), k.." printer")(k, map, t_concat, s_char)
end


for k, v in pairs{
    ["behind"] = [[ PL_pprint(pt.pattern, offset, "B ") ]],
    ["at least"] = [[ PL_pprint(pt.pattern, offset, pt.aux.." ^ ") ]],
    ["at most"] = [[ PL_pprint(pt.pattern, offset, pt.aux.." ^ ") ]],
    unm        = [[PL_pprint(pt.pattern, offset, "- ")]],
    lookahead  = [[PL_pprint(pt.pattern, offset, "# ")]],
    choice = [[
        print(offset..prefix.."+")
        -- dprint"Printer for choice"
        map(pt.aux, PL_pprint, offset.." :", "")
        ]],
    sequence = [[
        print(offset..prefix.."*")
        -- dprint"Printer for Seq"
        map(pt.aux, PL_pprint, offset.." |", "")
        ]],
    grammar   = [[
        print(offset..prefix.."Grammar")
        -- dprint"Printer for Grammar"
        for k, pt in pairs(pt.aux) do
            local prefix = ( type(k)~="string" 
                             and tostring(k)
                             or "\""..k.."\"" )
            PL_pprint(pt, offset.."  ", prefix .. " = ")
        end
    ]]
} do
    printers[k] = load(([[
        local map, PL_pprint, ptype = ...
        return function (pt, offset, prefix)
            XXXX
        end
    ]]):gsub("XXXX", v), k.." printer")(map, PL_pprint, type)
end

-------------------------------------------------------------------------------
--- Captures patterns
--

-- for __, cap in pairs{"C", "Cs", "Ct"} do
-- for __, cap in pairs{"Carg", "Cb", "Cp"} do
-- function PL_Cc (...)
-- for __, cap in pairs{"Cf", "Cmt"} do
-- function PL_Cg (pt, tag)
-- local valid_slash_type = newset{"string", "number", "table", "function"}


for __, cap in pairs{"C", "Cs", "Ct"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap)
        PL_pprint(pt.pattern, offset.."  ", "")
    end
end

for __, cap in pairs{"Cg", "Ctag", "Cf", "Cmt", "/number", "/zero", "/function", "/table"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap.." "..tostring(pt.aux or ""))
        PL_pprint(pt.pattern, offset.."  ", "")
    end
end

printers["/string"] = function (pt, offset, prefix)
    print(offset..prefix..'/string "'..tostring(pt.aux or "")..'"')
    PL_pprint(pt.pattern, offset.."  ", "")
end

for __, cap in pairs{"Carg", "Cp"} do
    printers[cap] = function (pt, offset, prefix)
        print(offset..prefix..cap.."( "..tostring(pt.aux).." )")
    end
end

printers["Cb"] = function (pt, offset, prefix)
    print(offset..prefix.."Cb( \""..pt.aux.."\" )")
end

printers["Cc"] = function (pt, offset, prefix)
    print(offset..prefix.."Cc(" ..t_concat(map(pt.aux, tostring),", ").." )")
end


-------------------------------------------------------------------------------
--- Capture objects
--

local cprinters = {}

function PL.cprint (capture)
    print"\nCapture Printer\n===============\n"
    -- print(capture)
    -- expose(capture)
    -- expose(capture[1])
    cprinters[capture.type](capture, "", "")
    print"\n/Cprinter -------\n"
end

cprinters["backref"] = function (capture, offset, prefix)
    print(offset..prefix.."Back: start = "..capture.start)
    cprinters[capture.ref.type](capture.ref, offset.."   ")
end

-- cprinters["string"] = function (capture, offset, prefix)
--     print(offset..prefix.."String: start = "..capture.start..", finish = "..capture.finish)
-- end
cprinters["value"] = function (capture, offset, prefix)
    print(offset..prefix.."Value: start = "..capture.start..", value = "..tostring(capture.value))
end

cprinters["values"] = function (capture, offset, prefix)
    -- expose(capture)
    print(offset..prefix.."Values: start = "..capture.start..", values = ")
    for _, c in pairs(capture.values) do
        print(offset.."   "..tostring(c))
    end
end

cprinters["insert"] = function (capture, offset, prefix)
    print(offset..prefix.."insert n="..capture.n)
    for i, subcap in ipairs(capture) do
        -- dprint("insertPrinter", subcap.type)
        cprinters[subcap.type](subcap, offset.."|  ", i..". ")
    end

end

for __, capname in ipairs{
    "Cf", "Cg", "tag","C", "Cs", 
    "/string", "/number", "/table", "/function" 
} do 
    cprinters[capname] = function (capture, offset, prefix)
        local message = offset..prefix..capname
            ..": start = "..capture.start 
            ..", finish = "..capture.finish
            ..(capture.Ctag and " tag = "..capture.Ctag or "")
        if capture.aux then 
            message = message .. ", aux = ".. tostring(capture.aux)
        end
        print(message)
        for i, subcap in ipairs(capture) do
            cprinters[subcap.type](subcap, offset.."   ", i..". ")
        end

    end
end


cprinters["Ct"] = function (capture, offset, prefix)
    local message = offset..prefix.."Ct: start = "..capture.start ..", finish = "..capture.finish
    if capture.aux then 
        message = message .. ", aux = ".. tostring(capture.aux)
    end
    print(message)
    for i, subcap in ipairs(capture) do
        -- print ("Subcap type",subcap.type)
        cprinters[subcap.type](subcap, offset.."   ", i..". ")
    end
    for k,v in pairs(capture.hash or {}) do 
        print(offset.."   "..k, "=", v)
        expose(v)
    end

end

cprinters["Cb"] = function (capture, offset, prefix)
    print(offset..prefix.."Cb: tag = "
        ..(type(capture.tag)~="string" and tostring(capture.tag) or "\""..capture.tag.."\"")
        )
end

return { pprint = PL.pprint,cprint = PL.cprint }

end -- module wrapper ---------------------------------------------------------


--                   The Romantic WTF public license.
--                   --------------------------------
--                   a.k.a. version "<3" or simply v3
--
--
--            Dear user,
--
--            The LuLPeg proto-library
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
