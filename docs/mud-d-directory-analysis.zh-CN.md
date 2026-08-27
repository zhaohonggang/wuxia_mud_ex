# LPC `d/` 目录完整分析报告

> 分析时间：2026-08-27
> 源路径：`C:\files\git\mud\d\`
> 目标：评估 LPC 世界数据迁移到 K Kalevala (.ucl) 的可行性与规模

---

## 一、总览

| 指标 | 数量 |
|---|---|
| 顶级目录（区域） | **72 个** |
| 子目录总计 | **253+ 个** |
| .c 文件总计 | **~7,029 个** |
| .h 头文件 | **18 个** |
| README 文档 | **1 个**（minimal_world/README.md） |
| 房间总数 | **~4,254 个** |
| NPC 总数 | **~1,718 个** |
| 物品总数 | **~754 个** |
| 门（create_door） | **55 个房间** |
| 传送机制 | **142 个房间** |
| 门派系统（CLASS_D） | **34 个门派** |
| 出生点（valid_startroom） | **65 个** |
| 安全区（no_fight） | **311 个** |
| 资源点（water/fish） | **72 个** |

> 注：minimal_world/README.md 提到整个 d/ + clone/ + kungfu/ 有 **10,760 个文件**，
> 本报告仅覆盖 d/ 目录的 7,029 个文件。

---

## 二、目录结构约定

每个区域遵循统一结构：

```
d/<zone_name>/
    <room1>.c          # 房间定义（平铺在区域根目录）
    <room2>.c
    ...
    npc/               # NPC 定义（可选）
        <npc1>.c
        <npc2>.c
    obj/               # 物品定义（可选）
        <item1>.c
        <item2>.c
```

- 房间文件继承 `ROOM`，放在区域根目录
- NPC 文件继承 `NPC`，放在 `npc/` 子目录
- 物品文件放在 `obj/` 子目录
- 路径引用规则：`__DIR__` 用于区域内相对引用，绝对路径 `/d/zone/path` 用于跨区域引用

---

## 三、区域清单（72 个）

### A. 大型城市（17 个）

| 区域 | 路径 | 房间 | NPC | 物品 | 子目录 | 特殊功能 |
|---|---|---|---|---|---|---|
| **beijing** | `d\beijing\` | 202 | 209 | 23 | npc, obj | 最大区域。皇宫、 guild（丐帮/镇远/云龙）、matong 传送 NPC |
| **dali** | `d\dali\` | 213 | 101 | 17 | npc, obj | 大理国。CLASS_D "duan"（段家） |
| **shaolin** | `d\shaolin\` | 206 | 27 | 58 | npc, obj | 少林寺。八卦阵迷宫、五行阵、武器库 |
| **changan** | `d\changan\` | 143 | 127 | 0 | npc | 长安。监狱传送至地狱 |
| **luoyang** | `d\luoyang\` | 157 | 46 | 0 | npc | 洛阳。交通枢纽，~30 条跨区域出口 |
| **kaifeng** | `d\kaifeng\` | 132 | 68 | 2 | npc, obj | 开封。红花会 guild（hh_ 前缀房间） |
| **hangzhou** | `d\hangzhou\` | 120 | 45 | 3 | honghua, npc, obj | 杭州 + 红花会子区域（21 房间） |
| **xiangyang** | `d\xiangyang\` | 119 | 34 | 2 | npc, obj | 襄阳。武馆连接 |
| **quanzhen** | `d\quanzhen\` | 109 | 52 | 3 | npc, obj | 全真教。完整道观布局，门机制 |
| **hengyang** | `d\hengyang\` | 107 | 31 | 6 | npc, obj, yueqi | 衡阳。乐器子区域（19 件琴/筝） |
| **chengdu** | `d\chengdu\` | 75 | 25 | 2 | npc, obj | 成都。蜀道连接峨眉/青城/北京 |
| **suzhou** | `d\suzhou\` | 72 | 24 | 1 | npc, obj | 苏州。CLASS_D "murong"（慕容家） |
| **fuzhou** | `d\fuzhou\` | 61 | 25 | 9 | npc, obj | 福州 |
| **lanzhou** | `d\lanzhou\` | 38 | 23 | 9 | npc, obj | 兰州。丝绸之路枢纽 |
| **kunming** | `d\kunming\` | 54 | 19 | 2 | npc, obj | 昆明。大理/峨眉门户 |
| **foshan** | `d\foshan\` | 32 | 14 | 5 | npc, obj | 佛山 |
| **quanzhou** | `d\quanzhou\` | 36 | 16 | 8 | npc, obj | 泉州。港口城市 |

### B. 门派区域（18 个）

| 区域 | 路径 | 房间 | NPC | 特点 |
|---|---|---|---|---|
| **wudang** | `d\wudang\` | 102 | 10 | 武当。漂浮机制（需梯云纵 120+） |
| **huashan** | `d\huashan\` | 91 | 15 | 华山。守卫 NPC 控制入口 |
| **emei** | `d\emei\` | 102 | 8 | 峨眉。多个寺院群（bgs/fss/hca/qfa/wna 前缀） |
| **mingjiao** | `d\mingjiao\` | 129 | 27 | 明教。地下迷宫（didao）、密道（midao0-12） |
| **gaibang** | `d\gaibang\` | 5 | 13 | 丐帮。goto 传送枢纽（16 城市） |
| **kunlun** | `d\kunlun\` | 51 | 6 | 昆仑。山门+府邸 |
| **tiezhang** | `d\tiezhang\` | 66 | 13 | 铁掌帮。门+密室 |
| **wudu** | `d\wudu\` | 108 | 28 | 五毒教。大量毒药物品 |
| **taohua** | `d\taohua\` | 31 | 7 | 桃花岛。CLASS_D "taohua" |
| **guiyun** | `d\guiyun\` | 25 | 34 | 归云庄。高 NPC 密度 |
| **lingjiu** | `d\lingjiu\` | 46 | 7 | 灵鹫宫 |
| **lingxiao** | `d\lingxiao\` | 78 | 16 | 凌霄城 |
| **heimuya** | `d\heimuya\` | 81 | 28 | 黑木崖。日月神教 |
| **baituo** | `d\baituo\` | 49 | 25 | 白驼山。欧阳家族 |
| **xiaoyao** | `d\xiaoyao\` | 22 | 4 | 逍遥谷 |
| **jueqing** | `d\jueqing\` | 57 | 7 | 绝情谷。大量传送器 |
| **xiakedao** | `d\xiakedao\` | 99 | 25 | 侠客岛。石室（24+ 间）参悟系统 |
| **songshan** | `d\songshan\` | 28 | 16 | 嵩山。连接少林/开封 |

### C. 地理/野外区域（20+ 个）

| 区域 | 路径 | 房间 | NPC | 特点 |
|---|---|---|---|---|
| **taishan** | `d\taishan\` | 33 | 21 | 泰山 |
| **hengshan** | `d\hengshan\` | 26 | 11 | 恒山 |
| **guanwai** | `d\guanwai\` | 67 | 25 | 塞外。寒冷天气伤害系统 |
| **gumu** | `d\gumu\` | 74 | 2 | 古墓。密室（mishi1-8） |
| **huanghe** | `d\huanghe\` | 56 | 26 | 黄河。沙漠传送 |
| **xiyu** | `d\xiyu\` | 61 | 17 | 西域。丝绸之路 |
| **xueshan** | `d\xueshan\` | 39 | 7 | 雪山 |
| **shenfeng** | `d\shenfeng\` | 51 | 13 | 神峰。狼群伏击 |
| **shenlong** | `d\shenlong\` | 21 | 13 | 神龙岛 |
| **village** | `d\village\` | 30 | 21 | 通用村庄。十字路口枢纽 |
| **wuguan** | `d\wuguan\` | 39 | 15 | 郭府（襄阳防务总部） |
| **yanziwu** | `d\yanziwu\` | 46 | 17 | 燕子坞。慕容家 |
| **jingzhou** | `d\jingzhou\` | 92 | 30 | 荆州 |
| **zhongzhou** | `d\zhongzhou\` | 90 | 27 | 中州。苗家庄 |
| **gaochang** | `d\gaochang\` | 31 | 5 | 高昌古国 |
| **wanjiegu** | `d\wanjiegu\` | 29 | 40 | 万劫谷。高 NPC 密度 |
| **xuedao** | `d\xuedao\` | 24 | 4 | 雪道 |
| **meizhuang** | `d\meizhuang\` | 37 | 9 | 梅庄。密室 |
| **tianlongsi** | `d\tianlongsi\` | 28 | 4 | 天龙寺 |
| **qingcheng** | `d\qingcheng\` | 23 | 10 | 青城山 |

### D. 特殊/系统区域（9 个）

| 区域 | 路径 | 房间 | NPC | 物品 | 用途 |
|---|---|---|---|---|---|
| **death** | `d\death\` | 56 | 29 | 95 | 地狱/轮回系统。HellZhen（18 房间鬼阵）、liudaolunhui（六道轮回）、sky（天界子区域） |
| **sky** | `d\sky\` | 6 | 17 | 9 | 天界。5 天界房 + 天门 |
| **register** | `d\register\` | 7 | 7 | 0 | 新手注册/角色创建（世外桃源）+ 监狱 |
| **pk** | `d\pk\` | 14 | 1 | 0 | PvP 竞技场（屠人场）。12 个擂台 |
| **wizard** | `d\wizard\` | 9 | 0 | 0 | 管理员区域 |
| **room** | `d\room\` | 2 | 1 | 5 | 玩家房屋模板（盘龙/彩虹/独乐）+ 房屋 NPC 模板 |
| **item** | `d\item\` | 6 | 1 | 7 | 锻造材料区域（干将/莫邪） |
| **special** | `d\special\` | 0 | 0 | 0 | 六道轮回展示房间 |
| **minimal_world** | `d\minimal_world\` | 10 | 6 | 7 | **参考实现**。LPC→ExVenture 迁移测试区 |

### E. 故事/任务区域（2 个）

| 区域 | 路径 | 子区域 | 说明 |
|---|---|---|---|
| **tulong** | `d\tulong\` | tulong/, yitian/, yubifeng/ | 屠龙刀 saga：3 条故事线 |
| **sky** | `d\sky\` | npc/, obj/ | 天界（见 D 节） |

---

## 四、跨区域连接图

### 主要枢纽

```
gaibang（丐帮 undertre）──→ 16 城市传送：
    fuzhou, xiangyang, suzhou, hangzhou, chengdu,
    jingzhou, nanyang, foshan, dali, hengyang,
    changan, beijing, kaifeng, zhongzhou, luoyang, lanzhou

city/guangchang（扬州广场）──→ beijing, taishan, minimal_world
beijing（北京）──→ shaolin, huashan, hengshan, guanwai, xueshan, heimuya, shenlong
chengdu（成都）──→ emei, qingcheng, beijing（蜀道）, jingzhou, xuedao
luoyang（洛阳）──→ beijing(~30), kaifeng(~15), changan, xiangyang, wudu, zhongzhou
changan（长安）──→ lanzhou, luoyang, quanzhen, huanghe, pk
```

### 连接度排名（跨区域出口数）

| 排名 | 区域 | 跨区域出口数 |
|---|---|---|
| 1 | gaibang/undertre | 16（goto 传送） |
| 2 | city/guangchang | ~10 |
| 3 | beijing | ~15 |
| 4 | luoyang | ~20 |
| 5 | chengdu | ~12 |

---

## 五、特殊机制统计

### 门系统（55 个房间）

| 区域 | 门数量 | 说明 |
|---|---|---|
| mingjiao | 13 | 密道（midao）、密室（mishi） |
| lingzhou | 6 | 城门（边关/宫/将军/一品） |
| shaolin | 5 | 暗道、竹林、兵器库 |
| kunlun | 4 | 山门、卧室 |
| quanzhen | 3 | 大门、大堂、密室 |
| quanzhou | 3 | 竹林、青龙、竹林 |
| minimal_world | 1 | 文庙山门（DOOR_CLOSED） |

### 传送机制（142 个房间）

| 类型 | 区域 | 数量 | 说明 |
|---|---|---|---|
| 丐帮 goto | gaibang | 16 | 16 城市快速传送 |
| 地狱传送 | death | ~10 | 死亡后单向传送 |
| 天界传送 | sky | 5 | sky1-sky5 顺序传送 |
| 沙暴迷失 | huanghe, xiyu | ~15 | 沙漠中随机位移 |
| 迷宫传送 | shaolin | ~20 | 八卦阵、五行阵 |
| 密道传送 | mingjiao | ~15 | 地下迷宫导航 |
| 悬崖跳跃 | hengyang, huashan, jueqing | ~10 | 悬崖区域 |
| 地狱鬼阵 | death/HellZhen | 18 | 18 房间迷宫 |

### 门派系统（34 个 CLASS_D）

| CLASS_D ID | 使用区域 | 说明 |
|---|---|---|
| shaolin | shaolin, city, lanzhou, luoyang | 少林 |
| wudang | wudang | 武当 |
| huashan | huashan | 华山 |
| quanzhen | quanzhen, gumu | 全真 |
| gaibang | gaibang, beijing, city | 丐帮 |
| duan | dali, wanjiegu | 段家 |
| taohua | taohua, guiyun, huanghe, wuguan, xiangyang | 桃花岛 |
| ouyang | baituo, city | 欧阳 |
| riyue | heimuya, quanzhou | 日月神教 |
| mingjiao | mingjiao | 明教 |
| xingxiu | xiyu | 星宿 |
| murong | yanziwu, guanwai | 慕容 |
| tangmen | chengdu | 唐门 |
| lingxiao | lingxiao, kaifeng, zhongzhou | 凌霄城 |
| honghua | kaifeng | 红花会 |
| emei | emei | 峨眉 |
| kunlun | kunlun | 昆仑 |
| tiezhang | tiezhang | 铁掌 |
| wudu | wudu | 五毒 |
| shenlong | shenlong, city | 神龙 |
| xiakedao | xiakedao, city | 侠客岛 |
| 其他 14 个 | 各区域 | henshan, songshan, meizhuang, xuedao, xueshan, tianlongsi, jueqing, xiaoyao, gumu, zhenyuan, yunlong, misc, ultra, none |

---

## 六、LPC 文件格式摘要

### 房间（inherit ROOM）

```lpc
inherit ROOM;
void create() {
    set("short", "房间名");
    set("long", @LONG 描述文本 LONG);
    set("exits", ([ "north" : __DIR__"other_room" ]));
    set("objects", ([ __DIR__"npc/name" : 1 ]));
    set("no_fight", 1);           // 可选：安全区
    set("valid_startroom", 1);    // 可选：出生点
    set("outdoors", "zone");      // 可选：室外
    setup();
    replace_program(ROOM);        // 可选：纯数据标记
}
```

### NPC（inherit NPC/KNOWER/F_DEALER/F_MASTER）

```lpc
inherit NPC;
void create() {
    set_name("显示名", ({ "pinyin_id", "别名" }));
    set("long", "描述文本");
    set("gender", "male");
    set("age", 40);
    set("str", 25); set("int", 20); set("con", 25); set("dex", 20);
    set("max_qi", 500); set("max_jing", 300);
    set("neili", 200); set("max_neili", 200);
    set("combat_exp", 50000);
    set_skill("force", 80); map_skill("force", "liuxi-neigong");
    set("attitude", "friendly");
    set("chat_msg", ({ "闲聊文本" }));
    set("inquiry", ([ "关键词" : "回复文本" ]));
    carry_object("/d/zone/obj/weapon")->wield();
}
```

### 物品（inherit SWORD/CLOTH/ITEM/F_FOOD/BOOK）

```lpc
inherit SWORD;
void create() {
    set_name("显示名", ({ "pinyin_id" }));
    set_weight(500);
    set("unit", "把");
    set("long", "描述文本");
    set("value", 300);
    set("material", "steel");
    init_sword(22);                    // 武器伤害
    // 或 set("armor_prop/armor", 5);  // 护甲值
    // 或 set("skill", ([ "name" : "liuxin-jian", ... ]));  // 书籍
    setup();
}
```

### 技能（inherit SKILL/FORCE）

```lpc
inherit SKILL;
mapping *action = ({
    ([ "action" : "$N 攻击 $n...", "damage" : 8, "lvl" : 0, ... ]),
    // ... 多级动作表
});
int valid_enable(string usage);           // "sword"/"parry"
string query_skill_name(int level);       // 当前等级招式名
```

---

## 七、K Kalevala 现有世界对比

### K 端当前世界

| 区域 | .ucl 文件 | 房间 | NPC | 物品 |
|---|---|---|---|---|
| global | global.ucl | 0 | 0 | 3（共享物品） |
| liuxi | liuxi.ucl | 4 | 4 | 2 |
| sammatti | sammatti.ucl | 12 | 6 | 0 |
| kissa-jarvi | kissa-jarvi.ucl | 8 | 0 | 0 |
| lepakko-luola | lepakko-luola.ucl | 2 | 0 | 0 |
| **合计** | **5 文件** | **26** | **10** | **5** |

### 与 LPC d/ 对比

| 指标 | LPC d/ | K Kalevala | 覆盖率 |
|---|---|---|---|
| 区域 | 72 | 5 | 7% |
| 房间 | 4,254 | 26 | 0.6% |
| NPC | 1,718 | 10 | 0.6% |
| 物品 | 754 | 5 | 0.7% |

> K 端当前世界仅为 LPC 世界的 **~0.6%**。

---

## 八、可翻译性分析

### 绿灯：可直接翻译（纯数据）

| 内容类型 | LPC 文件数 | K 端 UCL 支持 | 翻译方式 |
|---|---|---|---|
| 纯数据房间（replace_program） | ~2,500 | ✅ rooms + room_exits | set("short"/"long"/"exits") → UCL name/description/north/south... |
| NPC 基础属性 | ~1,000 | ✅ characters combat{} | set("str"/"max_qi"/...) → UCL combat = { str = ... } |
| 物品基础属性 | ~400 | ✅ items meta{} | set("damage"/"armor"/"value") → UCL meta = { damage = ... } |
| NPC 商人 goods | ~50 | ✅ characters goods[] | vendor_goods → UCL goods = [{ id = ... }] |
| NPC 问询 dialogue | ~200 | ✅ characters inquiries{} | set("inquiry") → UCL inquiries = { keyword = "..." } |
| 房间特征 item_desc | ~100 | ✅ rooms features[] | set("item_desc") → UCL features = [{ keyword, short, long }] |

### 黄灯：部分可翻译（需小改动）

| 内容类型 | LPC 文件数 | K 端状态 | 翻译方式 |
|---|---|---|---|
| NPC 闲聊 chat_msg | ~300 | ✅ chats[] 字段已有 | set("chat_msg") → UCL chats = ["...", "..."] |
| NPC 门派 teach | ~50 | ✅ teach{} 字段已有 | create_family/teach_skills → UCL teach = { family, teach_skills } |
| 任务 turn_in | ~30 | ✅ turn_in{} 字段已有 | QUEST_OB → UCL turn_in = { item, rewards } |
| NPC 战斗 AI chat_msg_combat | ~200 | ⚠️ 需 brain 文件 | LPC 闭包 → UCL brains 行为树 |
| 门 create_door | 55 | ⚠️ 需引擎支持 | LPC create_door() → 需评估 K 端门机制 |
| 房间传送逻辑 | ~100 | ⚠️ 需引擎支持 | LPC valid_leave + move() → 需 Elixir 模块 |

### 红灯：不可翻译（需 Elixir 重写）

| 内容类型 | LPC 文件数 | K 端状态 | 说明 |
|---|---|---|---|
| 技能系统（kungfu/） | ~3,000+ | 已硬编码在 Elixir | action table + perform + exert → lib/kantele/combat/skills/*.ex |
| 门派系统（CLASS_D） | 34 个 | 无 | 需要完整的门派框架 |
| NPC 行为闭包 | ~500 | 无 | LPC 闭包 `(: func :)` → 需 Elixir 模块 |
| add_action 自定义命令 | ~200 | 无 | LPC add_action → 需 Elixir 命令模块 |
| 毒药/condition 系统 | ~20 | 无 | inherit POISON → 需新系统 |
| 特殊天赋系统 | ~10 | 无 | inherit F_CLEAN_UP → 需新系统 |
| 迷宫算法 | ~5 | 无 | shaolin 八卦阵/五行阵 → 需引擎支持 |
| 玩家房屋系统 | ~30 | 无 | PRIVATE_ROOM + 房屋 NPC → 需新系统 |
| 冷寒天气伤害 | ~5 | 无 | guanwai gwxuedi.h → 需天气系统 |
| PvP 竞技场 | ~14 | 无 | pk 系统 → 需新系统 |

---

## 九、翻译工作量估算

### 纯数据翻译（绿灯部分）

| 内容 | 文件数 | 预估工时 |
|---|---|---|
| 2,500 房间 | ~2,500 | 高（但可脚本化） |
| 1,000 NPC 基础属性 | ~1,000 | 中（模板化） |
| 400 物品 | ~400 | 低（结构简单） |
| 200 NPC 问询 | ~200 | 低（字符串映射） |
| 50 商人 goods | ~50 | 低（引用映射） |
| **小计** | **~4,150** | **大规模但可自动化** |

### 需要 Elixir 配合（黄灯部分）

| 内容 | 需新增 Elixir 代码 | 预估工时 |
|---|---|---|
| NPC brain 行为树 | ~50 个 brain .ucl 文件 | 中 |
| 门机制 | 引擎扩展 | 中 |
| 传送逻辑 | Elixir 模块 | 中 |
| 任务 turn_in | 已有，需测试 | 低 |

### 需要重写（红灯部分）

| 内容 | 需新增 Elixir 代码 | 预估工时 |
|---|---|---|
| 34 个门派系统 | 框架级开发 | 极高 |
| 技能系统 | 已有，但需扩展 | 高 |
| NPC 行为闭包 | ~500 个 Elixir 模块 | 极高 |
| add_action 命令 | ~200 个命令模块 | 极高 |
| 毒药/天赋/天气 | 新系统开发 | 高 |
| 迷宫/竞技场/房屋 | 新系统开发 | 高 |

---

## 十、结论与建议

### 核心发现

1. **d/ 是一个完整的 MUD 世界**：72 个区域、7000+ 文件、4000+ 房间，形成一个互联的游戏世界图。

2. **minimal_world 只是 1/72**：它是专门为迁移设计的参考实现，不代表完整世界的复杂度。

3. **不能"翻译"，只能"重建"**：纯数据部分（~60% 的文件）可以 1:1 翻译成 UCL，但行为逻辑部分（~40%）需要 Elixir 重写。

4. **K 端当前覆盖 ~0.6%**：26 个房间 vs 4,254 个房间，差距巨大。

5. **门派系统是最大障碍**：34 个 CLASS_D 门派、每个门派有自己的技能树/收徒逻辑/特殊机制，这是架构级工作。

### 建议路径

**Phase 1：数据翻译（可行，工作量大）**
- 翻译 minimal_world 中尚未覆盖的 6 个房间 + tiesheng 商人 + liuxinpu 秘籍
- 建立 LPC→UCL 的自动化转换脚本
- 目标：验证翻译流程，覆盖 minimal_world 100%

**Phase 2：区域原型（中等难度）**
- 选择 1 个中等复杂度的完整区域（如 village 或 taishan）
- 翻译其所有房间、NPC、物品
- 目标：验证单个区域的完整游戏体验

**Phase 3：系统扩展（高难度）**
- 实现 NPC brain 行为树（替代 LPC 闭包）
- 实现门机制/传送引擎
- 实现基础门派框架（先支持 1-2 个门派）

**Phase 4：规模化（取决于 Phase 3）**
- 批量翻译剩余区域
- 扩展门派系统
- 实现迷宫/竞技场/房屋等系统

---

*本文档基于 `C:\files\git\mud\d\` 目录的静态分析，不含 clone/ 和 kungfu/ 目录（据 README 称另有 ~3,700 个文件）。*
