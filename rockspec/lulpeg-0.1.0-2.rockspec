package = "lulpeg"
version = "0.1.0-2"

source = {
  url = "git://github.com/pygy/LuLPeg",
}

description = {
  summary     = "LuLPeg",
  detailed    = "LuLPeg, a pure Lua port of LPeg, Roberto Ierusalimschy's Parsing Expression Grammars library. Copyright (C) Pierre-Yves Gerardy.",
  license     = "The Romantic WTF public license",
  maintainer  = "pygy",
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type    = "command",
  build_command = 'cd src && $(LUA) -e "package.path=\'./?.lua;./?/init.lua;\'..package.path" ../scripts/pack.lua > lulpeg.lua',
  install = {
    lua = {
      ["lulpeg"] = "lulpeg.lua",
    }
  }
}
