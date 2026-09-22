inherit ROOM;

void create()
{
    set("short", "后院");
    set("long", @LONG
这里是白驼山庄的后院，种着各种奇花异草，还有一口古井。
井边立着一块石碑，上刻"毒经"二字。四周种满了各种毒草，
散发着诡异的香气。东边是练功房，西边是毒物室。
LONG );
    set("exits", ([
        "south" : __DIR__"dating",
        "east"  : __DIR__"liangong",
        "west"  : __DIR__"duwushi",
    ]));
    set("outdoors", "minimal_world_v2");
    set("objects", ([
        __DIR__"obj/rice" : 1,
        __DIR__"obj/rice" : 1,
    ]));
    setup();
    replace_program(ROOM);
}