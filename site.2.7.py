#
# copied from parts of original Python-2.7/Lib/site.py
# by pts@fazekas.hu at Wed Aug 11 10:22:30 CEST 2010
#
# **** pts ****

import sys
import os
import __builtin__

USER_BASE = ''
USER_SITE = ''
ENABLE_USER_SITE = None

def setquit():
    """Define new builtins 'quit' and 'exit'.

    These are objects which make the interpreter exit when called.
    The repr of each object contains a hint at how it works.

    """
    if os.sep == ':':
        eof = 'Cmd-Q'
    elif os.sep == '\\':
        eof = 'Ctrl-Z plus Return'
    else:
        eof = 'Ctrl-D (i.e. EOF)'

    class Quitter(object):
        def __init__(self, name):
            self.name = name
        def __repr__(self):
            return 'Use %s() or %s to exit' % (self.name, eof)
        def __call__(self, code=None):
            # Shells like IDLE catch the SystemExit, but listen when their
            # stdin wrapper is closed.
            try:
                sys.stdin.close()
            except:
                pass
            raise SystemExit(code)
    __builtin__.quit = Quitter('quit')
    __builtin__.exit = Quitter('exit')


class _Printer(object):
    """interactive prompt objects for printing the license text, a list of
    contributors and the copyright notice."""

    MAXLINES = 23

    def __init__(self, name, data, files=(), dirs=()):
        self.__name = name
        self.__data = data
        self.__files = files
        self.__dirs = dirs
        self.__lines = None

    def __setup(self):
        if self.__lines:
            return
        data = None
        for dir in self.__dirs:
            for filename in self.__files:
                filename = os.path.join(dir, filename)
                try:
                    fp = file(filename, "rU")
                    data = fp.read()
                    fp.close()
                    break
                except IOError:
                    pass
            if data:
                break
        if not data:
            data = self.__data
        self.__lines = data.split('\n')
        self.__linecnt = len(self.__lines)

    def __repr__(self):
        self.__setup()
        if len(self.__lines) <= self.MAXLINES:
            return "\n".join(self.__lines)
        else:
            return "Type %s() to see the full %s text" % ((self.__name,)*2)

    def __call__(self):
        self.__setup()
        prompt = 'Hit Return for more, or q (and Return) to quit: '
        lineno = 0
        while 1:
            try:
                for i in range(lineno, lineno + self.MAXLINES):
                    print self.__lines[i]
            except IndexError:
                break
            else:
                lineno += self.MAXLINES
                key = None
                while key is None:
                    key = raw_input(prompt)
                    if key not in ('', 'q'):
                        key = None
                if key == 'q':
                    break

def setcopyright():
    """Set 'copyright' and 'credits' in __builtin__"""
    __builtin__.copyright = _Printer("copyright", sys.copyright)
    if sys.platform[:4] == 'java':
        __builtin__.credits = _Printer(
            "credits",
            "Jython is maintained by the Jython developers (www.jython.org).")
    else:
        __builtin__.credits = _Printer("credits", """\
    Thanks to CWI, CNRI, BeOpen.com, Zope Corporation and a cast of thousands
    for supporting Python development.  See www.python.org for more information.""")
    here = os.path.dirname(os.__file__)
    __builtin__.license = _Printer(
        "license", "See http://www.python.org/%.3s/license.html" % sys.version,
        ["LICENSE.txt", "LICENSE"],
        [os.path.join(here, os.pardir), here, os.curdir])


class _Helper(object):
    """Define the builtin 'help'.
    This is a wrapper around pydoc.help (with a twist).

    """

    def __repr__(self):
        return "Type help() for interactive help, " \
               "or help(object) for help about object."
    def __call__(self, *args, **kwds):
        import pydoc
        return pydoc.help(*args, **kwds)

def sethelper():
    __builtin__.help = _Helper()


def setencoding():
    """Set the string encoding used by the Unicode implementation.  The
    default is 'ascii', but if you're willing to experiment, you can
    change this."""
    encoding = "ascii" # Default value set by _PyUnicode_Init()
    if 0:
        # Enable to support locale aware default string encodings.
        import locale
        loc = locale.getdefaultlocale()
        if loc[1]:
            encoding = loc[1]
    if 0:
        # Enable to switch off string to Unicode coercion and implicit
        # Unicode to string conversion.
        encoding = "undefined"
    if encoding != "ascii":
        # On Non-Unicode builds this will raise an AttributeError...
        sys.setdefaultencoding(encoding) # Needs Python Unicode build !

def fix_appengine_py_zimpimport():
    class StaticPythonImporter(object):
        @classmethod
        def find_module(cls, fullmodname, path=None):
            # Cancel the effect of the py_zipimport module in Google
            # AppEngine. py_zipimport installs a .zip import handler which
            # can't properly import from /proc/self/exe . The default
            # zipimporter is just fine.
            if fullmodname == 'google.appengine.dist.py_zipimport':
                return cls  # Replace it with an empty module.
            return None
        @classmethod
        def load_module(self, fullmodname):
            mod = type(sys)(fullmodname)
            mod.__name__ = fullmodname
            return mod
    sys.meta_path[:0] = [StaticPythonImporter]


def main():
    setquit()
    setcopyright()
    sethelper()
    setencoding()
    # Remove sys.setdefaultencoding() so that users cannot change the
    # encoding after initialization.  The test for presence is needed when
    # this module is run as a script, because this code is executed twice.
    if hasattr(sys, "setdefaultencoding"):
        del sys.setdefaultencoding
    fix_appengine_py_zimpimport()

main()

def _script():
    help = """\
    %s [--user-base] [--user-site]

    Without arguments print some useful information
    With arguments print the value of USER_BASE and/or USER_SITE separated
    by '%s'.

    Exit codes with --user-base or --user-site:
      0 - user site directory is enabled
      1 - user site directory is disabled by user
      2 - uses site directory is disabled by super user
          or for security reasons
     >2 - unknown error
    """
    args = sys.argv[1:]
    if not args:
        print "sys.path = ["
        for dir in sys.path:
            print "    %r," % (dir,)
        print "]"
        print "USER_BASE: %r (%s)" % (USER_BASE,
            "exists" if os.path.isdir(USER_BASE) else "doesn't exist")
        print "USER_SITE: %r (%s)" % (USER_SITE,
            "exists" if os.path.isdir(USER_SITE) else "doesn't exist")
        print "ENABLE_USER_SITE: %r" %  ENABLE_USER_SITE
        sys.exit(0)

    buffer = []
    if '--user-base' in args:
        buffer.append(USER_BASE)
    if '--user-site' in args:
        buffer.append(USER_SITE)

    if buffer:
        print os.pathsep.join(buffer)
        if ENABLE_USER_SITE:
            sys.exit(0)
        elif ENABLE_USER_SITE is False:
            sys.exit(1)
        elif ENABLE_USER_SITE is None:
            sys.exit(2)
        else:
            sys.exit(3)
    else:
        import textwrap
        print textwrap.dedent(help % (sys.argv[0], os.pathsep))
        sys.exit(10)

if __name__ == '__main__':
    _script()
