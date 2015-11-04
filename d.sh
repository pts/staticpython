#! /bin/bash --
#
# download.sh: downloader for StaticPython which autodetects the OS
# by pts@fazekas.hu at Mon May 23 16:06:56 CEST 2011
#
# Example usage:
#
#   curl http://pts-mini-gpl.googlecode.com/svn/trunk/staticpython/d.sh |
#   bash /dev/stdin python2.7-static
#
if test $# != 1 || test "${1/\//}" != "$1"; then
  echo "Usage: $0: {python2.7-static|stackless2.7-static|stacklessco2.7-static}" >&2
  exit 1
fi
if test "`uname`" = Darwin; then
  URL="https://raw.githubusercontent.com/pts/staticpython/master/release.darwin/$1"
else
  URL="https://raw.githubusercontent.com/pts/staticpython/master/release/$1"
fi
echo "info: downloading: $URL"
if type -p curl >/dev/null 2>&1; then
  curl -o "$1.download" "$URL" || exit 2
else
  wget -O "$1.download" "$URL" || exit 2
fi
chmod +x "$1.download" || exit 2
mv "$1.download" "$1" || exit 2
echo "info: download OK, run with: ./$1"
