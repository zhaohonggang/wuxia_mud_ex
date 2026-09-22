#include <ansi.h>
inherit SNAKE;

void create()
{
    set_name(HIR "巨蟒" NOR, ({"mang she", "mangshe", "she", "python"}));
    set("long", HIR "这是一条巨大的蟒蛇，身粗如桶，鳞甲闪着寒光，头部三角\n"
                  "竖瞳冷冷地盯着你，吐着芯子发出嘶嘶声。\n" NOR);

    set("age", 20);
    set("str", 40);
    set("dex", 25);
    set("con", 30);
    set("max_qi", 2000);
    set("max_jing", 800);
    set("combat_exp", 150000);

    set("power", 60);
    set("item1", "/clone/quarry/item/sherou");
    set("item2", "/clone/herb/shedan");

    set_temp("apply/dodge", 120);
    set_temp("apply/defense", 150);
    set_temp("apply/unarmed_damage", 200);
    set_temp("apply/armor", 100);

    setup();
}