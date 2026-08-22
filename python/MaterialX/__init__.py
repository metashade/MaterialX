# Python 3.8+ on Windows: DLL search paths for dependent
# shared libraries
# Refs.:
# - https://github.com/python/cpython/issues/80266
# - https://docs.python.org/3.8/library/os.html#os.add_dll_directory
import os
import sys
if sys.platform == "win32" and sys.version_info >= (3, 8):
    mxdir = os.path.dirname(__file__)
    if os.path.exists(mxdir):
        try:
            os.add_dll_directory(mxdir)
        except (AttributeError, OSError):
            pass
    # On a non-pip installation or editable install, this file is in %INSTALLDIR%\python\MaterialX
    # We need to add %INSTALLDIR%\bin to the DLL path.
    pydir = os.path.split(mxdir)[0]
    installdir = os.path.split(pydir)[0]
    bindir = os.path.join(installdir, "bin")
    if os.path.exists(bindir):
        try:
            os.add_dll_directory(bindir)
        except (AttributeError, OSError):
            pass
    if "MATERIALX_BIN_DIR" in os.environ and os.path.exists(os.environ["MATERIALX_BIN_DIR"]):
        try:
            os.add_dll_directory(os.environ["MATERIALX_BIN_DIR"])
        except (AttributeError, OSError):
            pass

from .main import *

__version__ = getVersionString()
