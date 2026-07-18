
discard """
  Pernah kah kau merasa? Jrek Jrek.
  Saat. AAA. Bayangmupun tak mampu ku lihat lagiiiii
"""

discard """
  ffmpeg -headers \"Referer: https://megacloud.blog/\" -i URL -vcodec libx264 -crf 28 -preset veryfast -r 25 output.mp4
  ffmpeg -headers \"Referer: https://megacloud.blog/\" -i \"$#\" -vf \"ass=local_$#\" sj.mp4
"""

import
  os,
  options,
  strutils,
  sequtils,
  tables

import  
  ../process,
  ../media/[format, types],
  ../tui/logger

type
  FfmpegDownloaderOption* = tuple[
    crf = 28,
    fps = 25,
    sub = true,
    keepFormat = true
  ]    

  FfmpegMediaInput* = tuple[
    media: MediaFormatData,
    outputName: string,
    formatIdentity: FormatIdentity
  ]

  FfmpegDownloader* = ref object of CliApplication
    outdir*: string
    targetExt {.deprecated.}: string = "mp4"
    options*: FfmpegDownloaderOption

proc newFfmpegDownloader*(outdir: string; options: FfmpegDownloaderOption) : FfmpegDownloader =
  result = FfmpegDownloader(
    name: "ffmpeg",
    outdir: outdir,
    options: options
  ).setUp()

method failureHandler(ffmpeg: FfmpegDownloader, context: CLiError) =
  raise newException(ValueError, "ffmpeg is not detected on your system.")

method specialLine*(cli: FfmpegDownloader; text: string) : bool =
  text.contains("time=") 

proc setHeader(ffmpeg: FfmpegDownloader, ty, val: string) =
  let ngantukCok = {
    "userAgent" : "User-Agent",
    "referer" : "Referer",
    "cookie" : "Cookie"
  }.toTable

  ffmpeg.addArg "-headers"
  ffmpeg.addArg "$#: $#" % [ngantukCok[ty], val]

proc setUpHeader(ffmpeg: FfmpegDownloader, headers: Option[MediaHttpHeader]) =
  if headers.isNone :
    return

  for chi, no in headers.get.fieldPairs() :
    if no != "" :
      ffmpeg.setHeader(chi, no)

proc setGatauIniApa(ffmpeg: FfmpegDownloader) {.deprecated.} =
  # Vcodec
  ffmpeg.addArg "-vcodec"
  ffmpeg.addArg "libx264"

  # Crf
  ffmpeg.addArg "-crf"
  ffmpeg.addArg $ffmpeg.options.crf

  # Fps
  ffmpeg.addArg "-r"
  ffmpeg.addArg $ffmpeg.options.fps

proc setInput(ffmpeg: FfmpegDownloader, media: MediaFormatData) =
  # Allow .jpg files as HLS segments (for encrypted streams)
  ffmpeg.addArg "-allowed_segment_extensions"
  ffmpeg.addArg "jpg,ts,mpegts"
  # Disable strict extension checking
  ffmpeg.addArg "-extension_picky"
  ffmpeg.addArg "0"
  # ffmpeg's file protocol separately blocks opening local files whose
  # extension isn't in its own "common multimedia" allowlist (e.g. the
  # AES-128 key.bin mirrorHlsVod writes for encrypted streams) -- distinct
  # from allowed_segment_extensions/extension_picky above, which only cover
  # HLS segment naming, not generic file opens.
  ffmpeg.addArg "-allowed_extensions"
  ffmpeg.addArg "ALL"
  # Enable crypto protocol for AES-128 decryption
  ffmpeg.addArg "-protocol_whitelist"
  ffmpeg.addArg "file,http,https,tcp,tls,crypto"
  ffmpeg.addArg "-i"
  ffmpeg.addArg media.video

proc sanitizeFileName*(s: string) : string =
  const nega = ["[", "]", "/", "\\", "?", ",", ":"]
  result = s.replace(" ", "-")

  for ne in nega:
    result = result.replace(ne)

proc setOutput(ffmpeg: FfmpegDownloader, output: string, targetExt: string) =
  if not dirExists(ffmpeg.outdir) :
    createDir(ffmpeg.outdir)

  # Without -y, ffmpeg prompts on stdin when the output file already exists
  # (e.g. re-running into a previous download's directory) and hangs forever,
  # since nothing feeds its stdin. Always overwrite instead.
  ffmpeg.addArg "-y"
  ffmpeg.addArg "$#.$#" % [ffmpeg.outdir / output.sanitizeFileName(), targetExt]

proc handleSubtite(ffmpeg: FfmpegDownloader, media: MediaFormatData) =
  # Download and convert the sub-file to ass format.
  # Burn the subtitle.
  let
    file = media.subtitle.get.url
    tempFile = "wewbo_sub_file" & ".ass"

  # Set Input
  ffmpeg.addArg "-i"
  ffmpeg.addArg file

  # Set Subtite Codec [ASS]
  ffmpeg.addArg "-c:s"
  ffmpeg.addArg "ass"

  # Download
  ffmpeg.addArg tempFile

  if ffmpeg.execute("Downloading Subtitle...") < 1 :
    ffmpeg.setUpHeader(media.headers)
    ffmpeg.setInput(media)
    ffmpeg.addArg "-vf"
    ffmpeg.addArg "ass=" & tempFile

  else :
    raise newException(ValueError, "Gagal Download Subtitle Jir")

proc deleteTempFile {.nimcall.} = removeFile("wewbo_sub_file.ass")

proc deleteHlsMirror(mirrorDir: string) =
  # mirrorHlsVod() (src/http/impersonate.nim) downloads the whole VOD into
  # its own wewbo-hls-<oid> dir before handing it to ffmpeg; nothing else
  # ever reads it again once ffmpeg is done, so it's safe to remove here.
  if mirrorDir.extractFilename.startsWith("wewbo-hls-"):
    removeDir(mirrorDir)

proc download*(ffmpeg: FfmpegDownloader, input: MediaFormatData, output: string, targetExt: string = "mp4") : int =
  let hlsMirrorDir = input.video.parentDir()

  if input.subtitle.isSome and ffmpeg.options.sub:
    ffmpeg.log.info("Extracting subtitle.")
    ffmpeg.setUpHeader(input.headers)
    ffmpeg.handleSubtite(input)
  else:
    ffmpeg.setUpHeader(input.headers)
    ffmpeg.setInput(input)

  if ffmpeg.options.keepFormat:
    ffmpeg.addArg "-c"
    ffmpeg.addArg "copy"

  ffmpeg.setOutput(output, targetExt)
  result = ffmpeg.execute("Downloading " & output, after = some(AfterExecuteProc(deleteTempFile)))

  # Only clean up the mirror on success -- on failure it's the only evidence
  # of what curl-impersonate actually fetched, useful for debugging why
  # ffmpeg choked on it.
  if result == 0:
    deleteHlsMirror(hlsMirrorDir)
  else:
    ffmpeg.log.warn("Download failed, HLS mirror kept for inspection: " & hlsMirrorDir)

proc downloadAll*(ffmpeg: FfmpegDownloader, inputs: openArray[MediaFormatData], outputs: openArray[string]) : seq[int] {.deprecated.} =
  assert inputs.len == outputs.len

  ffmpeg.log.info("Downloading Options: " & $ffmpeg.options)    
  sleep(3_000)

  for (input, output) in zip(inputs, outputs) :
    result.add(
      ffmpeg.download(input, output))

proc downloadAll*(ffmpeg: FfmpegDownloader; inputs: openArray[FfmpegMediaInput]): seq[int] =
  var targetExt: string

  for (input, output, fmIdentity) in inputs:
    if not ffmpeg.options.keepFormat:
      targetExt = "mp4"
    else:
      # fmIdentity.ext is detected from the format *title* string (e.g.
      # "480p - SomeFansub"), which only happens to contain a recognizable
      # extension for some sources -- for mori it never does, so this was
      # always "" ("extNone"), producing an output filename with no
      # extension at all ("...Collar." -- ffmpeg then can't infer a muxer
      # and fails outright rather than downloading anything). Fall back to
      # mp4, same as the not-keepFormat case, rather than emit an
      # extensionless file.
      targetExt = $fmIdentity.ext
      if targetExt.len == 0:
        targetExt = "mp4"
    result.add ffmpeg.download(input, output, targetExt)
