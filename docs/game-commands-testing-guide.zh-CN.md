# 游戏命令测试指南（新手 admin 版）

> 面向第一次进游戏做验收的管理员。按本文场景从上到下走一遍，
> 即可覆盖当前版本全部玩家可见命令与主要系统链路。
> 编写时间：2026-08-25 ｜ **更新：2026-09-11**（补 Q1–Q6 / M/S/K/W 批次命令与系统链路）。
> 命令实现以 `lib/kantele/character/commands.ex`（200 个命令模块、注册动词 190+，含中英文别名）
> 与 `commands/` 目录为准；本文与代码不符时以代码为准。
> 测试基线：**2334 tests / 0 failures**（seed 731933 / 788424）。

---

## 一、准备与进入游戏

1. 确认容器在跑：宿主机执行 `docker ps`，应看到
   `wuxia_mud_dev-app-1` 与 `wuxia_mud_dev-db-1`。
2. 浏览器打开 `http://localhost:4000/_health`，应返回
   `{"status":"OK","world":"ok",...}`。
3. 进入游戏二选一：
   - **Web**：登录网站（admin@example.com / password）→ 打开
     `http://localhost:4000/client/play`；
   - **Telnet**：`telnet localhost 4646`。
4. 游戏内登录三步（密码**不校验**，随便输）：

   ```text
   用户名：grant        ← 任意非空字符串（输入 quit 则断开）
   密  码：123          ← 任意
   角色名：阿福          ← 新名字即新建角色；老名字会读回存档
   ```

5. 登录成功会看到房间描述与 `[气血150/150 ...] >` 提示符。
   输入 `look` 可随时重看当前房间。

> 提示：想每次都拿全新号测流程，就换个没用过的角色名；
> 想验证存档恢复（等级/铜钱/背包），就复用老角色名重新登录。

---

## 二、地图速览与行走

### 世界总览（6 个 zone）

```
[萨玛蒂镇 sammatti]        出生点=城镇广场（13 房间，新手教学区）
   ↓ south 基萨湖             [基萨湖 kissa-jarvi] ──south── [蝙蝠洞 lepakko-luola]
[柳溪镇 liuxi]             武侠主线区（8 房间 + 任务链路）
   ↑ north 隐世之境           [隐世之境 signature]（5 房间特色 NPC）
```

跨区连接（关键路线）：
- **柳溪 ↔ 萨玛蒂**：`liuxi:shanlu.south` ⇄ `sammatti:blacksmith.north`
- **柳溪 ↔ 隐世之境**：`liuxi:guangchang.north` ⇄ `signature:yinyi.north`（双向）
- **萨玛蒂 ↔ 基萨湖**：`sammatti:town_square.south` ⇄ `kissa-jarvi:gates`（出生点向南）
- **基萨湖 ↔ 蝙蝠洞**：`kissa-jarvi:lake-4.south` ⇄ `lepakko-luola:cave-outside`

### 柳溪镇地图（武侠主线）

```
   [子虚观 zixu_guan]（庙祝，no_fight）          ← 仅子虚道人驻守，无步行路
        （代码传送）
   [练武场 lianwuchang]  ──north──  [郭府 guofu]（郭府管家）
   （王重九/张青崖，no_fight）             │
                 │ south        │
        west    │              │
   [镇广场 guangchang] ──east── [张记铁铺 tiepupu] ──east── [钱庄 qianzhuang]
    （野猪/阿婆/周不通/包子嫂）           （店小二/王铁匠）      （钱掌柜）
        │ south
   [山路 shanlu]（黑虎，主动攻击）→ south 萨玛蒂铁匠铺
```

### 行走命令

| 方向 | 命令 | 单字母 | 中文 |
|---|---|---|---|
| 北 | north | n | 北 |
| 南 | south | s | 南 |
| 东 | east | e | 东 |
| 西 | west | w | 西 |
| 上 | up | u | 上 |
| 下 | down | d | 下 |

常用路线（每条都是连续输入的方向序列）：

| 目的地 | 路线 |
|---|---|
| 张记铁铺（商店/问询） | `w` `n` `n` `e` |
| 练武场（拜师学艺） | `w` `n` `n` `e` `w` `w` |
| 柳溪镇广场（野猪/阿婆/任务） | `w` `n` `n` |
| 山路（黑虎，危险） | 柳溪镇广场 `s` |
| 隐世之境（特色 NPC） | 柳溪镇广场 `n` |
| 郭府（新手链第 4 步） | 练武场 `n` |
| 钱庄（新手链第 2 步） | 张记铁铺 `e` |

---

## 三、命令总表（按类别）

> **英文动词 100+ 条、含中英别名共 190+ 注册**；下表只列玩家高频命令，
> 完整清单以游戏内 `commands` 输出为准。⚠️ 标注的为占位命令。

### 信息与帮助
| 命令 | 说明 |
|---|---|
| `look` `watch` `l` / `看` | 查看当前房间（人物/物品/出口/小地图） |
| `score` / `score2` | 自我状态总览（气血/四维/经验/潜能/铜钱/阅历威望贡献） |
| `info` | 武学与属性明细（含技能等级与映射特技） |
| `map` | 当前区域小地图 |
| `who` `finger` / `查找` | 在线玩家列表 / 按名查询玩家 |
| `who1` `who2` `who3` | 玩家列表变体（wiz） |
| `whoami` `whoride` | 本尊信息 / 在线骑乘统计（wiz） |
| `version` / `uptime` / `mudinfo` | 版本号 / 运行时间 / 系统资讯 |
| `system` | 系统信息 |
| `help` / `帮助` | 帮助索引；`help <主题>` 查看单篇 |
| `commands` / `命令` | 列出全部玩家可见命令及一句说明 |
| `channels` | 列出可用频道 |
| `time` / `bjtime` | 游戏时间（含中文农历/季节岁月） |
| `world_status` | 最近一次世界加载结果（排障用） |

### 移动与探索
| 命令 | 说明 |
|---|---|
| 方向命令 | 见第二节表格 |
| `rideto` | 骑乘传送（64 预设地点，需骑马+非战斗+非负重） |
| `recall` / `回城` | 回出生点 |
| `map` | 区域小地图 |
| `search` | 搜索房间隐藏物件 |
| `watch` | 观察房间详情变体 |
| `emotes` / `semote` | 预置表情列表 |
| `smile` / `wave` / `frown` / `beep` / `femote` | 直接以表情名做出动作 / 表情搜索 |

### 物品与背包
| 命令 | 中文 | 说明 |
|---|---|---|
| `get <物品>` | `拿`/`捡` | 拾取房间地上物品 |
| `drop <物品>` | — | 丢弃 |
| `put <物品> in <容器>` | — | 放入容器 |
| `inventory`（简写 `i`/`inv`) | `背包` | 查看背包 |
| `wield <武器>` / `unwield` | — | 装备/卸下武器 |
| `wear <护甲>` / `remove` | `穿`/`脱` | 装备/卸下护甲 |
| `store` / `take` | — | 背部行囊存取 |
| `eat <食物/丹药>` | `吃` | 进食/服药 |
| `drink`（`heal`/`喝药`/`喝`） | — | 喝药水（回气血/内力） |
| `fill` / `灌水` | — | 容器灌水 |
| `feed` / `喂养` | — | 喂养 NPC |

### 社交与关系
| 命令 | 说明 |
|---|---|
| `say <话>` | 房间说话（支持 `@某人` 点名、`>副词` 修饰） |
| `general <话>` | general 频道喊话，全服在线可见 |
| `tell <人> <话>` / `reply` / `whisper` | 私聊 / 回复 / 房间耳语 |
| `emote <文本>` | 第三人称动作 |
| `tune` | 频道订阅/退订控制 |
| `follow` / `跟随` | 跟随目标 |
| `ask <人> <关键词>` / `问` | 向 NPC 问询（问答表/脚本化问询/任务交付） |
| `apprentice` / `拜师` · `detach` / `叛师` | 拜师 / 叛师 |
| `swear` / `right` / `refuse` | 结拜请求 / 应允 / 拒绝 |
| `engage` / `accede` / `divorce` | 求婚 / 应婚 / 离婚 |
| `team` / `组队` · `league` / `帮派` · `brothers` / `兄弟` | 组队 / 帮派 / 结义 |
| `recruit` / `persuade` / `assist` / `guard` | 招募 / 说服 / 协战 / 护卫 |
| `ride` / `unride` | 上马 / 下马 |

### 战斗
| 命令 | 中文 | 说明 |
|---|---|---|
| `kill` / `hit` / `fight` | `杀掉`/`杀` | 开战（目标须在同房间且存活） |
| `halt` · `flee` / `逃跑` · `surrender` / `投降` | — | 停手 / 逃跑 / 投降 |
| `wimpy` / `自动逃跑` | — | 设置自动逃跑血量阈值 |
| `perform 武功.招式` | — | 绝招（有技能门槛） |
| `jiali <0-N>` / `enforce` | — | 加力档位（耗内力换伤害；上限=内功等级÷2） |
| `touxi` / `偷袭` | — | 先手偷袭 |
| `steal` | — | 偷窃 |
| `accept` | — | 接受剧情挑战者摆擂应战 |
| `berserk`/`baofa` · `pique`/`jianu` · `burning`/`fenu` | — | 狂暴 / 激怒 / 狂怒（战斗心态） |
| `crattack` · `spattack` | — | 反击 / 特殊攻击 |
| `guard` | — | 招架护卫 |
| `special` `stab` `push` `hand` `train` `stop` `stay` `come` `release` | — | ⚠️ 占位（特技/插/推人/手持/驯兽/放生未开放） |

### 商店与经济
| 命令 | 说明 |
|---|---|
| `list [商人]` | 列出货单 |
| `buy <物品>` / `买` | 从商人购买（支持批量 `buy 包子 x5`） |
| `sell` / `卖` / `value` / `估价` | 向收购商变卖 / 估价 |
| `purchase` | 商店系统采购（走 shop/buy 事件） |
| `shop` | 我的货摊/商店列表 |
| `bank` / `银行` | 钱庄存取 / 查余额 |
| `auction` | 拍卖行（上架/出价/流拍） |
| `baitan` | 摆摊（is_vendor 校验） |

### 任务
| 命令 | 说明 |
|---|---|
| `quest` / `myquest` / `任务` | 当前任务列表 |
| `quest2` / `任务日志` | 任务日志变体 |
| `ask_quest` / `问任务` · `cancel_quest` / `取消任务` | 向掌门接/取消师门任务 |
| `give <物品> to <人>` / `给` | 上交任务物品（NPC 结算） |
| `hatred` / `仇人` | 仇人列表 |
| `scheme` / `计划` · `tianshu` / `天书` · `jifen` / `积分` | 计划 / 天书 / 积分（查询） |
| `news` | 公告阅读 |

### 养成与修炼
| 命令 | 中文 | 说明 |
|---|---|---|
| `exercise <耗气量>` / `dazuo` / `打坐` | — | 打坐炼内力 |
| `respirate` / `tuna` / `吐纳` / `炼精` | — | 吐纳炼精力上限 |
| `jingzuo` / `静坐` | — | 峨嵋静坐（需门派=峨嵋派+force≥40） |
| `closed` / `闭关` | — | ⚠️ 占位（大宗师闭关未开放） |
| `study <书>` / `研习` / `读书` | — | 研读秘籍 |
| `research` / `yanjiu` | — | 研究（🔺 note：`yanjiu` 实际路由到 research，非 study） |
| `learn <技能> <师父>` / `学` | — | 拜师学艺（`learn x5` 批量） |
| `practice <技能>` / `练` | — | 练习（`practice x3` 批量） |
| `skills` / `myskill` / `技能` | — | 全分类技能列表 |
| `skill` · `checkskill` / `查技能` | — | 单项技能详情 |
| `prepare` / `备招` | — | 备招组合（`prepare ?` 种类；`prepare none` 取消） |
| `enable <用法> <特技>` | — | 映射内功/轻功/招架 |
| `exert powerup` | — | 运功加攻（耗内力，临时攻防提升） |
| `san` · `imbue` · `enchase` · `combine` | — | 散功 / 注灵 / 镶嵌 / 组合 |
| `jingxiu` · `animaout` | — | 静修（少林）/ 元神出窍 |
| `breakup` · `fuse` · `derive` · `syn` · `yanlian` | — | 拆解 / 融合 / 派生 / 同步 / 炎炼 |

### 个性化与系统
| 命令 | 说明 |
|---|---|
| `alias` / `别名` · `nick` / `昵称` · `color` / `颜色` | 别名 / 昵称 / 颜色主题 |
| `option` / `选项` · `title` / `头衔` · `set` / `unset` | 选项 / 头衔 / 设置环境变量 |
| `note` / `便笺` / `笔记` · `passwd` · `id` | 笔记 / 改密码 / 身份 |
| `save` / `存档` · `quit` | 存档 / 退出 |
| `cls` / `clear` | 清屏 |
| `describe` / `描述` · `whistle` / `xiao` · `cut` | 描述 / 口哨 / 切割 |
| `open`/`开` · `close`/`关` | 开门 / 关门 |
| `delay <秒> <命令>` | 延时执行（内部机制） |
| `reload` · `recompile` | 热更 UCL+代码 / 仅重编译（wiz） |
| `drive` / `赶车` · `sleep` / `睡觉` | 赶车 / 睡觉 |
| `make` · `cook` · `wash` · `drug` · `daub` · `pour` | 制作 / 烹饪 / 清洗 / 下毒 / 涂毒 / 倒毒 |
| `miss` · `check` / `dating` | 追寻任务物品 / 打探信息 |

### 频道与剧情（Q3/Q4/Q5 新增）
| 命令 | 说明 |
|---|---|
| `waidi` | 外族入侵频道（`waidi on/off` 控制收听；Q4 入侵/Q5 宝镜广播走此频道） |
| `accept` | 应战剧情挑战者（Q3-stretch 摆擂真打） |

### 巫师管理（wiz，需 `Admin.Access`）
| 命令 | 说明 |
|---|---|
| `goto` / `where` / `localcmds` / `home` / `mem` / `nodie` / `copyskill` / `promote` | 已实现 |
| `clone`（物品可、生物⚠️「暂未实现，请用 update」）、`dest`、`update` | 部分实现 |
| `build call smash possess throw var setsk purge restore register reboot shutdown grant changeuser` | ⚠️ 14 个静默 no-op 占位（需对象系统） |
| `top` / `top2` / `topp` | ⚠️ 排行榜占位 |

---

## 四、分场景实操脚本

> 每个场景独立可测，按序做完整覆盖最顺。
> 「预期」给出判定用的关键输出片段。

### 场景 A：新号出生与信息命令
```text
score        预期：气血 150/150、实战经验 1000、潜能 100、铜钱 100文
who          预期：列出自己
version      预期：版本号
commands     预期：命令清单（190+ 注册动词，中英文别名，含一句中文说明）
help         预期：帮助主题索引
help say     预期：say 主题内容
info         预期：四维 20、基本拳脚/剑法 60 级、基本内功 20 级等明细
look         预期：城镇广场描述 + 出口 south/north/west
time         预期：游戏年月日 + 时辰/季节
```

### 场景 B：行走与中文别名
```text
北           预期：走到广场北侧房间；同时验证中文方向可用
南           预期：回到城镇广场
北上         预期：报未知命令（词边界生效，不误触发移动）
w            预期：到铁匠铺
e            预期：回城镇广场
```

### 场景 C：物品拾取与装备（在张记铁铺）
路线：`w` `n` `n` `e`
```text
get 长剑      预期：拾取提示
i            预期：背包出现长剑
wield 长剑    预期："抽出长剑"之类装备文案
get 布袍 → wear 布袍                    预期：穿上布袍
脱 布袍（先 remove 布袍 再试中文别名）    预期：再次穿上正常
drop 包子     （若无包子先跳过）          预期：丢弃提示
```

### 场景 D：商店购物与进食（张记铁铺）
```text
list 店小二   预期：货单（包子/培元丹/长剑/布袍/斗笠/束腰带/束脩/谢师礼）
买 包子       预期："你从店小二手里买下包子…花了 15 文铜钱"
eat 包子      预期："你吃下包子…" 且背包少一个
score         预期：铜钱相应减少
喝药          预期：（受伤状态下）气血+80 内力+50；满血也可服用
```

### 场景 D2：四维成长丹（培元丹 +1 臂力）
```text
买 培元丹      预期：扣 100 文，培元丹入包
eat 培元丹     预期："一股热气涌向四肢百骸。（气血+50 臂力+1）"
score          预期：臂力 20 → 21
```
（吃满上限多颗后提示"你服药已多，臂力再难精进"，软上限 30 拒绝消耗；
嫌麻烦先用 psql 给测试号改 coins，见场景 D2 原稿。）

### 场景 E：问询与闲聊
```text
问 店小二 柳溪   预期：店小二 tell 你柳溪镇介绍
问 店小二 黑虎   预期：黑虎背景故事
ask 店小二 about 玉牌   预期：玉牌传闻引导
say 大家好       预期：房间说话回显
general 测试频道  预期：[general] 开头的频道回显
wave            预期：挥手动作广播
```
闲聊（N3 概率台词）：野猪所在房间多停留，应能看到"野猪用鼻子拱了拱地面。"之类随机台词。

### 场景 F：拜师学艺（练武场）
路线：`w` `w`
```text
apprentice 王重九    预期：「好，从今日起你便是柳溪派门下弟子」
pai / 门派          预期：门派：柳溪派 / 师父：王重九 / 贡献 0
learn force 王重九   预期："你的基本内功进步了！"（潜能 -2，精力 -1）
learn x5 force 王重九   预期：连续学5次，精<70%时中断；learned_points 累加
learn liuxi-neigong 王重九   预期：学会柳溪内功
enable force liuxi-neigong   预期：映射成功
exert powerup        预期：运功 buff 生效；再输一次提示已在运功中
practice sword       预期：learned_points −1，剑法进步
practice x3 sword    预期：连续练3次，精<70%时中断
jiali 3              预期：若柳溪内功≤1级提示"最多加力 0 档"；学到 6 级后再设可成功
```

### 场景 G：打坐修炼（注意房间限制）
```text
dazuo 30             在练武场输入 → 预期："无法在这个地方安心打坐"（no_fight 房）
e / s                回镇广场
打坐 30              预期："盘膝坐下…"，数十秒后"运功完毕"
score                预期：内力上限可能 +1
```
**⚠️ 瓶颈是初始状态的正常预期**：新号 max_neili=200，天花板低于此值时必提示瓶颈；
想看到"你的内力增加了！！"先 `learn liuxi-neigong 王重九` 学到 11 级以上再打坐。
打坐前置条件：参数≥10、非战斗、已 enable 内功、精力≥70%、非 no_fight 房间；
打坐中卷入战斗会自动中断。

### 场景 H：战斗全流程
```text
（柳溪镇广场）
kill 野猪        预期：战况播报数轮后"你杀死了对手，获得 X 点实战经验、Y 点潜能"
score            预期：经验/潜能增加；铜钱可能增加 5~15 文（击杀掉落）
s                到山路
kill 黑虎        预期：黑虎很强，大概率被打死 → "慢慢睁开眼睛，清醒了过来" 并回到出生点
wield 长剑       预期：重生后重新装备（死亡不掉装备）
```
黑虎是主动怪（aggressive）：站在山路上它会主动开战；逃跑用 `halt` 后立刻往反方向走。
记仇（attacked_by 内存态）：打过的怪再回来会优先攻击你；NPC 死亡/重载后清空。

### 场景 I：任务闭环（送还血玉牌 + 新手链）
```text
s                到山路
kill 黑虎        击杀后背包自动获得"血玉牌 Yupai"（i 查看）
n                回柳溪镇广场
问 阿婆 玉牌      预期：阿婆收走玉牌，发放奖励（实战经验+200 潜能+50 阅历+10 威望+5 铜钱+100）
                  rumor 频道播报谣言
score            预期：阅历/威望/铜钱上涨
```

### 场景 I2：新手链七步（Q1-T4，周不通引导）
在镇广场 `问 周不通 任务` 开启线性任务链，每步先完成前置才能接下一步：
```text
1. 打铁 20 件     → 问 周不通 任务 → 王铁匠（张记铁铺）→ 打铁收集铁块
2. 存钱           → 钱庄（tiepupu 往东）钱掌柜 → 银票
3. 买包子         → 包子嫂（镇广场）→ 包子
4. 郭府报到       → 郭府管家（练武场 north）→ 束脩
5. 拜师           → 张青崖大师兄（练武场）→ 正式入门
6. 祈福           → 庙祝（子虚观）→ 佛香
7. 师门任务       → 回周不通交付谢师礼 → 链完结
```
> 每步 `quest`/`任务` 查看当前步；前置未完成时接下一步会被拒并提示"先办前事"。

### 场景 J：社交补充（建议双端测试）
再开一个 telnet 窗口登第二个号，验证：
```text
tell 对方名 你好    预期：对方收到私聊；对方 reply 可回复
whisper 对方名 悄悄话  预期：仅房间内低语样式
swear 对方名 ...    预期：结拜请求 → 对方 right 应允 → brothers
```

### 场景 K：特色 NPC（Q6 隐世之境，数据驱动）
柳溪镇广场 `n` 到隐逸山径：
```text
n（镇广场→隐逸山径）   预期：进入隐世之境 zone
s → 铸剑亭
问 干将 铸剑         预期：干将回话并给你 精钢块（入包）
问 莫邪 寒铁         预期：寒铁入包
（观云阁）问 青阳子 道法   预期：学会 道家 技能（taoism）
问 青阳子 拜师       预期：入青阳门，贡献+10；pai 查看门派变化
（书林）问 南贤 识字      预期：学会 读书识字（literate）
（论武台）问 裁判 比武    预期：比武令牌入包
```

### 场景 L：宝镜任务（Q5，waidi 频道）
```text
# 轮次刷新时 waidi 频道广播：30 件任务物品已散落各地
pai / 门派 或 score    预期：无宝镜时先去子虚观
# 子虚观仅在 world kickoff 后由代码生成子虚道人（liuxi:zixu_guan）
问 子虚道人 宝镜      预期：获得乾坤宝镜（每人限 1 个；再领被拒）
# 找携带 task 物品的任务载体 NPC（随机散落柳溪非 no_fight 房间）
give <任务物品> to <载体NPC>   预期：送还奖励 + 里程碑；本轮全交 → 全服公告
```
> 宝镜定位 v1 无灵力递减，玩家靠 `look`/广播线索找载体。

### 场景 M：剧情叙事（Q3，全服播报）
无需操作。空闲期 30 秒~5 分钟一次，`general` 频道自动逐行播报——
四仙丹/两卷书/玄铁令/幻阴指/三分剑/四天灾/摆擂（challenge 真打，`accept` 可应战）。
在线玩家房间可能随机掉落赠礼物品（look 查看地面）。

### 场景 N：入侵事件（Q4，waidi 频道）
```text
waidi on      预期：订阅外族频道
# 波次触发：waidi 广播入侵开始 → 24 只外族 NPC 散落柳溪
kill 入侵者    预期：按 LPC 公式奖励 exp/potential/体会/威望/阅历
# 全歼 24 只 → 大奖广播；闲置 10 分钟自毁
waidi off     预期：不再看到入侵广播
```

### 场景 O：天气与昼夜（Q2，户外房间 look 注入）
```text
# 游戏时间每 12 秒过 1 分钟：季节/昼夜自动切换
look           户外房间（山路/镇广场）→ 描述末尾含当前天象文案（天色/风雨/outcolor 上色）
室内房间（铁铺/客栈）→ 无天气文案
# 午夜换季 → 广播换季公告；昼夜时段切换 → 广播时段提示
time           预期：显示游戏年月日/时辰/季节
```

---

## 五、常见失败文案对照

| 提示 | 原因 |
|---|---|
| 你要跟谁动手？ | kill 未带目标名 |
| 这里没有 XX 这个人。 | 目标不在本房间或名字不符 |
| 此处乃习武清修之地，不可动手。 | 当前房间是 no_fight（练武场/子虚观） |
| 你必须先用 enable 选择要运用的内功心法。 | 打坐/加力前未映射内功 |
| 你现在的气太少了… | qi 低于打坐耗气量 |
| 你现在精不够… | 精力低于七成 |
| 无法在这个地方安心打坐。 | no_fight 房间禁止打坐 |
| 你的内力修为似乎已经达到了瓶颈。 | 内力已达当前天花板，需先升内功等级 |
| 你还没用 enable…无法加力。 | jiali 前未映射内功 |
| 最多加力 N 档。 | 超过 enable内功等级÷2 |
| 这里不卖 XX。 | 该商人的 goods 里没有此物 |
| 你身上的钱不够… | 铜钱低于售价 |
| 你身上没有这样东西。 | eat/drop 找不到背包物品 |
| 你是个文盲/谈何施展 之类门槛提示 | perform 技能等级未达标 |
| 先办前事。 | 任务链前置未完成（chain_blocked） |
| 然而你今天太累了，无法再进行任何学习了。 | 精力不足，learn 中断 |
| 也许是缺乏实战经验，你对师父的回答总是无法领会。 | 经验值不够（exp gate），learn 被拒 |
| 也许是缺乏实战经验，你的练习总没法进步。 | 经验值不够（exp gate），practice 被拒 |
| 你发现自身所学的XX和XX冲突不已，根本没办法并存。 | 内功互斥（force_conflict） |
| 你现在精神不济，无法专心练习。 | 精力不足（精 < 70%），practice 被拒 |
| 没有这项武功。 | base skill（如 sword）无模块，practice 被拒 |
| XX只能用学(learn)的来增加熟练度。 | 柳溪内功等只学不练的技能 |
| 你的体力太低了。 | 气不够 practice 消耗 |
| 你的内力不够。 | 内力不够 practice 消耗 |
| 你的潜能不足，先去实战中磨练吧。 | available_potential < learn_cost |
| 你现在正忙着呢。 | 命令执行中重复操作（respirate/jingzuo 等 busy 期间） |
| 你现在精不足，无法修行精力！ | respirate 参数 > 当前 jing |
| 你正闭目吐纳，心无二用。 | respirate 进行中重复操作 |
| 你的精力修为似乎已经达到了瓶颈。 | jingli 已达上限，需升 force 等级 |
| 只有峨嵋派弟子才会静坐！ | 非峨嵋派使用 jingzuo |
| 你的内功修为还不够，没法静心静坐。 | force 有效等级 < 40 |
| 你刚才静坐过，现在头脑一片空白。 | 120 秒冷却期内使用 jingzuo |
| 闭关修行功能尚未完全开放。 | closed 占位命令正常输出 |
| 你身上没有「XX」这本书。 | study 找不到背包中的秘籍 |
| 你无法从这样东西学到任何东西。 | 物品无 book 元数据 |
| 你的实战经验不足，再怎么读也没用。 | combat_exp < 书籍 exp_required |
| 你研读了一会儿，但是发现上面所说的对你而言都太浅了。 | 技能等级 > 书籍 max_skill |
| 你研读了一会儿，但是却发现你对这门技能的理解还太浅。 | 技能等级 < 书籍 min_skill |
| 你现在太累了，结果一行也没有看下去。 | jing 不足，study 一行未完成 |
| 你是个文盲，先学点文化(literate)吧。 | 无 literate 技能使用 study |
| 生物克隆暂未实现，请使用 update。 | clone 目标为 NPC |
| 计划自动执行功能暂未开放… | scheme 裸命令 |
| 排行榜暂未开放。 | top/top2/topp |

---

## 六、已知限制与备注

- **占位命令清单**（输出"暂未开放"）：`beg` `ansuan` `answer` `come` `stay` `stop` `train` `release` `hand` `liuxi/柳溪` `pkd` `push` `secularize/huansu/还俗` `special` `stab` `talk` `to` `top` `top2` `topp` `touch` `vote` `closed`（半开）`scheme`（裸命令）`clone`（生物部分）。
- **W3 arch 14 命令为静默 no-op**（无输出）：`build` `call` `smash` `possess` `throw` `var` `setsk` `purge` `restore` `register` `reboot` `shutdown` `grant` `changeuser`。
- 两个注册顺序注意点：`remove` 实际绑到功能完整的 WieldCommand（RemoveCommand stub 是死代码）；`yanjiu` 实际路由到 research（研究）而非 study（研习）。
- `jing`（精力）随根骨自然回复；learn/practice 消耗精力（精 < 70% 中断）。
- `jingli`（精力修为）由吐纳炼精提升，不自然回复，上限 = con×10，到瓶颈需升 force 等级。
- 死亡无惩罚：满血回出生点、装备背包保留。
- `reload` 会终止并重建全部 NPC——正在进行的战斗会被打断，属预期行为（注意：被删除的 UCL 房间/NPC 当前不保证被终止，见 `docs/remaining-work-checklist.zh-CN.md` A3）。
- 世界数据改动（`data/world/*.ucl`）后用 `reload` 生效；改 lib 代码需重启容器。
- 自动化回归：`scripts/combat_e2e.exs`、`scripts/phase_a_e2e.exs`、`scripts/phase_b_e2e.exs`，
  运行方式见各脚本头部注释。
- 全量测试：`MIX_ENV=test mix test --seed 731933`（当前 2334 tests / 0 failures）。