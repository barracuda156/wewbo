import
  main,
  terminal/[command, paramarg]

const
  name = "temp"
  help = "Manage temp files"
  entry = tempManagement

let  
  commands = @[
    option("--list", "list", "List Temp Files", false),
    option("--clear", "clear", "Cleat Temp Files", false)
  ]
  tempCommand* = newSubCommand(
    name = name,
    help = help,
    entry = entry,
    argOpts = commands)
