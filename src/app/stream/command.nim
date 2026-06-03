import
  main,
  terminal/[command, paramarg]

const
  name = "stream"
  help = "Streaming Anime"
  entry = stream

let  
  commands = @[
    option("-s", "source", "Select Source", "toyo"),
    option("-p", "player", "Select Player"),
    option("--mpv", "mpv_path", "MPV Path"),
    option("--ffplay", "ffplay_path", "ffplay path")
  ]
  streamCommand* = newSubCommand(
    name = name,
    help = help,
    entry = entry,
    argOpts = commands)
