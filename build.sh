#! /bin/bash --
#
# build.sh -- compile StaticPython from sources
# by pts@fazekas.hu at Wed Aug 11 16:49:32 CEST 2010
#
# Example invocation: ./build.sh
# Example invocation: ./compie.sh stackless
# This script has been tested on Ubuntu Hardy, should work on any Linux system.
#
# TODO(pts): document: ar cr ../stackless2.7-static.build/cross-compiler-i686/lib/libevent_evhttp.a http.o listener.o bufferevent_sock.o

if true; then  # Make the shell script editable while it's executing.

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
  PYTHONTBZ2=Python-2.7.tar.bz2
  IS_CO=
fi

if test $# = 0; then
  # Don't include betry here.
  STEPS="initbuilddir extractinst configure patchsetup patchimport patchgetpath patchsqlite makepython buildlibzip buildtarget"
else
  STEPS="$*"
fi

if test "$IS_CO"; then
  INSTS="$INSTS_BASE libevent2-2.0.10.inst.tbz2"
else
  INSTS="$INSTS_BASE"
fi

cd "${0%/*}"
BUILDDIR="$TARGET.build"
export CC="$PWD/$BUILDDIR/cross-compiler-i686/bin/i686-gcc -static -fno-stack-protector"

echo "Running in directory: $PWD"
echo "Building target: $TARGET"
echo "Building in directory: $BUILDDIR"
echo "Using Python source distribution: $PYTHONTBZ2"
echo "Will run steps: $STEPS"
echo "Is adding coroutine libraries: $IS_CO"
echo

initbuilddir() {
  rm -rf "$BUILDDIR"
  mkdir "$BUILDDIR"
  ( cd "$BUILDDIR" || exit "$?"
    tar xjvf ../"$PYTHONTBZ2" || exit "$?"
  )
  ( cd "$BUILDDIR" || exit "$?"
    mv */* . || exit "$?"
  )
  ( cd "$BUILDDIR" || exit "$?"
    mkdir cross-compiler-i686
    cd cross-compiler-i686
    tar xjvf ../../gcxbase.inst.tbz2 || exit "$?"
    tar xjvf ../../gcc.inst.tbz2 || exit "$?"
    tar xjvf ../../gcxtool.inst.tbz2 || exit "$?"
  )
  ( cd "$BUILDDIR/Modules" || exit "$?"
    tar xzvf ../../greenlet-0.3.1.tar.gz
  )
}

extractinst() {
  for INSTTBZ2 in $INSTS; do
    ( cd "$BUILDDIR/cross-compiler-i686" || exit "$?"
      tar xjvf ../../"$INSTTBZ2" || exit "$?"
    )
  done
}

configure() {
  # TODO(pts): Reduce the startup time of $CC (currently it's much-much slower
  # than /usr/bin/gcc).
  ( cd "$BUILDDIR" || exit "$?"
    ./configure --disable-shared --disable-ipv6 || exit "$?"
  )
}

patchsetup() {
  # This must be run after the configure step, because configure overwrites
  # Modules/Setup
  cp Modules.Setup.2.7.static "$BUILDDIR/Modules/Setup"
  sleep 2  # Wait 2 seconds after the configure script creating Makefile.
  touch "$BUILDDIR/Modules/Setup"
  # We need to run `make Makefile' to rebuild it using our Modules/Setup
  ( cd "$BUILDDIR" || exit "$?"
    make Makefile || exit "$?"
  )
}

patchimport() {
  # This patch is idempotent.
  perl -pi~ -e 's@#ifdef HAVE_DYNAMIC_LOADING(?!_NOT)@#ifdef HAVE_DYNAMIC_LOADING_NOT  /* StaticPython */@g' "$BUILDDIR"/Python/{import.c,importdl.c}
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

makepython() {
  ( cd "$BUILDDIR" || exit "$?"
    make python || exit "$?"
  )
}

buildlibzip() {
  # This step doesn't depend on makepython.
  ( set -ex
    cd "$BUILDDIR" ||
    (test -f xlib.zip && mv xlib.zip xlib.zip.old) || exit "$?"
    rm -rf xlib || exit "$?"
    cp -a Lib xlib || exit "$?"
    rm -rf xlib/{bdddb,ctypes,distutils,idlelib,lib-tk,lib2to3,msilib,plat-aix*,plat-atheos,plat-beos*,plat-darwin,plat-freebsd*,plat-irix*,plat-mac,plat-netbsd*,plat-next*,plat-os2*,plat-riscos,plat-sunos*,plat-unixware,test,*.egg-info} || exit "$?"
    cp ../site.static.py xlib/site.py || exit "$?"
    cd xlib || exit "$?"
    rm -f *~ */*~ || exit "$?"
    zip -9r ../xlib.zip * || exit "$?"
  )
}

buildtarget() {
  cp "$BUILDDIR"/python "$BUILDDIR/$TARGET"
  strip -s "$BUILDDIR/$TARGET"
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
  (cd be && ./sp)
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
