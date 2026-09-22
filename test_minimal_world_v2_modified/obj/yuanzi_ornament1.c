// yuanzi_ornament.c - 装饰品（简化版）
inherit ITEM;

void create()
{
    set_name("金色装饰品", ({ "gold ornament", "ornament", "decoration" }));
    set("long", "这是一件精美的金色装饰品，闪闪发光。\n");
    set("unit", "件");
    set("weight", 500);
    set("value", 1000);
    set("material", "gold");
    setup();
}