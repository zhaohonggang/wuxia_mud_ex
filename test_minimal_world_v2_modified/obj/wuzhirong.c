// wuzhirong.c - 吴之荣（仇人首级）
inherit ITEM;

void create()
{
    set_name("吴之荣", ({ "wu zhi rong", "wu", "zhirong" }));
    set("long", "这是吴之荣的首级，面容狰狞，双眼圆睁。\n");
    set("unit", "颗");
    set("weight", 1000);
    set("no_drop", 1);
    set("no_give", 1);
    setup();
}