#include <ansi.h>

inherit NPC;

void create()
{
    set_name("武敦儒", ({ "wu dunru", "wu", "dunru" }));
    set("title", HIY "郭靖大弟子" NOR);
    set("nickname", HIC "消息灵通" NOR);
    set("gender", "男性");
    set("age", 23);
    set("long", "他是郭靖大弟子，相貌和蔼，一天到晚笑呵呵的。\n");
    set("attitude", "peaceful");
    set("shen_type", 1);
    set("max_qi", 3000);
    set("max_jing", 2500);
    set("neili", 2800);
    set("max_neili", 2800);
    set("jiali", 50);
    set("combat_exp", 400000);
    set("score", 20000);
    set_skill("force", 160);
    set_skill("dodge", 160);
    set_skill("unarmed", 160);
    set_skill("parry", 160);

    create_family("郭府", 2, "弟子");

    set("inquiry", ([
        "黄蓉" : "那是我师母。",
        "郭靖" : "那是我师父。",
    ]));

    set("guarder", ([
        "refuse_carry": CYN "$N" CYN "对$n" CYN "喝道：你背上"
                        "背的是什么人？还不给我放下来。\n" NOR,
    ]));

    setup();
    carry_object("/clone/misc/cloth")->wear();
}

void init()
{
    object ob;
    ::init();

    if (interactive(ob = this_player()) && !is_fighting())
    {
        if (!ob || environment(ob) != environment())
            return;

        if (ob->query("combat_exp") < 5000
              && !ob->query("mark/guofu_ok")
              && !ob->query("mark/guofu_over")
              && !ob->query("mark/guofu_out"))
        {
            command("say 这位" + RANK_D->query_respect(ob) +
                    "，武功这么差，怎么闯江湖呢？\n");
        } else
        if (ob->query("combat_exp") >= 40000
              && ob->query("mark/guofu_ok"))
        {
            command("look " + ob->query("id"));
            command("haha");
        } else
        if (ob->query("mark/guofu_over"))
        {
            command("sneer " + ob->query("id"));
        } else
        if (ob->query("mark/guofu_out"))
        {
            command("nod " + ob->query("id"));
        } else
        if (ob->query("combat_exp") > 20000
              && !ob->query("mark/guofu_ok")
              && !ob->query("mark/guofu_over")
              && !ob->query("mark/guofu_out"))
        {
            command("hi " + ob->query("id"));
            command("say 现襄阳正值动乱时期，不及招呼，还请恕罪。");
        } else
        if (ob->query("combat_exp") < 40000
              && ob->query("mark/guofu_ok"))
        {
            command("look " + ob->query("id"));
            command("hmm");
            command("say 赶快干活去，没事瞎溜达什么？");
        }
    }
    add_action("do_join", "join");
    add_action("do_kill", "hit");
    add_action("do_kill", "kill");
    add_action("do_kill", "touxi");
    add_action("do_kill", "fight");
}

int do_kill(string arg)
{
    object ob = this_object();

    if (arg != "wu dunru"
       && arg != "wu"
       && arg != "dunru")
    {
        message_vision(CYN "\n武敦儒喝道：什么人？郭府门"
                       "前可由不得你放肆！\n" NOR, ob);
        return 1;
    }
    return 0;
}

int do_join(string arg)
{
    object ob = this_player();

    if (!arg
       && arg != "guofu"
       && arg != "郭府")
        return notify_fail(CYN "武敦儒眉头一皱，道：你到"
                           "底要干什么？怎么说话吞吞吐吐"
                           "的？\n" NOR);

    if (ob->query("mark/guofu_over"))
        return notify_fail(CYN "武敦儒冷笑道：师傅让你走"
                           "开，你还赖在这里干嘛？\n" NOR);

    if (ob->query("mark/guofu_ok"))
        return notify_fail(CYN "武敦儒皱眉道：你不是已经"
                           "进来了吗？赶快干活去，罗嗦什"
                           "么？\n" NOR);

    if (ob->query("combat_exp") > 5000)
        return notify_fail(CYN "武敦儒微笑道：让你来打杂"
                           "可太委屈你了，你还是另谋出路"
                           "吧。\n" NOR);

    if (ob->query_temp("mark/guofu_join"))
    {
        message_vision(HIC "\n$N" HIC "对$n" HIC "点了点"
                       "头，说道：甚好，甚好。入了郭府一"
                       "切就要\n按规矩办事，你现在去耶律"
                       "帮主那里，他会帮你安排事情的。\n"
                       "\n", this_object(), ob);
        ob->set("mark/guofu_ok", 1);
        ob->set("startroom", "/d/wuguan/guofu_dayuan");
        ob->delete_temp("mark/guofu_join");
    } else
    {
        command("nod");
        command("whisper " + ob->query("id") + " 你进郭"
                "府之后我们会确保你的安\n全，但是经验在"
                HIW "四万" NOR + WHT "前不能离开郭府。如"
                "果你决定下来了，请\n再输入一次此命令。"
                "\n" NOR);
        ob->set_temp("mark/guofu_join", 1);
    }
    return 1;
}

int accept_fight(object who)
{
    object ob = this_player();

    if (ob->query("mark/guofu_ok"))
    {
        command("say 给我滚进去，跑到这里来瞎胡闹什么！");
        return 0;
    } else
    {
        command("say 我现在没空。\n");
        return 0;
    }
}

int accept_hit(object who)
{
    object ob = this_player();

    if (ob->query("mark/guofu_ok"))
    {
        command("say 给我滚进去，跑到这里来瞎胡闹什么！");
        return 0;
    } else
    {
        command("say 找死。\n");
        kill_ob(ob);
        return 1;
    }
}

int accept_kill(object who)
{
    object ob = this_player();

    if (ob->query("mark/guofu_ok"))
    {
        command("say 给我滚进去，跑到这里来瞎胡闹什么！");
        return notify_fail("你还是不要轻举妄动为好。\n");
    } else
    {
        command("say 找死。\n");
        kill_ob(ob);
        return 1;
    }
}