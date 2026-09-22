inherit ROOM;

void create()
{
    set("short", "岩洞深处");
    set("long", @LONG
岩洞越往里越宽敞，洞壁上长满了发光的苔藓，泛着幽幽的
蓝绿色光芒。地下有清澈的地下河流过，水声潺潺。洞顶垂下
无数钟乳石，形态各异。出口在南边。
LONG );
    set("exits", ([
        "out" : __DIR__"cave",
    ]));
    set("outdoors", "minimal_world_v2");
    set("objects", ([
        __DIR__"obj/throwing" : 1,
        __DIR__"obj/dagger" : 1,
    ]));
    setup();
    replace_program(ROOM);
}