util = util or {}

-- error('bonkers in util')

-- Iterator that returns successive hex dump lines from str.
function string.hexdump(str)
  local pos = 1
  return function()
    local hex, newpos
    if pos > 0 then
      hex, newpos = string.hexline(str, pos)
      if hex then
        hex = string.format('%05x  %s', pos - 1, hex)
        pos = newpos
      end
    else
      hex = nil
    end
    return hex
  end
end

function util.fprintf(fl, fmt, ...)
  fl:write(string.format(fmt, ...))
end

 function util.printf(fmt, ...)
  util.fprintf(io.stdout, fmt, ...)
end

function util.eprintf(fmt, ...)
  util.fprintf(io.stderr, fmt, ...)
end

function util.spairs(tbl, cmp)
  local sort_tbl = {}
  if 'table' == type(tbl) then
    for key, val in pairs(tbl) do
      table.insert(sort_tbl, key)
    end
  end
  table.sort(sort_tbl, cmp)
  local count = #sort_tbl
  local pos = 1
  return function ()
    if pos <= count then
      local key = sort_tbl[pos]
      pos = pos + 1
      return key, tbl[key]
    else
      return nil
    end
  end
end

-- This function conditions a key or value for display

local function lclRenderStr(Obj, TruncLen)
  local TpStr = type(Obj)
  if TpStr == "string" then
    -- Obj = string.gsub(Obj, "[^%w%p ]", function(Ch)
    Obj = string.gsub(Obj, "%c", function(Ch)
      return "\\" .. string.format("%03d", string.byte(Ch)) end )
    if TruncLen and TruncLen > 0 and string.len(Obj) > TruncLen + 3 then
      -- This could misleadingly truncate numeric escape value
      Obj = string.sub(Obj, 1, TruncLen) .. "..."
    end
    Obj = '"' .. Obj .. '"'
  elseif TpStr == "boolean" then
    Obj = "boolean: " .. tostring(Obj)
  else
    Obj = tostring(Obj)
  end
  return Obj
end

-- This function replaces ["x"]["y"] stubble with x.y. Keys are assumed to be
-- identifier-compatible.

local function lclShave(Str)
  local Count
  Str, Count = string.gsub(Str, '^%[%"(.+)%"%]$', '%1')
  if Count == 1 then
    Str = string.gsub(Str, '%"%]%[%"', '.')
  end
  return Str
end

local function lclRender(Tbl, Val, KeyStr, TruncLen, Lvl, Visited, KeyPathStr)
  local VtpStr, ValStr
  VtpStr = type(Val)
  if Visited[Val] then
    ValStr = "same as " .. Visited[Val]
  else
    ValStr = lclRenderStr(Val, TruncLen)
    if VtpStr == "function" then -- Display function's environment
      -- local Env = getfenv(Val)
      -- Env = Visited[Env] or Env
      -- ValStr = string.gsub(ValStr, "(function:%s*.*)$", "%1 (env " ..
        -- string.gsub(tostring(Env), "table: ", "")  .. ")")
    elseif VtpStr == "table" then
      ValStr = ValStr .. string.format(" (n = %d)", #Val)
    end
  end
  KeyPathStr = KeyPathStr .. "[" .. KeyStr .. "]"
  table.insert(Tbl, { Lvl, string.format('[%s] %s',
    KeyStr, ValStr) })
  if VtpStr == "table" and not Visited[Val] then
    Visited[Val] = lclShave(KeyPathStr)
    local SrtTbl = {}
    for K, V in pairs(Val) do
      table.insert(SrtTbl, { lclRenderStr(K, TruncLen), V, K, type(K) })
    end
    local function LclCmp(A, B)
      local Cmp
      local Ta, Tb = A[4], B[4]
      if Ta == "number" then
        if Tb == "number" then
          Cmp = A[3] < B[3]
        else
          Cmp = true -- Numbers appear first
        end
      else -- A is not a number
        if Tb == "number" then
          Cmp = false -- Numbers appear first
        else
          Cmp = A[1] < B[1]
        end
      end
      return Cmp
    end
    table.sort(SrtTbl, LclCmp)
    for J, Rec in ipairs(SrtTbl) do
      lclRender(Tbl, Rec[2], Rec[1], TruncLen, Lvl + 1, Visited, KeyPathStr)
    end
  end
end

-- This function appends a series of records of the form { level,
-- description_string } to the indexed table specified by Tbl. When this
-- function returns, Tbl can be used to inspect the Lua object specified by
-- Val. Key specifies the name of the object. TruncLen specifies the maximum
-- length of each description string; if this value is zero, no truncation will
-- take place. Keys are sorted natively (that is, numbers are sorted
-- numerically and everything else lexically). String values are displayed with
-- quotes, numbers are unadorned, and all other values have an identifying
-- prefix such as "boolean". Consequently, all keys are displayed within their
-- type partition. This function returns nothing; its only effect is to augment
-- Tbl.

function util.describe(Tbl, Val, Key, TruncLen)
  lclRender(Tbl, Val, lclRenderStr(Key, TruncLen), TruncLen or 0, 1, {}, "")
end

-- This function prints a hierarchical summary of the object specified by Val
-- to standard out. See util.describe for more details.

function util.show(Val, Key, TruncLen)
  local Tbl = {}
  util.describe(Tbl, Val, Key, TruncLen)
  for J, Rec in ipairs(Tbl) do
    io.write(string.rep("  ", Rec[1] - 1), Rec[2], "\n")
  end
end

-- Replace plain keys with plain values. For example,
-- 'aCATbDOGcCATdDOGe' <- util.replace('acatbdogccatddogestr', 'cat', 'CAT', 'dog', 'DOG')
function util.replace(str, ...)
  local kvlist = {...}
  local keypos = 1
  while keypos < #kvlist do
    local list = {str}
    local key, val = kvlist[keypos], kvlist[keypos + 1]
    keypos = keypos + 2
    repeat
      local pos = #list
      local a, b = string.find(list[pos], key, 1, true)
      if a then
        list[pos + 1] = val
        list[pos + 2] = string.sub(list[pos], b + 1)
        list[pos] = string.sub(list[pos], 1, a - 1)
      end
    until not a
    if #list > 1 then
      str = table.concat(list)
    end
  end
  return str
end

function util.fileread(filename)
  local str, hnd, err
  hnd = io.open(filename, 'r')
  if hnd then
    str = hnd:read('a')
    if str then
      -- ok
    else
      err = 'error reading content from ' .. filename
    end
    hnd:close()
  else
    err = 'error opening ' .. filename .. ' for reading'
  end
  return util.ret(str, err)
end

function util.filewrite(filename, content)
  local ok, hnd, err
  hnd = io.open(filename, 'w')
  if hnd then
    if hnd:write(content) then
      ok = true
    else
      err = 'error writing content to ' .. filename
    end
    hnd:close()
  else
    err = 'error opening ' .. filename .. ' for writing'
  end
  return util.ret(ok, err)
end

-- Return (ok) if err is nil, (nil, err) otherwise.
function util.ret(ok, err)
  if err then
    return nil, err
  end
  return ok
end

-- Encode each nonalphanumeric character and 'q' to 'q%02x'.
util.qencode = function(str)
  return (str:gsub('[^a-pr-zA-Z0-9]', function(s) return string.format('q%02x', string.byte(s)) end))
end

util.qdecode = function(str)
  return (str:gsub('q(%x%x)', function(x) return string.char(tonumber(x, 16)) end))
end

-- Encode each nonalphanumeric character and 'z' to 'z%02x'.
util.zencode = function(str)
  return (str:gsub('[^a-yA-Z0-9]', function(s) return string.format('z%02x', string.byte(s)) end))
end

util.zdecode = function(str)
  return (str:gsub('z(%x%x)', function(x) return string.char(tonumber(x, 16)) end))
end

util.execute = function(fmt, ...)
  local cmd = string.format(fmt, ...)
  local ok = os.execute(cmd)
  return ok
end

-- Convert 'One, two, three' to 'one-two-three'.
util.titletoname = function(title)
  return (title:lower():gsub('%W', '-'):gsub('%-%-+', '-'):gsub('^%-+', ''):gsub('%-+$', ''))
end

local function lclmkdir(dirstr)
  local ok = lfs.attributes(dirstr, 'mode') == 'directory'
  if not ok then
    local substr = string.match(dirstr, '^(.*)[\\/]')
    if substr then
      if not lclmkdir(substr) then
        -- util.printf('creating [%s]\n', substr)
        lfs.mkdir(substr)
      end
    end
  end
  return ok
end

-- Make the specified directory including intermediate subdirectories if
-- needed. Return true if dirstr already exists or is successfully created.
util.mkdir = function(dirstr)
  lclmkdir(dirstr .. '/')
  return lfs.attributes(dirstr, 'mode') == 'directory'
end

-- Return str. If length of str exceeds len, it will be truncated to that
-- length and an ellipsis will be appended. If middle is true and the length of
-- str exceeds len, then characters from the middle of the string are replaced
-- with an ellipsis.
-- function util.shortstr(str, len, middle)
--   if not len then
--     len = 24
--   end
--   if #str > len then
--     if middle then
--       local leftlen = len // 2
--       str = str:sub(1, leftlen) .. '…' .. str:sub(leftlen - len)
--     else
--       str = str:sub(1, len) .. '…'
--     end
--   end
--   return str
-- end

-- Return str or a shortened form of str. If the length of str exceeds the sum
-- of left and right, the string that is returned comprises the first left
-- characters followed by three periods followed by the final right characters.
-- The default values of left and right are 24 and 0, respectively.
function util.shortstr(str, left, right)
  local s
  left = left or 24
  right = right or 0
  if #str > left + right then
    s = str:sub(1, left) .. '...'
    if right > 0 then
      s = s .. str:sub(-right)
    end
    str = s
  end
  return str
end

-- Convert, for example, a command-line argument table like
--   { '--foo=bar', '--baz=quux', '--name="Don Quixote"', 'xyz', '"abc def ghi"' }
-- to a mixed table like
--   {[1] = "xyz", [2] = "abc def ghi", ["baz"] = "quux", ["foo"] = "bar", ["name"] = "Don Quixote" }
util.args = function(arg)
  local a = {}
  local count = 0
  for j = 1, #arg do
    local key, val = string.match(arg[j], '^%-%-(.-)%=(.*)$')
    if key then
      a[key] = val
    else
      count = count + 1
      a[count] = arg[j]
    end
  end
  return a
end

-- Clean path
util.pathclean = function(str)
  local gs = string.gsub
  local c, count
  repeat
    str, count = gs(str, '//+', '/')
    str, c = gs(str, '/%./', '/')
    count = count + c
    str, c = gs(str, '/[^/]*/%.%./', '/')
    count = count + c
    str, c = string.gsub(str, '^/%.%.', '')
    count = count + c
  until count == 0
  return str
end

-- Join all path arguments and clean result
util.pathjoin = function(...)
  return util.pathclean(table.concat({...}, '/'))
end
