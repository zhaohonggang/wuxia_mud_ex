// Multiple include test
#include <room.h>
#include <ansi.h>
#include <weapon.h>
#include <condition.h>
#include "custom_header.h"

inherit ROOM;

void create()
{
    set("short", "多重包含测试");
    set("long", @LONG
测试多重 #include 指令的解析。
LONG);

    set("exits", ([
        "north" : __DIR__"room1",
    ]));

    setup();
    replace_program(ROOM);
}
