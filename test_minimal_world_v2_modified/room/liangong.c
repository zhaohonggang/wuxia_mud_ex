inherit ROOM;

void create()
{
    set("short", "练功房");
    set("long", @LONG
这里是白驼山庄的练功房，地上铺着厚厚的软垫，墙上挂着
各种兵器架。正中央竖着一个木人桩，四周墙壁上刻满了拳法
剑法的招式图解。空气中弥漫着淡淡的药香。
LONG );
    set("exits", ([
        "west" : __DIR__"houyuan",
    ]));
    set("objects", ([
        __DIR__"npc/worker-liu" : 1,
        __DIR__"obj/axe" : 1,
        __DIR__"obj/staff" : 1,
        __DIR__"obj/hammer" : 1,
        __DIR__"obj/throwing" : 1,
    ]));
    setup();
    replace_program(ROOM);
}