// jinship.c - 金国战船（简化版物品）
inherit ITEM;

void create()
{
    set_name("金国战船模型", ({ "jin ship", "jinship", "ship", "model" }));
    set("long", "这是一艘金国战船的精致模型，船身雕龙画凤，威武雄壮。\n");
    set("unit", "艘");
    set("weight", 5000);
    set("value", 5000);
    set("material", "wood");
    setup();
}