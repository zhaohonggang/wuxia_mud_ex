#include <ansi.h>

inherit NPC;

void create()
{
    set_name("赌场管事", ({ "duke", "guan shi", "guan" }));
    set("gender", "男性");
    set("age", 45);
    set("long", "他是赌场的管事，精明干练，眼神锐利。\n");
    set("combat_exp", 50000);
    set("shen_type", 1);
    set("attitude", "friendly");
    set_skill("unarmed", 50);
    set_skill("dodge", 50);
    set_skill("parry", 50);
    setup();
    carry_object("/clone/misc/cloth")->wear();
}