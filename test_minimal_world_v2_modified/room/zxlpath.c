inherit ROOM;

void create()
{
    set("short", "醉仙楼大道");
    set("long", @LONG
这是通往醉仙楼的青石大道，两旁种满了桃树杨柳，春天桃红
柳绿，美不胜收。大道笔直通向北边的醉仙楼大门，南边是客店
北大街，西边是玫瑰宴厅，东边是牡丹宴厅。
LONG );
    set("exits", ([
        "south" : __DIR__"beidajie1",
        "north" : __DIR__"damen",
        "west"  : __DIR__"furong",
        "east"  : __DIR__"mudan",
    ]));
    set("outdoors", "minimal_world_v2");
    set("objects", ([
        __DIR__"obj/food" : 1,
        __DIR__"obj/water" : 1,
        __DIR__"obj/wine" : 1,
    ]));
    setup();
    replace_program(ROOM);
}