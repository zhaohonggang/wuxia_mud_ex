#include <room.h>
#include <ansi.h>

inherit ROOM;

void create()
{
    set("short", "白驼山庄大厅");
    set("long", "这是白驼山庄的大厅，气派非凡。大厅正中悬挂着一块匾额，\n"
        "上书\"毒中之王\"四个大字。厅内陈设奢华，两侧排列着太师椅，\n"
        "正中设有太师椅一把，乃是庄主议事之处。两侧各有侧门通往\n"
        "内院。\n");
set("outdoors", "minimal_world_v2");
    set("exits", ([
        "south" : __DIR__"yuanzi",
        "north" : __DIR__"houyuan"
    ]));
    set("objects", ([
        __DIR__"obj/mingshijilue" : 1,
        __DIR__"obj/wuzhirong" : 1,
        __DIR__"obj/zhuangyuncheng" : 1,
        __DIR__"npc/furen" : 1
    ]));
    setup();
    replace_program(ROOM);
}