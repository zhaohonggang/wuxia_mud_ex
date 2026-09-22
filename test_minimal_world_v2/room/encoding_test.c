// Encoding test file - GBK/UTF-8 mixed content
#include <ansi.h>

inherit ROOM;

void create()
{
    set("short", "编码测试房间");
    set("long", @LONG
这是一个包含特殊中文字符的房间：
- 常用字：中文测试
- 生僻字：龘靐齉爨
- 标点符号：。、；：「」『』（）［］〔〕
- 数字：１２３４５６７８９０
- 英文：ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
LONG);

    set("exits", ([
        "north" : __DIR__"room1",
    ]));

    setup();
    replace_program(ROOM);
}
