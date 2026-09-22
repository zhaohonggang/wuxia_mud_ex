inherit ROOM;

void create()
{
    set("short", "赌场大厅");
    set("long", @LONG
这里是赌场的大厅，人声鼎沸，烟雾缭绕。四周摆满了各式
赌桌，骰子、牌九、马吊应有尽有。空气中弥漫着酒气和汗味，
夹杂着金银碰撞的清脆声响。北边是贵宾厅。
LONG );
    set("exits", ([
        "north" : __DIR__"bet",
    ]));
    set("outdoors", "minimal_world_v2");
    setup();
    replace_program(ROOM);
}