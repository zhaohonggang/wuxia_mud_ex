# `room_items` 悬空引用扫描报告

> **只读扫描，未改动任何数据。**
> 生成方式：遍历 `data/world/*.ucl` 的顶层 `room_items` 块（括号配平定位，
> 不用正则切块 —— 见 [lpc-objects-placement-issues.zh-CN.md](lpc-objects-placement-issues.zh-CN.md) §八），
> 再按 `items.<id>` 逐个查本区有没有对应 `items` 定义，最后回 `mud/` 按文件名回溯 LPC 源。

## 当前状态（2026-10：room_items 里的活物已搬走）

下面各节是**历史扫描记录**，数字停在动手修之前。现在的实际口径：

| 指标 | 修之前 | 现在 |
|---|---|---|
| 悬空引用合计（loader 计数） | **444** | **13** |
| ├ `room_items` | 437 | 6 |
| └ `room_characters` | 7 | 7 |
| 其中「char 被误写成 item」 | 431 | **0** |
| clone_lib 里的 NPC 定义 | 121 | **487** |

做法是新增 `scripts/fix_npc_in_items.py`：按 LPC 目标的 `inherit` 链
（`NPC` / `QUARRY` / `WORM` / `SNAKE` …）判定一个 `room_items` 引用到底是
人物还是物品，把判定为人物的**外科式**搬到 `room_characters`，缺的定义按
`<来源>_<id>` 命名落进 `clone_lib.ucl`。439 条引用 / 386 个房间 / 53 个区。

`scripts/classify_dangling_items.py` 现在报 `room_items` 悬空 **4 条、NPC-in-items 0 条**。

剩下的 13 条是真待办：

| 类别 | 条数 | 说明 |
|---|---|---|
| 本区没有 `characters` 块 | 7 | `lingxiao` 的 `cheng`/`liang`/`liao`/`qi` 是武功招式名当文件名；`chengdu:tong_ren`、`city:zixu`、`xiangyang:mujiang` 同理 |
| `shaolin:cjlou1` 的 `wuji1`~`wuji4` | 4 | 秘籍随机技能缺口，见 [lpc-port-gaps.zh-CN.md](lpc-port-gaps.zh-CN.md) |
| `sammatti:town_square` 引 `global.items.*` | 2 | `global` 已搬去 `test/fixtures/world`，默认加载不含它 |

## 〇、总账（含此前漏掉的一类）

> **本节是加 loader warning 之后才发现的。**
> 前面所有统计只扫了 `room_items`，**从来没扫过 `room_characters`** ——
> 而它的悬空量比 `room_items` 还大。

| 类别 | 引用总数 | 悬空 | 不同 id |
|---|---|---|---|
| `room_items` | 880 | 489 | 142 |
| `room_characters` | **3040** | **767** | **134** |
| 合计 | 3920 | **1256** | — |

loader 现在会把这两类都打出来（见 §〇 的说明）：

    [world] kunming 的 kunming:bijifang 引用了不存在的 character
    "characters.jumin1.id" —— 已跳过，该内容运行时不存在。

实际统计（`mix run -e 'Kantele.World.Loader.load()'` 后读进程字典）：

    按类型: %{character: 767, item: 468}

（item 468 比 §一 的 489 少，是因为那一版跳过了 `global` / `test`
两个转换器测试夹具区，而 loader 不跳。）

### `room_characters` 悬空 top 25

| id | 引用数 | 房间（例） |
|---|---|---|
| `walker` | **142** | `baituo:gebi` `beijing:caishi` `beijing:dianmen` |
| `bing` | **80** | `chengdu:eastgate` `chengdu:northgate` |
| `mafu` | 27 | `beijing:majiu` `changan:majiu` `chengdu:majiu` |
| `ducha` | 23 | `city:beimen` `city:dongmen` `city:ximen` |
| `liumang` | 22 | `chengdu:eastroad2` `chengdu:westroad1` |
| `wujiang` | 20 | `chengdu:eastgate` `chengdu:guangchang` |
| `kid1` | 19 | `heimuya:pingdingzhou` `jingzhou:lydao1` |
| `xunbu` | 16 | `changan:baihu1` `city:dongdajie1` |
| `guanbing` | 16 | `zhongzhou:beimen` |
| `xiaoer2` | 15 | `baituo:jiudian` `huashan:shop` |

几个说明：

- **`walker`（142 处）与 `bing`（80 处）** 是最严重的两项 ——
  一个「西洋人」和一个「官兵」被几乎所有城门/道路引用，但只有少数区有定义。
- **`mafu`（27 处）** 就是马夫。这轮补了三匹马（每厩 3 匹），
  但**马夫本身在 27 个马厩里是悬空的** —— 那些区没定义 `characters "mafu"`。
  所以「马厩里有马但没马夫」。
- `guanbing` / `bing` 是同一个角色（官兵）的两种 id，
  与 `room_items` 那批 `gangdao` / `changjian` 是完全一样的**跨区问题**：
  定义在某个区，别的区引用不到。修法也一样 —— 每个引用它的区补一份。

### 为什么之前没发现

因为 loader 对解析不到的引用**静默跳过**：

```elixir
nil ->
  # NPC 数据缺失（引用不存在）时跳过，避免悬挂引用
  []
```

和 `if is_nil(item_id) do zone`。既不报错也不打日志，
所以 767 条 NPC 悬空可以一直躺着，而门禁条件那边只表现为
「这个 NPC 不在房里」，很容易被误判成"条件写错了"。

**这就是加 warning 的价值**：不能靠人肉扫 3920 条引用。

---

## 一、总账

| 指标 | 数量 |
|---|---|
| `room_items` 引用总数 | **880** |
| 能正常解析（本区有 `items` 定义） | 391（44%） |
| **悬空**（本区无 `items` 定义） | **489（56%）** |

按 LPC 源的类型再分：

| 分类 | 引用数 | 不同 id 数 | 含义 |
|---|---|---|---|
| **char** | 241 | 214 | LPC 里有 `set_name` 且 `inherit NPC/SNAKE/...` —— 是**人物**，被误写进了 `room_items` |
| **item** | 98 | 57 | LPC 里 `inherit QUARRY/BOOK/WEAPON/ITEM/...` —— 是**真物品**，只是我们没生成定义 |
| **ambiguous** | 150 | 85 | 同一个 id 在 LPC 里**既有像人物的又有像物品的**，需逐个判断 |
| **unknown** | 0 | 0 | LPC 里完全找不到同名文件 |

> **更正**：本文早先写的「694 处悬空 / 674 处彻底悬空 / 只有 20 处是 NPC 被当物品」
> **三个数字都错了**。
> 1. 694 是用正则切块数出来的，实际是 **880**（正则会在房间内部提前截断）；
> 2. 「彻底悬空」这个说法本身不成立 —— LPC 里**没有一个** id 找不到出处（unknown = 0）；
> 3. 「只有 20 处是 NPC 被当物品」严重低估，真实数量是 **241 条引用 / 214 个 id**。

## 二、char：被误写成 `room_items` 的人物（241 条 / 214 个 id）

> **本节已修完。** 439 条引用已由 `scripts/fix_npc_in_items.py` 搬进
> `room_characters`，缺的 366 个定义进了 `clone_lib.ucl`（`<来源>_<id>` 命名）。
> 下面的表格保留，作为「哪些 id 其实是活物」的依据。

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
| `xihuazi` | 西华子 | NPC | 1 | `kunlun:qianting` | `kungfu/class/kunlun/xihuazi.c` |

### 引用最多的几个（都是马厩）

`zaohongma`（枣红马）/`huangbiaoma`（黄骠马）/`ziliuma`（紫骝马）各 **29** 处，
分布在 `beijing:majiu`、`beijing:majuan`、`changan:majiu`、`chengdu:majiu` 等马厩。
单这一项就是 87 条引用 —— 光补这三个 NPC 就能让近 30 个马厩不再是空房。

### 白驼山的蛇（`baituo` 为主）

`dushe`(毒蛇) 17、`qingshe`(竹叶青蛇) 5、`yanjingshe`(眼镜蛇) 5、
`jinshe`(金环蛇) 4、`wubushe`(五步蛇) 2、`mangshe`(蟒蛇) 2、
`caihuashe`(菜花蛇) 1、`wangshe`(眼镜王蛇) 1、`fushe`(腹蛇) 1 ——
全部 `inherit SNAKE`。`baituo/cave` 的蟒蛇已在 §2④ 单独修过。

## 三、item：真物品，只是我们没生成定义（98 条 / 57 个 id）

这一类是**真的丢了东西**：LPC 有 `clone/quarry/` `clone/book/` `clone/weapon/` 等，
转换器写了 `room_items` 引用，但对应的 `items` 块从没生成。
后果是这些房间** loot 全空** —— 道德经、钢刀、长剑、野兔、尸体、鹅卵石、大树枝等等。

| id | 名字 | inherit | 引用数 | 房间（前 3 个） | LPC 源 |
|---|---|---|---|---|---|
| `tu` | 野兔 | QUARRY | 9 | `dali:road5`, `fuzhou:fzroad1`, `hengyang:xuanyadi` …+6 | `clone/quarry/tu.c` |
| `laohu` | 老虎 | QUARRY | 6 | `dali:gaolishan2`, `fuzhou:fzroad7`, `hangzhou:shanlu6` …+3 | `clone/quarry/laohu.c` |
| `gou2` | 狼狗 | QUARRY | 6 | `foshan:street4`, `foshan:street5`, `hangzhou:guozhuang` …+3 | `clone/quarry/gou2.c` |
| `yang2` | 山羊 | QUARRY | 5 | `dali:dalangan1`, `dali:gaolishan1`, `dali:gelucheng` …+2 | `clone/quarry/yang2.c` |
| `laozi1` | 道德经「第一章」 | BOOK | 4 | `wudang:cangjingge`, `wudang:cangjingge`, `wudang:cangjingge` …+1 | `clone/book/laozi1.c` |
| `gou` | 野狗 | QUARRY | 3 | `hengyang:hsroad7`, `huanghe:tiandi4`, `village:sexit` | `clone/quarry/gou.c` |
| `he2` | 雪鹤 | QUARRY | 3 | `lingxiao:huajing`, `lingxiao:meiroad2`, `lingxiao:qianyuan` | `clone/quarry/he2.c` |
| `ouyangke` | 欧阳克 | F_MASTER | 2 | `city:beidajie1`, `guiyun:jinship` | `kungfu/class/ouyang/ouyangke.c` |
| `sword` | 长剑 | SWORD | 2 | `global:dir_macro_test`, `test:dir_macro_test` | `d/beijing/npc/obj/sword.c` |
| `poison` | ? | SKILL | 2 | `global:duwushi`, `test:duwushi` | `kungfu/skill/poison.c` |
| `yijing0` | 「易经序卦篇」 | BOOK | 2 | `taohua:shufang`, `taohua:shufang` | `clone/book/yijing0.c` |
| `yijing1` | 「易经说卦篇」 | BOOK | 2 | `taohua:shufang`, `taohua:shufang` | `clone/book/yijing1.c` |
| `yijing2` | 「易经杂卦篇」 | BOOK | 2 | `taohua:shufang`, `taohua:shufang` | `clone/book/yijing2.c` |
| `yijing3` | 「易经系辞篇」 | BOOK | 2 | `taohua:shufang`, `taohua:shufang` | `clone/book/yijing3.c` |
| `laozi2` | 道德经「第二章」 | BOOK | 2 | `wudang:cangjingge`, `wudang:cangjingge` | `clone/book/laozi2.c` |
| `laozi8` | 道德经「第八章」 | BOOK | 2 | `wudang:cangjingge`, `wudang:cangjingge` | `clone/book/laozi8.c` |
| `laozi13` | 道德经「第十三章」 | BOOK | 2 | `wudang:cangjingge`, `wudang:cangjingge` | `clone/book/laozi13.c` |
| `laozi16` | 道德经「第十六章」 | BOOK | 2 | `wudang:cangjingge`, `wudang:cangjingge` | `clone/book/laozi16.c` |
| `laozi18` | 道德经「第十八章」 | BOOK | 2 | `wudang:cangjingge`, `wudang:cangjingge` | `clone/book/laozi18.c` |
| `shijing_book` | 诗经 | ITEM | 1 | `city:shuyuan2` | `u/mudren/obj/shijing_book.c` |
| `box` | 功德箱 | ITEM | 1 | `city:wumiao` | `d/city/npc/obj/box.c` |
| `xiong` | 灰熊 | QUARRY | 1 | `guanwai:heifengkou` | `clone/quarry/xiong.c` |
| `diao` | 紫貂 | QUARRY | 1 | `guanwai:luming` | `clone/quarry/diao.c` |
| `laohu2` | 东北虎 | QUARRY | 1 | `guanwai:milin2` | `clone/quarry/laohu2.c` |
| `niao` | 斑鸠 | QUARRY | 1 | `guiyun:tiandi` | `clone/quarry/niao.c` |
| `qianjiewugong` | 千节蜈蚣 | WORM | 1 | `huanghe:bingcao` | `clone/worm/qianjiewugong.c` |
| `shitou` | 大石头 | HAMMER | 1 | `huanghe:shixiazi` | `d/city/obj/shitou.c` |
| `zhengqi_book` | 正气吟 | BOOK | 1 | `huashan:shufang` | `clone/book/zhengqi_book.c` |
| `eyu` | 鳄鱼 | QUARRY | 1 | `jueqing:eyutan2` | `clone/quarry/eyu.c` |
| `fengmi` | 玉蜂蜜 | ITEM | 1 | `jueqing:house` | `d/gumu/obj/fengmi.c` |
| `qianjinzi` | 千金子 | ? | 1 | `kunlun:conglinggu` | `clone/herb/qianjinzi.c` |
| `renshen` | 人参 | ? | 1 | `kunlun:conglinggu` | `clone/herb/renshen.c` |
| `yang3` | 黄羊 | QUARRY | 1 | `lingzhou:huangyangtan` | `clone/quarry/yang3.c` |
| `dagger` | 普通匕首 | DAGGER | 1 | `luoyang:bingqiku` | `clone/weapon/dagger.c` |
| `qunxing_tu` | 群星璀璨图 | BOOK | 1 | `meizhuang:lingmu` | `clone/book/qunxing-tu.c` |
| `xuejie` | 血竭 | ? | 1 | `quanzhen:fu_mishi` | `clone/herb/xuejie.c` |
| `wuji1` | shaolin wuji | BOOK | 1 | `shaolin:cjlou1` | `clone/book/wuji1.c` |
| `wuji2` | shaolin wuji | BOOK | 1 | `shaolin:cjlou1` | `clone/book/wuji2.c` |
| `wuji3` | shaolin wuji | BOOK | 1 | `shaolin:cjlou1` | `clone/book/wuji3.c` |
| `wuji4` | shaolin wuji | BOOK | 1 | `shaolin:cjlou1` | `clone/book/wuji4.c` |
| `xisuijing` | 洗髓经 | BOOK | 1 | `shaolin:dmyuan2` | `clone/book/xisuijing.c` |
| `jitui` | 烤鸡腿 | HAMMER | 1 | `shenlong:chufang` | `clone/food/jitui.c` |
| `jiuzhang` | 「九章算术」 | BOOK | 1 | `taohua:shufang` | `clone/book/jiuzhang.c` |
| `niao3` | 乌鸦 | QUARRY | 1 | `wudang:wuyaling` | `clone/quarry/niao3.c` |
| `lang2` | 饿狼 | QUARRY | 1 | `wudu:langwo` | `clone/quarry/lang2.c` |
| `gou3` | 藏獒 | QUARRY | 1 | `wudu:nanyuan` | `clone/quarry/gou3.c` |
| `mitao` | 水蜜桃 | ITEM | 1 | `xiakedao:chashi` | `d/shenlong/obj/mitao.c` |
| `xiangcha` | 香茶 | ITEM | 1 | `xiakedao:chashi` | `d/kunlun/obj/xiangcha.c` |
| `duanjian` | 短剑 | SWORD | 1 | `xiakedao:wuqiku` | `clone/weapon/duanjian.c` |
| `blade` | 钢刀 | BLADE | 1 | `xiaoyao:bingqif` | `clone/weapon/blade.c` |
| `muding` | 木鼎 | ITEM | 1 | `xiyu:cangku` | `clone/misc/muding.c` |
| `xuelian1` | 天山雪莲 | __DIR__ | 1 | `xiyu:tianroad4` | `clone/fam/pill/xuelian1.c` |
| `xixuezhu` | 吸血蛛 | WORM | 1 | `xuedao:hollow` | `clone/worm/xixuezhu.c` |
| `book_iron` | 铁手掌 | HANDS | 1 | `yanziwu:huanshi` | `clone/book/book-iron.c` |
| `book_paper` | 易筋经文学篇 | BOOK | 1 | `yanziwu:huanshi` | `clone/book/book-paper.c` |
| `book_silk` | 薄绢 | BOOK | 1 | `yanziwu:huanshi` | `clone/book/book-silk.c` |
| `bian` | 羊鞭 | WHIP | 1 | `yanziwu:shijian` | `clone/weapon/bian.c` |

按 inherit 统计这一类的量级：

| inherit | id 数 |
|---|---|
| `BOOK` | 20 |
| `QUARRY` | 15 |
| `ITEM` | 6 |
| `?` | 3 |
| `SWORD` | 2 |
| `WORM` | 2 |
| `HAMMER` | 2 |
| `F_MASTER` | 1 |
| `SKILL` | 1 |
| `DAGGER` | 1 |
| `BLADE` | 1 |
| `__DIR__` | 1 |
| `HANDS` | 1 |
| `WHIP` | 1 |

## 四、ambiguous：同 id 既是人物又是物品（150 条 / 85 个 id）

这一类**不能自动判定**。LPC 里同一个文件名在 `d/*/npc/`（人物）和
`clone/quarry/`、`clone/weapon/`（物品）下各有一份，转换器合并成了同一个 id。
必须逐个看引用它的房间在 LPC 里 `set("objects")` 到底写的是哪个路径。

| id | 引用数 | 候选（人物） | 候选（物品） | 房间（前 3 个） |
|---|---|---|---|---|
| `lu` | 9 | 陆菲青 `d/hangzhou/honghua/lu.c`; 鲁开 `d/luoyang/npc/lu.c` | 梅花鹿 `clone/quarry/lu.c`; ? `kungfu/skill/bluesea-force/perform/lu.c` | `city:pomiao`, `guanwai:luming`, `guiyun:shufang` |
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
| `qin` | 1 | 秦绢 `d/hengshan/npc/qin.c`; 秦掌柜 `d/luoyang/npc/qin.c` | 琴谱 `clone/book/qin.c`; 檀木琴 `d/meizhuang/obj/qin.c` | `heimuya:pingdingzhou` |

### 判定结果：逐条去 LPC 房间的 `set("objects")` 比对

不能只看 id 猜。做法是：对每一条 ambiguous 引用，找到该房间的 LPC 文件
（`d/<zone>/<room>.c`），读它的 `set("objects", ([ ... ]))`，看里面写的是
人物的路径还是物品的路径。匹配时用**完整路径或「目录/基名」**，
只比基名会误命中（`lu` 会出现在无关文本里）。

83 条引用 / 31 个 id 的判定结果：

| 判定 | 引用 | id | 后续处理 |
|---|---|---|---|
| **物品** | 39 | 11 | 补 `items` 定义（多数是 QUARRY，见下） |
| **人物** | 2 | 2 | 改 `room_characters` |
| 仍判不出 | 42 | 28 | 需要人工看 LPC 原文 |

判为物品的 11 个 id 里，**10 个是 `clone/quarry/*`**（`hou` 猴子、`lang` 野狼、
`he` 丹顶鹤、`lu` 梅花鹿、`ying` 鹰、`fu` 蝙蝠、`song` 松鼠、`yang` 羊、
`zhu`/`zhu2`），只有 `zhujian` 是真武器 —— 已按 `clone/weapon/zhujian.c`
补进 8 个区（兵械库 / 炼房 / 演武厅等）。

## ⚠ 根本问题：同一个 id 在 LPC 里可能既是动物又是人

这是本轮最重要的发现，**数据模型表达不了**：

| id | 在这些房间是**物品** | 在这些房间是**人物** |
|---|---|---|
| `lu` | 梅花鹿（`clone/quarry/lu.c`）<br>`guanwai:luming` `gumu:shulin8` `lingjiu:huayuan` `city:pomiao` | 鹿杖翁（`kungfu/class/xuanming/lu.c`）<br>`xuanminggu:xuanminggu` |
| `he` | 丹顶鹤（`clone/quarry/he.c`）<br>`dali:shijing` `dali:yuhuayuan` `yanziwu:huizhen` | 鹤笔翁（`kungfu/class/xuanming/he.c`）<br>`xuanminggu:zulin2` |
| `hou` | 猴子（`clone/quarry/hou.c`） | 侯通海 / 侯人豪（`d/huanghe/npc/hou.c` 等） |
| `zhujian` | 竹剑（`clone/weapon/zhujian.c`） | 灵剑派弟子（`kungfu/class/lingjiu/zhujian.c`） |

LPC 里这些是**不同目录下**的两个文件，id 碰巧同名；
而我们的 UCL 是「每区一个命名空间」，转换器把 NPC 也写成了 `items.<id>`。
结果同一个区里可能既需要一个 `characters "lu"` 又需要一个 `items "lu"` ——
**这两者可以共存**（`characters` 和 `items` 是不同的表），
所以真正的修法是**按房间逐条判定**，而不是按 id 统一归类。

这也是「83 条里 42 条判不出」的原因：光看 id 无法决定，必须回到 LPC 原文。
本轮只处理了能机械判定的部分（`zhujian` 8 条 + 2 条 NPC），
剩下 42 条建议人工过一遍 `d/<zone>/<room>.c`。

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

## 五之二、`test` / `global` 已确认是转换器测试产物，已移出 `data/world`

上一节记的「值得单独确认」已经查清并处理完了。

### 它们是什么

`test.ucl`（34 房间 / 13 NPC / 42 物品）与 `global.ucl`（27 房间 / 12 NPC / 42 物品）
的每个文件头都写着 `Generated from test_minimal_world_v2_modified/…`
（分别 89 个和 203 个源文件）—— 当年挑 `.c` 文件跑 `lpc_converter.py` 做转换测试的产物。

### 它们没有被接入真实世界

| | `test` | `global` |
|---|---|---|
| 房间名与真实区重名 | **33 / 34** | **20 / 27** |
| `valid_leave` 条件 | 0 | 0 |
| 被任何真实区引用 | 0 | 0 |

- **重名**：`dating` / `yuanzi` / `liangong` / `cave` 在 `baituo`、`dali` 等真实区都存在。
- **不连通**：`rooms.<id>.id` 是区级解析，`test:cave` 的出口只能指向 `test:` 内的房间，
  而没有任何真实区引用 `test:` / `global:`，所以玩家根本走不到这 61 个房间。
- **不影响门禁**：两个区 `valid_leave` 条件都是 0，155/166 这个数字不受影响。

### 已做的处理

搬到 `test/fixtures/world/`，`Loader.load/1` 新增 `:extra_world_paths`，
**默认不再加载**；需要它们的测试显式调 `Loader.load_fixture_world/0`。

合并顺序是「夹具先、正式区后」，`Enum.into/2` 后写入的覆盖先写入的 ——
万一将来出现同名 zone key，**正式区赢**，符合「重复以正式区为准」。

### 影响（实测 `Loader.load()` vs `Loader.load_fixture_world()`）

| | 正式世界（现在） | 含夹具（以前） |
|---|---|---|
| zones | 77 | 79 |
| rooms | 4409 | 4470 |
| characters | 2277 | 2298 |
| items | 1119 | 1203 |
| 有物品的房间 | **163** | 202 |
| 悬空引用 | 1215 条 / 792 个 | 1235 条 / 809 个 |

两个副产物：

1. `veto_effectiveness_test.exs` 里「有物品的房间 `>= 190`」的阈值**只有靠夹具区
   那 39 间才够得着**，真实世界本来就只有 163 —— 阈值已下调到 160。
2. 悬空引用汇总的 `character 767 -> 751`、`item 468 -> 464`，
   少掉的都是夹具区自己的引用。

现在报告与审计脚本读到的数字**只反映真实世界**。

## 五之三、已补：`mafu` / `bing` / `guanbing`（−119 条悬空）

### 先把 LPC 原文找回来

转换器把 LPC 的 `set("objects")` 写成了裸 id，**跨区路径被丢掉了**。
拿 `# Generated from …` 注释把每个 `room_characters` 映射回 LPC 源文件、
再读原始 `set("objects")`，真相是：

```c
// d/lanzhou/ximen.c
set("objects", ([
    "/d/city/npc/bing"    : 4,      // <- 兰州城门用的是「开封」的官兵
    "/d/beijing/npc/ducha": 1,
    "/clone/npc/walker"   : 1,
]));

// d/zhongzhou/chenglou.c
    "/d/kaifeng/npc/guanbing" : 4,

// d/beijing/majiu.c
    "/clone/horse/zaohongma": 1, "/clone/horse/huangbiaoma": 1,
    "/clone/horse/ziliuma": 1,    "/clone/npc/mafu": 1,
    "/d/guanwai/npc/shenke" : 1,
```

所以 `bing` 那 76 条里 **96% 都指向同一个 `/d/city/npc/bing`**，
不是 10 个不同的士兵；`guanbing` 全部指向 `/d/kaifeng/npc/guanbing`。

### 因此没有「抄一个同名的了事」

6 个 `bing.c` 差异很大，逐个 diff 过 `create()`：

| 区 | create() sha | 说明 |
|---|---|---|
| `city` | `152c9bf4` | 官兵，22 岁 |
| `quanzhen` | `152c9bf4` | 与 city **逐字节相同** |
| `xiangyang` | `4ee70dc9` | 官兵，微调 |
| `xiyu` | `db109b14` | 官兵，微调 |
| `jingzhou` | `ba211461` | 官兵，少一个 alias |
| `dali` | `20c30ca2` | **完全另一个 NPC**：`set_name("士兵", …)`，大理国禁卫军 |

拿 `dali` 的去填别处就是错的。补的时候统一用
`LPCConverter.convert_file/2` 直接从 LPC 原文转，不从别的区抄。

### 补了什么

| NPC | LPC 源 | 区数 | 引用 |
|---|---|---|---|
| `mafu` | `/clone/npc/mafu` | 25 | 27 |
| `bing` | `/d/city/npc/bing` | 10 | 76 |
| `guanbing` | `/d/kaifeng/npc/guanbing` | 1（zhongzhou） | 16 |

外加 `bing`/`guanbing` 的 `carry` 依赖的 `items "blade"` / `items "junfu"`
也补进那 11 个区（LPC 里 `carry_object("/clone/weapon/blade")` 表示每个官兵
都带钢刀）。不补的话 NPC 会出现、刀却是悬空的。

`character` 悬空 **751 → 632（−119）**，`item` 仍是 464（那几个区原先整个 bing
被跳过，carry 引用压根没产生；补齐后人物与物品一起解析）。
门禁仍是 166 / 155 / 11。

### 顺带发现：`carry` 是死数据

`bing` 的 `carry = [{ id = items.blade.id }, …]` 转换出来了，但 **loader 根本不解析
`carry`**，`NonPlayerMeta` 也没有这个字段 —— 所以这些官兵运行时是**空着手**的，
刀和军服不会真的穿上。这是先前就有的缺口（对所有 NPC 都成立），不是本次引入的。
测试里钉了一条断言（`bing.inventory == []`）让这个缺口显形，等真实现了再改。

按「投入产出比 × 风险」排：

| 优先级 | 做什么 | 覆盖 | 风险 |
|---|---|---|---|
| ~~1~~ | ~~补 `zaohongma` / `huangbiaoma` / `ziliuma` 三个马厩 NPC~~ | ~~87 条~~ | **已完成** |
| ~~2~~ | ~~补 `baituo` 的 8 种蛇~~ | ~~约 36 条~~ | **已完成** |
| 1 | ~~补 `walker`（`/clone/npc/walker`，35 个区）~~ | ~~141 条~~ | **已完成**（§五之四） |
| ~~2~~ | ~~补 `ducha` / `liumang` / `wujiang` / `kid1`~~ | ~~84 条~~ | **已完成**（§五之五） |
| ~~3~~ | ~~补 `xunbu` / `xiaoer2` / `guest` / `duke`~~ | ~~56 条~~ | **已完成** |
| 1 | 剩下的平长尾：`xianren` / `dizi` / `chake` / `guanzhong` / `zaopeng` / `yayi` / `tangzi` / `qigai` 等 | 351 条（最大一项仅 6） | 中，要逐条回 LPC 原文核对是哪个 NPC |
| 4 | 补 `item` 类里引用最多的战利品（`gangdao` / `changjian` / `mudao` / `ganchai` / `corpse`） | 约 30 条引用 | 低（纯物品） |
| 5 | 逐个查 `ambiguous` 的 87 个 id 属于哪个候选 | 163 条引用 | 中，要看 LPC 原文 |
| ~~6~~ | ~~给 loader 加「引用解析不到」的 warning~~ | — | **已完成**（§〇 的加载末尾汇总） |

另有一条**独立于数据**的缺口：loader 不解析 `carry`，所有 NPC 的
`carry_object()` 装备都没生效（见 §五之三 末尾）。

另外：`clone/quarry/` 里那批（野兔/老虎/野狗/山羊/梅花鹿/猴子/雪鹤/丹顶鹤 …）
在 LPC 里是「猎物」，被玩家杀死后会变成肉/皮。移植它们等于把狩猎玩法带回来，
工作量比单纯生成 `items` 块大 —— 建议归到单独的「狩猎系统」轮次。

---

## 五之四、已补：`walker`（−141 条）+ 修掉 2 处转换器误命名

### 35 个区，139 条，全指向同一个 `/clone/npc/walker`

`character` 悬空 **632 → 491**，正好 −141。

### 名字：LPC 是运行时随机生成的

```c
// clone/npc/walker.c
void create()
{
    NPC_D->generate_cn_name(this_object());   // <- 名字运行时随机生成
    set("age", 53 + random(20));
    set("long", @LONG
这是一个拾荒者，看上去老实巴交的。……LONG);
```

转换器遇到 `generate_cn_name` 只能填占位符，产出了 `name = "NPC"`。
照抄的话 35 个区的拾荒者会全叫「NPC」。这里按 LPC 自己 `long` 里的说法
取名「拾荒者」。**这是本轮唯一没有 100% 照抄 LPC 的地方** —— LPC 的行为
（随机人名）静态数据表达不了。

`age = 53 + random(20)` 同理，转换器整个丢掉了 `age`，也没补：运行时随机年龄
静态表达不了，补一个固定值反而是编造。

### 顺带发现：2 处转换器把 NPC 认错了

补 walker 时逐房间核对 LPC 原文，发现这两个房间放的**根本不是 walker**，
但 UCL 里 id 被写成了 `characters.walker.id`：

| 房间 | LPC `set("objects")` | 实际是谁 |
|---|---|---|
| `dali:buxiongbu` | `npc/bshangfan` | 台夷商贩 |
| `foshan:street1` | `npc/jiading` | 家丁 |

不修的话，补了 walker 之后这两个房间会变成拾荒者。已按 LPC 原文补上
`characters "bshangfan"`（dali）/ `characters "jiading"`（foshan），
并把房间引用改回去。

`jiading` 另有 9 个区也有同名文件，转换器按文件名把 foshan 那份推成了
`foshan_jiading`，这里统一改回 `jiading`。

walker 本身仍要补 —— dali 另有 15 条、foshan 另有 1 条是真的 walker。

### 数字

- `character` 悬空 **751 → 632 → 491**（三轮累计 −260）
- `item` 悬空仍 **464**
- 运行时 NPC 实例 **2277 → 2537**
- 门禁仍 **166 / 155 / 11**
- 拾荒者实测 **139 个 / 35 个区**，`str 35 / int 15 / con 19 / dex 17`、
  `attitude = heroism` 与 LPC 一致

### 悬空测试的阈值改成上限

`veto_effectiveness_test.exs` 里原来写的是 `assert total_refs > 1000`
—— 那时总数 1235。补完 walker 变成 955，补完剩下 8 类变成 815，
这条断言就变成「必须还有 1000 个悬空」，**补得越多越容易红**。

改成上限（`<= 1000` → `<= 850`），数字变大才说明数据退化了。
断言列表也从「跨区共享 NPC」换成了剩下的平长尾 id，补一个划掉一个。

---

## 五之五、已补：剩下 8 类跨区 NPC（−140 条），头部变成平长尾

| NPC | LPC 源 | 区数 | 引用 |
|---|---|---|---|
| `ducha` | `/d/beijing/npc/ducha` | 7 | 23 |
| `wujiang` | `/d/city/npc/wujiang` | 9 | 20 |
| `kid1` | `/d/beijing/npc/kid1` | 8 | 19 |
| `xunbu` | `/clone/npc/xunbu` | 8 | 16 |
| `xiaoer2` | `/d/city/npc/xiaoer2` | 10 | 15 |
| `guest` | `/d/wudang/npc/guest` | 4 | 14 |
| `duke` | `/d/beijing/npc/duke` | 2 | 11 |
| `liumang` | **两个源**，见下 | 8 | 22 |

共 28 个区、56 个新块。

### `liumang` 有两个 LPC 实现，按区区分

```c
// d/city/npc/liumang.c      combat_exp 1000，无闲聊
// d/beijing/npc/liumang.c   combat_exp 10000，chat_chance 1 + 「流氓嘿嘿嘿奸笑几声」
```

所以 jingzhou 用 beijing 那份，其余 7 个区用 city 那份。

**zhonghou 是个例外**：它的两个房间分别指向两个不同的实现 ——
`wendingnan1` 放 beijing 版、`yanlingdong` 放 city 版，但两者的 UCL id 都是
`liumang`，一份定义只能服务一个。这里选了 beijing 版（更强、有闲聊）。
这是**有意的妥协**，不是遗漏。

### `xunbu` 的名字同样是占位符

和 `walker` 一样用 `NPC_D->generate_cn_name()`，转换器填了 `name = "NPC"`。
它 long 是「这是一个巡捕」、另有 `title = "六扇门内巡捕"`，故取名「巡捕」。

### 转换器把 id 按文件名推错了 4 个

`convert_file` 用路径推 id，带区名前缀的推错了，统一改回：

```
city_liumang -> liumang      bj_liumang -> liumang
city_xiaoer2 -> xiaoer2      wudang_guest -> guest
```

### 数字

- `character` 悬空 **751 → 632 → 491 → 351**（四轮累计 **−400**）
- `item` 悬空仍 **464**
- 门禁仍 **166 / 155 / 11**
- 12 类跨区共享 NPC 全部归零

补完后头部变成一条**平长尾**（最大只有 6 处）：
`xianren 6 / dizi 5 / chake 5 / guanzhong 5 / zaopeng 4 / yayi 4 / tangzi 4 /
qigai 4`。这些**不是**跨区共享 NPC，而是各自区的小角色（衙役、弟子、乞盖…），
只是恰好同名、且只在部分区有定义。

### 悬空测试的阈值

上限从 `<= 1000` 降到 `<= 850`，断言列表换成上面这批长尾 id。

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
