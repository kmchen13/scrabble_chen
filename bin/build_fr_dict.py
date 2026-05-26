import re

INPUT = "/usr/share/hunspell/fr_FR.dic"
OUTPUT = "fr.txt"

WORD_RE = re.compile(r"^[A-Za-zÀ-ÖØ-öø-ÿ]+$")

words = set()

with open(INPUT, encoding="latin-1") as f:
    next(f)  # ignore nombre initial

    for line in f:
        word = line.strip().split("/")[0]

        if WORD_RE.fullmatch(word):
            words.add(word.upper())

with open(OUTPUT, "w", encoding="utf-8") as f:
    for w in sorted(words):
        f.write(w + "\n")

print(f"✅ {len(words)} mots écrits dans {OUTPUT}")
