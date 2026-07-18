import
  std/osproc,
  os,
  options,
  strutils,
  streams

import
  ./tui/logger as tlog,
  ./tui/base,
  illwill

type
  AfterExecuteProc* = proc() {.gcsafe, closure.}
  SpecialLineProc* = proc(line: string) : bool {.gcsafe, nimcall.}

  CliApplication = ref object of RootObj
    name*: string
    args*: seq[string]
    path: string
    process {.deprecated.}: Process
    log*: tlog.WewboLogger
    logMode*: WewboLogMode
    available* {.deprecated.}: bool = false
    specialLogLine* {.deprecated.}: SpecialLineProc

  CliError* = enum
    erUnknown,
    erCommandNotFound,

method failureHandler(app: CliApplication, context: CliError) {.gcsafe, base.} =
  if context == erCommandNotFound:
    let msg = "'$#' Is not exist." % app.name
    raise newException(ValueError, msg)

proc logginArg(app: CliApplication; log = app.log) : void =
  log.text("APP_NAME: " & app.name, color(fgYellow))
  log.text("APP_PATH: " & app.path, color(fgYellow))
  log.text("APP_ARGS:", color(fgYellow))

  for arg in app.args:
    log.text("- " & arg, color(fgYellow))

proc check(app: CliApplication) : bool =
  app.path = app.name.findExe()
  app.path.fileExists()

method specialLine(cli: CliApplication; text: string) : bool {.gcsafe, base.} =
  text.contains("\r")

proc setUp[T: CliApplication](app: T) : T =
  app.log = useWewboLogger(app.name, mode = app.logMode)

  if not app.check() :
    app.failureHandler(erCommandNotFound)
    quit(1)

  app

proc start(app: CliApplication, process: Process, message: string, checkup: int = 50): int =
  let
    isUnix = defined(linux) or defined(macosx) or defined(macos)
    # Join the same shared log buffer everything else (extractors, the
    # Downloader logger, etc.) writes to via useWewboLogger -- otherwise
    # this logger's own private .logs is empty of everything but ffmpeg's
    # own output, even though it visually appears alongside earlier lines
    # in the TUI (which just renders whatever's currently on screen).
    processLogger = newWewboLogger(message, konten = some(addr tlog.loga.content), mode = app.logMode)

  var
    outputBuffer: string
    stream = process.peekableOutputStream()

  proc sendLog(line: string) =
    if app.specialLine(line):
      # Still recorded via saveLine below -- specialLine output (e.g.
      # ffmpeg's \r-updated progress line) is usually spam, but the actual
      # fatal error can land on a line that also matches (e.g. containing
      # "time="), so it must still reach the exportable log, just not the
      # scrolling live view.
      processLogger.setLineBuffer(processLogger.tb.height - 3, " " & line.strip, bg=bgWhite, fg=fgBlack)
      processLogger.saveLine(line)

    elif line != "":
      processLogger.info(line)

  proc handleOutputBufferWin(strm: Stream; place: var string) =
    sendLog strm.readLine()

  proc handleOutputBufferUnix(strm: Stream; place: var string) =
    place = stream.readLine()
    place.sendLog()

  proc handleOutputBuffer(strm: Stream; place: var string) =
    try:
      if isUnix: strm.handleOutputBufferUnix(place)
      else: strm.handleOutputBufferWin(place)
    except:
      discard # Jangan males napa lu ah

  # processLogger.info("ARGS: " & $app.args)
  app.logginArg(processLogger)

  while true:
    if process.running():
      stream.handleOutputBuffer(outputBuffer)
      checkup.sleep()

    else:
      stream.handleOutputBuffer(outputBuffer)
      checkup.sleep()

      let exitCode = process.peekExitCode()
      if exitCode != 0:
        # A fixed, predictable path -- the TUI truncates long lines to pane
        # width, so a path containing a temp-dir's random component would be
        # unreadable/uncopyable from the log line that reports it.
        let logDir = getHomeDir() / "wewbo"
        createDir(logDir)
        let logFile = logDir / "last_run.log"
        processLogger.exportLog(logFile)
        app.log.warn("$# exited with code $#, full output saved to $#" % [app.name, $exitCode, logFile])

      processLogger.stop()

      return exitCode

proc addArg(app: CliApplication, arg: string) =
  app.args.add arg

proc execute(
  app: CliApplication,
  message: string = "Executing external app.",
  clearArgs: bool = true,
  after: Option[AfterExecuteProc] = none(AfterExecuteProc)
) : int =
  let process = startProcess(app.path.findExe(), ".", app.args)

  result = app.start(process, message)

  if clearArgs :
    app.log.info("Clearing previous args")
    app.args = @[]

  if after.isSome :
    get(after)()

export
  CliApplication,
  check,
  setUp,
  addArg,
  execute,
  AfterExecuteProc
