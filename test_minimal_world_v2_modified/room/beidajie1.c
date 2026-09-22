inherit ROOM;

void create()
{
    set("short", "北大街");
    set("long", @LONG
这是一条宽阔的青石大街，两旁店铺林立，行人熙熙攘攘。
北边是玫瑰宴厅，西边是牡丹宴厅，东边通往客店。
LONG );
    set("exits", ([
        "east"  : __DIR__"kedian",
        "north" : __DIR__"furong",
        "west"  : __DIR__"mudan",
    ]));
    set("outdoors", "minimal_world_v2");
    set("objects", ([
        __DIR__"obj/cloth" : 1,
        __DIR__"obj/blade1" : 1,
        __DIR__"obj/food" : 1,
    ]));
    setup();
    replace_program(ROOM);
}