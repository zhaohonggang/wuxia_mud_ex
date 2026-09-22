#include <room.h>
#include <ansi.h>

inherit ROOM;

void create()
{
        set("short", "镇广场");
        set("long", @LONG
这里是柳溪镇的中央广场，青石板铺就的地面被岁月磨得
光可鉴人。广场中央竖着一根高大的旗杆(qigan)，上书「柳
溪」二字的杏黄旗在风中猎猎作响。来往的乡民、行脚商人和
江湖客在此穿行，不时传来小贩的吆喝声。东面是一间热闹的
客栈，南边传来隐隐的喝喝之声，似乎有人在练武。镇口东北
方向的官道(yangzhou)直通扬州府。
LONG);
        set("outdoors", "liuxi");
        set("item_desc", ([
                "qigan" : WHT "一根碗口粗的旗杆，旗面上绣着「柳溪」两个大字。\n" NOR,
        ]));
        set("exits", ([
                "east"  : __DIR__"kedian",
                "west"  : __DIR__"chaguan",
                "north" : __DIR__"tiepupu",
                "south" : __DIR__"lianwuchang",
                "yangzhou" : "/d/city/guangchang",
        ]));
        setup();
        replace_program(ROOM);
}
