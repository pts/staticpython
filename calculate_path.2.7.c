

/* StaticPython */  /* StaticPython-appended */
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
static void calculate_path   (void) {
    extern char *Py_GetProgramName(void);

    static char delimiter[2] = {DELIM, '\0'};
    char *rtpypath = Py_GETENV("PYTHONPATH");
    char *path = getenv("PATH");
    char *prog = Py_GetProgramName();
    static char proc_exe_path[] = "/proc/self/exe";
    char *xzip_path;
    char *buf;

    /* If there is no slash in the argv0 path, then we have to
     * assume python is on the user's $PATH, since there's no
     * other way to find a directory to start the search from.  If
     * $PATH isn't exported, you lose.
     */
    if (strchr(prog, SEP))
            strncpy(progpath, prog, MAXPATHLEN);
    else if (path) {
            while (1) {
                    char *delim = strchr(path, DELIM);

                    if (delim) {
                            size_t len = delim - path;
                            if (len > MAXPATHLEN)
                                    len = MAXPATHLEN;
                            strncpy(progpath, path, len);
                            *(progpath + len) = '\0';
                    }
                    else
                            strncpy(progpath, path, MAXPATHLEN);

                    joinpath(progpath, prog);
                    if (isxfile(progpath))
                            break;

                    if (!delim) {
                            progpath[0] = '\0';
                            break;
                    }
                    path = delim + 1;
            }
    }
    else
            progpath[0] = '\0';
    if (progpath[0] != SEP && progpath[0] != '\0')
            absolutize(progpath);

    /**** pts ****/
    { int fd = open(proc_exe_path, O_RDONLY);
      char hdr[22];
      /* fprintf(stderr, "progpath=(%s)\n", progpath); */
      if (fd < 0) {  /* If /proc is not avaialbe, e.g. in chroot */
       after_bad_proc_exe:
        xzip_path = progpath;  /* Use argv[0] for the .zip filename */
      } else {
        xzip_path = proc_exe_path;
        if (lseek(fd, -22, SEEK_END) < 0) {
         bad_proc_exe:
          close(fd);
          goto after_bad_proc_exe;
        }
        if (read(fd, hdr, 22) != 22) goto bad_proc_exe;
        /* ZIP end-ef-central-directory header with comment size == 0. */
        /* We check this because Linux i386 code running Docker on macOS
         * Ventura 13 with Apple Silicon doesn't have a working
         * /proc/self/exe, so we fall back to progpath (arg[0], sys.interpreter).
         */
        if (memcmp(hdr, "PK\5\6", 4) != 0 || hdr[20] != 0 || hdr[21] != 0) goto bad_proc_exe;
        close(fd);
      }
    }
    /*fprintf(stderr, "info: xzip_path=(%s)\n", xzip_path);*/

    /**** pts ****/
    if (rtpypath == NULL || rtpypath[0] == '\0') {
        module_search_path = xzip_path;
    } else if (NULL == (buf = (char *)PyMem_Malloc(
        2 + strlen(xzip_path) + strlen(rtpypath)))) {
        /* We can't exit, so print a warning and limp along */
        fprintf(stderr, "Not enough memory for dynamic PYTHONPATH.\n");
        fprintf(stderr, "Using default static PYTHONPATH.\n");
        module_search_path = xzip_path;
    } else {
        strcpy(buf, rtpypath);
        strcat(buf, delimiter);
        strcat(buf, xzip_path);
        module_search_path = buf;
    }
}

