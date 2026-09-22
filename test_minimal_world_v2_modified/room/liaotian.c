inherit ROOM;

void create()
{
    set("short", "聊天室");
    set("long", @LONG
这是客店后院的一间小屋，供住客休息聊天。墙上挂着几幅
山水画，角落里摆着一张八仙桌，几把竹椅。窗外是一片小花园，
鸟语花香，环境幽静。
LONG );
    set("exits", ([
        "north" : __DIR__"kedian",
    ]));
    set("no_fight", 1);
    set("no_sleep_room", 1);
    set("objects", ([
        __DIR__"obj/food" : 1,
        __DIR__"obj/water" : 1,
    ]));
    setup();
    replace_program(ROOM);
}