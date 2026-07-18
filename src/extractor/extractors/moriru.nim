import ../base

import
  http/impersonate

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

  # Miruro's pipe endpoint sits behind Cloudflare and rejects plain
  # httpclient/OpenSSL requests outright. curl-impersonate replicates a real
  # Chrome TLS fingerprint (JA3/JA4), which is what actually gets through;
  # the same-origin headers below mirror what a real page load sends.
  # See: https://github.com/walterwhite-69/Miruro-API/commit/dfb38a646e28afa5b6f14e4b4d9d542b2bf894df
  IMPERSONATE_HEADERS = [
    ("Referer", "https://www.miruro.tv/"),
    ("Origin", "https://www.miruro.tv"),
    ("Sec-Fetch-Site", "same-origin"),
    ("Sec-Fetch-Mode", "cors"),
    ("Sec-Fetch-Dest", "empty"),
    ("Sec-Ch-Ua", "\"Chromium\";v=\"124\", \"Not-A.Brand\";v=\"99\", \"Google Chrome\";v=\"124\""),
    ("Sec-Ch-Ua-Mobile", "?0"),
    ("Sec-Ch-Ua-Platform", "\"Windows\""),
  ]

proc newMoriru*(ex: var BaseExtractor) =
  ex = MoriruEX(
    name: "mori",
    host: "miruro.tv"
  )

proc pipeReq(ex: MoriruEX; encoded: string): string =
  # Bare miruro.tv 302-redirects (via Cloudflare) to www.miruro.tv; hitting
  # www. directly avoids that hop and is what actually serves the pipe.
  impersonatedGet(
    "https://www." & ex.host & "/api/secure/pipe?e=" & encoded,
    headers = IMPERSONATE_HEADERS
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
    encodedResp = ex.pipeReq (SEARCH_TEMPLATE % title).encode
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
    encodedResp = ex.pipeReq (LIST_EPISODE_TEMPLATE % animeId).encode
    decodedResp = ex.decode(encodedResp).parseJson()

  for eps in decodedResp["providers"][PROVIDER]["episodes"]["sub"]:
    let title = "$# - $#" % [$eps["number"].getInt(), eps["title"].getStr()]

    result.add EpisodeData(
      title: title,
      url: eps["id"].getStr() & "|" & animeId 
    )

method formats*(ex: MoriruEX; episodeUrl: string) : seq[ExFormatData] =
  let
    encodedResp = ex.pipeReq (LIST_FORMAT_TEMPLATE % episodeUrl.split("|")).encode
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
  # owocdn.top (miruro's CDN) 403s ffmpeg/ffplay's own HTTPS client the same
  # way it 403s plain curl — it's checking the TLS fingerprint, not just the
  # referer. Neither the player nor ani-dl's ffmpeg downloader can fetch this
  # CDN directly, so mirror the whole VOD locally via curl-impersonate first
  # and hand the player a local playlist instead of the remote one.
  #
  # The Referer here is only for curl-impersonate's own fetches -- once
  # mirrored, ffmpeg reads purely local files (playlist/key/segments), and
  # -headers is an HTTP-only ffmpeg option: passing it errors out with
  # "Option headers not found" when ffmpeg opens the local key/segment
  # files, so MediaFormatData.headers must stay unset here.
  let localPlaylist = mirrorHlsVod(
    data.format_identifier,
    headers = [("Referer", "https://kwik.cx/")],
    log = proc(text: string) = ex.lg.info(text)
  )

  result = MediaFormatData(
    video: localPlaylist,
    typeExt: extM3u8
  )
