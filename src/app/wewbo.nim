import
  stream/command,
  player/command,
  temp/command,
  ani_dl/command

import
  terminal/command,
  tui/[base, logger],
  os

let app = [
  streamCommand,
  anidlCommand,
  tempCommand,
  playerCommand,
]

proc main* = 
  try:
    app.start()

  except ref Exception:
    if not loga.logger.isNil:
      loga.logger.close()
    
    echo "ERROR: " & getCurrentExceptionMsg()

  if commandLineParams().contains "--capture-error":
    if not loga.logger.isNil:
      loga.logger.exportLog()
      echo "Error log saved to " & getCurrentDir() / "wewbo.txt"
