#! /bin/bash --
#
# build.sh -- compile StaticPython from sources
# by pts@fazekas.hu at Wed Aug 11 16:49:32 CEST 2010
# Mac OS X support at Sat May 21 21:04:07 CEST 2011
#
# Example invocation: ./build.sh
# Example invocation: ./compie.sh stackless
# This script has been tested on Ubuntu Hardy, should work on any Linux system.
#
# TODO(pts): Build linux libs from source as well.
#
# To facilitate exit on error,
#
#   (true; false; true; false)
#
# has to be changed to
#
#   (true && false && true && false) || return "$?"  # in bash-3.1.17
#   (true && false && true && false)  # in busybox sh
#
# for Mac OS X:
#
# TODO(pts): Implement stacklessco.
# TODO(pts): Configure -lz  --> pyconfig.h HAVE_ZLIB_COPY=1 
# TODO(pts): Verify `import sysconfig' on both Linux and Mac OS X.
# TODO(pts): Get rid of -ldl.
# TODO(pts): Get rid of -framework CoreFoundation.
# TODO(pts): Use libintl.a, but without libiconv.a (too large, 1MB).
# TODO(pts): Add -mtune=cpu-type and -march=cpu-type (with SSE).
# TODO(pts): Test if hard switching works on both Linux and the Mac.
#            --enable-stacklessfewerregisters .

if true; then  # Make the shell script editable while it's executing.

test "${0%/*}" != "$0" && cd "${0%/*}"

UNAME=$(./busybox uname 2>/dev/null || uname || true)

if test "$NO_BUSYBOX" || test "$UNAME" = Darwin; then  # Darwin is Mac OS X
  BUSYBOX=
elif test "$BASH_VERSION"; then
  unset BASH_VERSION
  exec ./busybox sh -- "$0" "$@"
else
  BUSYBOX=./busybox
  # Make sure we fail unless we use ./busybox for all non-built-in commands.
  export PATH=/dev/null
  set -e  # Abort on error.
  test -d busybox.bin || ./busybox mkdir busybox.bin
  for F in cp mv rm sleep touch mkdir tar expr sed awk ls pwd test cmp diff \
           sort cat head tail chmod chown uname basename tr find grep ln; do
    ./busybox rm -f busybox.bin/"$F"
    ./busybox ln -s ../busybox busybox.bin/"$F"
  done
  ./busybox rm -f busybox.bin/make; ./busybox ln -s ../make busybox.bin/make
  ./busybox rm -f busybox.bin/perl; ./busybox ln -s ../perl busybox.bin/perl
  export PATH="$PWD/busybox.bin"
  export SHELL="$PWD/busybox.bin/sh"
fi

set -e  # Abort on error.

# ---

INSTS_BASE="bzip2-1.0.5.inst.tbz2 ncurses-5.6.inst.tbz2 readline-5.2.inst.tbz2 sqlite-3.7.0.1.inst.tbz2 zlib-1.2.3.3.inst.tbz2"

if test "$1" = stackless; then
  TARGET=stackless2.7-static
  PYTHONTBZ2=stackless-271-export.tar.bz2
  IS_CO=
  shift
elif test "$1" = stacklessco; then
  TARGET=stacklessco2.7-static
  PYTHONTBZ2=stackless-271-export.tar.bz2
  IS_CO=1
  shift
else
  TARGET=python2.7-static
  PYTHONTBZ2=Python-2.7.1.tar.bz2
  IS_CO=
fi

if test $# = 0; then
  # Don't include betry here.
  STEPS="initbuilddir initdeps configure patchsetup patchimport patchgetpath patchsqlite makeminipython patchsyncless patchgevent patchgeventmysql patchconcurrence patchpycrypto patchaloaes fixmakefile makepython buildpythonlibzip buildtarget"
else
  STEPS="$*"
fi

if test "$IS_CO"; then
  INSTS="$INSTS_BASE libevent2-2.0.11.inst.tbz2"
else
  INSTS="$INSTS_BASE"
fi

BUILDDIR="$TARGET.build"
PBUILDDIR="$PWD/$BUILDDIR"

# GNU Autoconf's ./configure uses $CC, $LD, $AR, $LDFLAGS and $RANLIB to
# generate the Makefile.
if test "$UNAME" = Darwin; then
  # -march=i386 wouldn't work, it would disable SSE. So we use -m32.
  export CC="gcc-mp-4.4 -m32 -static-libgcc -I$PBUILDDIR/build-include"
  export AR=ar
  export RANLIB=ranlib
  export LD=ld
  export LDFLAGS="-L$PBUILDDIR/build-lib"

  export STRIP=strip
else
  export CC="$PBUILDDIR/cross-compiler-i686/bin/i686-gcc -static -fno-stack-protector"
  export AR="$PBUILDDIR/cross-compiler-i686/bin/i686-ar"
  export RANLIB="$PBUILDDIR/cross-compiler-i686/bin/i686-ranlib"
  export LD="$PBUILDDIR/cross-compiler-i686/bin/i686-ld"  # The ./configure script of libevent2 fails without $LD being set.
  export LDFLAGS=""

  export STRIP="$PBUILDDIR/cross-compiler-i686/bin/i686-strip -s"
fi

echo "Running in directory: $PWD"
echo "Building target: $TARGET"
echo "Building in directory: $BUILDDIR"
echo "Using Python source distribution: $PYTHONTBZ2"
echo "Will run steps: $STEPS"
echo "Is adding coroutine libraries: $IS_CO"
echo "Operating system UNAME: $UNAME"
echo

initbuilddir() {
  rm -rf "$BUILDDIR"
  mkdir "$BUILDDIR"

  if test "$UNAME" = Linux || test "$UNAME" = Darwin; then
    :
  else
    set +x
    echo "fatal: unsupported operating system: $UNAME" >&2
    exit 2
  fi

  if test "$UNAME" = Darwin; then
    mkdir "$BUILDDIR/build-include"
    mkdir "$BUILDDIR/build-lib"
  else
    ( cd "$BUILDDIR" || return "$?"
      mkdir cross-compiler-i686
      cd cross-compiler-i686
      tar xjvf ../../gcxbase.inst.tbz2 || return "$?"
      tar xjvf ../../gcc.inst.tbz2 || return "$?"
      tar xjvf ../../gcxtool.inst.tbz2 || return "$?"
    ) || return "$?"
  fi

  # Set up a fake config.guess for operating system and architecture detection.
  #
  # This is to make sure that we have i686 even on an x86_64 host for Linux.
  if test "$UNAME" = Darwin; then
    (echo '#!/bin/sh'; echo 'echo i386-apple-darwin9.8.0') >"$BUILDDIR/config.guess.fake" || return "$?"
  else
    (echo '#!/bin/sh'; echo 'echo i686-pc-linux-gnu') >"$BUILDDIR/config.guess.fake" || return "$?"
  fi
  chmod +x "$BUILDDIR/config.guess.fake"

  # Check the C compiler.
  (echo '#include <stdio.h>'
   echo 'main() { return!printf("Hello, World!\n"); }'
  ) >"$BUILDDIR/hello.c"
  if ! $CC -o "$BUILDDIR/hello" "$BUILDDIR/hello.c"; then
    set +x
    echo "fatal: the C compiler doesn't work" >&2
    if test "$UNAME" = Darwin; then
      echo "info: did you install MacPorts and run: sudo port install gcc44" >&2
    fi
    exit 2
  fi
  $STRIP "$BUILDDIR/hello"
  local OUT="$("$BUILDDIR/hello")"
  test "$?" = 0
  test "$OUT" = "Hello, World!"

  ( cd "$BUILDDIR" || return "$?"
    tar xjvf ../"$PYTHONTBZ2" || return "$?"
  ) || return "$?"
  ( cd "$BUILDDIR" || return "$?"
    if test -d Python-*; then
      mv Python-*/* . || return "$?"
    fi
    if test -d stackless-*; then
      mv stackless-*/* . || return "$?"
    fi
  ) || return "$?"
  ( cd "$BUILDDIR/Modules" || return "$?"
    tar xzvf ../../greenlet-0.3.1.tar.gz
  ) || return "$?"

  cp -f "$BUILDDIR/config.guess.fake" "$BUILDDIR/config.guess"
}

initdeps() {
  if test "$UNAME" = Darwin; then  # Mac OS X
    builddeps
  else  # Linux
    extractinsts
  fi
}

builddeps() {
  buildlibbz2
  buildlibreadline
  buildlibsqlite3
  buildlibz
  buildlibevent2
}

buildlibbz2() {
  ( cd "$BUILDDIR" || return "$?"
    rm -rf bzip2-1.0.6 || return "$?"
    tar xzvf ../bzip2-1.0.6.tar.gz || return "$?"
    cd bzip2-1.0.6 || return "$?"
    perl -pi~ -e 's@\s-g(?!\S)@@g, s@\s-O\d*(?!\S)@ -O3@g if s@^CFLAGS\s*=@CFLAGS = @' Makefile || return "$?"
    make CC="$CC" || return "$?"
    cp libbz2.a ../build-lib/libbz2-staticpython.a || return "$?"
    cp bzlib.h ../build-include/ || return "$?"
  ) || return "$?"
}

buildlibreadline() {
  ( cd "$BUILDDIR" || return "$?"
    rm -rf readline-5.2 || return "$?"
    tar xzvf ../readline-5.2.tar.gz || return "$?"
    cd readline-5.2 || return "$?"
    ./configure --disable-shared || return "$?"
    perl -pi~ -e 's@\s-g(?!\S)@@g, s@\s-O\d*(?!\S)@ -O2@g if s@^CFLAGS\s*=@CFLAGS = @' Makefile || return "$?"
    make || return "$?"
    # We could copy history.a, but Python doesn't need it.
    cp libreadline.a ../build-lib/libreadline-staticpython.a || return "$?"
    rm -rf ../build-include/readline || return "$?"
    mkdir ../build-include/readline || return "$?"
    cp rlstdc.h rltypedefs.h keymaps.h tilde.h readline.h history.h chardefs.h ../build-include/readline/ || return "$?"
  ) || return "$?"
}

buildlibsqlite3() {
  ( cd "$BUILDDIR" || return "$?"
    rm -rf sqlite-amalgamation-3070603 || return "$?"
    unzip ../sqlite-amalgamation-3070603.zip || return "$?"
    cd sqlite-amalgamation-3070603 || return "$?"
    $CC -c -O2 -DSQLITE_ENABLE_STAT2 -DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS4 -DSQLITE_ENABLE_RTREE -W -Wall sqlite3.c || return "$?"
    $AR cr libsqlite3.a sqlite3.o || return "$?"
    $RANLIB libsqlite3.a || return "$?"
    cp libsqlite3.a ../build-lib/libsqlite3-staticpython.a || return "$?"
    cp sqlite3.h ../build-include/ || return "$?"
  ) || return "$?"
}

buildlibz() {
  ( cd "$BUILDDIR" || return "$?"
    rm -rf zlib-1.2.5 || return "$?"
    tar xjvf ../zlib-1.2.5.tar.bz2 || return "$?"
    cd zlib-1.2.5 || return "$?"
    ./configure --static || return "$?"
    perl -pi~ -e 's@\s-g(?!\S)@@g, s@\s-O\d*(?!\S)@ -O3@g if s@^CFLAGS\s*=@CFLAGS = @' Makefile || return "$?"
    make || return "$?"
    cp libz.a ../build-lib/libz-staticpython.a || return "$?"
    cp zconf.h zlib.h ../build-include/ || return "$?"
  ) || return "$?"
}

buildlibevent2() {
  test "$IS_CO" || return 0
  ( cd "$BUILDDIR" || return "$?"
    rm -rf libevent-2.0.11-stable || return "$?"
    tar xzvf ../libevent-2.0.11-stable.tar.gz || return "$?"
    cd libevent-2.0.11-stable || return "$?"
    ./configure --disable-openssl --disable-debug-mode --disable-shared --disable-libevent-regress || return "$?"
    cp -f ../config.guess.fake config.guess
    perl -pi~ -e 's@\s-g(?!\S)@@g, s@\s-O\d*(?!\S)@ -O2@g if s@^CFLAGS\s*=@CFLAGS = @' Makefile */Makefile || return "$?"
    make || return "$?"
    $AR cr  libevent_evhttp.a bufferevent_sock.o http.o listener.o || return "$?"
    $RANLIB libevent_evhttp.a || return "$?"
    cp .libs/libevent_core.a ../build-lib/libevent_core-staticpython.a || return "$?"
    cp libevent_evhttp.a ../build-lib/libevent_evhttp-staticpython.a || return "$?"
    mkdir ../build-include/event2 || return "$?"
    cp include/event2/*.h ../build-include/event2/ || return "$?"
  ) || return "$?"
}

extractinsts() {
  for INSTTBZ2 in $INSTS; do
    ( cd "$BUILDDIR/cross-compiler-i686" || return "$?"
      tar xjvf ../../"$INSTTBZ2" || return "$?"
    ) || return "$?"
  done
}

configure() {
  ( cd "$BUILDDIR" || return "$?"
    # TODO(pts): Make sure x86 is detected (not x86_64).
    # This removal makes Python-ast.c not autogenerated. Autogeneration would
    # need a working Python binary, which we don't have yet.
    perl -pi -e '$_="" if /ASDLGEN/' Makefile.pre.in
    local REGSFLAGS=
    # Without --enable-stacklessfewerregisters, we'd get the error:
    #  ./Stackless/platf/switch_x86_unix.h:37: error: PIC register 'ebx' clobbered in 'asm'
    test "$UNAME" = Darwin && REGSFLAGS=--enable-stacklessfewerregisters
    ./configure --disable-shared --disable-ipv6 $REGSFLAGS || return "$?"
  ) || return "$?"
  fixmakefile
}

fixmakefile() {
  ( cd "$BUILDDIR" || return "$?"
    # `-framework CoreFoundation' is good to be removed on the Mac OS X, to
    # prevent additional .dylib dependencies on
    # /System//Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation
    # .
    perl -pi~ -e 's@\s-(?:ldl|framework\s+CoreFoundation)(?!\S)@@g if s@^LIBS\s*=@LIBS = @' Makefile || return "$?"
    # CFLAGS already has -O2.
    perl -pi~ -e 's@\s-(?:g|O\d*)(?!\S)@@g if s@^OPT\s*=@OPT = @' Makefile || return "$?"
    perl -pi~ -e 's@\s-g(?!\S)@@g, s@\s-O\d*(?!\S)@ -O2@g if s@^CFLAGS\s*=@CFLAGS = @' Makefile || return "$?"
  ) || return "$?"
}

patchsetup() {
  # This must be run after the configure step, because configure overwrites
  # Modules/Setup
  cp Modules.Setup.2.7.static "$BUILDDIR/Modules/Setup"
  if test "$UNAME" = Darwin; then
    # * /usr/lib/libncurses.5.dylib
    # * _locale is disabled because -lintl needs -liconv, which is too large
    #   (1MB)
    # * spwd is disabled because the Mac OS X doesn't contain
    #   /usr/include/shadow.h .
    # * -lcrypt and -lm are not necessary in the Mac OS X, everything is in
    #   the libc.
    # * -lz, -lsqlite3, -lreadline and -lbz2 have to be converted to
    #   -l...-staticpython so that out lib*-staticpython.a would be selected.
    # * _multiprocessing/semaphore.c is needed.
    perl -pi~ -e 's@\s-lncurses\S*@ -lncurses.5@g; s@^(?:_locale|spwd)(?!\S)@#@; s@\s-(?:lcrypt|lm)(?!\S)@@g; s@\s-(lz|lsqlite3|lreadline|lbz2|levent_core|levent_evhttp)(?!\S)@ -$1-staticpython@g; s@^(_multiprocessing)(?!\S)@_multiprocessing _multiprocessing/semaphore.c@' "$BUILDDIR/Modules/Setup" || return "$?"
  fi
  sleep 2 || return "$?"  # Wait 2 seconds after the configure script creating Makefile.
  touch "$BUILDDIR/Modules/Setup" || return "$?"
  # We need to run `make Makefile' to rebuild it using our Modules/Setup
  ( cd "$BUILDDIR" || return "$?"
    make Makefile || return "$?"
  ) || return "$?"
  fixmakefile
}

patchimport() {
  # This patch is idempotent.
  perl -pi~ -e 's@#ifdef HAVE_DYNAMIC_LOADING(?!_NOT)@#ifdef HAVE_DYNAMIC_LOADING_NOT  /* StaticPython */@g' "$BUILDDIR"/Python/import.c "$BUILDDIR"/Python/importdl.c
}

patchgetpath() {
  # This patch is idempotent.
  # TODO(pts): Make sure that the source string is there for patching.
  perl -pi~ -0777 -e 's@\s+static\s+void\s+calculate_path(?!   )\s*\(\s*void\s*\)\s*{@\n\nstatic void calculate_path(void);  /* StaticPython */\nstatic void calculate_path_not(void) {@g' "$BUILDDIR"/Modules/getpath.c
  if ! grep -q StaticPython-appended "$BUILDDIR/Modules/getpath.c"; then
    cat calculate_path.static.c >>"$BUILDDIR/Modules/getpath.c"
  fi
}

patchsqlite() {
  # This patch is idempotent.
  if ! grep '^#define MODULE_NAME ' "$BUILDDIR/Modules/_sqlite/util.h"; then
    perl -pi~ -0777 -e 's@\n#define PYSQLITE_UTIL_H\n@\n#define PYSQLITE_UTIL_H\n#define MODULE_NAME "_sqlite3"  /* StaticPython */\n@' "$BUILDDIR/Modules/_sqlite/util.h"
  fi    
  for F in "$BUILDDIR/Modules/_sqlite/"*.c; do
    if ! grep -q '^#include "util.h"' "$F"; then
      perl -pi~ -0777 -e 's@\A@#include "util.h"  /* StaticPython */\n@' "$F"
    fi    
  done
}

generate_loader_py() {
  local CEXT_MODNAME="$1"
  local PY_MODNAME="$2"
  local PY_FILENAME="Lib/${PY_MODNAME//.//}.py"
  : Generating loader "$PY_FILENAME"
  echo "import sys; import $CEXT_MODNAME; sys.modules[__name__] = $CEXT_MODNAME" >"$PY_FILENAME"
}

patch_and_copy_cext() {
  local SOURCE_C="$1"
  local TARGET_C="$2"
  local CEXT_MODNAME="${TARGET_C%.c}"
  export CEXT_MODNAME="${CEXT_MODNAME##*/}"
  export CEXT_MODNAME="${CEXT_MODNAME//._/_}"
  export CEXT_MODNAME="${CEXT_MODNAME//./_}"
  export CEXT_MODNAME=_"${CEXT_MODNAME#_}"
  : Copying and patching "$SOURCE_C" to "$TARGET_C", CEXT_MODNAME="$CEXT_MODNAME"
  <"$SOURCE_C" >"$TARGET_C" perl -0777 -pe '
    s@^(PyMODINIT_FUNC)\s+\w+\(@$1 init$ENV{CEXT_MODNAME}(@mg;
    s@( Py_InitModule\d*)\("\w[\w.]*",@$1("$ENV{CEXT_MODNAME}",@g;
    # Cython version of the one below.
    s@( Py_InitModule\d*\(__Pyx_NAMESTR\()"\w[\w.]*"\),@$1"$ENV{CEXT_MODNAME}"),@g;
    # For PyCrypto.
    s@^[ \t]*(#[ \t]*define\s+MODULE_NAME\s+\S+)@#define MODULE_NAME $ENV{CEXT_MODNAME}@mg;
    s@^[ \t]*(#[ \t]*define\s+MODULE_NAME\s+\S+.*triple DES.*)@#define MODULE_NAME _Crypto_Cipher_DES3@mg;
  '
}

enable_module() {
  local CEXT_MODNAME="$1"
  export CEXT_MODNAME
  : Enabling module: "$CEXT_MODNAME"
  grep -qE "^#?$CEXT_MODNAME " Modules/Setup
  perl -0777 -pi -e 's@^#$ENV{CEXT_MODNAME} @$ENV{CEXT_MODNAME} @mg' Modules/Setup
}

patchsyncless() {
  test "$IS_CO" || return 0
  ( cd "$BUILDDIR" || return "$?"
    rm -rf syncless-* syncless.dir Lib/syncless Modules/syncless || return "$?"
    tar xzvf ../syncless-0.22.tar.gz || return "$?"
    mv syncless-0.22 syncless.dir || return "$?"
    mkdir Lib/syncless Modules/syncless || return "$?"
    cp syncless.dir/syncless/*.py Lib/syncless/ || return "$?"
    generate_loader_py _syncless_coio syncless.coio || return "$?"
    patch_and_copy_cext syncless.dir/coio_src/coio.c Modules/syncless/_syncless_coio.c || return "$?"
    cp syncless.dir/coio_src/coio_minihdns.c \
       syncless.dir/coio_src/coio_minihdns.h \
       syncless.dir/coio_src/coio_c_*.h \
       Modules/syncless/ || return "$?"
    enable_module _syncless_coio || return "$?"
  ) || return "$?"
}

patchgevent() {
  test "$IS_CO" || return 0
  ( cd "$BUILDDIR" || return "$?"
    rm -rf gevent-* gevent.dir Lib/gevent Modules/gevent || return "$?"
    tar xzvf ../gevent-0.13.2.tar.gz || return "$?"
    mv gevent-0.13.2 gevent.dir || return "$?"
    mkdir Lib/gevent Modules/gevent || return "$?"
    cp gevent.dir/gevent/*.py Lib/gevent/ || return "$?"
    rm -f gevent.dir/gevent/win32util.py || return "$?"
    generate_loader_py _gevent_core gevent.core || return "$?"
    patch_and_copy_cext gevent.dir/gevent/core.c Modules/gevent/_gevent_core.c || return "$?"
    cat >Modules/gevent/libevent.h <<'END'
/**** pts ****/
#include "sys/queue.h"
#define LIBEVENT_HTTP_MODERN
#include "event2/event.h"
#include "event2/event_struct.h"
#include "event2/event_compat.h"
#include "event2/http.h"
#include "event2/http_compat.h"
#include "event2/http_struct.h"
#include "event2/buffer.h"
#include "event2/buffer_compat.h"
#include "event2/dns.h"
#include "event2/dns_compat.h"
#define EVBUFFER_DRAIN evbuffer_drain
#define EVHTTP_SET_CB  evhttp_set_cb
#define EVBUFFER_PULLUP(BUF, SIZE) evbuffer_pullup(BUF, SIZE)
#define current_base event_global_current_base_
#define TAILQ_GET_NEXT(X) TAILQ_NEXT((X), next)
extern void *current_base;
END
    enable_module _gevent_core || return "$?"
  ) || return "$?"
}

patchgeventmysql() {
  test "$IS_CO" || return 0
  ( cd "$BUILDDIR" || return "$?"
    rm -rf geventmysql-* geventmysql.dir Lib/geventmysql Modules/geventmysql || return "$?"
    tar xjvf ../geventmysql-20110201.tbz2 || return "$?"
    mv gevent-MySQL geventmysql.dir || return "$?"
    mkdir Lib/geventmysql Modules/geventmysql || return "$?"
    cp geventmysql.dir/lib/geventmysql/*.py Lib/geventmysql/ || return "$?"
    generate_loader_py _geventmysql_mysql geventmysql._mysql || return "$?"
    patch_and_copy_cext geventmysql.dir/lib/geventmysql/geventmysql._mysql.c Modules/geventmysql/geventmysql._mysql.c || return "$?"
    enable_module _geventmysql_mysql || return "$?"
  ) || return "$?"
}

run_pyrexc() {
  PYTHONPATH="$PWD/Lib:$PWD/pyrex.dir" "$PBUILDDIR"/minipython -S -W ignore::DeprecationWarning -c "from Pyrex.Compiler.Main import main; main(command_line=1)" "$@"
}

#** Equivalent to zip -9r "$@"
#** Usage: run_mkzip filename.zip file_or_dir ...
run_mkzip() {
  local PYTHON="$PBUILDDIR"/python.exe
  test -f "$PBUILDDIR"/minipython && PYTHON="$PBUILDDIR"/minipython
  # python.exe is for the Mac OS X (case insensitive, vs Python/)
  PYTHONPATH="$PWD/Lib" "$PYTHON" -S -c 'if 1:
  import os
  import os.path
  import stat
  import sys
  import zipfile
  def All(filename):
    s = os.lstat(filename)
    assert not stat.S_ISLNK(s.st_mode), filename
    if stat.S_ISDIR(s.st_mode):
      for entry in os.listdir(filename):
        for filename2 in All(os.path.join(filename, entry)):
          yield filename2
    else:
      yield filename
  zip_filename = sys.argv[1]
  zipfile.zlib.Z_DEFAULT_COMPRESSION = 9  # Maximum effort.
  z = zipfile.ZipFile(zip_filename, "w", compression=zipfile.ZIP_DEFLATED)
  for filename in sys.argv[2:]:
    for filename2 in All(filename):
      z.write(filename2)
  z.close()' "$@"
}

patchconcurrence() {
  test "$IS_CO" || return 0
  ( cd "$BUILDDIR" || return "$?"
    rm -rf concurrence-* concurrence.dir pyrex.dir Lib/concurrence Modules/concurrence || return "$?"
    tar xzvf ../concurrence-0.3.1.tar.gz || return "$?"
    mv concurrence-0.3.1 concurrence.dir || return "$?"
    tar xzvf ../Pyrex-0.9.9.tar.gz || return "$?"
    mv Pyrex-0.9.9 pyrex.dir || return "$?"
    mkdir Lib/concurrence Modules/concurrence || return "$?"
    # TODO(pts): Fail if any of the pipe commands fail.
    (cd concurrence.dir/lib && tar c $(find concurrence -type f -iname '*.py')) |
        (cd Lib && tar x) || return "$?"

    generate_loader_py _concurrence_event concurrence._event || return "$?"
    cat >Modules/concurrence/event.h <<'END'
/**** pts ****/
#include <event2/event.h>
#include <event2/event_struct.h>
#include <event2/event_compat.h>
END
    run_pyrexc concurrence.dir/lib/concurrence/concurrence._event.pyx || return "$?"
    patch_and_copy_cext concurrence.dir/lib/concurrence/concurrence._event.c Modules/concurrence/concurrence._event.c || return "$?"
    enable_module _concurrence_event || return "$?"

    generate_loader_py _concurrence_io_io concurrence.io._io || return "$?"
    run_pyrexc concurrence.dir/lib/concurrence/io/concurrence.io._io.pyx || return "$?"
    patch_and_copy_cext concurrence.dir/lib/concurrence/io/concurrence.io._io.c Modules/concurrence/concurrence.io._io.c || return "$?"
    cp concurrence.dir/lib/concurrence/io/io_base.c \
       concurrence.dir/lib/concurrence/io/io_base.h \
       Modules/concurrence/ || return "$?"
    enable_module _concurrence_io_io || return "$?"

    generate_loader_py _concurrence_database_mysql_mysql concurrence.database.mysql._mysql || return "$?"
    run_pyrexc -I concurrence.dir/lib/concurrence/io concurrence.dir/lib/concurrence/database/mysql/concurrence.database.mysql._mysql.pyx || return "$?"
    patch_and_copy_cext concurrence.dir/lib/concurrence/database/mysql/concurrence.database.mysql._mysql.c Modules/concurrence/concurrence.database.mysql._mysql.c || return "$?"
    enable_module _concurrence_database_mysql_mysql || return "$?"

  ) || return "$?"
}

patchpycrypto() {
  test "$IS_CO" || return 0
  ( cd "$BUILDDIR" || return "$?"
    rm -rf pycrypto-* pycrypto.dir pyrex.dir Lib/Crypto Modules/pycrypto || return "$?"
    tar xzvf ../pycrypto-2.3.tar.gz || return "$?"
    mv pycrypto-2.3 pycrypto.dir || return "$?"
    mkdir Lib/Crypto Modules/pycrypto Modules/pycrypto/libtom || return "$?"
    # TODO(pts): Fail if any of the pipe commands fail.
    (cd pycrypto.dir/lib && tar c $(find Crypto -type f -iname '*.py')) |
        (cd Lib && tar x) || return "$?"

    ln -s _Crypto_Cipher_DES.c Modules/pycrypto/DES.c || return "$?"
    cp pycrypto.dir/src/hash_template.c \
       pycrypto.dir/src/block_template.c \
       pycrypto.dir/src/stream_template.c \
       pycrypto.dir/src/pycrypto_compat.h \
       pycrypto.dir/src/_counter.h \
       pycrypto.dir/src/Blowfish-tables.h \
       pycrypto.dir/src/cast5.c \
       Modules/pycrypto/ || return "$?"
    cp pycrypto.dir/src/libtom/tomcrypt_des.c \
       pycrypto.dir/src/libtom/*.h \
       Modules/pycrypto/libtom/ || return "$?"

    local M CEXT_MODNAME
    for M in Crypto.Hash.MD2 Crypto.Hash.MD4 Crypto.Hash.SHA256 \
             Crypto.Hash.RIPEMD160 \
             Crypto.Cipher.AES Crypto.Cipher.ARC2 Crypto.Cipher.Blowfish \
             Crypto.Cipher.CAST Crypto.Cipher.DES Crypto.Cipher.DES3 \
             Crypto.Cipher.ARC4 Crypto.Cipher.XOR \
             Crypto.Util.strxor Crypto.Util._counter; do \
      CEXT_MODNAME="${M##*/}"
      CEXT_MODNAME="${CEXT_MODNAME//._/_}"
      CEXT_MODNAME="${CEXT_MODNAME//./_}"
      CEXT_MODNAME=_"${CEXT_MODNAME#_}"
      generate_loader_py "$CEXT_MODNAME" "$M" || return "$?"
      patch_and_copy_cext "pycrypto.dir/src/${M##*.}.c" Modules/pycrypto/"$CEXT_MODNAME".c || return "$?"
      enable_module "$CEXT_MODNAME" || return "$?"
    done

    perl -0777 -pi -e 's@ Py_InitModule\("Crypto[.]\w+[.]"@ Py_InitModule(""@g' \
        Modules/pycrypto/hash_template.c \
        Modules/pycrypto/stream_template.c \
        Modules/pycrypto/block_template.c

  ) || return "$?"
}

patchaloaes() {
  test "$IS_CO" || return 0
  ( cd "$BUILDDIR" || return "$?"
    rm -rf aloaes-* aloaes.dir Lib/aes Modules/aloaes || return "$?"
    tar xzvf ../alo-aes-0.3.tar.gz || return "$?"
    mv alo-aes-0.3 aloaes.dir || return "$?"
    mkdir Lib/aes Modules/aloaes || return "$?"
    cp aloaes.dir/aes/*.py Lib/aes/ || return "$?"
    generate_loader_py _aes_aes aes._aes || return "$?"
    patch_and_copy_cext aloaes.dir/aes/aesmodule.c Modules/aloaes/_aes_aes.c || return "$?"
    cp aloaes.dir/aes/rijndael-alg-fst.c \
       aloaes.dir/aes/rijndael-alg-fst.h \
       Modules/aloaes/ || return "$?"
    enable_module _aes_aes || return "$?"
  ) || return "$?"
}


makeminipython() {
  test "$IS_CO" || return 0
  ( cd "$BUILDDIR" || return "$?"
    # TODO(pts): Disable co modules in Modules/Setup
    if test "$UNAME" = Darwin; then
      make python.exe || return "$?"
      mv -f python.exe minipython || return "$?"
    else
      make python || return "$?"
      mv -f python minipython || return "$?"
    fi
    $STRIP minipython || return "$?"
  ) || return "$?"
}

makepython() {
  ( cd "$BUILDDIR" || return "$?"
    if test "$UNAME" = Darwin; then
      make python.exe || return "$?"
    else
      make python || return "$?"
      ln -s python python.exe || return "$?"
    fi
  ) || return "$?"
}

buildpythonlibzip() {
  # This step doesn't depend on makepython.
  ( set -ex
    IFS='
'
    cd "$BUILDDIR" ||
    (test -f xlib.zip && mv xlib.zip xlib.zip.old) || return "$?"
    rm -rf xlib || return "$?"
    # Compatibility note: `cp -a' works on Linux, but not on Mac OS X, so
    # we use `cp -R' here which works on both.
    cp -R Lib xlib || return "$?"
    rm -f $(find xlib -iname '*.pyc') || return "$?"
    rm -f xlib/plat-*/regen
    rm -rf xlib/email/test xlib/bdddb xlib/ctypes xlib/distutils \
           xlib/idlelib xlib/lib-tk xlib/lib2to3 xlib/msilib \
           xlib/plat-aix* xlib/plat-atheos xlib/plat-beos* \
           xlib/plat-freebsd* xlib/plat-irix* \
           xlib/plat-mac xlib/plat-netbsd* xlib/plat-next* \
           xlib/plat-os2* xlib/plat-riscos xlib/plat-sunos* \
           xlib/plat-unixware xlib/test xlib/*.egg-info || return "$?"
    if test "$UNAME" = Darwin; then
      rm -rf xlib/plat-linux2
    else
      rm -rf xlib/plat-darwin
    fi
    cp ../site.static.py xlib/site.py || return "$?"
    cd xlib || return "$?"
    rm -f *~ */*~ || return "$?"
    rm -f ../xlib.zip
    run_mkzip ../xlib.zip * || return "$?"
  ) || return "$?"
}

buildtarget() {
  cp "$BUILDDIR"/python.exe "$BUILDDIR/$TARGET"
  $STRIP "$BUILDDIR/$TARGET"
  cat "$BUILDDIR"/xlib.zip >>"$BUILDDIR/$TARGET"
  cp "$BUILDDIR/$TARGET" "$TARGET"
  ls -l "$TARGET"
}

betry() {
  # This step is optional. It tries the freshly built binary.
  mkdir -p bch be/bardir
  echo "print 'FOO'" >be/foo.py
  echo "print 'BAR'" >be/bardir/bar.py
  cp "$TARGET" be/sp
  cp "$TARGET" bch/sp
  export PYTHONPATH=bardir
  unset PYTHONHOME
  #unset PYTHONPATH
  (cd be && ./sp) || return "$?"
}

for STEP in $STEPS; do
  echo "Running step: $STEP"
  set -ex
  $STEP
  set +ex
done
echo "OK running steps: $STEPS"

exit 0

fi
