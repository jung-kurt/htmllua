-- lua embed.lua OUTPUT INPUT1, INPUT2, ...

-- TODO
-- Use binary search in C to identify embedded resource. This will require
-- postponement of record assignment to end of function.

local pr = io.write

local mimetab = {
  txt = 'text/plain',
  css = 'text/css',
  html = 'text/html',
  js = 'text/javascript',
  gif = 'image/gif',
  jpg = 'image/jpeg',
  jpeg = 'image/jpeg',
  png = 'image/png',
  svg = 'image/svg+xml',
  pdf = 'application/pdf',
}

local numtab = {}
for j = 0, 255 do
  numtab[string.char(j)] = string.format('%3d,', j)
end

dotstr = string.rep('.', 80)

timestr = os.date('%a, %d %b %Y %H:%M:%S %Z')

local function prf(fmt, ...)
  pr(string.format(fmt, ...))
end

math.randomseed()

local charstr = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

local function randomStr(length)
  local list = {}
  for j = 1, length do
    local pos = math.random(1, #charstr)
    list[#list + 1] = string.sub(charstr, pos, pos)
  end
  return table.concat(list)
end

local function hdr()
  pr [[
#include "lua.h"
#include <string.h>
#include "cgilua.h"

int staticget(const char * key, staticPtrType recPtr) {

]]
end

local function ftr()
  pr [[
  memset(recPtr, 0, sizeof(*recPtr));
  return 1;
}
]]
end

local function embed(pos, filestr)
  local hnd, err = io.open(filestr, 'r')
  if hnd then
    local str = hnd:read('a')
    if str then
      local len = #str
      str = str:gsub('.', numtab)
      str = str:gsub(dotstr, '%0\n')
      local dir, base = string.match(filestr, '^(.-)([^/]*)$')
      local ext = string.match(base, '([^.]+)%.gz$')
      if not ext then
        ext = string.match(base, '([^.]+)$')
        if not ext then
          ext = base
        end
      end
      local mime = mimetab[ext] or 'application/octet-stream'
      prf('const unsigned char b%d[] = {\n', pos)
      pr(str, '};\n')
      prf('if (0 == strcmp(key, "%s")) {\n', base)
      prf('  recPtr->len = %d;\n', len)
      prf('  recPtr->data = b%d;\n', pos)
      prf('  recPtr->mimeStr = "%s";\n', mime)
      prf('  recPtr->etagStr = "%s";\n', randomStr(32))
      prf('  recPtr->modDateStr = "%s";\n', timestr)
      prf('  return 0;\n')
      pr('}\n\n')
    end
    hnd:close()
  end
  return err == nil, err
end

local ret, ok, err
ret = 1
if #arg > 1 then
  ok = pcall(io.output, arg[1])
  if ok then
    hdr()
    local j = 2
    while j <= #arg and not err do
      ok, err = embed(j - 1, arg[j])
      j = j + 1
    end
    ftr()
   else
     err = 'error opening output file ' .. arg[1]
   end
else
  err = 'expecting output filename and at least one input filename'
end
if err then
  io.stderr:write(err, '\n')
  os.exit(1)
end
os.exit(0)
