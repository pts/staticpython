"""pipes module for StaticPython."""

# Safe unquoted
_safechars = frozenset('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%-+=:,./')

def quote(file):
    """Return a shell-escaped version of the file string."""
    for c in file:
        if c not in _safechars:
            break
    else:
        if not file:
            return "''"
        return file
    # use single quotes, and put single quotes into double quotes
    # the string $'b is then quoted as '$'"'"'b'
    return "'" + file.replace("'", "'\"'\"'") + "'"
