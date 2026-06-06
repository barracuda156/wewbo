import ../base

import
  http/[client, response]

import base64, strutils, json, options

import
  zippy

type
  MoriruEX = ref object of BaseExtractor

const
  OBF_KEY = "71951034f8fbcf53d89db52ceb3dc22c"
  SEARCH_TEMPLATE = """{"path":"search","method":"GET","query":{"q":"$#","limit":15,"offset":0,"type":"ANIME","sort":"POPULARITY_DESC"},"body":null,"version":"0.2.0"}"""
  LIST_EPISODE_TEMPLATE = """{"path":"episodes","method":"GET","query":{"anilistId":"$#"},"body":null,"version":"0.2.0"}"""
  LIST_FORMAT_TEMPLATE = """{"path":"sources","method":"GET","query":{"episodeId":"$#","provider":"kiwi","category":"sub","anilistId":$#},"body":null,"version":"0.2.0"}"""
  PROVIDER = "kiwi" # Gua gabisa move on dari animepahe.

proc newMoriru*(ex: var BaseExtractor) =
  ex = MoriruEX(
    name: "mori",
    host: "miruro.tv"
  )

proc decode(ex: MoriruEX; text: string): string =
  var b64 = text.replace("-", "+").replace("_", "/")
  let padLen = (4 - b64.len mod 4) mod 4
  
  b64.add(repeat('=', padLen))
  
  var data = decode(b64)
  let key = parseHexStr(OBF_KEY)
  
  # XOR deobfuscation
  for i in 0 ..< data.len:
    data[i] = char(uint8(data[i]) xor uint8(key[i mod key.len]))
  
  return uncompress(data, dataFormat = dfGzip)

proc toSlug(title: string): string =
  const notAllowed = ["’", ",", "@", "#", "'"]

  result = title.toLowerAscii().replace(" ", "-")

  for niga in notAllowed:
    result = result.replace(niga)

method animes*(ex: MoriruEX; title: string) : seq[AnimeData] =
  let
    encodedResp = ex.connection.req("/api/secure/pipe?e=" & (SEARCH_TEMPLATE % title).encode).to_readable()
    decodedResp = ex.decode(encodedResp).parseJson()

  for anime in decodedResp:
    let
      title = anime["title"]["romaji"].getStr()
      id = anime["id"].getInt()
      url = ["/watch", $id].join("/") & "|" & $anime["episodes"].getInt()
    
    result.add AnimeData(
      title: title,
      url: $id
    )

  # echo decodedResp    
  
method episodes*(ex: MoriruEX; animeId: string) : seq[EpisodeData] =
  let
    encodedResp = ex.connection.req("/api/secure/pipe?e=" & (LIST_EPISODE_TEMPLATE % animeId).encode).to_readable()
    decodedResp = ex.decode(encodedResp).parseJson()

  for eps in decodedResp["providers"][PROVIDER]["episodes"]["sub"]:
    let title = "$# - $#" % [$eps["number"].getInt(), eps["title"].getStr()]

    result.add EpisodeData(
      title: title,
      url: eps["id"].getStr() & "|" & animeId 
    )

method formats*(ex: MoriruEX; episodeUrl: string) : seq[ExFormatData] =
  let
    encodedResp = ex.connection.req("/api/secure/pipe?e=" & (LIST_FORMAT_TEMPLATE % episodeUrl.split("|")).encode).to_readable()
    decodedResp = ex.decode(encodedResp).parseJson()

  for stream in decodedResp["streams"]:
    if not (stream["type"].getStr() == "embed"):
      let
        quality = stream["quality"].getStr()
        fansub = stream["fansub"].getStr()
        url = stream["url"].getStr()

      result.add ExFormatData(
        title: [quality, fansub].join(" - "),
        formatIdentifier: url
      )

method get*(ex: MoriruEX; data: ExFormatData) : MediaFormatData =
  let header = MediaHttpHeader(
    referer: "https://kwik.cx/"
  )
  
  result = MediaFormatData(
    video: data.format_identifier,
    headers: some header,
    typeExt: extM3u8
  )
