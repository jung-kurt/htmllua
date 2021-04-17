#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#define unused(x) (void)(x)

// Three pipes are created, one each for stdin, stdout and stderr. They are
// indexed arbitrarily by the parent process's context.

#define NUM_PIPES          3

#define PARENT_WRITE_PIPE  0
#define PARENT_READ_PIPE   1
#define PARENT_READ_ERR_PIPE   2

// In each case, pipe[0] is for read and pipe[1] is for write
#define READ_FD  0
#define WRITE_FD 1

#define PARENT_READ_FD  ( pipes[PARENT_READ_PIPE][READ_FD]   )
#define PARENT_READ_ERR_FD  ( pipes[PARENT_READ_ERR_PIPE][READ_FD]   )
#define PARENT_WRITE_FD ( pipes[PARENT_WRITE_PIPE][WRITE_FD] )

#define CHILD_READ_FD   ( pipes[PARENT_WRITE_PIPE][READ_FD]  )
#define CHILD_WRITE_FD  ( pipes[PARENT_READ_PIPE][WRITE_FD]  )
#define CHILD_WRITE_ERR_FD  ( pipes[PARENT_READ_ERR_PIPE][WRITE_FD]  )

static void wr(int fd, const char * str) {
  ssize_t count;
  count = write(fd, str, strlen(str));
  unused(count);
}

// (cmd output) or (nil, error) <- lpipe3({fullpathcmdstr, arg1, ..., arg1}, tostr)
int lpipe3(lua_State *L) {
  int pipes[NUM_PIPES][2];
  const char * tostr;
  pid_t pid;
  size_t tolen;
  luaL_Buffer buf, errBuf;
  lua_Integer j, tbllen;
  const char * * args;

  luaL_buffinit(L, &buf);
  luaL_buffinit(L, &errBuf);
  if (lua_istable(L, 1)) {
    tostr = lua_tolstring(L, 2, &tolen);
    tbllen = luaL_len(L, 1);
    args = calloc(tbllen + 1, sizeof(char *));
    if (args) {
      for (j = 1; j <= tbllen; j++) {
        lua_rawgeti(L, 1, j);
        args[j - 1] = lua_tostring(L, -1);
        lua_pop(L, 1);
      }
      args[tbllen] = (char *) 0;
      // pipes for parent to write and read
      if (0 == pipe(pipes[PARENT_READ_PIPE])) {
        if (0 == pipe(pipes[PARENT_WRITE_PIPE])) {
          if (0 == pipe(pipes[PARENT_READ_ERR_PIPE])) {
            pid = fork();
            if (0 == pid) {
              dup2(CHILD_READ_FD, STDIN_FILENO);
              dup2(CHILD_WRITE_FD, STDOUT_FILENO);
              dup2(CHILD_WRITE_ERR_FD, STDERR_FILENO);
              // Close descriptors not required by child.
              close(CHILD_READ_FD);
              close(CHILD_WRITE_FD);
              close(CHILD_WRITE_ERR_FD);
              close(PARENT_READ_FD);
              close(PARENT_READ_ERR_FD);
              close(PARENT_WRITE_FD);
              execv(args[0], (char * const *) args);
              // Trouble: execv returned, something that happens only when the
              // child process could not be started. Report the error (using
              // the stderr pipe to the parent) and bail out of this forked
              // process.
              wr(STDERR_FILENO, "error calling ");
              wr(STDERR_FILENO, args[0]);
              // Exit the child; this will close pipes and allow parent to proceed
              exit(1);
            } else if (-1 != pid) {
              ssize_t count;
              int ok;
              // Close descriptors not required by parent. Others will be
              // closed after use.
              close(CHILD_READ_FD);
              close(CHILD_WRITE_FD);
              close(CHILD_WRITE_ERR_FD);
              // Write to child’s stdin
              if (tolen) {
                count = write(PARENT_WRITE_FD, tostr, tolen);
                ok = (count == (ssize_t) tolen);
              } else ok = 1;
              // Closing child's standard input will signal to the child that
              // there is no more content to arrive.
              close(PARENT_WRITE_FD);
              if (ok) {
                ssize_t got;
                char readBuf[4096];
                // Read child's stdout
                do {
                  got = read(PARENT_READ_FD, readBuf, sizeof(readBuf));
                  if (got > 0) {
                    luaL_addlstring(&buf, readBuf, got);
                  }
                } while (got == sizeof(readBuf));
                // Read child's stderr
                do {
                  got = read(PARENT_READ_ERR_FD, readBuf, sizeof(readBuf));
                  if (got > 0) {
                    luaL_addlstring(&errBuf, readBuf, got);
                  }
                } while (got == sizeof(readBuf));
              } else luaL_addstring(&errBuf, "error writing to child's stdin");
              close(PARENT_READ_FD);
              close(PARENT_READ_ERR_FD);
            } else luaL_addstring(&errBuf, "error forking process");
          } else luaL_addstring(&errBuf, "error creating parent read error pipe");
        } else luaL_addstring(&errBuf, "error creating parent write pipe");
      } else luaL_addstring(&errBuf, "error creating parent read pipe");
      free(args);
    } else luaL_addstring(&errBuf, "error allocating child's command arguments");
  } else luaL_addstring(&errBuf, "expecting table of command arguments as first argument");
  if (luaL_bufflen(&errBuf)) {
    lua_pushnil(L);
    luaL_pushresult(&errBuf);
    return 2;
  }
  luaL_pushresult(&buf);
  return 1;
}

// bstring which(const char * programStr)  {
//   bstring readStr;
//   const char * argv[] = { "/usr/bin/which", programStr, 0 };
//   readStr = bfromcstr("");
//   bExec(argv, (bstring) 0, readStr);
//   btrimws(readStr);
//   return readStr;
// }
