"""Records the PRAM announcements into assets/pram/, using the scripts in
lib/models/pram_item.dart. The ORIGINAL card (en-US-JennyNeural) goes to
assets/pram/<id>.mp3; the other simulated PRAM cards (female voices only)
go to assets/pram/<card>/<id>.mp3.

    python tool/gen_pram.py                  # ORIGINAL card, all announcements
    python tool/gen_pram.py safety           # only the listed ids
    python tool/gen_pram.py --card aria      # one other card
    python tool/gen_pram.py --card all       # every card
"""
import asyncio
import sys
import os
import re

import edge_tts

# Card folder -> voice. Keep in step with pramCards in lib/models/cartridge.dart.
CARDS = {
    "": "en-US-JennyNeural",
    "aria": "en-US-AriaNeural",
    "michelle": "en-US-MichelleNeural",
    "sonia": "en-GB-SoniaNeural",
    "natasha": "en-AU-NatashaNeural",
}
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def read_scripts():
    src = open(os.path.join(ROOT, "lib", "models", "pram_item.dart"), encoding="utf-8").read()
    items = {}
    for block in re.findall(r"PramItem\((.*?)\n  \)", src, re.S):
        if "isMusic: true" in block:
            continue
        pid = re.search(r"id: '([^']+)'", block).group(1)
        script = re.search(r"script:\s*((?:'[^']*'\s*)+)", block).group(1)
        items[pid] = "".join(re.findall(r"'([^']*)'", script))
    return items


async def record(card, only):
    voice = CARDS[card]
    out = os.path.join(ROOT, "assets", "pram", card) if card else os.path.join(ROOT, "assets", "pram")
    os.makedirs(out, exist_ok=True)
    for pid, text in read_scripts().items():
        if only and pid not in only:
            continue
        path = os.path.join(out, pid + ".mp3")
        await edge_tts.Communicate(text, voice, rate="+0%").save(path)
        print(card or "original", pid, os.path.getsize(path), "bytes")


async def main():
    args = sys.argv[1:]
    card = ""
    if "--card" in args:
        i = args.index("--card")
        card = args[i + 1]
        del args[i:i + 2]
    cards = [c for c in CARDS if c] if card == "all" else [card]
    for c in cards:
        await record(c, set(args))


asyncio.run(main())
