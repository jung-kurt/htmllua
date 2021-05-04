#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <string.h>

int luaopen_lfs(lua_State *L);
int lpipe3(lua_State *L);
int fullmkdir(const char *dir);
extern unsigned char script_lua[1];
extern unsigned int script_lua_len;

static void require(lua_State *L, const char * name, lua_CFunction openf) {
  luaL_requiref(L, name, openf, 1);
  lua_pop(L, 1);
}

static void loadextra (lua_State *L) {
  require(L, "lfs", luaopen_lfs);
}

/* str points to a buffer which will be filled according to the following
format:

    xx xx xx xx  xx xx xx xx  xx xx xx xx  xx xx xx xx  abcdefghijklmnop

The buffer needs to be at least 69 bytes long to accommodate the string and its
null terminator. The xx fields will be filled with hexidecimal values
indicating the bytes beginning at bufptr. The 16 rightmost characters are ASCII
codes for the corresponding bytes having values between the blank and the tilde
inclusive. Len is a value from 0 to 16. If Len is greater than 16 it is set
equal to 16. In all cases, the string is set to a length of 68. Blanks fill any
position beyond Len. */

void hexstr(char * str, const void * bufptr, int buflen) {
  unsigned char * byteptr;
  unsigned char val;
  char ch;
  char * asciistr;
  int j, skip;

  if (buflen > 0) {
    byteptr = (unsigned char *) bufptr;
    memset(str, ' ', 68);
    str[68] = 0;
    asciistr = str + 52;
    if (buflen > 16) buflen = 16;
    j = 0;
    while (buflen > 0) {
      val = *(byteptr++);
      if ((val >= ' ') && (val <= '~')) ch = (char) val;
      else ch = '.';
      *(asciistr++) = ch;
      ch = (char) ('0' + (val >> 4));
      if (ch > '9') ch += (char) 7;
      *(str++) = ch;
      ch = (char) ('0' + (val & 15));
      if (ch > '9') ch += (char) 7;
      *str = ch;
      j++;
      if ((j & 3) == 0) skip = 3;
      else skip = 2;
      str += skip;
      buflen--;
    } // while
  } // if
  else *str = 0;
}

// (hexstr, newpos) or (nil, error) <- hexline(str, pos)
// newpos is set to zero when the final part of str has been processed.
static int hexline(lua_State *L) {
  char errbuf[128];
  char hexbuf[128];
  const char * errstr;
  const char * srcstr;
  size_t buflen, srcpos, srclen;
  lua_Integer lpos;

  srcstr = luaL_checklstring(L, 1, &srclen);
  if (srcstr) {
    lpos = luaL_checkinteger(L, 2); // 1-based
    if (lpos > 0) {
      srcpos = (size_t) lpos;
      if (srcpos <= srclen) {
        buflen = srclen - srcpos + 1;
        if (buflen > 16) buflen = 16;
        hexstr(hexbuf, srcstr + srcpos - 1, buflen);
        srcpos += buflen;
        if (srcpos > srclen) srcpos = 0;
        lua_pushstring(L, hexbuf);
        lua_pushinteger(L, srcpos);
        return 2;
      } else {
        sprintf(errbuf, "hexline: position (%lu) exceeds length (%lu)", srcpos, srclen);
        errstr = errbuf;
      }
    } else errstr = "hexline: expecting argument 2 to be integer greater than zero";
  } else errstr = "hexline: expecting argument 1 to be string";
  lua_pushnil(L);
  lua_pushstring(L, errstr);
  return 2;
}

void mlib(lua_State *L) {
  int rc;

  loadextra(L);
  // ...
  rc = luaL_loadbuffer(L, (const char *) script_lua, script_lua_len, "script");
  // # err or fnc
  if (LUA_OK == rc) {
    // # fnc
    lua_call(L, 0, 0);
    // ...
    lua_getglobal(L, "string");
    // ... string
    lua_pushcfunction(L, hexline);
    // ... string hexline
    lua_setfield(L, -2, "hexline");
    // ... string
    lua_pop(L, 1);
    // ...
    lua_getglobal(L, "os");
    // ... os
    lua_pushcfunction(L, lpipe3);
    // ... os lpipe3
    lua_setfield(L, -2, "pipe3");
    // ... os
    lua_pop(L, 1);
    // ...
  } else lua_error(L);
}
