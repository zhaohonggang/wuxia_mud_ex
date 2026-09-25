// potion.c - Healing potion item

inherit ITEM;
inherit F_LIQUID;

void create()
{
    set_name("治疗药水", ({"healing potion", "potion"}));
    set_weight(100);
    if (clonep())
        set_default_object(__FILE__);
    else {
        set("long", "一瓶神奇的治疗药水，喝下后可以恢复气血。\n");
        set("unit", "瓶");
        set("value", 500);
        set("max_liquid", 5);
    }
    set("liquid", ([
        "type": "potion",
        "name": "治疗药水",
        "remaining": 5,
    ]));
}