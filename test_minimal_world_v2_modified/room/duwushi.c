inherit ROOM;

void create()
{
    set("short", "毒物室");
    set("long", @LONG
这里是白驼山庄的毒物室，四周摆满了各式瓶瓶罐罐，装着
各色毒药、毒虫、毒草。空气中弥漫着刺鼻的药味，令人作呕。
墙上挂着一张"毒物配方表"。角落里养着几只毒蛇、蝎子。
LONG );
    set("exits", ([
        "east" : __DIR__"houyuan",
    ]));
    set("objects", ([
        __DIR__"npc/jinhua" : 1,
        __DIR__"obj/bottle" : 3,
        __DIR__"obj/poison" : 1,
        __DIR__"obj/throwing" : 1,
    ]));
    setup();
    replace_program(ROOM);
}