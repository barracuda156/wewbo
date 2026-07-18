import os
import
  temp,
  tui/logger,
  terminal/paramarg

proc tempManagement*(n: FullArgument) = 
  let temp = newTempManager(getTempDir(), mEcho)
  
  if n["list"].getBool():
    for (path, _) in temp.all:
      echo path
    quit(0)

  if n["clear"].getBool():
    temp.clearAll()
    quit(0)

  echo "Options: "
  echo "--list"
  echo "--clear"
