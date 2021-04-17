url = {}

local char_to_hex = function(c)
  return string.format("%%%02X", string.byte(c))
end

-- URLEncode url. If plus is not nil or false, translate each ' ' to '+'.
url.encode = function(url, plus)
  if url ~= nil then
    local pat
    if plus then
      pat = '([^%w%-%.%_%~ ])'
    else
      pat = '([^%w%-%.%_%~])'
    end
    -- unreserved  = ALPHA / DIGIT / "-" / "." / "_" / "~"
    -- https://tools.ietf.org/html/rfc3986#section-2.3
    url = url:gsub('\n', '\r\n'):gsub(pat, char_to_hex):gsub(' ', '+')
  end
  return url
end

local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

url.decode = function(url)
  if url ~= nil then
    url = url:gsub('+', ' '):gsub('%%(%x%x)', hex_to_char)
  end
  return url
end

-- ref: https://gist.github.com/ignisdesign/4323051
-- ref: http://stackoverflow.com/questions/20282054/how-to-urldecode-a-request-uri-string-in-lua
-- to encode table as parameters, see https://github.com/stuartpb/tvtropes-lua/blob/master/urlencode.lua
