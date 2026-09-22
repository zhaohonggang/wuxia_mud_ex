// ship.c - 战船（简化版物品）
inherit ITEM;

void create()
{
    set_name("战船模型", ({ "ship", "warship", "model" }));
    set("long", "这是一艘战船的精致模型，船身结实，桅杆高耸。\n");
    set("unit", "艘");
    set("weight", 3000);
    set("value", 3000);
    set("material", "wood");
    setup();
}