package = "lulpeg"
version = "0.1.0-1"

source = {
  url = "git://github.com/Seriane/LuLPeg",
}

description = {
  summary     = "LuLPeg",
  detailed    = [[]],
  license     = "Public WTF License",
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



  



