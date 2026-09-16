------------------
-- HTTP status codes.
------------------

local HTTP = {
  [100] = "Continue",
  [101] = "Switching Protocols",
  [200] = "OK",
  [201] = "Created",
  [202] = "Accepted",
  [204] = "No Content",
  [206] = "Partial Content",
  [301] = "Moved Permanently",
  [302] = "Found",
  [303] = "See Other",
  [304] = "Not Modified",
  [307] = "Temporary Redirect",
  [308] = "Permanent Redirect",
  [400] = "Bad Request",
  [401] = "Unauthorized",
  [402] = "Payment Required",
  [403] = "Forbidden",
  [404] = "Not Found",
  [405] = "Method Not Allowed",
  [406] = "Not Acceptable",
  [408] = "Request Timeout",
  [409] = "Conflict",
  [410] = "Gone",
  [412] = "Precondition Failed",
  [413] = "Payload Too Large",
  [415] = "Unsupported Media Type",
  [418] = "I'm a teapot",
  [422] = "Unprocessable Entity",
  [425] = "Too Early",
  [428] = "Precondition Required",
  [429] = "Too Many Requests",
  [431] = "Request Header Fields Too Large",
  [451] = "Unavailable For Legal Reasons",
  [500] = "Internal Server Error",
  [501] = "Not Implemented",
  [502] = "Bad Gateway",
  [503] = "Service Unavailable",
  [504] = "Gateway Timeout",
  [505] = "HTTP Version Not Supported",
}

local function decode_http(text)
  local n = tonumber(text:match("^(%d%d%d)$") or "")
  if not n or n < 100 or n > 599 then
    return nil
  end
  local class = ({ "informational", "success", "redirection", "client error", "server error" })[math.floor(n / 100)]
  local name = HTTP[n]
  if not name and not class then
    return nil
  end
  return { "HTTP " .. n .. (name and ("  " .. name) or ""), "", "class  " .. (class or "unknown") }
end

return decode_http
