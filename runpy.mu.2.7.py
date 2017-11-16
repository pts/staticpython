def _run_module_as_main(mod_name, alter_argv=1):
  if mod_name == '__main__':
    # __import__('__main__') is a noop, and it's impossible to unload, so we
    # just do a fallback, which works for pdfsizeopt (because it has m.py in
    # the pdfsizeopt.single ZIP).
    mod_name = 'm'
  __import__(mod_name)
