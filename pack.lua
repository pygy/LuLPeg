-- A Lua source file packer.
-- released under the Romantic WTF Public License
-- setmetatable( _G or _ENV, {__index = require"init" } )
 
args = {...}
--[[]] pcall( require,"luarocks.loader" )
--[[]] fs = pcall( require,"lfs" )
files = {}
 
fs = fs or {
    dir = function (path) 
        local listing = io.popen ( "ls "..path ):read"*all"
        local files = {}
        for file in listing:gmatch( "[^\n]+" ) do
            files[file] = true
        end
        return next, files
    end,
   attributes = function() return{} end
}

root = "./"
 
function pront(...) print("PRONT ", ...) return ... end

function scandir (root)
-- adapted from http://keplerproject.github.com/luafilesystem/examples.html
    path = path or ""
    for f in fs.dir( root ) do
        if f:find"%.lua$" then
            hndl = f:gsub( "%.lua$", "" ):gsub("^[/\\]","")
                                         :gsub( "/", "." )
                                         :gsub( "\\", "." )
            files[hndl] = io.open( root..f ):read"*a"
        end
    end
end
 
scandir( root )
 
acc={(io.open("../ABOUT"):read("*all").."\n"):gsub( "([^\n]-\n)","-- %1" ),[[
local module_name = ...
local _ENV,       error,          loaded, packages, release, require_ 
    = _ENV or _G, error or print, {},     {},       true,    require
local t_concat = require"table".concat

local function require(...)
    local lib = ...

    -- is it a private file?
    if loaded[lib] then 
        return loaded[lib]
    elseif packages[lib] then 
        loaded[lib] = packages[lib](lib)
        return loaded[lib]
    else
        -- standard require.
        local success, lib = pcall(require_, lib)
        
        if success then return lib end

        -- -- error handling.
        -- local name, line, trace
        -- local success, d = pcall(require, "debug")
        -- if success then success, d = pcall (debug.getinfo, 2) end
        -- if success then
        --     line = d.currentline or "-1"
        --     name = ( d.name ~= "" ) and name 
        --         or ( d.shortsrc ~= "" ) and d.shortsrc
        --         or "?"
        --     success, trace = pcall(d.traceback(1))
        --     if not success then trace = "" end
        -- else
        --     line, name, trace = -1, "?", ""
        -- end

        -- print(t_concat( name, ":", line, ": module '", lib, "' not found:"))
        -- print(t_concat("\tno private field ", module_name,".packages['",
        --     lib,"']\n", trace))
        -- error()
    end
end

]]
} local wrapper = { [[
--=============================================================================
do local _ENV = _ENV
packages[']], nil, [['] = function (...)
]], nil, [[

end
end
]] }
-- local eol = "\n" + P(-1)
-- local blank = P" "^0 * eol / ""
-- local fullcomment = P" "^0 * "--" * (P(1)-eol)^0 * eol / ""
-- local trailingspace = P" "^0
-- local trailingcomment = P" "^0 * "--" * (P(1)-eol)^0
-- local lineWspace = (1 - trailingspace * eol) ^ 1 * (trailingspace / "") * eol
-- local lineWcomment = (1 - trailingcomment * eol) ^ 1 * (trailingcomment / "") * eol
-- local strip = Cs((blank + fullcomment 
--     -- + lineWspace + lineWcomment
--     )^0)

for k,v in pairs( files ) do
    wrapper[2], wrapper[4] 
  = k, v
  --:gsub("\n *\n","\n") -- strip blank lines and comments.
                 -- :gsub("( *\-\-.-\n)","\n")   -- and stray debug commands.
                 -- :gsub("^( -\n)","")
                 -- :gsub("^ *\-\-.*\n","")
                 -- :gsub("\n *$","")
                 -- :gsub("\n *\-\-.*$","")

    acc[#acc+1]= table.concat(wrapper)
end
 
acc[#acc + 1] = [[
return require"init"
]]

acc[#acc+1] = io.open("../LICENSE"):read("*all".."\n"):gsub("([^\n]-\n)","-- %1")

print( table.concat( acc ) )

