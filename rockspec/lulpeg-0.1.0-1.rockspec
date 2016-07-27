package = "lulpeg"
version = "0.1.0-1"

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
  build_command = "scripts/make.sh",
  install = {
    lua = {
      ["lulpeg"] = "lulpeg.lua",
    }
  }
}



  



