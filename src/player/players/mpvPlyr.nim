import ../base
from strutils import `%`, join, contains

type
  MpvPL {.final.} = ref object of Player
    headerString: string = ""

proc newMpvPlayer*(basePlayer: var Player): void {.gcsafe.} =
  basePlayer = MpvPL(name: "mpv")

proc generateHeader(mpv: MpvPL, ky, val: string) {.inline.} =
  mpv.headerString &= "$#:$#," % [ky, val]   

method specialLine(mpv: MpvPL; text: string): bool =
  text.contains("AV")

method setUserAgent(mpv: MpvPL, val: string) {.inline.} =
  mpv.args.add "--user-agent=" & val

method setReferer(mpv: MpvPL, val: string) {.inline.} =
  mpv.generateHeader("Referer", val)

method setSubtitle(mpv: MpvPL, subtitle: MediaSubtitle) {.inline.} =
  mpv.args.add "--sub-file=" & subtitle.url  
    
method watch_mp4(mpv: MpvPL, media: MediaFormatData) =
  mpv.args.add "--fullscreen"
  mpv.args.add "--ytdl=no"
  # NOTE: MPV has issues with comma-separated lavf options on macOS
  # For encrypted HLS with .jpg segments (like animepahe), use ffplay instead
  # The following options work in ffmpeg/ffplay but not MPV:
  # -allowed_segment_extensions jpg,ts,mpegts -extension_picky 0
  # Set referrer for HTTP requests
  mpv.args.add "--referrer=https://kwik.cx/"
  # Remove trailing comma from headerString
  var headers = mpv.headerString
  if headers.len > 0 and headers[^1] == ',':
    headers = headers[0 ..< headers.len - 1]
  if headers.len > 0:
    mpv.args.add "--http-header-fields=" & headers
  mpv.args.add media.video
 
method watch_m3u8(mpv: MpvPL, media: MediaFormatData) = 
  mpv.args.add "--demuxer-lavf-o=protocol_whitelist=[$#]" % mpv.protocolWhitelist & ",http_persistent=0"
  mpv.args.add "--cache=yes"
  mpv.args.add "--demuxer-readahead-secs=20"

  mpv.watch_mp4(media)

export
  MpvPL,
  watch
