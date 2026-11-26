# Bundled CJK font

`SsokSans-Regular.otf` is a single-face derivative of Noto Sans CJK 2.004.
It includes printable ASCII and Latin-1, workshop symbols and visible characters in
the repository's `.po`, `.pot`, `.json`, `.gd` and `.tscn` files. Learner text
coverage includes 2,350 KS X 1001 Hangul syllables, Hangul jamo, Japanese kana and
2,136 Jōyō kanji, and 3,755 GB2312 level-1 ideographs. The debugger's bee is an
original outline added to this font. The font ships under [SIL OFL 1.1](OFL.txt)
with the original copyright in its name table.

The face has fixed-width ASCII for the code editor. The shared UI font uses
OpenType `pwid` to recover the original proportional Latin advances. OpenType
`locl` supplies Korean, Japanese and Simplified Chinese forms in the shaping locale.

## Rebuild and verify

Download [Noto Sans CJK 2.004 regular TTC](https://raw.githubusercontent.com/notofonts/noto-cjk/Sans2.004/Sans/OTC/NotoSansCJK-Regular.ttc)
and [Unicode 16.0 Unihan.zip](https://www.unicode.org/Public/16.0.0/ucd/Unihan.zip)
outside the project or under the ignored `build/` directory. The script verifies
both SHA-256 digests and uses Python's `euc_kr` and `gb2312` codecs for the two
national character sets.

```sh
python -m pip install fonttools==4.56.0
python tools/fonts/subset_cjk.py --source build/NotoSansCJK-Regular.ttc --unihan build/Unihan.zip
python tools/fonts/subset_cjk.py --check --unihan build/Unihan.zip
```
