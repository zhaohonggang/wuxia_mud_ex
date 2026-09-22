inherit ROOM;

void create()
{
    set("short", "白驼山庄大院");
    set("long", "这里是白驼山庄的大院，占地极广，青砖绿瓦，古树参天。\n"
        "院子中央摆着几个大水缸，四周种着几株古松。北边是大厅，\n"
        "南边通向大门。\n");
    set("exits", ([
        "south" : __DIR__"damen",
        "north" : __DIR__"dating",
    ]));
    set("outdoors", "minimal_world_v2");
    set("objects", ([
        __DIR__"obj/yuanzi_ornament1" : 1,
    ]));
    setup();
    replace_program(ROOM);
}