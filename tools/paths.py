"""Where the sister projects live on this machine. Every tool that reaches outside this repo imports these names;
set the environment variable to point elsewhere when a folder moves (e.g. BTC_IMAGESET_OUT=F:\\ImageSet)."""
import os


def _p(env: str, default: str) -> str:
    return os.path.normpath(os.environ.get(env, default))


TACHNEN = _p("BTC_TACHNEN_DIR", r"D:\GitHub Projects\Tachnen")          # background cutter (tachnen_core, its .venv python)
IMAGESET = _p("BTC_IMAGESET_DIR", r"D:\GitHub Projects\ImageSet")       # ImageSet code (main.py --batch); its older output\ folder is here too
IMAGESET_OUT = _p("BTC_IMAGESET_OUT", r"E:\GitHub\ImageSet")            # ImageSet data / outputs (the big pictures: ...\output\<set name>)
ANYSFX = _p("BTC_ANYSFX_DIR", r"D:\GitHub Projects\AnySFX")             # sound generator
READANYBOOK = _p("BTC_READANYBOOK_DIR", r"D:\GitHub Projects\ReadAnyBook")  # voices (its rvc_env python, Gemini TTS keys)
