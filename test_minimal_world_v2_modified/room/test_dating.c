#include <room.h>
#include <ansi.h>

inherit ROOM;

void create()
{
    set("short", "测试大厅");
    set("long", "这是一个测试大厅。\n");
    set("exits", ([
        "south" : __DIR__"yuanzi",
        "north" : __DIR__"houyuan"
    ]));
    setup();
    replace_program(ROOM);
}