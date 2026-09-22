#include <ansi.h>

inherit NPC;

void create()
{
    set_name("门卫", ({ "men wei", "menwei", "wei" }));
    set("gender", "男性");
    set("age", 35);
    set("long", "他是白驼山庄的门卫，身材魁梧，手持钢叉，目光如炬。\n");
    set("combat_exp", 120000);
    set("shen_type", -1);
    set("attitude", "aggressive");
    set_skill("unarmed", 120);
    set_skill("dodge", 120);
    set_skill("parry", 120);
    set_skill("blade", 120);
    set_skill("force", 100);
    set("max_qi", 1500);
    set("max_jing", 800);
    set("neili", 1500);
    set("max_neili", 1500);
    setup();
    carry_object("/clone/weapon/blade")->wield();
    carry_object("/clone/misc/cloth")->wear();
}

int permit_pass(object me, string dir)
{
    if (me->query("family/family_name") == "白驼山庄"
        || me->query("shen") < -1000)
        return 1;

    message_vision("$N拦住$n，冷笑道：白驼山庄重地，闲杂人等不得入内！\n", this_object(), me);
    return 0;
}