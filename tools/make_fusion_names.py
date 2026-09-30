"""Builds data/fusion_names.json: the name of every spell fusion, ready before it ever happens.

A fused spell is called '<adjective of one> <noun of the other>' (words from data/fusion_words.json).
Which spell gives the noun doesn't depend on the order they were fused in: the rarer one (then the longer
pattern, then the id) gives the noun. If the two words share a root ('Misty Mistwalk'), the roles swap.
Usage: python tools/make_fusion_names.py
"""
import itertools
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), '..')
RANK = {'common': 0, 'rare': 1, 'legendary': 2}


def main():
    spells = json.load(open(os.path.join(ROOT, 'data', 'spells.json'), encoding='utf-8'))
    spells = spells if isinstance(spells, list) else spells['spells']
    words = json.load(open(os.path.join(ROOT, 'data', 'fusion_words.json'), encoding='utf-8'))
    ok = [s for s in spells if not s.get('power', False)]
    missing = [s['id'] for s in ok if s['id'] not in words]
    assert not missing, 'no fusion words for: %s' % missing

    def rank(s):
        return (RANK.get(s.get('rarity', 'common'), 0), len(s['pattern']), s['id'])

    def clash(a, b):
        a, b = a.lower().replace('-', ''), b.lower().replace('-', '')
        return a[:4] == b[:4] or a in b or b in a

    names = {}
    for a, b in itertools.combinations(ok, 2):
        hi, lo = (a, b) if rank(a) > rank(b) else (b, a)
        adj, noun = words[lo['id']][0], words[hi['id']][1]
        if clash(adj, noun):
            adj, noun = words[hi['id']][0], words[lo['id']][1]
        if clash(adj, noun):
            noun = words[lo['id']][1] + ' of ' + words[hi['id']][1]
            adj = ''
        key = '|'.join(sorted([a['id'], b['id']]))
        names[key] = (adj + ' ' + noun).strip()
    dupes = {}
    for k, v in names.items():
        dupes.setdefault(v, []).append(k)
    dupes = {v: ks for v, ks in dupes.items() if len(ks) > 1}
    json.dump(names, open(os.path.join(ROOT, 'data', 'fusion_names.json'), 'w', encoding='utf-8'), indent=0, ensure_ascii=False, sort_keys=True)
    print('%d fusion names written, %d duplicate names' % (len(names), len(dupes)))
    for v, ks in list(dupes.items())[:10]:
        print('  dupe:', v, ks)


if __name__ == '__main__':
    main()
