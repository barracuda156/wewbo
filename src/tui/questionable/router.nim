import
  base, illwill

import  
  ../logger, ../base, os

type
  RouteActionProc*[T] = proc(prevRoute: Route[T]): void {.gcsafe.}

  RouteAction*[T] = ref object of Questionable
    action*: RouteActionProc[T]
    data*: string
    hidden*: bool = false

  RouteActionError* = object of CatchableError

  Route*[T] = ref object of RootObj
    title*: string
    actions*: seq[RouteAction[T]]
    logger*: WewboLogger    
    data*: string
    session*: ptr T
    defaultActionIdx*: int

  RouteSignal* = ref object of CatchableError  
    request*: RouteRequest
    procedure*: proc() {.gcsafe.}

  RouteRequest* = enum
    reqBreak,    
    reqBack,
    reqClear {.deprecated.},
    reqExecProc,

proc setColour*(item: RouteAction; is_current: bool) : tuple[bg: BackgroundColor; fg: ForegroundColor] =
  result.bg = if is_current: bgGreen else: bgBlack
  result.fg = if is_current: fgBlack else: fgWhite

  if item.title == "Back":
    result.fg = fgRed
    result.bg = bgBlack

proc handleExceptionKey*(item: RouteAction; tui: WewboTUI; key: Key): void =
  case key
  of Key.CtrlH, Key.Backspace:
    raise RouteSignal(msg: "Linux Rijal", request: reqBack)
  else:
    discard
