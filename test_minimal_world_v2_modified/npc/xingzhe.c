#include <ansi.h>

inherit NPC;

void create()
{
    set_name("行者", ({ "xing zhe", "xingzhe", "xing" }));
    set("gender", "男性");
    set("age", 25);
    set("class", "bonze");
    set("long", "他是少林寺的俗家弟子，在此打坐修行。\n");
    set("combat_exp", 100000);
    set("shen_type", 1);
    set("attitude", "peaceful");
    set_skill("unarmed", 100);
    set_skill("dodge", 100);
    set_skill("parry", 100);
    set_skill("force", 100);
    set_skill("buddhism", 80);
    set_skill("shaolin-xinfa", 100);
    map_skill("force", "shaolin-xinfa");
    map_skill("unarmed", "shaolin-xinfa");
    map_skill("parry", "shaolin-xinfa");
    set("max_qi", 800);
    set("max_jing", 600);
    set("neili", 1000);
    set("max_neili", 1000);
    setup();
    carry_object("/clone/misc/cloth")->wear();
}