# LPC 新用户注册与转世重生机制分析

> 研究目标：梳理 LPC 源码中 **新用户注册** 与 **转世重生** 两条主流程，并标出其中
> **性格/人格（character）**、**性别（gender）**、**属性（str/con/int/dex/per）**、
> **出生地（startroom）** 的具体赋值点，为 Elixir 端口径对照提供依据。
>
> 源码根：`/c/files/git/mud/`（LPC/MudOS）
>
> **迁移状态**：✅ 已迁移至 ExVenture/Kantele（见 `EX-注册与转世迁移计划.zh-CN.md`，Phase 0–3 全部完成；LPC 行为逐项对照见该计划附录 B）。

---

## 1. 核心文件清单

| 文件 | 职责 |
|---|---|
| `adm/daemons/logind.c` | 登录、注册、选择性别、创建角色体、进入世界（`get_id`/`get_passwd`/`get_gender`/`make_body`/`init_new_player`/`enter_world`） |
| `clone/user/user.c` | 玩家「连接对象」（user object）；`create()` 极简，仅 `::create()` + 设名；真正的角色初始化在 `logind.c` |
| `adm/daemons/updated.c` | 转世核心 `zhuan_player(object me)`（约 448 行起） |
| `adm/daemons/race/human.c` | 气血/精气等派生属性计算（依 age/con/str + reborn 加成） |
| `d/register/npc/{hua,li,lu,wei}.c` | NPC 注册时设定 `character`（人格） |
| `include/login.h` | 出生地房间常量 `REGISTER_ROOM` / `BORN_ROOM` / `START_ROOM` |

---

## 2. 新用户注册流程（`logind.c`）

```
get_id → get_passwd → get_gender → make_body → [属性初值/性别] → init_new_player → enter_world
```

| 步骤 | 函数/行号 | 动作 |
|---|---|---|
| 取 ID | `get_id`（121）→ `ob->set("id", arg)`（167） | 账号 ID |
| 取密码 | `get_passwd`（207） | 密码（crypt 存储） |
| **选性别** | `get_gender`（658） | 提示 `m`/`f`，`ob->set_temp("gender", "男性"/"女性")``（672-674）` |
| 造角色体 | `make_body`（714） | `new(USER_OB)`，设 `id`/`surname`/`purename`/`name` |
| **属性初值** | 698-702 | `str=14, dex=14, con=14, int=14, per=20` |
| **写性别** | 703 | `user->set("gender", ob->query_temp("gender"))` |
| 新玩家初始化 | `init_new_player`（751） | `title="普通百姓"`、`birthday=time()`（755）、`potential=99`（756）、`food/water`、`channels`、`env/*` |
| 进入世界 | `enter_world`（776） | `user->setup()`（802）、按 class/gender 发初始衣物（822-880）、设定并 `move` 到 `startroom`（901-929） |

### 2.1 性别（gender）赋值
注册时由玩家选择（`get_gender`），先存 temp 再落到角色体：
`ob->set_temp("gender", "男性"/"女性")` → `user->set("gender", ...)`（logind.c:703）。

### 2.2 属性（先天）赋值 —— 重要：非固定
`logind.c` 的 698-702 仅设**临时默认**值：
```lpc
user->set("str", 14);
user->set("dex", 14);
user->set("con", 14);
user->set("int", 14);
user->set("per", 20);
```
这些只是进入世界前的占位值，**真正分配发生在「阎罗殿」(`BORN_ROOM`) 经 `washto` 指令完成**（见 §2.5）。

- `str/dex/con/int` 为「先天属性」；`per`（感知/洞察）与 `kar`（福缘）为不可自选、随机生成项。
- 这些是「先天属性」，可经吃丹（九转等）与转世加成提升。
- 派生属性 `max_qi` / `max_jing` 由 `race/human.c` 依 `age`/`con`/`str` 与 `reborn` 加成计算
  （新玩家 `age=14` → 默认 `max_qi=100`、`max_jing=100`，见 human.c:58/91 等）。

### 2.3 性格/人格（character）赋值 —— 关键结论
**新用户注册流程不设定 `character`** → 查询返回 `nil`/假值（0）。

全库 `set("character", ...)` 仅 5 处，且全部是 NPC/转世上下文（非玩家可选）：
| 位置 | 值 |
|---|---|
| `d/register/npc/hua.c:51` | `"阴险奸诈"` |
| `d/register/npc/li.c:51` | `"心狠手辣"` |
| `d/register/npc/lu.c:52` | `"光明磊落"` |
| `d/register/npc/wei.c:52` | `"狡黠多变"` |
| `adm/daemons/updated.c:515` | `"国士无双"`（转世） |
| `kungfu/class/hu/huyizhi.c:13` | `"光明磊落"`（NPC 师父胡衣之） |

`cmds/` 下无任何玩家设定 `character` 的命令（`score.c`/`score2.c` 仅展示已设值）。
`enter_world`（901-907）注释「16 岁以后再选天性」指向 `REGISTER_ROOM`，但注册流程中**并无实际赋值路径**。

> **结论**：普通玩家 `character` 恒为 `nil`，仅在 **转世** 后被设为「国士无双」。

### 2.4 出生地（startroom）
`enter_world`（901-929）按优先级设定 `startroom`，并 `user->move(startroom)`：
```lpc
if (!stringp(character) && age >= 16)   startroom = REGISTER_ROOM;   // /d/register/entry
else if (!stringp(born))                startroom = BORN_ROOM;       // /d/register/yanluodian
else if (!startroom 或房间不存在)        startroom = START_ROOM;      // /d/city/kedian
```
- 房间常量见 `include/login.h:24-26`。
- 新玩家 `age=14` 且未设 `born` → 落入 `BORN_ROOM`（`/d/register/yanluodian`）。
- 该 `startroom` 即玩家「出生/出发点」；`save()` 时若处于合法房间会刷新 `startroom`（user.c:144-148）。

### 2.5 阎罗殿洗点 / 投胎 / 与生俱来特技（新玩家真正初始化）
新玩家 `enter_world` 落入 `BORN_ROOM`（`/d/register/yanluodian`，阎罗殿），在此完成真正的属性分配、出生地选择与初始特技授予（logind.c:901-912 → yanluodian.c 全流程）：

1. **洗点 `washto <膂力 str> <悟性 int> <根骨 con> <身法 dex>`**（yanluodian.c:100-153）
   - 四项各 **10 ≤ 值 ≤ 30**；**总和必须 = 80**（否则报错「你所选择的属性总和必须为80」）；
   - 写入 `str/int/con/dex`；`per` 与 `kar` 随机 `5+random(26)`（即 5–30）；
   - 置临时标记 `washed=1`，未洗点者 `born` 会被拒。
2. **投胎 `born <中文地名>`**（yanluodian.c:155-273）
   - 须先 `washed`；从固定 `born` 映射取 `startroom`/`born`/`born_family`：
     - 普通地域：扬州人氏→`/d/city/kedian` 等；
     - 世家（附 `surname` 与专属 `startroom`）：欧阳世家/关外胡家/中原苗家/段氏皇族/慕容世家。
   - 设 `mud_age=0, age=14, registered=1`，`save()`。
3. **与生俱来特技 `UPDATE_D->born_player(me)`**（yanluodian.c:258-261 → updated.c:344-445，非转世者才走）
   - 从 `special_skill/*` 池随机赠 **1–3 项**，排除转世/特殊技（guibian/guimai/jinshen/piyi/lighting/qinzong/wuxing/shenyan/tiandao/herb/wrach/trick 等）；
   - `character` 不符排除 `wrath`/`trick`（新玩家恒 nil → 恒排除）；
   - 先天属性 `<20` 排除对应特技（str<20→strength、int<20→intellect/clever、con<20→constitution、dex<20→dexterity、per<20→youth）；
   - 命中 `strength/intellect/constitution/dexterity` 再 `+2` 对应属性。

> 结论：新玩家的「属性初值」实为 **washto 点数池（和=80）** 而非 14/20；且与转世共享同一 `str/int/con/dex` 字段、`per`/`kar` 随机规则。`born_player` 的「与生俱来特技」是注册侧（非转世侧）特技授予，迁移时须一并实现。

---

## 3. 转世重生流程（`updated.c` → `zhuan_player(me)`）

触发：`reborn` 经「地藏王 (`d/death/npc/dizangwang.c`) `ask_zhuan`」入口，需**四前置齐备**方可进入六道轮回→`zhuan_player`（dizangwang.c:117-271）：
1. **大宗师**：`combat_exp≥800000000` 且 `ultrap(me)`（注释硬门槛，dizangwang.c:123-129）；
2. **十八层地狱** `HellZhenPass`（dizangwang.c:138）；
3. **十二重天** `SkyPass`（闯过 sky12 取来「精元丹」，dizangwang.c:145,243）；
4. **击败地藏王** 得 `DiZangPass`（dizangwang.c:210，战败地藏王后置位并送天门）。
四者齐备后 `accept_object` 收精元丹→移入六道轮回房间→调用 `zhuan_player`。

核心函数 `zhuan_player` 自 448 行起。

### 3.1 性别
```lpc
if (me->query("gender") == "无性") me->set("gender", "男性");   // 458-459
```

### 3.2 清除记录（大量 `delete`）
社交/门派/任务/修炼状态全清：
`couple`、`sex`、`brothers`、`bunch`、`league`、`family`、`class`、`detach`、`betrayer`、
`born_family`、`combat`、`animaout`、`breakup`、`can_learn`、`can_make`、`env`、`gift`、
`opinion(s)`、`out_family`、`quest`、`map`、`rumor`、`schedule`、`skybook`、`luohan_winner`、
`story`、`DiZangPass`/`HellZhenPass`/`SkyPass`/`over_quest`、`tattoo`、`can_learned`、
`mirror_task`、`death`、`can_perform`、`learned_literate`、`static`、`mark` …（462-527）

### 3.3 性格/人格赋值（核心）
```lpc
me->set("character", "国士无双");   // 515  — 转世性格
```
→ 转世玩家获得「国士无双」，对一切 `character` 门槛 **全部放行**：
- 排除门（`== X 则拒`）：不拦；
- 包含门（`!= X && != Y 则拒`）：因命中「国士无双」而**放行**。
（这正是 Elixir 端口径——4 个包含门技能=转世专属——的来源。）

### 3.4 数值重置
```lpc
gongxian/score/weiwang/experience/learned_experience = 0;
max_neili/neili/jiali = 0;  max_jingli/jingli/jiajing = 0;  shen = 0;
combat_exp/learned_points/potential/magic_learned/magic_points = 0;   // 530-549
max_qi = 100;  max_jing = 100;  eff/qi/jing 同步;                     // 556-561
mud_age = 0;  age = 14;  birthday = time();                          // 563-565
```

### 3.5 技能清除与转世技能
- `delete_skill` 清空全部武功（567-577）；
- `reborn/count += 1`、`reborn/point += 1`（579-580，洗点 +1）；
- 随机先天加成：每项属性 50% 概率 `+1`（583-602）：
  ```lpc
  if (random(2)) me->add("reborn/str", 1);   // 同理 con/int/dex
  ```
- 赠送特技：1 个普通技能（12 选 1）+ 1 个转世特技（8 选 1，按 `int`/`dex` 条件过滤）+ 固定「神眼」（608-682）。

### 3.6 后续
`is_ghost()` 则 `reincarnate()`；`reset_action()`；回到世界。

---

## 4. 与 Elixir 端口径对照（F4 valid_learn 相关）

| 维度 | LPC 行为 | 端口现状 | 一致性 |
|---|---|---|---|
| **性格 character** | 玩家侧**无赋值入口**（仅 NPC 注册 + 转世设「国士无双」）；普通玩家恒 `nil` | `meta.character` 读取，nil ≡ LPC 0；排除门不拦、包含门拦 | ✅ 一致（4 包含门技能=转世专属，符合 LPC） |
| **性别 gender** | 注册可选 男性/女性 | `meta.env.gender`（`records.ex` 已建模） | ✅ 已建模 |
| **属性 str/con/int/dex/per** | 新玩家经 `washto` 点数池（str/int/con/dex 各10–30且和=80，per/kar随机5–30）；logind.c 仅给临时 14/20 | `Stats.new()` 默认 20；迁移时需实现 washto 式点数池 + per/kar 随机 | ⚠️ 端口暂无点数池/随机规则，迁移时按本表实现 |
| **出生地 startroom** | `BORN_ROOM`/`REGISTER_ROOM`/`START_ROOM` | 端口暂无对应字段（非 valid_learn 路径，F4 不涉及） | ➖ 无关 |

> 关联结论（见 `C-PVE27-valid_learn-长尾补全进度.zh-CN.md`）：因 `meta.character` 运行态不落盘、玩家侧无赋值入口（转世未实现），
> 端口当前**无法**让普通玩家拿到「国士无双」，故 4 个包含门技能（先天功 / 刀剑归真 / 三无三不手 / 五斗米神功）在端口**不可学**——
> 与 LPC 设计意图完全一致，属预期差异而非缺口。

---

## 5. 关键代码行号索引

| 文件:行 | 含义 |
|---|---|
| `logind.c:658` | `get_gender` 选择性别 |
| `logind.c:672-674` | `set_temp("gender", "男性"/"女性")` |
| `logind.c:698-702` | 新玩家属性初值 `str/dex/con/int=14, per=20` |
| `logind.c:703` | `user->set("gender", ...)` |
| `logind.c:751-773` | `init_new_player`：title/birthday/potential/env |
| `logind.c:776` | `enter_world` 入口 |
| `logind.c:901-912` | 出生地：`REGISTER_ROOM` / `BORN_ROOM` |
| `logind.c:919-924` | 默认 `START_ROOM` 并 move |
| `d/register/yanluodian.c:100-153` | `washto` 洗点：str/int/con/dex 各10–30且和=80，per/kar随机5–30 |
| `d/register/yanluodian.c:155-273` | `born` 投胎：选 startroom/born/born_family，世家附 surname |
| `d/register/yanluodian.c:258-261` | 非转世者调 `born_player` 赠与生俱来特技 |
| `updated.c:344-445` | `born_player`：随机赠 1–3 项特技（按 character/属性≥20 过滤，+2 属性） |
| `d/death/npc/dizangwang.c:117-271` | 地藏王 `ask_zhuan`：reborn 四前置（大宗师+十八层地狱+十二重天+击败地藏王） |
| `updated.c:448` | `zhuan_player` 入口 |
| `updated.c:458-459` | 转世性别：无性→男性 |
| `updated.c:462-527` | 转世清除记录（大量 delete） |
| `updated.c:515` | **`set("character", "国士无双")`** |
| `updated.c:530-565` | 转世数值/HP/年龄重置 |
| `updated.c:579-602` | `reborn/count`++ 与随机先天加成 |
| `updated.c:608-682` | 转世特技/普通技能赠送 |
| `d/register/npc/hua.c:51` | NPC `character="阴险奸诈"` |
| `d/register/npc/li.c:51` | NPC `character="心狠手辣"` |
| `d/register/npc/lu.c:52` | NPC `character="光明磊落"` |
| `d/register/npc/wei.c:52` | NPC `character="狡黠多变"` |
| `kungfu/class/hu/huyizhi.c:13` | NPC 师父 `character="光明磊落"` |
| `include/login.h:24-26` | `REGISTER_ROOM`/`BORN_ROOM`/`START_ROOM` 常量 |
| `race/human.c:42` / `:58-179` | 性别默认、派生 `max_qi`/`max_jing` 计算 |

---

*参考文档：`docs/systems/reborn_system_analysis.md`（转世系统总体设计）、
`docs/C-PVE27-valid_learn-长尾补全进度.zh-CN.md`（valid_learn 性格门口径）。*
