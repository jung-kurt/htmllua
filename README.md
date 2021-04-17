# HTML Lua

This project builds a version of Lua with tools to parse HTML5 and to render it
from Markdown. The modules that implement this functionality are preloaded into
Lua. This embedding eliminates the need to maintain external modules and search
paths.

## Dependencies

This project depends on installed versions of the following software.

* [Lua](https://www.lua.org/)
* [Discount](https://github.com/Orc/discount)
* [Lua Gumbo](https://craigbarnes.gitlab.io/lua-gumbo/)

Additionally, the following software is included in this repository.

* [Lua Discount](https://gitlab.com/craigbarnes/lua-discount)
* [Lua Filesystem](https://github.com/keplerproject/luafilesystem)
* [json.lua](https://github.com/rxi/json.lua)
* [Lua table persistence](https://github.com/hipe/lua-table-persistence)

Building HTML Lua uses the following tool.

* [strliteral](https://github.com/mortie/strliteral)

## Building

The following symbolic links need to be made.

```
src
   links
      lua -> /path/to/lua-repo
      gumbo -> /path/to/lua-gumbo-repo
      discount -> /path/to/discount-repo
```

The projects that the links point to should be already successfully built but
do not need to be installed.

The [strliteral](https://github.com/mortie/strliteral) utility should be
somehwere on the PATH.

GNU make should be used (`gmake` on some systems) to handle stem rules in the
Makefile.

```
cd htmllua/src
make
```

The resulting binary can be used as an augmented version of [standalone
Lua](https://www.lua.org/manual/5.4/manual.html#7).

## Sample usage

The following example can be used to generate a website from Google Drive.

```lua
local err, prm
prm = util.args(arg)

if prm.template and prm.site and prm.url and prm.cache then
  err = drive.websitegenerate(prm.template, prm.site, prm.url, prm.cache)
else
  err = 'expecting --template, --site, --url, and --cache arguments'
end

if err then
  io.stderr:write(err)
end
```
