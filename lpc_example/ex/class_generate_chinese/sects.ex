defmodule ExKantele.World.Sects do
  @moduledoc """
  对应原文件: lpc_example/class_npc/class_generate_chinese.c 中的 39 个门派原型(from_*)。
  create() 里 evaluate(init_family[random(...)]) 随机挑一个门派赋给随机 NPC。
  每项: scale(原型权重) / class(职业) / skills / maps(map_skill) / preps(prepare_skill)
        / carry(初始装备)。chat_msg_combat 的 perform/exert 表为机械式列表，略。
  """

  @sects %{
    "wudang" => %{
      scale: 200,
      class: "taoist",
      chat_chance_combat: 80,
      skills: ["force", "taiji-shengong", "parry", "dodge", "tiyunzong", "sword", "taiji-jian", "hand", "paiyun-shou", "unarmed", "taiji-quan", "literate", "martial-cognize", "taoism"],
      maps: %{"parry" => "taiji-jian", "force" => "taiji-shengong", "dodge" => "tiyunzong", "sword" => "taiji-jian", "hand" => "paiyun-shou", "unarmed" => "taiji-quan"},
      preps: %{"hand" => "paiyun-shou", "unarmed" => "taiji-quan"},
      carry: ["/clone/weapon/changjian", "/d/wudang/obj/greyrobe"]
    },
    "shaolin" => %{
      scale: 150,
      class: "bonze",
      chat_chance_combat: 100,
      skills: ["force", "hunyuan-yiqi", "parry", "dodge", "shaolin-shenfa", "sword", "damo-jian", "finger", "nianhua-zhi", "strike", "sanhua-zhang", "literate", "martial-cognize", "buddhism"],
      maps: %{"parry" => "damo-jian", "force" => "hunyuan-yiqi", "dodge" => "shaolin-shenfa", "sword" => "damo-jian", "finger" => "nianhua-zhi", "strike" => "sanhua-zhang"},
      preps: %{"finger" => "nianhua-zhi", "strike" => "sanhua-zhang"},
      carry: ["/clone/weapon/changjian", "/clone/cloth/cloth"]
    },
    "huashan" => %{
      scale: 130,
      class: "fighter",
      chat_chance_combat: 100,
      skills: ["force", "zixia-shengong", "parry", "dodge", "feiyan-huixiang", "sword", "huashan-jian", "cuff", "poyu-quan", "strike", "hunyuan-zhang", "literate", "martial-cognize"],
      maps: %{"parry" => "huaxian-sword", "force" => "zixia-shengong", "dodge" => "feiyan-huixiang", "sword" => "huashan-jian", "cuff" => "poyu-quan", "strike" => "hunyuan-zhang"},
      preps: %{"cuff" => "poyu-quan", "strike" => "hunyuan-zhang"},
      carry: ["/clone/weapon/changjian", "/clone/cloth/cloth"]
    },
    "ouyang" => %{
      scale: 130,
      class: nil,
      chat_chance_combat: 100,
      skills: ["force", "hamagong", "parry", "dodge", "chanchu-bufa", "staff", "lingshe-zhangfa", "cuff", "lingshe-quan", "finger", "shedu-qiqiao", "literate", "martial-cognize"],
      maps: %{"force" => "hamagong", "parry" => "lingshe-zhangfa", "dodge" => "chanchu-bufa", "staff" => "lingshe-zhangfa", "cuff" => "lingshe-quan", "finger" => "shedu-qiqiao"},
      preps: %{"cuff" => "lingshe-quan", "finger" => "shedu-qiqiao"},
      carry: ["/clone/weapon/gangzhang", "/clone/cloth/cloth"]
    },
    "gaibang" => %{
      scale: 120,
      class: "begger",
      chat_chance_combat: 80,
      skills: ["force", "huntian-qigong", "parry", "dodge", "feiyan-zoubi", "staff", "dagou-bang", "strike", "xianglong-zhang", "literate", "martial-cognize"],
      maps: %{"force" => "huntian-qigong", "parry" => "dagou-bang", "dodge" => "feiyan-zoubi", "staff" => "dagou-bang", "strike" => "xianglong-zhang"},
      preps: %{"strike" => "xianglong-zhang"},
      carry: ["/clone/weapon/gangzhang", "/clone/cloth/cloth"]
    },
    "taohua" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "bibo-shengong", "dodge", "anying-fuxiang", "finger", "throwing", "tanzhi-shentong", "parry", "sword", "yuxiao-jian", "qimen-wuxing", "count", "jingluo-xue", "mathematics", "literate", "martial-cognize", "chuixiao-jifa", "bihai-chaosheng"],
      maps: %{"force" => "bibo-shengong", "finger" => "tanzhi-shentong", "dodge" => "anying-fuxiang", "parry" => "tanzhi-shentong", "sword" => "yuxiao-jian", "throwing" => "tanzhi-shentong"},
      preps: %{},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
    "gumu" => %{
      scale: 130,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "yunv-xinjing", "parry", "dodge", "yunv-shenfa", "unarmed", "meinv-quan", "strike", "fireice-strike", "tianluo-diwang", "throwing", "yufeng-zhen", "sword", "yunv-jian", "quanzhen-jian", "literate", "martial-cognize"],
      maps: %{"force" => "yunv-xinjing", "sword" => "yunv-jian", "dodge" => "yunv-shenfa", "parry" => "meinv-quan", "unarmed" => "meinv-quan", "strike" => "tianluo-diwang", "throwing" => "yufeng-zhen"},
      preps: %{"unarmed" => "meinv-quan", "strike" => "tianluo-diwang"},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
    "xingxiu" => %{
      scale: 130,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "huagong-dafa", "dodge", "zhaixinggong", "strike", "chousui-zhang", "claw", "sanyin-wugongzhao", "whip", "chanhun-suo", "parry", "staff", "tianshan-zhang", "throwing", "feixing-shu", "poison", "xingxiu-qishu", "literate", "martial-cognize"],
      maps: %{"force" => "huagong-dafa", "dodge" => "zhaixinggong", "strike" => "chousui-zhang", "claw" => "sanyin-wugongzhao", "whip" => "chanhun-suo", "parry" => "tianshan-zhang", "staff" => "tianshan-zhang", "poison" => "xingxiu-qishu"},
      preps: %{"strike" => "chousui-zhang", "claw" => "sanyin-wugongzhao"},
      carry: ["/clone/weapon/gangzhang", "/clone/misc/cloth"]
    },
    "xueshan" => %{
      scale: 135,
      class: "bonze",
      chat_chance_combat: 80,
      skills: ["force", "longxiang-gong", "dodge", "shenkong-xing", "hammer", "riyue-lun", "parry", "unarmed", "lamaism", "literate", "martial-cognize"],
      maps: %{"force" => "longxiang-gong", "dodge" => "shenkong-xing", "unarmed" => "longxiang-gong", "parry" => "riyue-lun", "hammer" => "riyue-lun"},
      preps: %{"unarmed" => "longxiang-gong"},
      carry: ["/d/xueshan/obj/yinlun", "/clone/misc/cloth"]
    },
    "xuedao" => %{
      scale: 135,
      class: "bonze",
      chat_chance_combat: 80,
      skills: ["force", "xuedao-dafa", "blade", "dodge", "shenkong-xing", "hand", "dashou-yin", "cuff", "yujiamu-quan", "parry", "lamaism", "literate", "martial-cognize"],
      maps: %{"force" => "xuedao-dafa", "dodge" => "shenkong-xing", "hand" => "dashou-yin", "cuff" => "yujiamu-quan", "parry" => "xuedao-dafa", "blade" => "xuedao-dafa", "sword" => "mingwang-jian"},
      preps: %{"cuff" => "yujiamu-quan", "hand" => "dashou-yin"},
      carry: ["/clone/weapon/gangdao", "/clone/misc/cloth"]
    },
    "xiaoyao" => %{
      scale: 135,
      class: "taoist",
      chat_chance_combat: 80,
      skills: ["force", "beiming-shengong", "dodge", "feiyan-zoubi", "liuyang-zhang", "parry", "sword", "liuyue-jian", "zhemei-shou", "hand", "strike", "literate", "martial-cognize"],
      maps: %{"force" => "beiming-shengong", "dodge" => "feiyan-zoubi", "hand" => "zhemei-shou", "strike" => "liuyang-zhang", "parry" => "liuyue-jian", "sword" => "liuyue-jian"},
      preps: %{"hand" => "zhemei-shou", "strike" => "liuyang-zhang"},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
    "shenlong" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "shenlong-xinfa", "dodge", "yixingbu", "hand", "shenlong-bashi", "strike", "huagu-mianzhang", "parry", "staff", "sword", "shedao-qigong", "literate", "martial-cognize"],
      maps: %{"force" => "shenlong-xinfa", "dodge" => "yixingbu", "hand" => "shenlong-bashi", "strike" => "huagu-mianzhang", "parry" => "shedao-qigong", "staff" => "shedao-qigong"},
      preps: %{"strike" => "huagu-mianzhang", "hand" => "shenlong-bashi"},
      carry: ["/clone/misc/cloth"]
    },
    "kunlun" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "liangyi-shengong", "dodge", "chuanyun-bu", "strike", "kunlun-zhang", "cuff", "zhentian-quan", "parry", "sword", "zhengliangyi-jian", "qiankun-jian", "literate", "martial-cognize", "tanqin-jifa", "martial-cognize"],
      maps: %{"force" => "liangyi-shengong", "dodge" => "chuanyun-bu", "parry" => "zhengliangyi-jian", "sword" => "qiankun-jian", "strike" => "kunlun-zhang", "cuff" => "zhentian-quan"},
      preps: %{"strike" => "kunlun-zhang", "cuff" => "zhentian-quan"},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
    "yaowang" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "shennong-xinjing", "dodge", "xuefu-mizong", "strike", "dusha-zhang", "hand", "lansha-shou", "parry", "staff", "shennong-zhang", "throwing", "wuxing-jueming", "poison", "dispel-poison", "medical", "yaowang-miaoshu", "literate", "martial-cognize"],
      maps: %{"force" => "shennong-xinjing", "dodge" => "xuefu-mizong", "strike" => "dusha-zhang", "hand" => "lansha-shou", "throwing" => "wuxing-jueming", "parry" => "shennong-zhang", "staff" => "shennong-zhang", "poison" => "dispel-poison", "medical" => "yaowang-miaoshu"},
      preps: %{"hand" => "lansha-shou", "strike" => "dusha-zhang"},
      carry: ["/clone/weapon/gangzhang", "/clone/misc/cloth"]
    },
    "wudu" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "xiuluo-yinshagong", "dodge", "jinshe-youshenbu", "strike", "tianchan-zhang", "claw", "wusheng-zhao", "parry", "whip", "ruanhong-zhusuo", "poison", "wudu-qishu", "literate", "martial-cognize"],
      maps: %{"force" => "xiuluo-yinshagong", "dodge" => "jinshe-youshenbu", "strike" => "tianchan-zhang", "claw" => "wusheng-zhao", "parry" => "ruanhong-zhusuo", "whip" => "ruanhong-zhusuo", "poison" => "wudu-qishu"},
      preps: %{"claw" => "wusheng-zhao", "strike" => "tianchan-zhang"},
      carry: ["/clone/weapon/changbian", "/clone/misc/cloth"]
    },
    "lingxiao" => %{
      scale: 140,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "wuwang-shengong", "dodge", "taxue-wuhen", "cuff", "lingxiao-quan", "strike", "piaoxu-zhang", "sword", "xueshan-jian", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "wuwang-shengong", "dodge" => "taxue-wuhen", "cuff" => "lingxiao-quan", "strike" => "piaoxu-zhang", "sword" => "xueshan-jian", "parry" => "xueshan-jian"},
      preps: %{"strike" => "piaoxu-zhang", "cuff" => "lingxiao-quan"},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
    "tiezhang" => %{
      scale: 120,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "tianlei-shengong", "dodge", "dengping-dushui", "strike", "parry", "tie-zhang", "feilong-zhang", "staff", "literate", "martial-cognize"],
      maps: %{"force" => "tianlei-shengong", "strike" => "tie-zhang", "parry" => "tie-zhang", "dodge" => "dengping-dushui", "staff" => "feilong-zhang"},
      preps: %{"strike" => "tie-zhang"},
      carry: ["/clone/misc/cloth"]
    },
    "zhenyuan" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["parry", "wai-bagua", "force", "nei-bagua", "dodge", "bagua-bu", "strike", "bagua-zhang", "cuff", "bagua-quan", "blade", "bagua-dao", "throwing", "bagua-biao", "literate", "martial-cognize"],
      maps: %{"dodge" => "bagua-bu", "force" => "nei-bagua", "strike" => "bagua-zhang", "blade" => "bagua-dao", "cuff" => "bagua-quan", "parry" => "wai-bagua", "throwing" => "bagua-biao"},
      preps: %{"cuff" => "bagua-quan", "strike" => "bagua-zhang"},
      carry: ["/clone/weapon/gangdao", "/clone/misc/cloth"]
    },
    "wudang1" => %{
      scale: 200,
      class: "taoist",
      chat_chance_combat: 80,
      skills: ["force", "taiji-shengong", "parry", "dodge", "tiyunzong", "sword", "taiji-jian", "hand", "paiyun-shou", "unarmed", "taiji-quan", "literate", "martial-cognize", "taoism"],
      maps: %{"parry" => "taiji-quan", "force" => "taiji-shengong", "dodge" => "tiyunzong", "sword" => "taiji-jian", "hand" => "paiyun-shou", "unarmed" => "taiji-quan"},
      preps: %{"hand" => "paiyun-shou", "unarmed" => "taiji-quan"},
      carry: ["/d/wudang/obj/greyrobe"]
    },
    "shaolin1" => %{
      scale: 150,
      class: "bonze",
      chat_chance_combat: 100,
      skills: ["force", "hunyuan-yiqi", "parry", "dodge", "shaolin-shenfa", "whip", "riyue-bian", "finger", "nianhua-zhi", "strike", "sanhua-zhang", "literate", "martial-cognize", "buddhism", "cuff", "jingang-quan"],
      maps: %{"cuff" => "jingang-quan", "parry" => "riyue-bian", "force" => "hunyuan-yiqi", "dodge" => "shaolin-shenfa", "whip" => "riyue-bian", "finger" => "nianhua-zhi", "strike" => "sanhua-zhang"},
      preps: %{"finger" => "nianhua-zhi", "strike" => "sanhua-zhang"},
      carry: ["/clone/weapon/changbian", "/clone/cloth/cloth"]
    },
    "shaolin2" => %{
      scale: 150,
      class: "bonze",
      chat_chance_combat: 100,
      skills: ["force", "hunyuan-yiqi", "parry", "dodge", "shaolin-shenfa", "blade", "hongye-daofa", "finger", "nianhua-zhi", "strike", "sanhua-zhang", "literate", "martial-cognize", "buddhism", "cuff", "jingang-quan"],
      maps: %{"cuff" => "jingang-quan", "parry" => "hongye-daofa", "force" => "hunyuan-yiqi", "dodge" => "shaolin-shenfa", "blade" => "hongye-daofa", "finger" => "nianhua-zhi", "strike" => "sanhua-zhang"},
      preps: %{"finger" => "nianhua-zhi", "strike" => "sanhua-zhang"},
      carry: ["/clone/weapon/gangdao", "/clone/cloth/cloth"]
    },
    "shaolin3" => %{
      scale: 150,
      class: "bonze",
      chat_chance_combat: 100,
      skills: ["force", "hunyuan-yiqi", "parry", "dodge", "shaolin-shenfa", "finger", "qufannao-zhi", "strike", "sanhua-zhang", "literate", "martial-cognize", "buddhism", "cuff", "jingang-quan"],
      maps: %{"cuff" => "jingang-quan", "parry" => "qufannao-zhi", "force" => "hunyuan-yiqi", "dodge" => "shaolin-shenfa", "finger" => "qufannao-zhi", "strike" => "sanhua-zhang"},
      preps: %{"finger" => "qufannao-zhi"},
      carry: ["/clone/cloth/cloth"]
    },
    "shaolin4" => %{
      scale: 150,
      class: "bonze",
      chat_chance_combat: 100,
      skills: ["force", "hunyuan-yiqi", "parry", "dodge", "shaolin-shenfa", "finger", "qufannao-zhi", "strike", "shenzhang-bada", "literate", "martial-cognize", "buddhism", "cuff", "jingang-quan"],
      maps: %{"cuff" => "jingang-quan", "parry" => "shenzhang-bada", "force" => "hunyuan-yiqi", "dodge" => "shaolin-shenfa", "finger" => "qufannao-zhi", "strike" => "shenzhang-bada"},
      preps: %{"strike" => "shenzhang-bada"},
      carry: ["/clone/cloth/cloth"]
    },
    "taohua1" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "bibo-shengong", "dodge", "anying-fuxiang", "finger", "throwing", "tanzhi-shentong", "parry", "sword", "yuxiao-jian", "qimen-wuxing", "count", "jingluo-xue", "mathematics", "literate", "martial-cognize", "chuixiao-jifa", "bihai-chaosheng"],
      maps: %{"force" => "bibo-shengong", "finger" => "tanzhi-shentong", "dodge" => "anying-fuxiang", "parry" => "tanzhi-shentong", "sword" => "yuxiao-jian", "throwing" => "tanzhi-shentong"},
      preps: %{},
      carry: ["/clone/misc/cloth"]
    },
    "xueshan1" => %{
      scale: 135,
      class: "bonze",
      chat_chance_combat: 80,
      skills: ["force", "longxiang-gong", "dodge", "shenkong-xing", "hammer", "riyue-lun", "parry", "unarmed", "lamaism", "literate", "martial-cognize"],
      maps: %{"force" => "longxiang-gong", "dodge" => "shenkong-xing", "unarmed" => "longxiang-gong", "parry" => "longxiang-gong", "hammer" => "riyue-lun"},
      preps: %{"unarmed" => "longxiang-gong"},
      carry: ["/clone/misc/cloth"]
    },
    "xiaoyao1" => %{
      scale: 135,
      class: "taoist",
      chat_chance_combat: 80,
      skills: ["force", "beiming-shengong", "dodge", "feiyan-zoubi", "liuyang-zhang", "parry", "sword", "liuyue-jian", "zhemei-shou", "hand", "strike", "literate", "martial-cognize"],
      maps: %{"force" => "beiming-shengong", "dodge" => "feiyan-zoubi", "hand" => "zhemei-shou", "strike" => "liuyang-zhang", "parry" => "zhemei-shou", "sword" => "liuyue-jian"},
      preps: %{"hand" => "zhemei-shou", "strike" => "liuyang-zhang"},
      carry: ["/clone/misc/cloth"]
    },
    "emei" => %{
      scale: 135,
      class: "bonze",
      chat_chance_combat: 80,
      skills: ["force", "linji-zhuang", "dodge", "zhutian-bu", "strike", "piaoxue-zhang", "parry", "sword", "huifeng-jian", "literate", "martial-cognize"],
      maps: %{"force" => "linji-zhuang", "dodge" => "zhutian-bu", "strike" => "piaoxue-zhang", "parry" => "huifeng-jian", "sword" => "huifeng-jian"},
      preps: %{"strike" => "piaoxue-zhang"},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
    "xuanming" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "xuanming-shengong", "dodge", "liuying-bu", "strike", "xuanming-zhang", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "xuanming-shengong", "dodge" => "liuying-bu", "strike" => "xuanming-zhang", "parry" => "xuanming-zhang"},
      preps: %{"strike" => "xuanming-zhang"},
      carry: ["/clone/misc/cloth"]
    },
    "mingjiao" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "shenghuo-shengong", "dodge", "qingfu-shenfa", "cuff", "qishang-quan", "sword", "shenghuo-ling", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "shenghuo-shengong", "dodge" => "qingfu-shenfa", "cuff" => "qishang-quan", "parry" => "shenghuo-ling", "sword" => "shenghuo-ling"},
      preps: %{"cuff" => "qishang-quan"},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
    "lingjiu" => %{
      scale: 135,
      class: "taoist",
      chat_chance_combat: 80,
      skills: ["force", "bahuang-gong", "dodge", "yueying-wubu", "liuyang-zhang", "parry", "sword", "tianyu-qijian", "zhemei-shou", "hand", "strike", "literate", "martial-cognize"],
      maps: %{"force" => "bahuang-gong", "dodge" => "yueying-wubu", "hand" => "zhemei-shou", "strike" => "liuyang-zhang", "parry" => "tianyu-qijian", "sword" => "tianyu-qijian"},
      preps: %{"hand" => "zhemei-shou", "strike" => "liuyang-zhang"},
      carry: ["/clone/misc/cloth"]
    },
    "honghua" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "zhanshen-xinjing", "dodge", "zhuangzi-wu", "unarmed", "baihua-cuoquan", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "zhanshen-xinjing", "dodge" => "zhuangzi-wu", "unarmed" => "baihua-cuoquan", "parry" => "baihua-cuoquan"},
      preps: %{"unarmed" => "baihua-cuoquan"},
      carry: ["/clone/misc/cloth"]
    },
    "quanzhen" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "xuanmen-neigong", "dodge", "jinyan-gong", "unarmed", "kongming-quan", "sword", "quanzhen-jian", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "xuanmen-neigong", "dodge" => "jinyan-gong", "unarmed" => "kongming-quan", "parry" => "kongming-quan"},
      preps: %{"unarmed" => "kongming-quan"},
      carry: ["/clone/misc/cloth"]
    },
    "quanzhen1" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "xuanmen-neigong", "dodge", "jinyan-gong", "unarmed", "kongming-quan", "sword", "quanzhen-jian", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "xuanmen-neigong", "dodge" => "jinyan-gong", "sword" => "quanzhen-jian", "unarmed" => "kongming-quan", "parry" => "quanzhen-jian"},
      preps: %{"unarmed" => "kongming-quan"},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
    "riyue" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "tianhuan-shenjue", "dodge", "juechen-shenfa", "strike", "guzhuo-zhang", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "tianhuan-shenjue", "dodge" => "juechen-shenfa", "strike" => "guzhuo-zhang", "parry" => "guzhuo-zhang"},
      preps: %{"strike" => "guzhuo-zhang"},
      carry: ["/clone/misc/cloth"]
    },
    "song" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "hanbing-zhenqi", "dodge", "lingxu-bu", "strike", "hanbing-zhang", "sword", "poyang-jian", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "hanbing-zhenqi", "dodge" => "lingxu-bu", "sword" => "poyang-jian", "strike" => "hanbing-zhang", "parry" => "poyang-jian"},
      preps: %{"strike" => "hanbing-zhang"},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
    "murong" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "zihui-xinfa", "dodge", "beidou-xianzong", "finger", "canhe-zhi", "douzhuan-xingyi", "blade", "longcheng-shendao", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "zihui-xinfa", "dodge" => "beidou-xianzong", "blade" => "longcheng-shendao", "finger" => "canhe-zhi", "parry" => "douzhuan-xingyi"},
      preps: %{"finger" => "canhe-zhi"},
      carry: ["/clone/weapon/gangdao", "/clone/misc/cloth"]
    },
    "murong1" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "zihui-xinfa", "dodge", "beidou-xianzong", "finger", "canhe-zhi", "douzhuan-xingyi", "blade", "longcheng-shendao", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "zihui-xinfa", "dodge" => "beidou-xianzong", "blade" => "longcheng-shendao", "finger" => "canhe-zhi", "parry" => "douzhuan-xingyi"},
      preps: %{"finger" => "canhe-zhi"},
      carry: ["/clone/misc/cloth"]
    },
    "hengshan" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "zhenyue-jue", "dodge", "henshan-shenfa", "strike", "biluo-zhang", "cuff", "henshan-quan", "sword", "wushen-jian", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "zhenyue-jue", "dodge" => "henshan-shenfa", "sword" => "wushen-jian", "strike" => "biluo-zhang", "cuff" => "henshan-quan", "parry" => "wushen-jian"},
      preps: %{"strike" => "biluo-zhang", "cuff" => "henshan-quan"},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
    "pixie" => %{
      scale: 135,
      class: nil,
      chat_chance_combat: 80,
      skills: ["force", "zixia-shengong", "pixie-jian", "feiyan-zoubi", "dodge", "unarmed", "sword", "parry", "literate", "martial-cognize"],
      maps: %{"force" => "zixia-shengong", "dodge" => "feiyan-zoubi", "sword" => "pixie-jian", "unarmed" => "pixie-jian", "parry" => "pixie-jian"},
      preps: %{"unarmed" => "pixie-jian"},
      carry: ["/clone/weapon/changjian", "/clone/misc/cloth"]
    },
  }

  def all(), do: @sects

  def random(rng \\ &:rand.uniform/1) do
    keys = Map.keys(@sects)
    k = Enum.at(keys, rng.(length(keys)) - 1)
    {k, @sects[k]}
  end
end
