import ../base 
from strutils import `%`, join, contains

type
  FfplayPL {.final.} = ref object of Player

proc newFfplayPlayer*(basePlayer: var Player): void =
  basePlayer = FfplayPL(name: "ffplay")

proc setHeader(ffplay: FfplayPL, ty, val: string) =
  ffplay.args.add "-headers"
  ffplay.args.add "$#: $#" % [ty, val]

method specialLine(ffplay: FfplayPL; text: string) : bool =
  text.contains("A-V") or text.contains("\r")

method setUserAgent(ffplay: FfplayPL, val: string) =
  ffplay.setHeader("User-Agent", val)

method setReferer(ffplay: FfplayPL, val: string) =
  ffplay.setHeader("Referer", val)

method watch_mp4(ffplay: FfplayPL, media: MediaFormatData) =
  # Allow .jpg files as HLS segments (for encrypted streams)
  ffplay.args.add "-allowed_segment_extensions"
  ffplay.args.add "jpg,ts,mpegts"
  # Disable strict extension checking
  ffplay.args.add "-extension_picky"
  ffplay.args.add "0"
  # Enable crypto protocol for AES-128 decryption
  ffplay.args.add "-protocol_whitelist"
  ffplay.args.add "file,http,https,tcp,tls,crypto"
  ffplay.args.add "-i"
  ffplay.args.add media.video

method watch_m3u8(ffplay: FfplayPL, media: MediaFormatData) =
  ffplay.args.add "-protocol_whitelist"
  ffplay.args.add ffplay.protocolWhitelist
  ffplay.watch_mp4(media)

export
  FfplayPL,
  setUp,
  watch  
