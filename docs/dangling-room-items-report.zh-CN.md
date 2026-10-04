# `room_items` 悬空引用扫描报告

> **只读扫描，未改动任何数据。**
> 生成方式：遍历 `data/world/*.ucl` 的顶层 `room_items` 块（括号配平定位，
> 不用正则切块 —— 见 [lpc-objects-placement-issues.zh-CN.md](lpc-objects-placement-issues.zh-CN.md) §八），
> 再按 `items.<id>` 逐个查本区有没有对应 `items` 定义，最后回 `mud/` 按文件名回溯 LPC 源。

## 一、总账

| 指标 | 数量 |
|---|---|
| `room_items` 引用总数 | **880** |
| 能正常解析（本区有 `items` 定义） | 310（35%） |
| **悬空**（本区无 `items` 定义） | **570（65%）** |

按 LPC 源的类型再分：

| 分类 | 引用数 | 不同 id 数 | 含义 |
|---|---|---|---|
| **char** | 242 | 215 | LPC 里有 `set_name` 且 `inherit NPC/SNAKE/...` —— 是**人物**，被误写进了 `room_items` |
| **item** | 169 | 96 | LPC 里 `inherit QUARRY/BOOK/WEAPON/ITEM/...` —— 是**真物品**，只是我们没生成定义 |
| **ambiguous** | 159 | 86 | 同一个 id 在 LPC 里**既有像人物的又有像物品的**，需逐个判断 |
| **unknown** | 0 | 0 | LPC 里完全找不到同名文件 |

> **更正**：本文早先写的「694 处悬空 / 674 处彻底悬空 / 只有 20 处是 NPC 被当物品」
> **三个数字都错了**。
> 1. 694 是用正则切块数出来的，实际是 **880**（正则会在房间内部提前截断）；
> 2. 「彻底悬空」这个说法本身不成立 —— LPC 里**没有一个** id 找不到出处（unknown = 0）；
> 3. 「只有 20 处是 NPC 被当物品」严重低估，真实数量是 **242 条引用 / 215 个 id**。

## 二、char：被误写成 `room_items` 的人物（242 条 / 215 个 id）

这些 LPC 源是 `inherit NPC` / `inherit SNAKE`，转换器把 `set("objects", ...)`
里的它们写成了 `items.<id>`，而本区没有同名 `items` 定义，于是被 loader 静默跳过。
**后果**：这些房间运行时是空的，相关 `valid_leave` 门禁永远不触发。

| id | 名字 | inherit | 引用数 | 房间（前 3 个） | LPC 源 |
|---|---|---|---|---|---|
| `li` | 李管家 | NPC | 5 | `emei:huayanding`, `gaibang:inhole`, `gumu:liangong3` …+2 | `d/baituo/npc/li.c` |
| `chen` | 陈有德 | NPC | 4 | `beijing:qingmu_dating`, `gumu:baoziyan`, `huanghe:shidong` …+1 | `d/city/npc/chen.c` |
| `ma` | 马青雄 | NPC | 3 | `city:beimen`, `city:ma_zhengting`, `quanzhen:shiweishi` | `d/huanghe/npc/ma.c` |
| `daotong` | 道童 | NPC | 3 | `wudang:cangjingge`, `wudang:guangchang`, `wudang:xuanyuegate` | `d/quanzhen/npc/daotong.c` |
| `shouyuan` | 守园道长 | NPC | 3 | `wudang:langmei`, `wudang:langmeiyuan`, `wudang:tyroad13` | `kungfu/class/wudang/shouyuan.c` |
| `ouyangfeng` | 欧阳锋 | NPC | 2 | `baituo:dating`, `guiyun:jinship` | `kungfu/class/ouyang/ouyangfeng.c` |
| `ada` | 阿大 | NPC | 2 | `beijing:huiyingup`, `tulong:jiulou` | `b/yitian/npc/ada.c` |
| `xingzhe` | 行者 | NPC | 2 | `city:kedian2`, `lanzhou:kedian2` | `d/minimal_world_v2/npc/xingzhe.c` |
| `xu` | 徐子陵 | NPC | 2 | `emei:hcaguangchang`, `shenlong:kongdi` | `d/death/sky/npc/xu.c` |
| `su` | 苏万虹 | NPC | 2 | `emei:lianhuashi`, `shenlong:jushi` | `d/lingxiao/npc/su.c` |
| `mangshe` | 蟒蛇 | SNAKE | 2 | `global:cave`, `test:cave` | `clone/beast/mangshe.c` |
| `longnv` | 小龙女 | NPC | 2 | `gumu:houting`, `gumu:zhengting` | `kungfu/class/gumu/longnv.c` |
| `sang` | 桑土公 | NPC | 2 | `heimuya:tian1`, `lingjiu:pingtai` | `kungfu/class/lingjiu/sang.c` |
| `mo` | 莫大 | NPC | 2 | `hengyang:zhurongfeng`, `wudang:nanyanfeng` | `kungfu/class/henshan/mo.c` |
| `wen` | 文泰来 | NPC | 2 | `kaifeng:hh_zhengting`, `zhongzhou:miaojia_men` | `d/hangzhou/honghua/wen.c` |
| `zuo` | 左冷禅 | NPC | 2 | `lingjiu:shandao2`, `songshan:fengchantai` | `d/songshan/npc/zuo.c` |
| `lengqian` | 冷谦 | NPC | 2 | `mingjiao:rjqyuan`, `mingjiao:shanmen` | `kungfu/class/mingjiao/lengqian.c` |
| `duanyq` | 段延庆 | NPC | 2 | `wanjiegu:backyard`, `xiaoyao:qingcaop` | `kungfu/class/duan/duanyq.c` |
| `rong` | 黄蓉 | NPC | 2 | `wuguan:guofu_huayuan`, `xiangyang:guofuhuayuan` | `kungfu/class/taohua/rong.c` |
| `daiyongming` | 戴永明 | NPC | 1 | `beijing:front_yard2` | `kungfu/class/zhenyuan/daiyongming.c` |
| `tongzhaohe` | 童兆和 | NPC | 1 | `beijing:gate` | `kungfu/class/zhenyuan/tongzhaohe.c` |
| `xuanzhen` | 玄贞道长 | NPC | 1 | `beijing:qingmu_dayuan` | `kungfu/class/yunlong/xuanzhen.c` |
| `wangweiyang` | 王维扬 | NPC | 1 | `beijing:shufang` | `kungfu/class/zhenyuan/wangweiyang.c` |
| `wangjianying` | 王剑英 | NPC | 1 | `beijing:son_cabinet1` | `kungfu/class/zhenyuan/wangjianying.c` |
| `wangjianjie` | 王剑杰 | NPC | 1 | `beijing:zhengting` | `kungfu/class/zhenyuan/wangjianjie.c` |
| `tangrou` | 唐柔 | NPC | 1 | `chengdu:tanggate` | `kungfu/class/tangmen/tangrou.c` |
| `pang` | 胖商人 | NPC | 1 | `city:duchang` | `d/foshan/npc/pang.c` |
| `tuoboseng` | 托钵僧 | NPC | 1 | `city:nandajie2` | `kungfu/class/shaolin/tuoboseng.c` |
| `peng` | 彭连虎 | NPC | 1 | `city:pomiao` | `d/huanghe/npc/peng.c` |
| `duanzc` | 段正淳 | NPC | 1 | `dali:neitang` | `kungfu/class/duan/duanzc.c` |
| `huyizhi` | 胡逸之 | NPC | 1 | `dali:paifang` | `kungfu/class/hu/huyizhi.c` |
| `duanzm` | 段正明 | NPC | 1 | `dali:qiandian` | `kungfu/class/duan/duanzm.c` |
| `yideng` | 一灯大师 | NPC | 1 | `dali:qingchi` | `kungfu/class/duan/yideng.c` |
| `ba` | 巴天石 | NPC | 1 | `dali:sikong` | `kungfu/class/duan/ba.c` |
| `gu` | 顾炎武 | NPC | 1 | `dali:tingfang` | `d/tiezhang/npc/gu.c` |
| `daobf` | 刀白凤 | NPC | 1 | `dali:yuxuguan` | `kungfu/class/duan/daobf.c` |
| `wenhui` | 文晖小师太 | NPC | 1 | `emei:hcaeast` | `kungfu/class/emei/wenhui.c` |
| `miejue` | 灭绝师太 | NPC | 1 | `emei:hcahoudian` | `kungfu/class/emei/miejue.c` |
| `wenqing` | 文清小师太 | NPC | 1 | `emei:hcawest` | `kungfu/class/emei/wenqing.c` |
| `fengling` | 风陵师太 | NPC | 1 | `emei:jinding` | `kungfu/class/emei/fengling.c` |
| `houwang` | 猴王 | NPC | 1 | `emei:lengsl4` | `kungfu/class/misc/houwang.c` |
| `wenyin` | 文音小师太 | NPC | 1 | `emei:qfadadian` | `kungfu/class/emei/wenyin.c` |
| `wenfang` | 文方小师太 | NPC | 1 | `emei:wnadian` | `kungfu/class/emei/wenfang.c` |
| `longcheng` | 慕容龙城 | NPC | 1 | `guanwai:huandi1` | `kungfu/class/murong/longcheng.c` |
| `hufei` | 胡斐 | NPC | 1 | `guanwai:xiaowu` | `kungfu/class/hu/hufei.c` |
| `pingsi` | 平四 | NPC | 1 | `guanwai:xiaoyuan` | `kungfu/class/hu/pingsi.c` |
| `lin` | 仪琳 | NPC | 1 | `gumu:mishi8` | `d/hengshan/npc/lin.c` |
| `shangguan` | 上官银票 | NPC | 1 | `heimuya:baihutang` | `kungfu/class/misc/shangguan.c` |
| `mi` | 米为义 | NPC | 1 | `hengyang:zhurongdian` | `kungfu/class/henshan/mi.c` |
| `yue_wife` | 岳夫人 | NPC | 1 | `huashan:jushi` | `kungfu/class/huashan/yue-wife.c` |
| `cheng_buyou` | 成不忧 | NPC | 1 | `huashan:jzroad6` | `kungfu/class/huashan/cheng-buyou.c` |
| `yue_buqun` | 岳不群 | NPC | 1 | `huashan:qunxianguan` | `kungfu/class/huashan/yue-buqun.c` |
| `linghu` | 令狐冲 | NPC | 1 | `huashan:sgyhole1` | `kungfu/class/huashan/linghu.c` |
| `cong_buqi` | 丛不弃 | NPC | 1 | `huashan:shangu` | `kungfu/class/huashan/cong-buqi.c` |
| `feng_buping` | 封不平 | NPC | 1 | `huashan:xiaowu` | `kungfu/class/huashan/feng-buping.c` |
| `shiqing` | 石清 | NPC | 1 | `kaifeng:tinyuan` | `kungfu/class/lingxiao/shiqing.c` |
| `gaozecheng` | 高则成 | NPC | 1 | `kunlun:guangchang` | `kungfu/class/kunlun/gaozecheng.c` |
| `weisiniang` | 卫四娘 | NPC | 1 | `kunlun:guangchange` | `kungfu/class/kunlun/weisiniang.c` |
| `zhanchun` | 詹春 | NPC | 1 | `kunlun:guangchangw` | `kungfu/class/kunlun/zhanchun.c` |
| `hezudao` | 何足道 | NPC | 1 | `kunlun:jingshenfeng` | `kungfu/class/kunlun/hezudao.c` |

### 引用最多的几个（都是马厩）

`zaohongma`（枣红马）/`huangbiaoma`（黄骠马）/`ziliuma`（紫骝马）各 **29** 处，
分布在 `beijing:majiu`、`beijing:majuan`、`changan:majiu`、`chengdu:majiu` 等马厩。
单这一项就是 87 条引用 —— 光补这三个 NPC 就能让近 30 个马厩不再是空房。

### 白驼山的蛇（`baituo` 为主）

`dushe`(毒蛇) 17、`qingshe`(竹叶青蛇) 5、`yanjingshe`(眼镜蛇) 5、
`jinshe`(金环蛇) 4、`wubushe`(五步蛇) 2、`mangshe`(蟒蛇) 2、
`caihuashe`(菜花蛇) 1、`wangshe`(眼镜王蛇) 1、`fushe`(腹蛇) 1 ——
全部 `inherit SNAKE`。`baituo/cave` 的蟒蛇已在 §2④ 单独修过。

## 三、item：真物品，只是我们没生成定义（169 条 / 96 个 id）

这一类是**真的丢了东西**：LPC 有 `clone/quarry/` `clone/book/` `clone/weapon/` 等，
转换器写了 `room_items` 引用，但对应的 `items` 块从没生成。
后果是这些房间** loot 全空** —— 道德经、钢刀、长剑、野兔、尸体、鹅卵石、大树枝等等。

| id | 名字 | inherit | 引用数 | 房间（前 3 个） | LPC 源 |
|---|---|---|---|---|---|
| `tu` | 野兔 | QUARRY | 9 | `dali:road5`, `fuzhou:fzroad1`, `hengyang:xuanyadi` …+6 | `clone/quarry/tu.c` |
| `daodejing` | 道德经 | BOOK | 8 | `wudang:cangjingge`, `wudang:cangjingge`, `wudang:cangjingge` …+5 | `clone/book/daodejing.c` |
| `gangdao` | 钢刀 | BLADE | 6 | `city:ma_bingqi`, `gaibang:chucang`, `kaifeng:hh_bingqi` …+3 | `clone/weapon/gangdao.c` |
| `laohu` | 老虎 | QUARRY | 6 | `dali:gaolishan2`, `fuzhou:fzroad7`, `hangzhou:shanlu6` …+3 | `clone/quarry/laohu.c` |
| `gou2` | 狼狗 | QUARRY | 6 | `foshan:street4`, `foshan:street5`, `hangzhou:guozhuang` …+3 | `clone/quarry/gou2.c` |
| `ganchai` | 干柴 | ITEM | 5 | `baituo:chaifang`, `city:ma_chufang`, `fuzhou:mishi` …+2 | `d/wudu/obj/ganchai.c` |
| `yang2` | 山羊 | QUARRY | 5 | `dali:dalangan1`, `dali:gaolishan1`, `dali:gelucheng` …+2 | `clone/quarry/yang2.c` |
| `laozi1` | 道德经「第一章」 | BOOK | 4 | `wudang:cangjingge`, `wudang:cangjingge`, `wudang:cangjingge` …+1 | `clone/book/laozi1.c` |
| `corpse` | 无名尸体 | ITEM | 4 | `wudang:nanyan1`, `wudang:nanyan2`, `wudang:nanyan3` …+1 | `clone/misc/corpse.c` |
| `changjian` | 长剑 | SWORD | 3 | `city:ma_bingqi`, `kaifeng:hh_bingqi`, `luoyang:bingqiku` | `clone/weapon/changjian.c` |
| `gou` | 野狗 | QUARRY | 3 | `hengyang:hsroad7`, `huanghe:tiandi4`, `village:sexit` | `clone/quarry/gou.c` |
| `eluanshi` | 鹅卵石 | THROWING | 3 | `huanghe:caodi2`, `huanghe:shixiazi`, `suzhou:huqiu` | `d/hangzhou/obj/eluanshi.c` |
| `shuzhi` | 大树枝 | STAFF | 3 | `huanghe:shulin1`, `lingzhou:luorilin2`, `suzhou:huqiu` | `d/city/obj/shuzhi.c` |
| `zhubang` | 竹棒 | STAFF | 3 | `kaifeng:hh_bingqi`, `xiakedao:wuqiku`, `yanziwu:shijian` | `clone/weapon/zhubang.c` |
| `he2` | 雪鹤 | QUARRY | 3 | `lingxiao:huajing`, `lingxiao:meiroad2`, `lingxiao:qianyuan` | `clone/quarry/he2.c` |
| `ouyangke` | 欧阳克 | F_MASTER | 2 | `city:beidajie1`, `guiyun:jinship` | `kungfu/class/ouyang/ouyangke.c` |
| `changbian` | 长鞭 | WHIP | 2 | `dali:bingqiku`, `xiakedao:wuqiku` | `clone/weapon/changbian.c` |
| `sword` | 长剑 | SWORD | 2 | `global:dir_macro_test`, `test:dir_macro_test` | `d/beijing/npc/obj/sword.c` |
| `poison` | ? | SKILL | 2 | `global:duwushi`, `test:duwushi` | `kungfu/skill/poison.c` |
| `mudao` | 木刀 | BLADE | 2 | `guanwai:jingxiu`, `yanziwu:shijian` | `clone/weapon/mudao.c` |
| `book_stone` | 石板 | BOOK | 2 | `shaolin:beilin3`, `yanziwu:huanshi` | `clone/book/book-stone.c` |
| `book_bamboo` | 旧竹片 | BOOK | 2 | `shaolin:damodong`, `yanziwu:huanshi` | `clone/book/book-bamboo.c` |
| `gold` | 黄金 | MONEY | 2 | `shenfeng:shibi`, `taohua:mushi` | `clone/money/gold.c` |
| `yijing0` | 「易经序卦篇」 | BOOK | 2 | `taohua:shufang`, `taohua:shufang` | `clone/book/yijing0.c` |
| `yijing1` | 「易经说卦篇」 | BOOK | 2 | `taohua:shufang`, `taohua:shufang` | `clone/book/yijing1.c` |
| `yijing2` | 「易经杂卦篇」 | BOOK | 2 | `taohua:shufang`, `taohua:shufang` | `clone/book/yijing2.c` |
| `yijing3` | 「易经系辞篇」 | BOOK | 2 | `taohua:shufang`, `taohua:shufang` | `clone/book/yijing3.c` |
| `laozi2` | 道德经「第二章」 | BOOK | 2 | `wudang:cangjingge`, `wudang:cangjingge` | `clone/book/laozi2.c` |
| `laozi8` | 道德经「第八章」 | BOOK | 2 | `wudang:cangjingge`, `wudang:cangjingge` | `clone/book/laozi8.c` |
| `laozi13` | 道德经「第十三章」 | BOOK | 2 | `wudang:cangjingge`, `wudang:cangjingge` | `clone/book/laozi13.c` |
| `laozi16` | 道德经「第十六章」 | BOOK | 2 | `wudang:cangjingge`, `wudang:cangjingge` | `clone/book/laozi16.c` |
| `laozi18` | 道德经「第十八章」 | BOOK | 2 | `wudang:cangjingge`, `wudang:cangjingge` | `clone/book/laozi18.c` |
| `gangzhang` | 钢杖 | STAFF | 1 | `baituo:wuqiku` | `clone/weapon/gangzhang.c` |
| `fruit` | 果汁 | ITEM | 1 | `city:liaotian` | `clone/game/fruit.c` |
| `mint` | 薄荷冰 | ITEM | 1 | `city:liaotian` | `clone/game/mint.c` |
| `idiom_book` | 成语词典 | CORE_HTTP | 1 | `city:shuyuan` | `u/mudren/obj/idiom_book.c` |
| `dizigui_book` | 弟子规 | ITEM | 1 | `city:shuyuan2` | `u/mudren/obj/dizigui_book.c` |
| `qianjiashi_book` | 千家诗 | ITEM | 1 | `city:shuyuan2` | `u/mudren/obj/qianjiashi_book.c` |
| `shijing_book` | 诗经 | ITEM | 1 | `city:shuyuan2` | `u/mudren/obj/shijing_book.c` |
| `box` | 功德箱 | ITEM | 1 | `city:wumiao` | `d/city/npc/obj/box.c` |
| `chahua2` | 十八学士 | HEAD | 1 | `dali:chahua10` | `d/dali/obj/chahua2.c` |
| `chahua3` | 十三太保 | HEAD | 1 | `dali:chahua10` | `d/dali/obj/chahua3.c` |
| `chahua6` | 风 | HEAD | 1 | `dali:chahua10` | `d/dali/obj/chahua6.c` |
| `chahua1` | 落第秀才 | HEAD | 1 | `dali:chahua2` | `d/dali/obj/chahua1.c` |
| `chahua8` | 八宝妆 | HEAD | 1 | `dali:chahua3` | `d/dali/obj/chahua8.c` |
| `chahua9` | 满月 | HEAD | 1 | `dali:chahua3` | `d/dali/obj/chahua9.c` |
| `chahua10` | 眼 | HEAD | 1 | `dali:chahua3` | `d/dali/obj/chahua10.c` |
| `chahua4` | 八仙过海 | HEAD | 1 | `dali:chahua4` | `d/dali/obj/chahua4.c` |
| `chahua5` | 七仙女 | HEAD | 1 | `dali:chahua6` | `d/dali/obj/chahua5.c` |
| `chahua7` | 二 | HEAD | 1 | `dali:chahua9` | `d/dali/obj/chahua7.c` |
| `xiong` | 灰熊 | QUARRY | 1 | `guanwai:heifengkou` | `clone/quarry/xiong.c` |
| `diao` | 紫貂 | QUARRY | 1 | `guanwai:luming` | `clone/quarry/diao.c` |
| `laohu2` | 东北虎 | QUARRY | 1 | `guanwai:milin2` | `clone/quarry/laohu2.c` |
| `niao` | 斑鸠 | QUARRY | 1 | `guiyun:tiandi` | `clone/quarry/niao.c` |
| `changaoxie` | 长螯蝎 | WORM | 1 | `hangzhou:shiwudong` | `clone/worm/changaoxie.c` |
| `qianjiewugong` | 千节蜈蚣 | WORM | 1 | `huanghe:bingcao` | `clone/worm/qianjiewugong.c` |
| `shitou` | 大石头 | HAMMER | 1 | `huanghe:shixiazi` | `d/city/obj/shitou.c` |
| `zhengqi_book` | 正气吟 | BOOK | 1 | `huashan:shufang` | `clone/book/zhengqi_book.c` |
| `eyu` | 鳄鱼 | QUARRY | 1 | `jueqing:eyutan2` | `clone/quarry/eyu.c` |
| `fengmi` | 玉蜂蜜 | ITEM | 1 | `jueqing:house` | `d/gumu/obj/fengmi.c` |

按 inherit 统计这一类的量级：

| inherit | id 数 |
|---|---|
| `BOOK` | 24 |
| `QUARRY` | 16 |
| `ITEM` | 13 |
| `HEAD` | 10 |
| `?` | 7 |
| `SWORD` | 4 |
| `WORM` | 4 |
| `STAFF` | 3 |
| `BLADE` | 3 |
| `WHIP` | 2 |
| `HAMMER` | 2 |
| `F_MASTER` | 1 |
| `CORE_HTTP` | 1 |
| `SKILL` | 1 |
| `THROWING` | 1 |
| `DAGGER` | 1 |
| `MONEY` | 1 |
| `__DIR__` | 1 |
| `HANDS` | 1 |

## 四、ambiguous：同 id 既是人物又是物品（159 条 / 86 个 id）

这一类**不能自动判定**。LPC 里同一个文件名在 `d/*/npc/`（人物）和
`clone/quarry/`、`clone/weapon/`（物品）下各有一份，转换器合并成了同一个 id。
必须逐个看引用它的房间在 LPC 里 `set("objects")` 到底写的是哪个路径。

| id | 引用数 | 候选（人物） | 候选（物品） | 房间（前 3 个） |
|---|---|---|---|---|
| `lu` | 9 | 陆菲青 `d/hangzhou/honghua/lu.c`; 鲁开 `d/luoyang/npc/lu.c` | 梅花鹿 `clone/quarry/lu.c`; ? `kungfu/skill/bluesea-force/perform/lu.c` | `city:pomiao`, `guanwai:luming`, `guiyun:shufang` |
| `zhujian` | 9 | 竹剑 `kungfu/class/lingjiu/zhujian.c` | 竹剑 `clone/weapon/zhujian.c`; 竹剑 `d/emei/obj/zhujian.c` | `dali:bingqiku`, `huashan:bingqifang`, `kunlun:liangong` |
| `hou` | 9 | 侯通海 `d/huanghe/npc/hou.c`; 侯人英 `d/qingcheng/npc/hou.c` | 猴子 `clone/quarry/hou.c` | `emei:jldongkou`, `fuzhou:gushan`, `gumu:shulin12` |
| `he` | 5 | 何太冲 `b/yitian/npc/he.c`; 仪和 `d/hengshan/npc/he.c` | 丹顶鹤 `clone/quarry/he.c`; ? `kungfu/skill/riyue-bian/he.c` | `dali:shijing`, `dali:yuhuayuan`, `emei:hcaeast` |
| `ying` | 5 | 锺兆英 `kungfu/class/miao/ying.c`; 任盈盈 `kungfu/class/riyue/ying.c` | 突鹰 `clone/quarry/ying.c`; ? `kungfu/skill/hanwang-qingdao/ying.c` | `heimuya:shenggu`, `xuedao:nroad3`, `xuedao:nroad5` |
| `feng` | 4 | 凤天南 `adm/npc/feng.c`; 冯锡范 `d/beijing/npc/feng.c` | ? `adm/daemons/story/feng.c`; ? `d/minimal_world_v2/skill/feng.c` | `emei:chuwujian`, `heimuya:up1`, `huashan:luoyan` |
| `zhao` | 4 | 赵敏 `b/yitian/npc/zhao.c`; 赵半山 `d/hangzhou/honghua/zhao.c` | ? `kungfu/skill/jinzhong-zhao/zhao.c`; ? `kungfu/skill/piaoxue-zhang/zhao.c` | `emei:lingwenge`, `heimuya:shimen`, `kaifeng:hh_houting` |
| `yang` | 4 | 杨永福 `d/city/npc/yang.c`; 杨永福 `d/city/npc/obj/yang.c` | 绵羊 `clone/quarry/yang.c`; ? `kungfu/skill/poguang-dao/yang.c` | `gumu:houting`, `kaifeng:hh_damen`, `shenfeng:huijiang2` |
| `lang` | 4 | 浪翻云 `d/luoyang/npc/lang.c` | 野狼 `clone/quarry/lang.c`; ? `kungfu/skill/xuanming-zhang/lang.c` | `heimuya:linjxd4`, `lingxiao:cityout`, `shenfeng:huijiang1` |
| `fan` | 3 | 范先生 `d/wuguan/npc/fan.c`; 范骅 `kungfu/class/duan/fan.c` | 大米饭 `d/tiezhang/obj/fan.c`; ? `kungfu/skill/youshen-zhang/fan.c` | `dali:sima`, `heimuya:shijie2`, `jueqing:shanzhuang` |
| `fu` | 3 | 傅思归 `kungfu/class/duan/fu.c` | 蝙蝠 `clone/quarry/fu.c`; ? `kungfu/skill/jiandun-zhusuo/fu.c` | `dali:wangfulu`, `emei:jiulaodong`, `emei:jldongnei` |
| `cheng` | 3 | 程药发 `d/city/npc/cheng.c`; 成自学 `d/lingxiao/npc/cheng.c` | ? `d/lingxiao/cheng.c` | `lingjiu:changl13`, `quanzhen:nairongdian`, `xiangyang:caodi4` |
| `song` | 3 | 宋远桥 `kungfu/class/wudang/song.c` | 松鼠 `clone/quarry/song.c`; ? `kungfu/skill/huashan-quan/song.c` | `lingjiu:dadao1`, `lingjiu:dadao2`, `wudang:sanqingdian` |
| `yin` | 3 | 殷素素 `b/tulong/npc/yin.c`; 殷素素 `d/tulong/tulong/npc/yin.c` | ? `d/minimal_world_v2/skill/yin.c`; ? `kungfu/skill/bazhen-zhang/yin.c` | `quanzhen:shijianyan`, `shenlong:houting`, `wudang:caolianfang` |
| `zhang` | 3 | 张翠山 `b/tulong/npc/zhang.c`; 张朝唐 `d/foshan/npc/zhang.c` | 獐子 `clone/quarry/zhang.c`; 张天师 `d/item/npc/zhang.c` | `quanzhen:xianzhentang`, `shenlong:zoulang`, `wudang:xiaoyuan` |
| `hong` | 2 | 洪人雄 `d/qingcheng/npc/hong.c`; 洪七公 `kungfu/class/gaibang/hong.c` | ? `kungfu/skill/baihua-cuoquan/hong.c`; ? `kungfu/skill/dali-chu/hong.c` | `city:gbxiaowu`, `shenlong:dating` |
| `bai` | 2 | 白龟寿 `b/tulong/npc/bai.c`; 白无常 `d/death/npc/bai.c` | ? `kungfu/skill/tiangang-chenfa/bai.c` | `city:ma_huayuan`, `xuanminggu:xuanmingfeng` |
| `xi` | 2 | 奚长老 `kungfu/class/gaibang/xi.c`; 张松溪 `kungfu/class/wudang/xi.c` | ? `kungfu/skill/feifeng-bian/xi.c`; ? `kungfu/skill/shenghuo-ling/xi.c` | `city:ma_zhengting`, `wudang:donglang1` |
| `shi` | 2 | 史镖头 `d/fuzhou/npc/shi.c`; 石双英 `d/hangzhou/honghua/shi.c` | ? `kungfu/skill/chousui-zhang/shi.c`; ? `kungfu/skill/jinshe-jian/shi.c` | `city:tree`, `kaifeng:hh_xingtang` |
| `zhu` | 2 | 朱熹 `d/city/npc/zhu.c`; 褚万春 `d/lingxiao/npc/zhu.c` | 山猪 `clone/quarry/zhu.c`; ? `kungfu/skill/bluesea-force/perform/zhu.c` | `dali:shufang`, `kaifeng:yezhulin` |
| `zhen` | 2 | 静真师太 `kungfu/class/emei/zhen.c`; 商宝震 `kungfu/class/shang/zhen.c` | ? `d/minimal_world_v2/skill/zhen.c`; 长针 `kungfu/class/riyue/dongfang/zhen.c` | `emei:fushouan`, `shaolin:shang_men` |
| `zhou` | 2 | 周仲英 `d/hangzhou/honghua/zhou.c`; 周逸风 `d/luoyang/npc/zhou.c` | 腊八粥 `d/xiakedao/obj/zhou.c`; ? `kungfu/skill/mizong-houquan/zhou.c` | `emei:qinggong`, `quanzhen:jiaobei` |
| `jia` | 2 | 贾人达 `d/qingcheng/npc/jia.c`; 家丁 `d/xiangyang/npc/jia.c` | 捕兽夹 `d/hengyang/obj/jia.c`; ? `d/minimal_world_v2/skill/jia.c` | `emei:wanxingan`, `heimuya:qing` |
| `fang` | 2 | 方人智 `d/qingcheng/npc/fang.c`; 方碧琳 `kungfu/class/emei/fang.c` | ? `d/baituo/fang.c` | `emei:yunufeng`, `quanzhen:datang3` |
| `wang` | 2 | 王夫人 `d/fuzhou/npc/wang.c`; 王合计 `d/suzhou/npc/wang.c` | ? `d/luoyang/wang.c`; ? `kungfu/skill/tan-tui/wang.c` | `heimuya:shanya1`, `quanzhen:shandong` |
| `liu` | 2 | 刘老实 `d/changan/npc/liu.c`; 刘通 `d/kunming/npc/liu.c` | ? `d/minimal_world/skill/liuxin-jian/liu.c`; ? `kungfu/skill/jueqing-jian/liu.c` | `hengyang:furongfeng`, `quanzhen:jingxiushi` |
| `qu` | 2 | 曲洋 `kungfu/class/riyue/qu.c`; 曲灵风 `kungfu/class/taohua/qu.c` | ? `kungfu/skill/xianglong-zhang/qu.c` | `hengyang:furongfeng`, `taohua:shufang` |
| `xiang` | 2 | 向大年 `kungfu/class/henshan/xiang.c`; 向问天 `kungfu/class/riyue/xiang.c` | 大象 `clone/quarry/xiang.c`; 普贤菩萨像 `d/emei/obj/xiang.c` | `hengyang:zigai`, `quanzhou:chating` |
| `yu` | 2 | 余鱼同 `d/hangzhou/honghua/yu.c`; 于人豪 `d/qingcheng/npc/yu.c` | ? `kungfu/skill/guzhuo-zhang/yu.c` | `kaifeng:hh_xiaozhu`, `wudang:houyuan` |
| `zhu2` | 2 | 朱饮 `d/luoyang/npc/zhu2.c` | 野猪 `clone/quarry/zhu2.c` | `kaifeng:yezhulin`, `motianya:mtroad5` |
| `ding` | 2 | 丁勉 `d/songshan/npc/ding.c`; 丁敏君 `kungfu/class/emei/ding.c` | 铜鼎 `b/tulong/obj/ding.c`; 铜鼎 `d/tulong/tulong/obj/ding.c` | `meizhuang:keting`, `xiyu:riyuedong` |
| `huang` | 2 | 黄伯流 `d/heimuya/npc/huang.c`; 黄钟公 `kungfu/class/meizhuang/huang.c` | ? `kungfu/skill/tianchang-zhang/huang.c` | `meizhuang:xiaowu`, `taohua:dating` |
| `quan` | 1 | 全冠清 `kungfu/class/gaibang/quan.c` | ? `kungfu/skill/jiuyin-shengong/perform/quan.c` | `city:ma_houyuan` |
| `wu` | 1 | 吴青烈 `d/huanghe/npc/wu.c`; 乌老大 `d/pk/npc/wu.c` | ? `kungfu/skill/feifeng-whip/wu.c`; ? `kungfu/skill/qiulin-shiye/wu.c` | `city:ma_zhengting` |
| `gao` | 1 | 高克新 `d/songshan/npc/gao.c`; 高升泰 `kungfu/class/duan/gao.c` | 冰雪翡翠糕 `d/lingjiu/obj/gao.c`; 龟苓膏 `d/quanzhen/npc/obj/gao.c` | `dali:louti` |
| `hua` | 1 | 华英雄 `d/death/sky/npc/hua.c`; 花铁干 `d/register/npc/hua.c` | 鲜花 `d/beijing/obj/hua.c`; 百香花 `d/shenlong/obj/hua.c` | `dali:situ` |
| `chu` | 1 | 褚万里 `kungfu/class/duan/chu.c` | ? `kungfu/skill/tongbi-zhang/chu.c`; ? `kungfu/skill/xueshan-jian/chu.c` | `dali:wangfugate` |
| `dao` | 1 | 静道师太 `kungfu/class/emei/dao.c` | ? `kungfu/skill/tie-zhang/dao.c` | `emei:cangjingge` |
| `bei` | 1 | 贝锦仪 `kungfu/class/emei/bei.c` | ? `kungfu/skill/dabei-zhang/bei.c` | `emei:duguangtai` |
| `xin` | 1 | 静心师太 `kungfu/class/emei/xin.c` | 书信 `d/guiyun/npc/obj/xin.c`; ? `kungfu/skill/jiuyin-shengong/perform/xin.c` | `emei:hcazhengdian` |
| `ling` | 1 | 赵灵珠 `kungfu/class/emei/ling.c` | 镔铁令 `b/tulong/npc/obj/ling.c`; 镔铁令 `d/tulong/tulong/npc/obj/ling.c` | `emei:lianhuashi` |
| `hui` | 1 | 静慧师太 `kungfu/class/emei/hui.c` | ? `d/minimal_world_v2/skill/hui.c`; ? `kungfu/skill/dragon-strike/hui.c` | `emei:qfadadian` |
| `xian` | 1 | 冼老板 `d/city/npc/xian.c`; 定闲师太 `d/hengshan/npc/xian.c` | ? `kungfu/skill/bagua-biao/xian.c`; ? `kungfu/skill/emei-jian/xian.c` | `emei:qingyinge` |
| `kong` | 1 | 孔大官人 `d/kaifeng/npc/kong.c`; 静空师太 `kungfu/class/emei/kong.c` | ? `kungfu/skill/kongming-quan/kong.c`; ? `kungfu/skill/kunlun-zhang/kong.c` | `emei:wnadian` |
| `xuan` | 1 | 静玄师太 `kungfu/class/emei/xuan.c` | ? `kungfu/skill/bluesea-force/perform/xuan.c`; ? `kungfu/skill/taixuan-gong/xuan.c` | `emei:woyunan` |
| `liang` | 1 | 梁喜禄 `d/changan/npc/liang.c`; 梁子翁 `d/huanghe/npc/liang.c` | ? `d/fuzhou/liang.c`; ? `d/lingxiao/liang.c` | `gaibang:undertre` |
| `jian` | 1 | 简长老 `kungfu/class/gaibang/jian.c` | 倚天剑 `b/yitian/npc/obj/jian.c`; 倚天剑 `d/tulong/yitian/npc/obj/jian.c` | `gaibang:undertre` |
| `pi` | 1 | 裨将 `d/xiangyang/npc/pi.c`; 皮清玄 `kungfu/class/quanzhen/pi.c` | ? `kungfu/skill/jiuyang-shengong/perform/pi.c`; ? `kungfu/skill/pixie-jian/pi.c` | `gumu:daxiaochang` |
| `ji` | 1 | 吉人通 `d/qingcheng/npc/ji.c`; 计老人 `d/shenfeng/npc/ji.c` | 山鸡 `clone/quarry/ji.c`; ? `d/minimal_world_v2/skill/ji.c` | `gumu:juyan` |
| `tong` | 1 | 童百熊 `kungfu/class/riyue/tong.c` | ? `kungfu/skill/lutou-zhang/tong.c`; ? `kungfu/skill/poxu-daxuefa/tong.c` | `heimuya:fen0` |

### 最容易搞错的几个

| id | 陷阱 |
|---|---|
| `zhujian` | **竹剑**。`clone/weapon/zhujian.c`（SWORD）是武器，但 `kungfu/class/lingjiu/zhujian.c` 是 NPC。房间在兵械库，多半是武器 |
| `lu` | `clone/quarry/lu.c`（梅花鹿，QUARRY）对上 `d/hangzhou/honghua/lu.c`（陆菲，NPC）、`d/luoyang/npc/lu.c`（鲁开，NPC）。要按房间判断 |
| `hou` | `clone/quarry/hou.c`（猴子）对上 `d/huanghe/npc/hou.c`（侯通海）、`d/qingcheng/npc/hou.c`（侯人豪） |
| `he` | `clone/quarry/he.c`（丹顶鹤）对上 `b/yitian/npc/he.c`（何太后）、`d/hengshan/npc/he.c`（仪和） |
| `sword` | `clone/weapon/sword.c`（长剑） |

## 五、顺带发现：`data/world` 里混进了测试夹具

扫描时看到几个 id 的引用房间在 `global` 和 `test` 这两个「区」里：

- mangshe -> `global:cave`
- mangshe -> `test:cave`
- poison -> `global:duwushi`
- poison -> `test:duwushi`
- sword -> `global:dir_macro_test`
- sword -> `test:dir_macro_test`

`data/world/test.ucl` / `global.ucl` 里的房间（`test:cave`、`test:duwushi`、
`global:dir_macro_test` …）看起来是**测试夹具**，却被 loader 和审计脚本一并加载了。
值得单独确认它们是否该留在 `data/world`。

## 六、建议的处理顺序（供决策，本次未执行）

按「投入产出比 × 风险」排：

| 优先级 | 做什么 | 覆盖 | 风险 |
|---|---|---|---|
| 1 | 补 `zaohongma` / `huangbiaoma` / `ziliuma` 三个马厩 NPC | 87 条引用 / 近 30 个房间 | 低（马匹，不参与门禁） |
| 2 | 补 `baituo` 的 8 种蛇（`SNAKE` 基类，字段少） | 约 36 条引用 | 低（同 §2④ 的玄冰莽，已有先例） |
| 3 | 补 `item` 类里引用最多的战利品（`gangdao` / `changjian` / `mudao` / `ganchai` / `corpse`） | 约 30 条引用 | 低（纯物品） |
| 4 | 补 `item` 类里的书籍（`daodejing` / `laozi1..18` / `yijing0..3`） | 约 30 条引用 | 低（`wudang:cangjingge` / `taohua:shufang` 是藏经阁，本该有书） |
| 5 | 逐个查 `ambiguous` 的 87 个 id 属于哪个候选 | 163 条引用 | 中，要看 LPC 原文 |
| 6 | 给 loader 加「`room_items` 引用解析不到」的 warning | — | 低，但能让这类问题不再静默 |

另外：`clone/quarry/` 里那批（野兔/老虎/野狗/山羊/梅花鹿/猴子/雪鹤/丹顶鹤 …）
在 LPC 里是「猎物」，被玩家杀死后会变成肉/皮。移植它们等于把狩猎玩法带回来，
工作量比单纯生成 `items` 块大 —— 建议归到单独的「狩猎系统」轮次。

---

## 附：复现方法

本报告是**一次性扫描**的产物，没有留下脚本。若要重跑，逻辑是：

1. 遍历 `data/world/*.ucl`，用括号配平取出每个顶层 `room_items "<room>" { … }`；
2. 抽其中所有 `items.<id>.id`；
3. 若该区没有 `items "<id>" {` 定义 → 记为悬空；
4. 拿 `<id>` 去掉 `-`/`_` 并小写，去 `mud/` 里找同名 `.c`；
5. 读该文件的 `inherit`，结合路径含 `/npc/` `/beast/` 还是 `/obj/` `/item/` `/book/` `/weapon/` `/quarry/` 判人物还是物品；
6. 同一 id 同时命中两类 → 标 ambiguous，留给人工。

第 5 步的判据不能只看 `set_name` —— **武器和书也有 `set_name`**
（`clone/weapon/zhujian.c` 就有 `set_name("竹剑", …)`）。
