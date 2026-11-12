r"""The sound of YOU taking a hit (2026-11-12): sfx_player_hit, cut from the Sonniss GDC libraries (E:\Soniss SFX) into assets/Global/SFX/sfx_player_hit.wav (44.1 kHz stereo, 16 bit),
to go with the light-saber cuts of SaberSlash. Backups in assets/Global/_Backup_sfx_2026-11-12/: sfx_player_hit.wav (the original flat 0.97 s tone at 48 kHz) and
sfx_player_hit_v2_light.wav (the first Soniss mix: saber cut + slash impact + a small thump, which was too light). This version is HEAVY, so the player notices it. Layers:
    the BODY     "punch_heavy_huge_distorted_01" (Gamemaster Punch pack): a huge distorted punch, the weight of the blow
    the ROCK     "PM_RI_Designed_19 Rocks Impact Hit Big LFE Heavy Designed" (PMSFX Rocky Impacts): a big heavy impact with its crunch and LFE
    the SUB      "10 Hit Deep Thud" (Baxter Audio IMPACT): a deep sub thud that rings under it for a second
    the CLANG    "IMPACT METAL Short Slam_03" (SmartSoundFX): a bright metal slam, the part that cuts through and grabs the ear
    the BLADE    "SWSH_Sword Slash Impact V2 Assorted 18" (David Dumais): the blade cut that goes with the picture (the Mecha Energy Sword Cut layer was taken out 2026-11-12 at the user's request)
Everything is soft-clipped hard (tanh) so it is dense and loud, not just peaky.
Run with D:\GitHub Projects\AnySFXackend\.venv\Scripts\python.exe (numpy + soundfile); ffmpeg must be on the PATH."""
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_shop_sfx import RATE, fade, find, load, peak  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets" / "Global" / "SFX" / "sfx_player_hit.wav"


def put(mix, a, at, gain):
    i = int(at * RATE)
    mix[i:i + len(a)] += a[:len(mix) - i] * gain


mix = np.zeros((int(1.6 * RATE), 2), dtype=np.float32)
put(mix, fade(load(find("punch_heavy_huge_distorted_01"), 0.0, 0.5), 0.0, 0.15), 0.0, 1.0)
put(mix, fade(load(find("Rocks Impact Hit Big LFE Heavy Designed.wav"), 0.0, 1.1), 0.0, 0.5), 0.0, 0.85)
put(mix, fade(load(find("10 Hit Deep Thud"), 0.1, 1.4), 0.0, 0.7), 0.0, 0.75)
put(mix, fade(load(find("IMPACT METAL Short Slam_03"), 0.13, 0.7), 0.0, 0.35), 0.0, 0.55)
put(mix, fade(load(find("Sword Slash Impact V2 Assorted 18"), 0.04, 0.9), 0.0, 0.4), 0.0, 0.6)
mix = np.tanh(mix * 2.2).astype(np.float32)  # (soft clip: dense and loud)
sf.write(OUT, peak(fade(mix, 0.0, 0.4), -1.0), RATE, subtype="PCM_16")
print("sfx_player_hit %.2f s" % (len(mix) / RATE))
