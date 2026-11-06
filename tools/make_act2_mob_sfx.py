r"""Sounds for the Act 2 mob fights (2026-11-06), cut from the Sonniss GDC libraries (E:\Soniss SFX) into assets/Puppet/SFX (44.1 kHz stereo, 16 bit).
Run with D:\GitHub Projects\AnySFX\backend\.venv\Scripts\python.exe (numpy + soundfile); ffmpeg must be on the PATH.
    sfx_throw_whoosh   something thrown from behind the Orphans' bush
    sfx_explode        Bug Hunter 1.0 goes off
    sfx_power_down     the Sentinel stuns itself to recharge
    sfx_boot_up        Bug Hunter reboots with 5 Essence
    sfx_flyer_fall     a flyer is knocked out of the air
    sfx_kids_giggle    the Orphans peek out / run away
    sfx_head_scream    the Horseman screams through his head, then throws it
The ones Soniss has nothing good for (sfx_sentinel_wake, sfx_lamp_glow, sfx_stun_apply) come from AnySFX: tools/make_act2_mob_sfx_ai.py"""
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_shop_sfx import fade, find, load, peak  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets" / "Puppet" / "SFX"


def cut(out, name, length, db=-3.0, fin=0.0, fout=0.1, start=0.0):
    a = fade(load(find(name), start, length), fin, fout)
    sf.write(OUT / (out + ".wav"), peak(a, db), 44100, subtype="PCM_16")
    print("%-18s %.2f s  <- %s" % (out, len(a) / 44100, name))


cut("sfx_throw_whoosh", "Action Swish_HW 02", 0.7, -8, fout=0.15)
cut("sfx_explode", "EFX EXT Mortar Explosion 08", 2.2, -2, fout=0.8)
cut("sfx_power_down", "PowerDown_DDM19", 1.8, -6, fout=0.4)
cut("sfx_boot_up", "System Boot_2", 1.6, -8, fout=0.3)
cut("sfx_flyer_fall", "IMPACT_LOW_THUD_10", 1.0, -5, fout=0.1)
cut("sfx_kids_giggle", "Female suppressed giggly laughter 03.M", 1.8, -8, fout=0.3)
cut("sfx_head_scream", "Creature Scream_SI 07", 1.6, -6, fout=0.3)
