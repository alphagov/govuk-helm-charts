local cjson = require "cjson"

local headersToEcho = ngx.req.get_headers()
-- These should all be lower-case
local headersToRedact = {
  "authorization",
  "cookie",
  "proxy-authorization",
  "set-cookie",
  "x-amz-security-token",
  "x-forwarded-for",
}

-- Belt and braces lowercase the above table to make sure we don't accidentally add one
-- that's not lower case
for i, headerToRedact in pairs(headersToRedact) do
  headersToRedact[i] = string.lower(headerToRedact)
end

for headerName, _ in pairs(headersToEcho) do
  local lowercaseHeaderName = string.lower(headerName)

  for _, headerToRedact in pairs(headersToRedact) do
    if lowercaseHeaderName == headerToRedact then
      headersToEcho[headerName] = "**REDACTED**"
    end
  end
  
  if string.find(string.lower(headerName), "api-key", 1, true) then
    headersToEcho[headerName] = "**REDACTED**"
  end
end

ngx.header.content_type = "application/json"
ngx.status = 200
ngx.say(cjson.encode({
  ["method"] = ngx.req.get_method(),
  ["requestHeaders"] = headersToEcho,
}))
