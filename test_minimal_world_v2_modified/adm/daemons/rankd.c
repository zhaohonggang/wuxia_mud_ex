// rankd.c - 简化版称号守护进程
#pragma optimize
#pragma save_binary

inherit F_DBASE;
inherit F_CLEAN_UP;

string *respect = ({
    "大侠", "少侠", "前辈", "老前辈", "大爷", "大嫂",
    "道长", "师太", "和尚", "小师父", "施主", "女侠",
});

void create()
{
    seteuid(getuid());
    set("channel_id", "称号精灵");
}

string query_respect(object ob)
{
    if (!ob) return "这位" + respect[random(sizeof(respect))];
    
    int shen = ob->query("shen");
    if (shen > 10000) return "大侠";
    if (shen > 5000) return "少侠";
    if (shen > 1000) return "侠士";
    if (shen > -1000) return "这位" + respect[random(sizeof(respect))];
    if (shen > -5000) return "邪徒";
    return "魔头";
}

string query_rude(object ob)
{
    if (!ob) return "喂";
    
    int shen = ob->query("shen");
    if (shen > 5000) return "小子";
    if (shen > 0) return "小兄台";
    if (shen > -5000) return "小邪徒";
    return "小魔头";
}

int valid_respect(object ob)
{
    return 1;
}