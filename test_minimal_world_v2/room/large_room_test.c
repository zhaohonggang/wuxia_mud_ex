// Large room test - simulates a 40KB+ room file
#include <room.h>
#include <ansi.h>

inherit ROOM;

void create()
{
    set("short", "大型测试房间");
    set("long", @LONG
这是一个模拟大型房间文件的测试文件。
LONG);

    // 添加大量重复内容以增加文件大小
    set("item_desc", ([
EOF

# Add many item_desc entries to make file large
for ($i = 1; $i -le 500; $i++) {
    $largeContent += "        \"item$i\" : \"这是第 $i 个物品的描述，包含一些中文文字和英文 ABCDEFGHIJKLMNOPQRSTUVWXYZ。\n\",`n"
}

$largeContent += @'
    ]));

    set("exits", ([
        "north" : __DIR__"room1",
        "south" : __DIR__"room2",
        "east"  : __DIR__"room3",
        "west"  : __DIR__"room4",
        "up"    : __DIR__"room_up",
        "down"  : __DIR__"room_down",
    ]));

    set("objects", ([
        __DIR__"npc/guard1" : 1,
        __DIR__"npc/guard2" : 1,
        __DIR__"npc/merchant" : 1,
    ]));

    setup();
    replace_program(ROOM);
}
