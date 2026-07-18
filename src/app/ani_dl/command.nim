import
  main,
  terminal/[command, paramarg]

const
  name = "ani-dl"
  help = "Ani-DL. Anime Downloader"
  entry = download2

let  
  commands = @[
    option("-s", "source", "Select Source", "mori"),
    option("-o", "output", "Output directory (default: ~/wewbo/<anime title>)", "")
  ]
  anidlCommand* = newSubCommand(
    name = name,
    help = help,
    entry = entry,
    argOpts = commands)
