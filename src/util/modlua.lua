local function fread(filestr, ...)
  local str
  local hnd = io.open(filestr, 'r')
  if hnd then
    str = hnd:read(...)
    hnd:close()
  end
  return str
end

local function log(...)
  local hnd, err = io.open('log', 'a+')
  if hnd then
    hnd:write(...)
    hnd:close()
  end
end

--- lua file system ---
local lfsver = fread('lfs.c', 'a') or ''
lfsver = lfsver:match('LFS_VERSION "(.-)"') or '---'
lfsver = string.format('LuaFileSystem %s  Copyright (C) Kepler Project', lfsver)

-- discount ---
local dver = fread('links/discount/VERSION', 'l') or '---'
dver = string.format('Discount %s  Copyright (C) David L Parsons', dver)

-- lua discount ---
local ldver = fread('discount.c', 300)
ldver = ldver:gsub('^.-(Lua.-library).-(Copyright.-Barnes).*$', '%1  %2')

-- gumbo ---
local gver = fread('links/gumbo/lib/parser.c', 300)
local gver = gver:gsub('^.-(Copy.-Barnes).-(Copy.-Google Inc).*$', 'Gumbo HTML5 parser  %1, %2')

-- lua gumbo ---
local lgver = fread('links/gumbo/gumbo/parse.c', 300)
local lgver = lgver:gsub('^.-(Copy.-Barnes).*$', 'Lua bindings for the Gumbo HTML5 parser  %1')

local str = io.read('a')
str = str:gsub('luaL_openlibs%(L%);', '%1 void mlib(lua_State *L); mlib(L);')
  :gsub('print_version%(%);', '{ %1 printf("' ..
  lfsver  .. '\\n' .. dver .. '\\n' .. ldver .. '\\n' .. gver .. '\\n' .. lgver .. '\\n"); }')
io.write(str)
