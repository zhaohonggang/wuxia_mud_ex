#include <ansi.h>

inherit NPC;

void create()
{
    set_name("庄家", ({ "zhuang jia", "zhuang", "jia" }));
    set("gender", "男性");
    set("age", 50);
    set("long", "他是赌场的庄家，一脸精明相，手里拿着骰盅。\n");
    set("combat_exp", 80000);
    set("shen_type", 0);
    set("attitude", "neutral");
    set_skill("unarmed", 80);
    set_skill("dodge", 80);
    set_skill("parry", 80);
    set_skill("throwing", 100);
    setup();
    carry_object("/clone/misc/cloth")->wear();
}

int accept_object(object who, object ob)
{
    if (ob->query("money_id"))
    {
        message_vision("$N接过$n给的钱，笑道：好！请押注。\n", this_object(), who);
        return 1;
    }
    return 0;
}