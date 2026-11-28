#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性工具：把 GBK 排布的 HZK16 点阵字库转成 UTF-8（Unicode 码点）索引的 pack。

A-5-c C3（docs/北京领赏reward-移植计划.zh-CN.md）。用户 2026-11-28 指定：
ex 侧全程保持 UTF-8，不做运行时 GBK 偏移换算——GBK→码点的换算在构建期由本
脚本完成，运行时按 UTF-8 字符直接索引 pack。

pack 格式（little-endian）：
  magic "HZK16PACK"(8B) + version u8=1 + font_count u8
  每 font：tag 1B(ASCII 字母) + count u16 + count × { codepoint u32 + bitmap 32B }

同时把 ASC16 原样拷贝（字节索引，ASCII 在 UTF-8 中同值），并为定向测试
生成若干样例词的 LPC 算法逐行渲染期望值（test/fixtures/bitmap_font/*.txt）。

LPC 算法参照：mudcore/system/kernel/simul_efun/bitmap_font.c:26-102
字库源：mudcore/system/kernel/simul_efun/fonts/HZK16{C,F,H,K,L,S,V,X,Y}、ASC16
"""

import os

SRC = r"C:/files/git/mud/mudcore/system/kernel/simul_efun/fonts"
OUT_DIR = r"C:/files/git/wuxia_mud_ex/priv/fonts"
FIXTURE_DIR = r"C:/files/git/wuxia_mud_ex/test/fixtures/bitmap_font"

FONT_TAGS = ["C", "F", "H", "K", "L", "S", "V", "X", "Y"]
MASKS = [0x80, 0x40, 0x20, 0x10, 0x8, 0x4, 0x2, 0x1]
FILL, BG = "8", "-"
SIZE, FONTSIZE = 16, 32  # 16 号点阵：每字 32 字节


def render(text, font_map, asc, size=SIZE, fontsize=FONTSIZE):
    """UTF-8 原生渲染（= ex 运行时语义）：按字符码点直接索引 pack，
    位掩码展开与 LPC bitmap_font.c 完全一致（字节数据同源，仅索引方式
    从「GBK 偏移换算」改为「构建期码点直查」）。"""
    out = [""] * size
    for ch in text:
        cp = ord(ch)
        if cp < 128:
            start = cp * size
            if start + size > len(asc):
                return "Can't read bytes from character lib.\n"
            bmp = asc[start:start + size]
            scale = 1
        else:
            bmp = font_map.get(cp)
            if bmp is None or len(bmp) != fontsize:
                return "Can't read bytes from character lib.\n"
            scale = fontsize // size
        for i in range(len(bmp)):
            row = out[i // scale]
            for j in range(8):
                row += FILL if (MASKS[j] & bmp[i]) else BG
            out[i // scale] = row
    return "\n".join(out)


def build_font_map(path):
    """读 HZK16?，按 GBK 全区位枚举，产出 {codepoint: 32B bitmap}。"""
    data = open(path, "rb").read()
    slots = len(data) // FONTSIZE  # 261696/32 = 8178 = 94区 × 87行
    assert slots == 94 * 87, "unexpected HZK16 size: %s" % path
    font_map = {}
    for b1 in range(0xA1, 0xF8):        # 区码 0xA1..0xF7
        for b2 in range(0xA1, 0xFF):    # 位码 0xA1..0xFE
            gbk = bytes([b1, b2])
            try:
                ch = gbk.decode("gbk")
            except UnicodeDecodeError:
                continue  # 空槽（未定义码位）
            offset = FONTSIZE * ((b1 - 0xA1) * 94 + (b2 - 0xA1))
            font_map[ord(ch)] = data[offset:offset + FONTSIZE]
    return font_map


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(FIXTURE_DIR, exist_ok=True)

    # ASC16：字节索引，原样拷贝
    asc = open(os.path.join(SRC, "ASC16"), "rb").read()
    with open(os.path.join(OUT_DIR, "asc16"), "wb") as f:
        f.write(asc)

    # pack：magic + version + font_count + 9 个 font 块
    pack = bytearray()
    pack += b"HZK16PACK"
    pack += bytes([1, len(FONT_TAGS)])

    maps = {}
    for tag in FONT_TAGS:
        path = os.path.join(SRC, "HZK16" + tag)
        font_map = build_font_map(path)
        maps[tag] = font_map
        pack += tag.encode("ascii")
        pack += len(font_map).to_bytes(2, "little")
        for cp in sorted(font_map):
            pack += cp.to_bytes(4, "little")
            pack += font_map[cp]
        print("HZK16%s: %d glyphs" % (tag, len(font_map)))

    with open(os.path.join(OUT_DIR, "hzk16.pack"), "wb") as f:
        f.write(bytes(pack))
    print("pack written: %s (%d bytes)"
          % (os.path.join(OUT_DIR, "hzk16.pack"), len(pack)))

    # 定向测试期望值：用 LPC 原算法（Python 复刻）渲染样例
    samples = [
        ("国富", "C"), ("国富", "F"),
        ("民强", "K"), ("龙腾", "Y"),
        ("AB", "C"), ("A国", "S"),
    ]
    for word, tag in samples:
        text = render(word, maps[tag], asc)
        with open(os.path.join(FIXTURE_DIR, "%s_%s.txt" % (word, tag)), "w",
                  encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("fixture: %s_%s -> %d lines" % (word, tag, len(text.split("\n"))))


if __name__ == "__main__":
    main()
