import
  os, opt, sugar, sequtils, options,
  extractor/[all, types],
  tui/[base, logger, ask],
  media/[types, downloader, format],
  terminal/[command, paramarg]

proc download2*(f: FullArgument = nil) =
  let
    (animeTitle, exName) = parseTitleAndSource(f.nargs[0], f["source"].getStr())
    extractor = getExtractor(exName)
    anime = extractor.ask(animeTitle)
    epds = extractor.episodes extractor.get anime
    formatResolution = extractor.formats extractor.get epds[0]
    logger = useWewboLogger("Downloader")
    outputOverride = f["output"].getStr()
    defaultOutputDir =
      if outputOverride.len > 0: outputOverride
      else: getHomeDir() / "wewbo" / anime.title.sanitizeFileName()

  var
    inputs: seq[FfmpegMediaInput]
    args = OptionArgs()

  proc setArgsDownloader =
    let epdsLen = epds.len
    args.putRange(1, epdsLen, "Episode Range Start", 1)
    args.putRange(1, epdsLen, "Episode Range End", epdsLen)
    args.putEnum(formatResolution, "Format Resolution")

    block ffmpegDownloaderOption:
      args.put(defaultOutputDir, "Output Directory")
      args.putBool("With Subtitle")
      args.putBool("Keep Format")

  proc extract =
    if args["Output Directory"].s.dirExists():
      raise newException(RangeDefect, "The output directory is already exist. Try to change it.")

    var
      selectedSubtitleIndex = -1
      selectedFormatIndex = block:
        formatResolution
        .map(format => format.title)
        .find(args["Format Resolution"].s)
      selectedFormatResolution = args["Format Resolution"].s.detectFormat()  

    proc selectSubtitle(subs: seq[MediaSubtitle]): int {.inline.} =
      subs.find subs.ask("Select Subtitle")

    proc format(ept: EpisodeData): MediaFormatData =
      let
        episodeUrl = extractor.get(ept)
        allFormat = extractor.formats(episodeUrl)
        ex = extractor
        exmedia = findMatch(allFormat, some selectedFormatResolution)

      block selectFormatAndFallback:
        result = ex.get exmedia
        selectedFormatResolution = detectFormat exmedia.title
        logger.text("[DL] Selected Resolution: " & $selectedFormatResolution.res, color(fgGreen))

      if args["With Subtitle"].b: 
        let episodeSubtitles = ex.subtitles allFormat[selectedFormatIndex]

        if episodeSubtitles.isSome:
          let episodeSubs = episodeSubtitles.get

          if selectedSubtitleIndex == -1:
            selectedSubtitleIndex = selectSubtitle episodeSubs

          try:
            result.subtitle = some episodeSubs[selectedSubtitleIndex]
          except RangeDefect:
            let tempSelectedSubtitleIndex = selectSubtitle episodeSubs
            result.subtitle = some episodeSubs[tempSelectedSubtitleIndex]

        else:
          logger.text("[DL] Subtitle is not exist for this format. Skip", color(fgYellow))

    for ept in epds[args["Episode Range Start"].n - 1 .. args["Episode Range End"].n - 1]:
      logger.text("[DL] Extractiong format: " & ept.title, color(fgGreen))
      inputs.add((ept.format, ept.title, selectedFormatResolution))

  proc tryExtract =
    try:
      args.ask()
      extract()
    except Exception:
      logger.error("[DL] " & getCurrentExceptionMsg())
      tryExtract()  

  proc downloadAll =
    let
      ffmpegDownloadOption: FfmpegDownloaderOption = (
        crf: 25,
        fps: 25,
        sub: args["With Subtitle"].b,
        keepFormat: args["Keep Format"].b
      )
      downloader = newFfmpegDownloader(
        outdir = args["Output Directory"].s,
        options = ffmpegDownloadOption
      )
      outputCode = downloader.downloadAll(inputs)      

    logger.info("[DL] Inspecting")

    for (input, code) in zip(inputs, outputCode):
      if code < 1:
        logger.text("[DL] Success: " & input.outputName, color(fgGreen))
      else:
        logger.warn("[DL] Failed: " & input.outputName)  

  setArgsDownloader()
  tryExtract()
  downloadAll()

  logger.error("Task Completed")    
  illwillDeinit()
