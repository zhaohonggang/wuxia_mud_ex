inherit ROOM;

void create()
{
    set("short", "山间石阶");
    set("long", @LONG
这是一条蜿蜒的山间石阶，两旁杂草丛生，古树遮天蔽日。
石阶蜿蜒向上，通向白驼山庄大门，向下通往山脚。
LONG );
    set("exits", ([
        "northup"   : __DIR__"damen",
        "southdown" : __DIR__"shanlu",
    ]));
    set("outdoors", "minimal_world_v2");
    set("objects", ([
        __DIR__"obj/staff" : 1,
    ]));
    setup();
    replace_program(ROOM);
}