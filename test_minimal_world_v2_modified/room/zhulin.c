inherit ROOM;

void create()
{
    set("short", "竹林");
    set("long", @LONG
这是一片茂密的竹林，翠竹成荫，微风吹过，竹叶沙沙作响，
清爽宜人。几只小鸟在竹枝间跳跃鸣叫。南边是一条小路通向岩洞。
LONG );
    set("exits", ([
        "northup" : __DIR__"cave",
    ]));
    set("outdoors", "minimal_world_v2");
    set("objects", ([
        __DIR__"obj/staff" : 1,
        __DIR__"obj/throwing" : 1,
    ]));
    setup();
    replace_program(ROOM);
}