# 尸体掉落系统：LPC 对照与 Elixir 实现

> ## 📌 归档声明 · 全库待办清零（2026-11-13）
>
> 本文件为**已结案的实现记录**。文中出现的 `⚠️` `后续` `待办` 等字样，
> 一律指「与 LPC 的有意设计取舍」或「历史快照」，**不代表当前待办**。
> 截至 2026-11-13 尸体 / NPC 掉落系统的代码、数据、测试均已落地并回归通过；
> 验证清单全部勾选，本文件不含任何剩余待办项，无需排期。
>
> **唯一状态入口**：`.workbuddy-ai/memory/MEMORY.md` 与
> `docs/待办对照代码核查.zh-CN.md` §三 / §6.2。

**文档目的**：说明 LPC 原版尸体 / 狩猎掉落物流程，对照 Elixir 端口的最终实现，并记录有意为之的差异。

**状态（2026-11-13）**：✅ 已落地。代码、数据、测试、验证清单全部完成；本文 §7 的「已知差异」是设计取舍，不是待办。

**相关文档**：`docs/npc-drop-completion-plan.zh-CN.md`（NPC 掉落数据补全清单）

---

## 1. LPC 原版做法

### 1.1 尸体对象（`adm/daemons/chard.c` + `clone/misc/corpse.c`）

玩家或 NPC 死亡时 `CHAR_D->make_corpse(victim, killer)` 克隆 `/clone/misc/corpse`，
`corpse->make_corpse()` 把尸体放进 `environment(victim)`（死亡地点房间）。尸体是容器：

```c
int is_container() { return 1; }

inv = all_inventory(victim);
inv->owner_is_killed(killer);
while (i--)
{
    if ((string)inv[i]->query("equipped") == "worn")
    {
        inv[i]->move(this_object());
        if (!inv[i]->wear())
            inv[i]->move(environment(victim));
    }
    else
        inv[i]->move(this_object());       // 死者背包物品移入尸体
}
```

腐烂：`call_out("decay", 60, 1)` 三段（尸体 → 白骨 → `destruct`），共约 180 秒；
销毁前把尸体容器里的物品移到 `environment`，所以掉落物留在地上而不是随之消失。

### 1.2 狩猎掉落物（`inherit/char/quarry.c::die()` / `inherit/char/snake.c::die()`）

QUARRY / SNAKE 继承的 NPC 通过 `set("item1"/"item2"/"item3", ...)` 配置掉落，
对应 UCL 的 `drop_a` / `drop_b` / `drop_c`：

```c
skill = me->query_skill("hunting", 1);
if (ob->query("item1") && random(skill) > 10)
{
        item = new(ob->query("item1"));
        item->move(me, 1);                     // ★ 直接给击杀者，不是放地上

        if (ob->query("item3") && random(skill) > 60 && random(5) > 3)
            item3 也给击杀者;                  // 与 item2 互斥
        else if (ob->query("item2") && random(skill) > 30 && random(4) > 2)
            item2 也给击杀者;
}
destruct(ob);
```

即：item1 是主掉落，item2 / item3 是**互斥的二选一**稀有掉落，且全部按狩猎技能概率门控。

---

## 2. Elixir 端口最终架构

### 2.1 两条死亡管线（关键）

端口有两条互相独立的死亡路径，尸体逻辑必须**两路都接**，否则数据配置根本不会生效：

| 路径 | 入口 | 触发场景 | 尸体接线 |
|------|------|----------|----------|
| 主路径 | `Kantele.Character.Events.CombatEvent.die/3` | 正常战斗 / `hunt` 击杀 | ✅ 已接 |
| 次路径 | `Kantele.Feature.Damage.die/2` → `process_death/2` | `smash`、房间 `break`、跳崖等 | ✅ 已接 |

> **历史坑**：早期只在 `Feature.Damage` 里生成尸体。由于打猎走的是 `CombatEvent.die/3`，
> 当时击杀野兽既没有尸体也没有掉落物 —— 所有 `drop_*` 数据都是死配置。
> 现已把公共逻辑抽到 `Kantele.World.Corpse.spawn/1`，两路统一调用。

### 2.2 `lib/kantele/world/corpse.ex`（唯一实现）

| 函数 | 作用 |
|------|------|
| `spawn/1` | 在 `character.room_id` 生成尸体 + 掉落物 + 超时销毁；玩家（`player:` 前缀）返回 `:skip`；房间/缓存未就绪返回 `:error` 且整段 `try/rescue` 兜底，绝不带崩死亡结算 |
| `corpse_instance/1` | 纯函数，构造 `%Kalevala.World.Item.Instance{}`；`item_id` 解析成完整缓存 key |
| `drop_item_ids/1` | 纯函数，读 `meta.drop_a/drop_b/drop_c`，去 nil、去重 |
| `resolve_drop_item/1` | 把 UCL 短 id 解析成 `{完整缓存 key, 物品定义}` |

**物品 id 解析是必须的**：UCL 的 `drop_a = { id = "zhurou" }` 经 `loader.parse_item_ref/1`
得到短 id，而 `Kantele.World.Items` 的 key 是 `loader.parse_item/4` 生成的
`"<zone.id>:<key>"`（`clone_lib:zhurou`）。`ItemCommand` 拾取时又用
`Items.get!(item_instance.item_id)` 取定义。短 id 会同时造成「掉落物查不到」和
「`get` 抛 `Could not find key`」。

解析顺序：原样 → 补 `clone_lib:` 前缀 → 在缓存中按 `":<短名>"` 后缀兜底。
`Items.get/1` / `Items.keys/0` 都包了 `try/rescue`，ETS 表未建好时静默降级。

**尸体 `item_id` 也必须是完整 key**：早期写死 `"corpse"`，但缓存里是
`clone_lib:corpse`，导致房间里有尸体时 `get all` 会遍历到它并调用
`Items.get!("corpse")` 抛异常，把整条拾取命令带崩。现在由 `resolve_corpse_key/0` 解析。

### 2.3 `lib/kantele/world/room.ex`

`add_item/2` / `remove_item/2`：通过 `:sys.replace_state/2` 修改房间进程
`state.private.item_instances`。`Room.snapshot/1` 正是从这里取 `items`，故放置后
`look` / `get` 立即可见。

### 2.4 字段链路

```
UCL drop_a/drop_b/drop_c
  → loader.parse_character/4 → NonPlayerMeta（字段 + Trim 白名单）
  → CombatEvent.die/3 或 Feature.Damage.process_death/2
  → Kantele.World.Corpse.spawn/1
  → Room.add_item(room_id, 尸体实例)
  → Room.add_item(room_id, 各掉落物实例)   ← 方案 A，独立实例散在地上
  → Scheduler.schedule_once(180_000) → Room.remove_item(尸体)
```

`NonPlayerMeta` 的 `Kalevala.Meta.Trim` 白名单包含 `:drop_a/:drop_b/:drop_c/:power`，
否则房间快照里的裁剪 meta 会丢掉掉落配置（`test/kantele/meta_trim_contract_test.exs` 守护）。

---

## 3. 与 LPC 的对齐表

| LPC 原版 | Elixir 端口 | 状态 |
|---------|------------|------|
| `chard.c make_corpse()` 在死亡房间生成尸体 | `Corpse.spawn/1` + `Room.add_item/2` | ✅ |
| `corpse.c is_container()` + 死者背包物品移入尸体 | 只生成展示用尸体 Item，不转移背包 | ⚠️ 见 §7 |
| `quarry.c`/`snake.c die()` 的 item1/item2/item3 | `drop_a`/`drop_b`/`drop_c` → 独立 Item.Instance 入房间（`get` 拾取） | ✅ 数据齐全 |
| `item->move(me, 1)` 直接给击杀者 | 掉落物放在地上，任何人可 `get` | ⚠️ 见 §7 |
| `random(skill) > 10/30/60` 概率 + item2/item3 互斥 | 固定掉落全部三件 | ⚠️ 见 §7 |
| `call_out("decay", 60, 1)` 三段约 180 秒 | `Scheduler.schedule_once(180_000)` 一段式销毁 | ✅ 近似 |
| 销毁前把尸体容器物品移到 environment | 掉落物本来就在地上，不随尸体销毁 | ✅ 等效 |
| `get <物品> from <尸体>` | 未实现容器语义，用 `get <物品>` | ⚠️ 见 §7 |

---

## 4. 数据补全（`data/world/*.ucl`）

### 4.1 物品定义

`clone_lib.ucl` 原有 12 件狩猎掉落物，本次按 LPC `clone/quarry/item/*.c` 补齐 23 件
（名称 / `value` / `unit` / `weight` 均取自 LPC `base_value`/`base_unit`/`base_weight`；
肉类继承 `meat.h` 的 `base_weight = 300`）。其中 3 件在第一阶段加入，本次新增 20 件：

`diaorou` 貂肉、`diaopi` 貂皮、`eyurou` 鳄鱼肉、`eyupi` 鳄鱼皮、`baorou` 豹肉、
`zhangrou` 獐子肉、`yingrou` 鹰肉、`xiangrou` 象肉、`xiangya` 象牙、`paorou` 狍子肉、
`langrou` 狼肉、`langpi` 狼皮、`langpi2` 银狼皮、`jizirou` 麂子肉、`jirou` 山鸡肉、
`lirou` 狸肉、`lipi` 狐狸皮、`lipi2` 白狐皮、`sherou` 蛇肉、`shepi` 蛇皮。

已存在的：`turou` `zhurou` `lurou` `hupi` `hurou` `gourou` `yangrou` `baopi`
`xiongpi` `guijia` `lurong` `shedan` `xiongdan` `goupi` `xiongrou` `yangpi` `blood`。

### 4.2 NPC 配置

- **26 个 `quarry_*` NPC**（`clone_lib.ucl`）全部存在于端口，与 LPC `clone/quarry/*.c` 一一对应。
  其中 19 个在 LPC 有 item1/item2/item3，全部已配置 `drop_*`；7 个
  （`fu`/`he`/`he2`/`hou`/`niao`/`niao3`/`song`）在 LPC 本来就没有掉落，保持不配置。
- **蛇类 26 个 `characters` 块**（`baituo.ucl` 9 个 + 其余 8 个区 17 个）按
  LPC `clone/beast/*.c` 配置 `drop_a = sherou`、`drop_b = shedan`；
  `mangshe` 的 item2 是 `shepi`；`xuanmang` 额外 `drop_c = blood`（碧魄血精）。
- `quarry_xiong` 配 `drop_c = xiongdan`（LPC `item3`）。
- `power` 按 LPC `set("power", N)` 补齐到 12 个新配置的 NPC，使 `hunt` 可命中。

> **计划文档纠错**：`docs/npc-drop-completion-plan.zh-CN.md` 初版列了 12 个
> `quarry_*` ID（`quarry_bao`/`hu`/`hu2`/`ji`/`jizi`/`lang3`/`lu2`/`pao`/
> `xiang`/`xiong2`/`zhang`/`niao2`），这些 NPC **在 Elixir UCL 中根本不存在**
> （LPC 有、端口未移植）。它们不是代码缺口，已在该文档 §8 结案，不再作为待办。

---

## 5. 验证清单（全部 ✅）

- ✅ 77 个 `data/world/*.ucl` 全部经 `Elias.parse/1` 解析通过
- ✅ 87 条 `drop_*` 引用 0 条悬空，全部能解析到物品定义
- ✅ `mix compile`（`MIX_ENV=test`）通过
- ✅ `test/kantele/world/corpse_test.exs`：14 tests / 0 failures
  （纯函数、降级行为、20 件物品数值、12 个 quarry NPC 配置、蛇类配置、引用完整性）
- ✅ 全量 `mix test --seed 831693`：**7757 tests / 27 failures**，见 §6
- ✅ 游戏内：击杀野兽 → 房间出现 `<NPC名>的尸体` + 掉落物 → `get <物品>` 可拾取
- ✅ 尸体 180 秒后自动消失，掉落物留在地上
- ✅ `get all` 不再因尸体 `item_id` 解析失败而抛异常

---

## 6. 回归基线

本次 `mix test --seed 831693` 实跑结果：**7757 tests / 27 failures，耗时 575.6 秒**。
逐条核对失败清单，27 例全部是 `Web.Plugs.*` / `Web.SessionControllerTest` /
`Web.Registration*` / `Web.ProfileControllerTest` / `Web.ConfirmationControllerTest` /
`Web.Admin.ZoneControllerTest` / `ExVenture.UsersTest` / `ExVenture.CharactersTest`，
统一报 `Bcrypt.Base.gensalt_nif/3 is undefined`（`bcrypt_elixir` NIF 在本机不可用）。
引擎 / 命令 / 技能 / 世界测试 0 失败，**0 新增失败**，与长期基线一致。
日志中的 `Knock.fire_check_pass`、`Failed to save character metadata`、
`kickoff.ex:629 KeyError :id` 均为既有测试夹具打印的告警，不是测试失败。

---

## 7. 已知差异（有意为之，非待办）

以下均为**设计取舍**，代码与数据已按此定稿；如需改成严格 LPC 语义，属于新的需求，
不是本系统的遗留缺陷：

1. **掉落物给谁**：LPC `item->move(me, 1)` 直接进击杀者背包；端口采用「方案 A」，
   作为独立 `Item.Instance` 放在死亡房间，任何人可 `get`。理由：复用现成的
   `ItemCommand.get/2` 拾取流程，且 `CombatEvent` 奖励通道的 `loot`/`drops`
   已能覆盖「直接进包」语义，两者不必重复实现。
2. **概率门控**：LPC 按 `query_skill("hunting")` 做 `random(skill) > 10/30/60`，
   且 item2 / item3 互斥；端口固定掉落全部配置项。若要严格对齐，需在
   `Corpse.spawn/1` 拿到 killer 的 hunting 等级并改判定。
3. **死者背包**：LPC 把死者身上物品移入尸体容器；端口不转移背包，玩家被黑虎
   杀死后随身物品仍保留。这是刻意保护玩家资产，避免未完成存档/容器语义时丢物品。
4. **玩家尸体**：LPC 玩家也有尸体；端口 `Corpse.spawn/1` 对 `player:` 前缀返回
   `:skip`（玩家直接幽灵态进地府），与之前答复用户的行为一致。
5. **尸体容器**：未实现 `get <物品> from <尸体>`（方案 B），掉落物直接散在地上。
6. **腐烂阶段**：LPC 三段变白骨；端口一段式 180 秒销毁。
7. **生肉可食**：LPC `meat.h` 的 `do_effect()` 提示「还是生的，烤熟了再吃」，
   端口沿用既有约定给肉挂 `eat` verb + `meta.food`。

---

## 8. 代码索引

| 文件 | 职责 |
|------|------|
| `lib/kantele/world/corpse.ex` | 尸体/掉落物唯一实现，两条死亡管线共用 |
| `lib/kantele/character/events/combat_event.ex` | `die/3` NPC 分支调用 `Corpse.spawn/1`（主路径） |
| `lib/kantele/feature_damage.ex` | `process_death/2` 调用 `Corpse.spawn/1`（次路径） |
| `lib/kantele/world/room.ex` | `add_item/2` / `remove_item/2` |
| `lib/kantele/world/loader.ex` | `parse_character/4` 解析 `drop_a/b/c`、`power` |
| `lib/kantele/character.ex` | `NonPlayerMeta` 字段 + `Meta.Trim` 白名单 |
| `lib/kantele/character/commands/hunt_command.ex` | `meta.power > 0` 判定可猎 |
| `lib/kantele/character/commands/item_command.ex` | `get` / `get all` 拾取 |
| `test/kantele/world/corpse_test.exs` | 回归测试 |
| `test/kantele/meta_trim_contract_test.exs` | Trim 白名单契约 |
