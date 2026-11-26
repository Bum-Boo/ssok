#!/usr/bin/env python3
"""Build or check the single-face workshop font. See assets/fonts/README.md."""

from __future__ import annotations

import argparse
from hashlib import sha256
from pathlib import Path
import re
import subprocess
import unicodedata
from zipfile import ZipFile

from fontTools import subset
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.ttLib import TTFont


PROJECT = Path(__file__).resolve().parents[2]
OUTPUT = PROJECT / "assets/fonts/SsokSans-Regular.otf"
SOURCE_SHA256 = "b76b0433203017ca80401b2ee0dd69350349871c4b19d504c34dbdd80541690a"
UNIHAN_SHA256 = "b8f000df69de7828d21326a2ffea462b04bc7560022989f7cc704f10521ef3e0"
SOURCE_TYPES = ("*.po", "*.pot", "*.json", "*.gd", "*.tscn")
ESCAPE = re.compile(r"\\u(?:\{([0-9a-fA-F]{1,6})\}|([0-9a-fA-F]{4}))")
BEE = 0x1F41D


def verify_source(path: Path, expected: str) -> None:
    if sha256(path.read_bytes()).hexdigest() != expected:
        raise SystemExit(f"Source checksum mismatch: {path}")


def repository_codepoints() -> set[int]:
    files = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--", *SOURCE_TYPES],
        cwd=PROJECT,
    ).decode("utf-8").split("\0")
    points = set()
    for name in filter(None, files):
        path = PROJECT / name
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8-sig")
        points.update(map(ord, text))
        points.update(int(match[1] or match[2], 16) for match in ESCAPE.finditer(text))
    # Controls, format characters and standalone surrogates have no visible glyph.
    return {point for point in points if point <= 0x10FFFF and unicodedata.category(chr(point))[0] != "C"}


def legacy_han_and_hangul() -> tuple[set[int], set[int]]:
    hangul = {ord(bytes((row, col)).decode("euc_kr"))
              for row in range(0xB0, 0xC9) for col in range(0xA1, 0xFF)}
    simplified = {ord(bytes((row, col)).decode("gb2312"))
                  for row in range(0xB0, 0xD8) for col in range(0xA1, 0xFF)
                  if row != 0xD7 or col <= 0xF9}
    if len(hangul) != 2350 or len(simplified) != 3755:
        raise SystemExit("Unexpected KS X 1001 or GB2312 mapping size")
    return hangul, simplified


def required_codepoints(unihan: Path) -> set[int]:
    verify_source(unihan, UNIHAN_SHA256)
    with ZipFile(unihan) as archive:
        mappings = archive.read("Unihan_OtherMappings.txt").decode("utf-8").splitlines()
    joyo = {int(line.split("\t", 1)[0][2:], 16) for line in mappings if line.endswith("\tkJoyoKanji\t2010")}
    if len(joyo) != 2136:
        raise SystemExit("Unexpected 2010 Joyo Kanji mapping size")
    hangul, simplified = legacy_han_and_hangul()
    ranges = (
        (0x0020, 0x007E), (0x00A0, 0x00FF), (0x1100, 0x11FF), (0x3000, 0x303F),
        (0x3041, 0x3096), (0x3099, 0x30FF), (0x3131, 0x318E), (0x31F0, 0x31FF),
        (0xA960, 0xA97C), (0xD7B0, 0xD7C6), (0xD7CB, 0xD7FB), (0xFF01, 0xFF9F),
    )
    fixed = {point for first, last in ranges for point in range(first, last + 1)}
    fixed.update(map(ord, "Ωμ°×÷±→←↑↓·—–−…•℃℉✓"))
    return repository_codepoints() | joyo | hangul | simplified | fixed | {BEE}


def add_bee(font: TTFont) -> None:
    """The Beehave debugger's bee is outside Noto CJK. Add a small original outline."""
    cff = font["CFF "].cff
    top = cff.topDictIndex[0]
    strings = top.CharStrings
    order = font.getGlyphOrder()
    # A CID near the end of the original range is unused by this subset.
    cid = max(int(name[3:]) for name in order[1:]) + 1
    name = f"cid{cid:05d}"
    pen = T2CharStringPen(1000, None)
    outlines = (
        ((72, 267), (148, 335), (247, 413), (313, 511), (414, 551), (540, 540), (606, 473),
         (708, 493), (829, 459), (891, 361), (866, 245), (795, 191), (699, 189), (587, 220),
         (496, 162), (365, 147), (254, 183), (160, 247)),
        ((350, 567), (274, 636), (263, 718), (328, 777), (420, 753), (502, 661), (522, 576),
         (461, 580), (409, 664), (352, 706), (329, 681), (371, 622), (419, 570)),
        ((522, 590), (516, 691), (552, 774), (628, 795), (678, 737), (663, 653), (596, 552),
         (560, 564), (600, 673), (615, 735), (589, 724), (566, 660), (566, 555)),
        ((783, 439), (819, 439), (871, 525), (837, 551)),
    )
    holes = (
        ((270, 386), (313, 387), (404, 185), (359, 182)),
        ((387, 487), (425, 505), (555, 234), (516, 213)),
        ((742, 382), (773, 408), (802, 383), (783, 352), (751, 352)),
    )
    for points in (*outlines, *(tuple(reversed(hole)) for hole in holes)):
        pen.moveTo(points[0])
        for point in points[1:]:
            pen.lineTo(point)
        pen.closePath()
    index = strings.charStringsIndex
    selector = top.FDSelect.gidArray[0]
    strings.charStrings[name] = len(index)
    index.append(pen.getCharString(private=top.FDArray[selector].Private, globalSubrs=cff.GlobalSubrs))
    top.FDSelect.gidArray.append(selector)
    top.charset = [*order, name]
    font.setGlyphOrder(top.charset)
    top.CIDCount = max(top.CIDCount, cid + 1)
    font["hmtx"].metrics[name] = (1000, 72)
    if "vmtx" in font:
        font["vmtx"].metrics[name] = font["vmtx"].metrics[order[0]]
    for table in font["cmap"].tables:
        if table.isUnicode() and table.format == 12:
            table.cmap[BEE] = name


def restore_proportional_alternates(font: TTFont, regular: TTFont) -> None:
    # TextEdit reads the base space width for tabs. Keep mono as the default cmap
    # and limit the UI's proportional feature to differences from the regular face.
    mono_cmap = font.getBestCmap()
    regular_cmap = regular.getBestCmap()
    alternates = {mono_cmap[point]: regular_cmap[point] for point in sorted(mono_cmap.keys() & regular_cmap.keys())
                  if mono_cmap[point] != regular_cmap[point]}
    layout = font["GSUB"].table
    lookup, = {index for record in layout.FeatureList.FeatureRecord if record.FeatureTag == "pwid"
               for index in record.Feature.LookupListIndex}
    subtable, = layout.LookupList.Lookup[lookup].SubTable
    subtable.mapping = alternates


def build(source: Path, output: Path, points: set[int]) -> None:
    verify_source(source, SOURCE_SHA256)
    with TTFont(source, fontNumber=5, recalcTimestamp=False) as font, TTFont(source, fontNumber=0) as regular:
        restore_proportional_alternates(font, regular)
        options = subset.Options()
        options.layout_features.append("pwid")
        options.layout_scripts = ["DFLT"] + [f"{script}.{lang}" for script in ("cyrl", "grek", "hang", "hani", "kana", "latn")
                                              for lang in ("dflt", "JAN", "KOR", "ZHS")]
        options.name_IDs = list(range(15))
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=points - {BEE})
        subsetter.subset(font)
        add_bee(font)
        for record in font["name"].names:
            value = {1: "Ssok Sans", 3: "SsokSans-Regular-2.004", 4: "Ssok Sans Regular", 6: "SsokSans-Regular"}.get(record.nameID)
            if value is not None:
                record.string = value.encode(record.getEncoding())
        cff = font["CFF "].cff
        cff.fontNames[0] = "SsokSans-Regular"
        top = cff.topDictIndex[0]
        top.FamilyName, top.FullName = "Ssok Sans", "Ssok Sans Regular"
        for index, dictionary in enumerate(top.FDArray):
            dictionary.FontName = f"SsokSans-Regular-{index}"
        font.save(output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Noto Sans CJK 2.004 regular TTC")
    parser.add_argument("--unihan", type=Path, required=True, help="Unicode 16.0 Unihan.zip")
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--check", action="store_true", help="Verify the committed font without rebuilding it")
    args = parser.parse_args()
    points = required_codepoints(args.unihan)
    if not args.check:
        if args.source is None:
            parser.error("--source is required when building")
        build(args.source, args.output, points)
    with TTFont(args.output) as font:
        missing = sorted(points - font.getBestCmap().keys())
        if missing:
            raise SystemExit("Missing glyphs: " + ", ".join(f"U+{point:04X}" for point in missing))
        print(f"{args.output.name}: {len(points)} required codepoints, {font['maxp'].numGlyphs} glyphs, "
              f"{args.output.stat().st_size} bytes")


if __name__ == "__main__":
    main()
