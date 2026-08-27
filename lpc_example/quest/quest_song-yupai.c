#include <quest.h>
#include <ansi.h>

#define NPC_OB    my["npc_ob"]
#define NPC_NAME  my["npc_name"]
#define QOB       my["qob"]
#define QOB_NAME  my["qob_name"]

int npc_accept_object(object me, object who, object ob);

mixed ask_npc(object knower);
mixed ask_qob(object knower);

string query_introduce(object knower);
string query_prompt();

void create()
{
        seteuid(getuid());
        setup();
}

void init_quest()
{
        mapping my;
        object qob;

        my = query_entire_dbase();

        set_name("送还玉佩");
        set_temp("started", 1);

        if (! objectp(NPC_OB))
                NPC_OB = load_object("/d/minimal_world/chaguan");

        if (objectp(NPC_OB))
                NPC_OB = present("a po", NPC_OB);
        if (! objectp(NPC_OB))
        {
                destruct(this_object());
                return;
        }

        if (objectp(qob = find_object("/d/minimal_world/obj/yupai")))
        {
                if (objectp(qob->query_temp("quest_ob")))
                {
                        destruct(this_object());
                        return;
                }
        } else
                qob = load_object("/d/minimal_world/obj/yupai");

        qob->set_temp("quest_ob", this_object());

        NPC_NAME = NPC_OB->name();
        QOB = qob;
        QOB_NAME = qob->name();

        NPC_OB->set_temp("override/accept_object", (: npc_accept_object :));
        change_status(QUEST_READY);
}

void cancel_quest()
{
        if (objectp(NPC_OB))
        {
                NPC_OB->delete_temp("override/accept_object");
                NPC_OB->delete_temp("quest_ob");
        }

        if (objectp(QOB))
                QOB->delete_temp("quest_ob");

        delete_temp("started");
        ::cancel_quest();
}

int npc_accept_object(object me, object who, object ob)
{
        mapping b;

        if (ob != QOB || who != NPC_OB)
                return 0;

        message_vision(CYN "$N接过" + ob->name() + CYN "，浑浊的眼里泛起了泪光，"
                       "连声向$n道谢。\n" NOR, who, me);

        b = ([
                "exp"    : 500 + random(200),
                "pot"    : 300 + random(100),
                "score"  : 20,
                "weiwang": 50,
                "prompt" : "在替" + who->name() + "找回玉佩的过程中，经过锻炼",
        ]);
        GIFT_D->delay_bonus(me, b);

        CHANNEL_D->do_channel(this_object(), "rumor",
                              "听说" + me->name(1) + "(" + me->query("id") + ")替茶馆的" +
                              HIM "阿婆" NOR "找回了祖传玉佩，江湖上传为美谈。");

        destruct(ob);
        call_out("cancel_quest", 0);
        return -1;
}

string query_introduce(object knower)
{
        return CYN "听说" HIY "茶馆的阿婆" NOR CYN "正在托人寻找一枚祖传的" +
               HIY "羊脂玉佩" NOR CYN "，啧啧，这年头好心人可不多喽。" NOR;
}

string query_prompt()
{
        switch (random(3))
        {
        case 0:
                return CYN "最近听人说起过『" HIY + name() + NOR CYN "』这件事。";
        case 1:
                return "噢！上山小路那头最近怪事多着呢，兴许跟『" HIY + name() +
                       NOR CYN "』有关。";
        default:
                return "老婆子念叨那枚玉佩好些年了，你若有心就去『" HIY + name() +
                       NOR CYN "』帮帮她吧。";
        }
}

mixed ask_npc(object knower)
{
        return CYN "你说阿婆啊？她就坐在春风茶馆里头，你去问她便知。" NOR;
}

mixed ask_qob(object knower)
{
        mapping my;

        my = query_entire_dbase();

        if (! objectp(QOB) || ! objectp(environment(QOB)))
                return CYN "那" HIY + QOB_NAME + NOR CYN "么？我可不知道。" NOR;

        return CYN "那" HIY + QOB_NAME + NOR CYN "么？听说上山小路的山壁"
                   "里头藏着些古怪，你自个儿去瞧瞧罢。" NOR;
}

void register_information()
{
        mapping my;

        my = query_entire_dbase();

        if (! clonep() || ! mapp(my))
                return;

        set_information(NPC_NAME, (: ask_npc :));
        set_information(QOB_NAME, (: ask_qob :));
}

int can_know_by(object knower)
{
        string fname;

        if (! objectp(knower) || ! environment(knower))
                return 0;

        fname = file_name(environment(knower));
        if (strlen(fname) >= strlen("/d/minimal_world/") &&
            fname[0..strlen("/d/minimal_world/") - 1] == "/d/minimal_world/")
                return 1;

        return 0;
}
