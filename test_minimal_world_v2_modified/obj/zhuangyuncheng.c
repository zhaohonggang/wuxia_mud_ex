// zhuangyuncheng.c - 庄允城（人物模型/雕像）
inherit ITEM;

void create()
{
    set_name("庄允城", ({ "zhuang yun cheng", "zhuang", "yuncheng", "statue" }));
    set("long", "这是一尊庄允城的塑像，栩栩如生，眼神中透着坚毅。\n");
    set("unit", "尊");
    set("weight", 5000);
    set("no_drop", 1);
    set("no_give", 1);
    setup();
}