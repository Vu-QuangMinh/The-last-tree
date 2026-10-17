"""The Handyman's recorded lines (docs/dialogue/Handy_voice.wav, one long take) cut into one clip per line of his talk (scripts/core/boss_talk.gd node ids),
with the time of every word, so the game can show the words as they are said.
  1. Whisper (ReadAnyBook's faster-whisper, word timestamps) hears the take:
     cd "D:/GitHub Projects/ReadAnyBook" && ./rvc_env/Scripts/python.exe transcribe_to_srt.py --src <wav> --out <any>.srt --words-out <words.json> --lang en --model medium
  2. this script cuts the wav at the quietest moment of the pause between two lines (LINES below says which words open and close each line) and writes
     assets/Puppet/Voice/handyman/<id>.wav (48 kHz stereo 16 bit, a few ms of fade at both ends) + handyman_voice.json (id, file, length, text, and the words with
     their times inside the clip).
Run with ReadAnyBook's python (numpy + soundfile):  rvc_env/Scripts/python.exe tools/split_handyman_voice.py [words.json]  (default: docs/dialogue/handy_voice_words.json, the words of the
current take; made by step 1 for a new take). Every clip is passed through loudness.loudify (compressed, speaking level -11 dB, peaks under -1 dB)"""
import json
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loudness import loudify

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "docs", "dialogue", "Handy_voice.wav")
OUT = os.path.join(ROOT, "assets", "Puppet", "Voice", "handyman")
# (BossTalk node id, number of the first word of the line, number of the last word) - counted in the whisper words, 0-based, found by reading words.json;
# set below from the first words of each line so a new take only needs the words, not numbers
LINES = [
    ("hm_greeting", "Hello", "Hee", "Hello there, weary traveler. You seem burdened. Would you like me to give you A HAND? Hehe, hehehe."),
    ("hm_sure", "How", "Mu", "How about MORE than just A hand? Muahahahah!"),
    ("hm_creepy", "Thank", "Mu", "Thank you for your compliment. Let's see how you feel about this! Muahahahah!"),
    ("hm_why", "Fate", "up.", "Fate put me here to, uhm, fix you up. Hehe, hehe."),
    ("hm_why_chance", "Oh", "Hee", "Oh no, my Chosen One, it was written. You were destined to walk this Path and be... HANDLED by me. Hehe, you will get that soon enough. Hehehehe."),
    ("hm_why_chance_show", "With", "Mu", "With pleasure! Muahahahah!"),
    ("hm_why_chance_hands_a", "My", "one.", "My hands are a gift from God. They are so wonderful. Here, take a look at this one."),
    ("hm_why_chance_hands_b", "This", "Ha", "This used to belong to a great artist, but it is MINE now. I will show you the rest, in due time. Hahahahaha."),
]
# a giggle the recogniser did not hear (it is in the take, found by listening to the level between two lines): [start, end, text] added to the line
EXTRA = {}
QUIET = 0.03  # peak level (of 1.0) below which a 10 ms slice counts as silence
PAD_IN = 0.06  # seconds kept before the first word / after the last word
PAD_OUT = 0.30


def main():
    words = json.load(open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "dialogue", "handy_voice_words.json"), encoding="utf-8"))  # [[start, end, text], ...]
    data, sr = sf.read(SRC, dtype="float32", always_2d=True)
    mono = np.abs(data).max(axis=1)
    # where each line starts: the first word that is its opening word, searched from the end of the previous line
    starts = []
    k = 0
    for _id, first, _last, _text in LINES:
        while k < len(words) and not words[k][2].startswith(first):
            k += 1
        starts.append(k)
        k += 1
    bounds = starts + [len(words)]
    os.makedirs(OUT, exist_ok=True)
    meta = []
    cut_prev = 0.0
    for i, (nid, first, _last, text) in enumerate(LINES):
        a, b = bounds[i], bounds[i + 1]
        ws = words[a:b] + EXTRA.get(nid, [])
        t0, t1 = ws[0][0], ws[-1][1]
        # the end of this clip / the start of the next: the middle of the quiet stretch just before the next line's first word (whatever was said before it, a laugh
        # the recogniser did not hear included, stays in this clip)
        last_loud = t1
        if i + 1 < len(LINES):
            nxt = words[b][0]
            win = int(0.01 * sr)
            pos = int((nxt - 0.12) * sr)  # (a breath or the first sound of the next line starts a little before the recogniser's time)
            while pos > int(t1 * sr) and float(mono[pos - win:pos].max()) < QUIET:
                pos -= win
            last_loud = pos / sr
            cut_next = (last_loud + nxt - 0.12) / 2.0
        else:
            cut_next = len(data) / sr
            pos = len(data)
            win = int(0.01 * sr)
            while pos > int(t1 * sr) and float(mono[pos - win:pos].max()) < QUIET:
                pos -= win
            last_loud = pos / sr
        start = max(cut_prev, t0 - PAD_IN)
        end = min(cut_next, max(t1, last_loud) + PAD_OUT)
        clip = data[int(start * sr):int(end * sr)].copy()
        fade = int(0.008 * sr)
        clip[:fade] *= np.linspace(0, 1, fade)[:, None]
        clip[-fade:] *= np.linspace(1, 0, fade)[:, None]
        clip = loudify(clip, sr, target_db=-11.0)  # (the game's sounds are loud: the voice has to stand above them and the music)
        peak = float(np.abs(clip).max())
        path = os.path.join(OUT, nid + ".wav")
        sf.write(path, clip, sr, subtype="PCM_16")
        meta.append({"id": nid, "file": "res://assets/Puppet/Voice/handyman/%s.wav" % nid, "length": round(len(clip) / sr, 3), "text": text, "peak": round(peak, 3),
                     "words": [[round(w[0] - start, 3), round(w[1] - start, 3), w[2]] for w in ws]})
        print("%-24s %6.2f - %6.2f  (%.2f s)  last loud %.2f cut %.2f  %s" % (nid, start, end, end - start, last_loud, cut_next, " ".join(w[2] for w in ws)[:44]))
        cut_prev = cut_next
    json.dump(meta, open(os.path.join(OUT, "handyman_voice.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
