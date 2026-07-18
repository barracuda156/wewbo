import os, strutils, oids
import tui/logger

type TempManager* = ref object of RootObj
  dir: string
  log: WewboLogger

iterator all*(temp: TempManager): tuple[path: string, kind: PathComponent] =
  for kind, path in walkDir(temp.dir):
    if path.extractFilename.contains("wewbo-"):
      yield (path, kind)

proc clearAll*(temp: TempManager): void =
  for (tempPath, kind) in temp.all:
    temp.log.info("Deleting: " & tempPath)
    case kind
    of pcDir, pcLinkToDir:
      tempPath.removeDir()
    else:
      tempPath.removeFile()

proc write*(temp: TempManager; content: string; prefix = ""): string =
  temp.log.info("Write Temp: " & content.split("\n")[0] & "...")
  result = temp.dir / "wewbo-" & $genOid() & prefix
  result.writeFile(content)

proc newTempManager*(dir = getTempDir(), logMode = mTui): TempManager =
  result = TempManager()
  result.dir = dir
  result.log = useWewboLogger("temp", mode=logMode)
