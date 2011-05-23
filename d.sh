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
  URL="http://pts-mini-gpl.googlecode.com/svn/trunk/staticpython/release.darwin/$1"
  echo "info: downloading: $URL"
  curl -o "$1.download" "$URL" || exit 2
else
  URL="http://pts-mini-gpl.googlecode.com/svn/trunk/staticpython/release/$1"
  if type -p wgetz >/dev/null 2>&1; then
    wget -O "$1.download" "$URL" || exit 2
  else
    echo "info: downloading: $URL"
    curl -o "$1.download" "$URL" || exit 2
  fi
fi
chmod +x "$1.download"
mv "$1.download" "$1"
echo "info: download OK, run with: ./$1"
