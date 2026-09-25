// longsword.c - Longsword weapon

inherit BLADE;

void create()
{
    set_name("长剑", ({"changjian", "longsword", "sword"}));
    set_weight(5000);
    if (clonep())
        set_default_object(__FILE__);
    else {
        set("unit", "柄");
        set("value", 1000);
        set("material", "steel");
        set("long", "一把精工打造的长剑，剑身修长，寒光凛凛。\n");
        set("wield_msg", "$N「唰」地一声抽出一柄$n握在手中。\n");
        set("unequip_msg", "$N将手中的$n插回腰间的剑鞘。\n");
    }
    init_blade(30, 120);
    setup();
}