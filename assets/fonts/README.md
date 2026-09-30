# Bundled CJK font

`NotoSansCJK-Regular.ttc` is the unmodified Noto Sans CJK regular collection
(version 2.004, installed `noto-fonts-cjk` package). Source project:
https://github.com/notofonts/noto-cjk. Copyright notices are embedded in the font;
the SIL Open Font License 1.1 is included in `OFL.txt`.

The collection shares outlines across regional faces: JP=0, KR=1, SC=2;
the corresponding monospace faces are 5, 6, 7. The UI selects the regional face
and the code editor uses its monospace counterpart. All faces are bundled for
desktop/web, without depending on an installed system font. This adds about
19 MB before export compression; it is deliberately not a UI-only glyph subset
so learners can type their own Korean, Chinese and Japanese text.
