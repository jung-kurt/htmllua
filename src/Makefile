# This Makefile requires a subdirectory named "links" with the following named
# links shown here with example targets.
#
# lua (https://www.lua.org/)
#
# All targets must exist. Libraries should already be built.
#
# The strliteral utility comes from https://github.com/mortie/strliteral

CFLAGS:=-std=gnu99 -O2 -Wall -fPIC
LUADIR:=links/lua/src
LUA=${LUADIR}/lua
LUAC=${LUADIR}/luac
LUALIB=${LUADIR}/liblua.a
LUAFLAGS:=-DLUA_USE_LINUX
OBJS:=lfs.o exec.o jlua.o modlua.o script.o
SCRIPTS:=script/ok/utility.lua script/ok/json.lua script/ok/url.lua
LUACHECK=${LUA} util/check.lua ${LUAC}

all : script/ok links verify jlua

script/ok :
	mkdir -p $@

links :
	mkdir links

ls :
	git ls-tree -r main --name-only | sort

verify : ${SCRIPTS}
	test -f ${LUALIB}
	test -x ${LUA}
	test -x ${LUAC}
	which strliteral
	which gcc
	${LUAC} -o /dev/null ${SCRIPTS}
	touch $@

jlua : ${OBJS}
	gcc ${CFLAGS} $^ ${LUALIB} -lm -ldl -o $@

%.o : %.c
	gcc ${CFLAGS} -I ${LUADIR} ${LUAFLAGS} -c -o $@ $<

script/ok/%.lua : script/%.lua
	${LUACHECK} $< printstr printf errorf util json url
	cp $< $@

modlua.c : ${LUADIR}/lua.c util/modlua.lua
	${LUA} util/modlua.lua < $< > $@

script.c : ${SCRIPTS}
	${LUAC} -o - $^ | strliteral --ident script_lua > $@

nfs :
	@echo Syncing with NFS server
	rsync --archive --exclude='.git' --exclude="links" --exclude-from="../.gitignore" ./ nfs:~/c/jlua

clean :
	rm -f jlua modlua.c verify *.o script.c script/ok/*.lua
