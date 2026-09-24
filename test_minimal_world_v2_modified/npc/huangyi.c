#include <ansi.h>

inherit NPC;

void create()
{
    set_name(HIY "黄衣" NOR, ({ "huang yi" }));
    set("title", CYN "群玉八娇" NOR);
    set("gender", "女性");
    set("age", 22);
    set("str", 30);
    set("per", 40);
    set("long", "一个全身上下穿着黄装，领露酥胸的美女。\n");
    set("combat_exp", 10);
    set("attitude", "friendly");
    setup();
    carry_object("/clone/misc/cloth")->wear();
}

int accept_fight(object me)
{
    command("say 小女子哪里是您的对手？");
    return 0;
}

int accept_kill(object me)
{
    object ob;
    if (is_fighting()) return 1;
    if (query("called")) return 1;
    command("say 要杀人了，快来人救命啊！");
    ob = present("bao biao");
    if (!ob)
    {
        seteuid(getuid());
        ob = new(__DIR__"baobiao");
        ob->move(environment());
    }
    message_vision(HIC "\n忽然从门外冲进来几个保镖，对$N"
                       HIC "大喊一声“干什么？在这儿闹事，想"
                       "找死吗？\n\n" NOR, me);
    ob->kill_ob(me);
    ob->set_leader(me);
    me->kill_ob(ob);
    set("called", 1);
    call_out("regenerate", 200);
    return 0;
}

int regenerate()
{
    set("called", 0);
    return 1;
}