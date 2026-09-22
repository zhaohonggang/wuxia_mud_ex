// Test file for __DIR__ macro variations
#include <room.h>

inherit ROOM;

void create()
{
    set("short", "测试房间");
    set("long", @LONG
这是一个测试房间，用于验证各种 __DIR__ 宏变体。
LONG);

    // 简单引用
    set("exits", ([
        "north"  : __DIR__"room1",
        "south"  : __DIR__"room2",
    ]));

    // 子目录引用
    set("objects", ([
        __DIR__"npc/guard" : 1,
        __DIR__"obj/sword" : 1,
    ]));

    // 相对路径引用
    set("exits", ([
        "up"    : __DIR__"../room_above",
        "down"  : __DIR__"../room_below",
    ]));

    // 多级子目录
    set("item_desc", ([
        "sign" : __DIR__"obj/signboard/sign",
    ]));

    setup();
    replace_program(ROOM);
}
