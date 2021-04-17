# This Makefile requires a subdirectory named "links" with the following named
# links shown here with example targets.
#
# discount (https://github.com/Orc/discount)
# lua (https://www.lua.org/)
# gumbo (https://gitlab.com/craigbarnes/lua-gumbo)
#
# All targets must exist. Libraries should already be built.
#
# The strliteral utility comes from https://github.com/mortie/strliteral

CFLAGS=-std=gnu99 -O2 -Wall -fPIC
LUADIR=links/lua/src
LUA=${LUADIR}/lua
LUAC=${LUADIR}/luac
LUALIB=${LUADIR}/liblua.a
LUAFLAGS:=-DLUA_USE_LINUX
DISCOUNTDIR:=links/discount
DISCOUNTLIB=${DISCOUNTDIR}/libmarkdown.a
OBJS:=lfs.o discount.o exec.o htmllua.o modlua.o script.o gumbo_util.o gumbo_parse.o embed_gumbo.o
SCRIPTS:=script/ok/utility.lua script/ok/persistence.lua script/ok/json.lua script/ok/drive.lua script/ok/url.lua
LUACHECK=${LUA} util/check.lua ${LUAC}

all : script/ok links verify htmllua

script/ok :
	mkdir -p $@

links :
	mkdir links

ls :
	git ls-tree -r master --name-only | sort

verify : ${SCRIPTS}
	test -f ${DISCOUNTLIB}
	test -d links/gumbo/
	test -f ${LUALIB}
	test -x ${LUA}
	test -x ${LUAC}
	which strliteral
	which gcc
	links/lua/src/luac -o /dev/null ${SCRIPTS}
	touch $@

htmllua : ${OBJS} gumbo.a
	gcc ${CFLAGS} $^ ${LUALIB} ${DISCOUNTLIB} -lm -ldl -o $@

gumbo.a :
	mkdir -p gumbo
	rm -f gumbo/*
	rm -f $@
	cd gumbo && find ../links/gumbo/lib/ -name "*.c" | xargs gcc -c -I links/gumbo/lib/
	ls -1 gumbo/*.o | xargs ar r $@
	ranlib $@

embed_gumbo.c :
	find links/gumbo/gumbo/ -name "*.lua" -exec ${LUA} util/preload.lua links/gumbo/ embed_gumbo links/gumbo/gumbo.lua {} +

.c.o :
	gcc ${CFLAGS} -I ${LUADIR} -I ${DISCOUNTDIR} ${LUAFLAGS} -c -o $@ $<

gumbo_%.o : links/gumbo/gumbo/%.c
	gcc ${CFLAGS} -I ${LUADIR} -I links/gumbo/lib ${LUAFLAGS} -c -o $@ $<

script/ok/%.lua : script/%.lua
	${LUACHECK} $< printstr printf errorf discount persistence util json drive url
	cp $< $@

modlua.c : ${LUADIR}/lua.c util/modlua.lua
	${LUA} util/modlua.lua < $< > $@

script.c : ${SCRIPTS}
	${LUAC} -o - $^ | strliteral --ident script_lua > $@

clean :
	rm -f htmllua modlua.c verify *.o script.c script/ok/*.lua gumbo.a embed_gumbo.c
	rm -fr gumbo
