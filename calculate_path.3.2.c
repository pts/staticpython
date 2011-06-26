

/* StaticPython */  /* StaticPython-appended */
#include <fcntl.h>
static void calculate_path   (void) {
    extern wchar_t *Py_GetProgramName(void);

    static wchar_t delimiter[2] = {DELIM, '\0'};
    char *_rtpypath = Py_GETENV("PYTHONPATH");
    wchar_t rtpypath[MAXPATHLEN + 1];
    char *_path = getenv("PATH");
    wchar_t pathbuf[MAXPATHLEN + 1];
    wchar_t *prog = Py_GetProgramName();
    static wchar_t proc_exe_path[] = L"/proc/self/exe";
    wchar_t *xzip_path;
    wchar_t *buf;

    /* If there is no slash in the argv0 path, then we have to
     * assume python is on the user's $PATH, since there's no
     * other way to find a directory to start the search from.  If
     * $PATH isn't exported, you lose.
     */
    if (wcschr(prog, SEP))
        wcsncpy(progpath, prog, MAXPATHLEN);
    else if (_path) {
        size_t s = mbstowcs(pathbuf, _path, sizeof(pathbuf) / sizeof(wchar_t));
        if (s == (size_t)-1 || s >= sizeof(pathbuf) / sizeof(wchar_t))
          /* XXX deal with errors more gracefully */
          _path = NULL;
        if (_path) {
          wchar_t *path = pathbuf;
          while (1) {
            wchar_t *delim = wcschr(path, DELIM);

            if (delim) {
                size_t len = delim - path;
                if (len > MAXPATHLEN)
                    len = MAXPATHLEN;
                wcsncpy(progpath, path, len);
                *(progpath + len) = '\0';
            }
            else
                wcsncpy(progpath, path, MAXPATHLEN);

            joinpath(progpath, prog);
            if (isxfile(progpath))
                break;

            if (!delim) {
                progpath[0] = L'\0';
                break;
            }
            path = delim + 1;
          }
        }
    }
    else
        progpath[0] = '\0';
    if (progpath[0] != SEP && progpath[0] != '\0')
            absolutize(progpath);

    /**** pts ****/
    { FILE *f = _Py_wfopen(proc_exe_path, L"rb");
      /* fprintf(stderr, "progpath=(%s)\n", progpath); */
      if (f == NULL) {  /* If /proc is not avaialbe, e.g. in chroot */
        xzip_path = progpath;  /* Use argv[0] for the .zip filename */
      } else {
        xzip_path = proc_exe_path;
        fclose(f);
      }
    }

    if (_rtpypath != NULL) {
      size_t s = mbstowcs(rtpypath, _rtpypath, sizeof(rtpypath) / sizeof(wchar_t));
      if (s == (size_t)-1 || s >= sizeof(rtpypath) / sizeof(wchar_t))
        /* XXX deal with errors more gracefully */
        _rtpypath = NULL;
    }

    /**** pts ****/
    if (_rtpypath == NULL || _rtpypath[0] == '\0') {
      module_search_path = xzip_path;
    } else {
      if (NULL == (buf = (wchar_t *)PyMem_Malloc(
        sizeof(wchar_t) * (2 + wcslen(xzip_path) + wcslen(rtpypath))))) {
        /* We can't exit, so print a warning and limp along */
        fprintf(stderr, "Not enough memory for dynamic PYTHONPATH.\n");
        fprintf(stderr, "Using default static PYTHONPATH.\n");
        module_search_path = xzip_path;
      } else {
        wcscpy(buf, rtpypath);
        wcscat(buf, delimiter);
        wcscat(buf, xzip_path);
        module_search_path = buf;
      }
    }
}

