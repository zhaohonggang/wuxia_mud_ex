// mingshijilue.c - 明史辑略（书籍）
inherit ITEM;

void create()
{
    set_name("明史辑略", ({ "mingshi jilue", "mingshi", "jilue", "book" }));
    set("long", "这是一本《明史辑略》，记载了明朝历史的精要。\n");
    set("unit", "本");
    set("weight", 500);
    set("value", 100);
    set("material", "paper");
    set("skill", ([
        "name": "literate",
        "exp_required": 1000,
        "jing_cost": 20,
        "difficulty": 20,
        "max_skill": 50,
        "min_skill": 0,
    ]));
    setup();
}