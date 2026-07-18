## Shells out to curl-impersonate (https://github.com/lexiforest/curl-impersonate)
## for requests that need a real browser TLS fingerprint to get past
## Cloudflare's bot detection. Only used where the plain Nim httpclient
## gets blocked outright.

import std/[os, osproc, strutils]

type
  ImpersonateError* = object of CatchableError

proc findCurlImpersonate(browser: string): string =
  ## Looks for a curl-impersonate wrapper script (e.g. curl_chrome124) on
  ## PATH, or at the path given by the WEWBO_CURL_IMPERSONATE env var.
  let override = getEnv("WEWBO_CURL_IMPERSONATE")
  if override.len > 0:
    return override

  result = findExe("curl_" & browser)
  if result.len == 0:
    raise newException(ImpersonateError,
      "curl_" & browser & " not found on PATH (get it from " &
      "https://github.com/lexiforest/curl-impersonate/releases, or set " &
      "WEWBO_CURL_IMPERSONATE to its full path)")

proc impersonatedGet*(
  url: string,
  headers: openArray[(string, string)] = [],
  browser: string = "chrome124"
): string =
  ## Performs a GET request via curl-impersonate and returns the response
  ## body. Raises ImpersonateError on a non-2xx/3xx status or if the binary
  ## can't be found.
  let bin = findCurlImpersonate(browser)

  var args = @["-s", "-o", "-", "-w", "\n__WEWBO_STATUS__%{http_code}"]
  for (k, v) in headers:
    args.add "-H"
    args.add(k & ": " & v)
  args.add url

  let output = execProcess(bin, args = args, options = {poUsePath})
  let marker = "\n__WEWBO_STATUS__"
  let markerPos = output.rfind(marker)

  if markerPos < 0:
    raise newException(ImpersonateError, "curl-impersonate produced no status marker (binary may have crashed)")

  let
    body = output[0 ..< markerPos]
    status = output[markerPos + marker.len .. ^1].strip()
    code = try: parseInt(status) except ValueError: 0

  if code < 200 or code >= 400:
    raise newException(ImpersonateError, "curl-impersonate got HTTP " & status & " for " & url)

  return body
