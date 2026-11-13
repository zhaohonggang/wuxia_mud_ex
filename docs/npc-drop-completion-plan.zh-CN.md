# NPC 掉落物补全计划（按 LPC 原版）· 已结案

> ## 📌 归档声明 · 全库待办清零（2026-11-13）
>
> 本文件为**历史过程文档 / 阶段性快照**。文中出现的 `[ ]` `待办` `未移植`
> `后续` 等字样，一律是初版计划撰写当时的状态快照或偏差说明，**不代表当前待办**。
> 三阶段均已完成并回归通过；复选框已统一按「已结案」勾选，原文保留作历史取证。
> §8 列出的 12 个 LPC NPC 属端口未移植的世界数据范围，非代码缺口，无需排期。
>
> **唯一状态入口**：`.workbuddy-ai/memory/MEMORY.md` 与
> `docs/待办对照代码核查.zh-CN.md` §三 / §6.2。

**目的**：补全 Elixir 端口中 LPC NPC 死亡后的掉落物系统，使杀死 NPC 时尸体携带掉落物品，玩家可 `get` 拾取。

**状态（2026-11-13）**：✅ **三阶段全部完成**，代码端与数据端均已落地并通过验证。
本文保留计划原文结构作历史取证，§8 记录初版计划与真实数据的偏差及结案依据。
实现详情见 `docs/corpse-drop-system.zh-CN.md`。

**依据**：
- LPC 源码：`C:\files\git\mud\clone\quarry\*.c`、`C:\files\git\mud\clone\beast\*.c`、
  `inherit/char/quarry.c`、`inherit/char/snake.c`、`adm/daemons/chard.c`、`clone/misc/corpse.c`
- Elixir 数据：`data/world/clone_lib.ucl` 及 8 个含蛇类 NPC 的区文件
- Elixir 代码：`lib/kantele/world/corpse.ex`、`lib/kantele/character/events/combat_event.ex`、
  `lib/kantele/feature_damage.ex`、`lib/kantele/world/room.ex`

---

## 1. 当前状态总览（核查后的真实数字）

| 维度 | 数量 |
|------|------|
| LPC `clone/quarry/*.c` 中配置 item1/item2/item3 的 NPC | 30 |
| LPC `clone/beast/*.c` 中配置 item1/item2/item3 的蛇类 | 11 |
| LPC `clone/quarry/*.c` 中**无**掉落的 NPC | 8（fu/he/he2/hou/niao/niao2/niao3/song） |
| Elixir 已移植的 `quarry_*` NPC | 26（与 LPC 一一对应） |
| LPC 有、Elixir **未移植**的 quarry NPC | 12（见 §8，非代码缺口） |
| Elixir 中已配置 `drop_*` 的 `quarry_*` NPC | 19（= LPC 有掉落的已移植 NPC，全覆盖） |
| Elixir 中已配置 `drop_*` 的蛇类 `characters` 块 | 26（9 个 baituo + 17 个跨区重名定义） |
| `data/world/*.ucl` 中 `drop_a/b/c` 引用总数 | 87（悬空 0） |
| 本次新建的掉落物 item 定义 | 23（第一阶段 3 + 第三阶段 20） |

---

## 2. 第一阶段：补全已配置但不完整的 NPC ✅

| # | NPC ID | 中文名 | LPC 掉落 | 处置 |
|---|--------|--------|----------|------|
| 1 | `quarry_gou` | 野狗 | item1=gourou, item2=goupi | 加 `drop_b=goupi`；新建 `items "goupi"` |
| 2 | `quarry_lu` | 梅花鹿 | item1=lurou, item2=lurong | 加 `drop_b=lurong` |
| 3 | `quarry_xiong` | 灰熊 | item1=xiongrou, item2=xiongpi, item3=xiongdan | 修正 `drop_a`（原误配 xiongpi）、加 `drop_b=xiongpi`、`drop_c=xiongdan`；新建 `items "xiongrou"` |
| 4 | `quarry_yang` | 绵羊 | item1=yangrou, item2=yangpi | 加 `drop_b=yangpi`；新建 `items "yangpi"` |
| — | `quarry_laohu` | 老虎 | item1=hurou, item2=hupi | 附带修正 `drop_a`/`drop_b` 顺序，对齐 LPC item1/item2 |

同时补齐代码端缺口：`drop_c`（LPC item3）、`NonPlayerMeta` 的 `Meta.Trim` 白名单、
短 id → 完整缓存 key 解析、corpse `item_id` 崩溃修复。

---

## 3. 第二阶段：items 已定义但 NPC 未配置 drop ✅

| # | NPC ID | 中文名 | LPC 掉落 | 处置 |
|---|--------|--------|----------|------|
| 5 | `quarry_gui` | 乌龟 | item1=guijia | 加 `power=5`、`drop_a=guijia`（guijia 已定义） |

初版计划还列了 `quarry_lu2`，但该 NPC 在 Elixir UCL 中不存在（见 §8），已剔除。

---

## 4. 第三阶段：新建缺失 item 定义 + 配置 NPC ✅

### 4.1 新建的 20 个 item 定义（`clone_lib.ucl`）

`diaorou` `diaopi` `eyurou` `eyupi` `baorou` `zhangrou` `yingrou` `xiangrou` `xiangya`
`paorou` `langrou` `langpi` `langpi2` `jizirou` `jirou` `lirou` `lipi` `lipi2` `sherou` `shepi`

全部按 LPC `base_value` / `base_unit` / `base_weight` 填值；肉类继承 `meat.h`
的 `base_weight = 300`。其中 11 件对应「LPC 有、Elixir 未移植」的 NPC，作为预置定义保留，
将来移植那些 NPC 时可直接引用。

（第一阶段已建 `goupi` / `xiongrou` / `yangpi`，合计 23 件。）

### 4.2 12 个已存在的 quarry NPC 补齐 `power` + `drop_*`

| NPC ID | 中文名 | power | drop_a | drop_b |
|--------|--------|-------|--------|--------|
| `quarry_diao` | 紫貂 | 7 | diaorou | diaopi |
| `quarry_eyu` | 鳄鱼 | 50 | eyurou | eyupi |
| `quarry_gou2` | 狼狗 | 13 | gourou | goupi |
| `quarry_gou3` | 藏獒 | 22 | gourou | goupi |
| `quarry_gui` | 乌龟 | 5 | guijia | — |
| `quarry_lang` | 野狼 | 25 | langrou | langpi |
| `quarry_lang2` | 饿狼 | 30 | langrou | langpi |
| `quarry_laohu2` | 东北虎 | 50 | hurou | hupi |
| `quarry_yang2` | 山羊 | 7 | yangrou | yangpi |
| `quarry_yang3` | 黄羊 | 7 | yangrou | yangpi |
| `quarry_ying` | 秃鹰 | 32 | yingrou | — |
| `quarry_zhu` | 山猪 | 28 | zhurou | — |

### 4.3 蛇类 26 个 `characters` 块

LPC `clone/beast/*.c` 的 `die()` 统一 `item1 = /clone/quarry/item/sherou`、
`item2 = /clone/herb/shedan`，例外：

- `mangshe`（蟒蛇）：`item2 = shepi`
- `xuanmang`（玄冰莽蛇）：额外 `item3 = /clone/fam/pill/blood` → `clone_lib:blood`

涉及文件：`baituo.ucl`(9)、`city.ucl`、`clone_lib.ucl`(`beast_jinshewang`)、`dali.ucl`、
`foshan.ucl`、`fuzhou.ucl`、`hangzhou.ucl`、`heimuya.ucl`、`hengyang.ucl`、
`huanghe.ucl`、`lingxiao.ucl`、`lingzhou.ucl`、`shenlong.ucl`、`taohua.ucl`、
`wudang.ucl`、`xiakedao.ucl`(各 1)、`xiyu.ucl`(2)。

### 4.4 代码端关键修复（超出原计划，但必须做）

原计划 §6 写「代码端已就绪，无需代码改动」，实际核查发现 **3 个真实缺口**：

1. **尸体逻辑没有接入主路径**：正常战斗死亡走 `CombatEvent.die/3`，而尸体生成只写在
   `Feature.Damage.die/2`（仅 `smash` / `break` 调用）。→ 抽出 `Kantele.World.Corpse`
   模块，`CombatEvent.die/3` 的 NPC 分支与 `Feature.Damage.process_death/2` 都调用
   `Corpse.spawn/1`。这是「按 LPC 做」能否生效的**决定性修复**。
2. **corpse `item_id` 崩溃**：写死 `"corpse"`，缓存 key 实为 `clone_lib:corpse`；
   `get all` 遍历到尸体时 `Items.get!("corpse")` 抛异常。→ 改为解析完整 key。
3. **`drop_c` / `Meta.Trim` / 短 id 解析**：见 §2，均已补齐。

---

## 5. 实施模板（已应用）

### 5.1 新建 item 定义

```ucl
# Source: C:/files/git/mud/clone/quarry/item/<名>.c
    items "<id>" {
      name = "<中文名>"
      aliases = ["<拼音>", "..."]
      description = "<LPC long>"
      verbs = ["get", "drop", "eat"]

      meta = {
        value = <base_value>
        weight = <base_weight>
        unit = "<base_unit>"
        food = 15
      }
    }
```

> 坑：UCL 中**单独一行的 `#`**（空注释）会让 `Elias.parse/1` 抛
> `syntax error before: "\n"`。注释行必须带内容。

### 5.2 为 NPC 添加 drop

在 `characters "<id>"` 块内（顶层键，位置不限）：

```ucl
  # LPC clone/quarry/<名>.c：set("power", N) + item1/item2
  power = <N>
  drop_a = { id = "<item_id>" }
  drop_b = { id = "<item_id>" }
  drop_c = { id = "<item_id>" }
```

### 5.3 验证

- `Elias.parse/1` 逐个解析 77 个 UCL 文件：0 失败
- 87 条 `drop_*` 引用解析到物品定义：0 悬空
- `mix compile`：通过
- `test/kantele/world/corpse_test.exs`：14 tests / 0 failures
- `mix test --seed 831693`：无新增失败（基线 27 例 bcrypt NIF 环境性）

---

## 6. 进度跟踪（全部 ✅）

- [x] 第一阶段：4 个 NPC + `quarry_laohu` 顺序修正 + 代码端缺口
- [x] 第二阶段：`quarry_gui`（`quarry_lu2` 证伪，见 §8）
- [x] 第三阶段 A：新建 20 个 item 定义（合计 23）
- [x] 第三阶段 B：12 个 quarry NPC + 26 个蛇类 `characters` 块
- [x] 代码端：尸体逻辑接入 `CombatEvent.die/3` 主路径 + `corpse item_id` 崩溃修复
- [x] 回归测试：`corpse_test.exs` 14 例 + 全量 `mix test --seed 831693`

---

## 7. 验证结果

| 项 | 结果 |
|----|------|
| `mix compile`（MIX_ENV=test） | ✅ 通过 |
| `Elias.parse/1` 全库 UCL | ✅ 77 文件 / 0 失败 |
| `drop_*` 引用完整性 | ✅ 87 条 / 0 悬空 |
| `test/kantele/world/corpse_test.exs` | ✅ 14 tests / 0 failures |
| `mix test --seed 831693` | ✅ **7757 tests / 27 failures，0 新增失败**（27 例全为 `bcrypt_elixir` NIF 环境性，耗时 575.6s） |

---

## 8. 初版计划偏差与结案依据

初版计划按 LPC 文件清单直接列出待办，未先核对 Elixir UCL 是否真有这些 NPC，产生两类偏差：

**8.1 12 个「幽灵 NPC」—— Elixir UCL 中不存在，不是代码缺口**

`quarry_bao`、`quarry_hu`、`quarry_hu2`、`quarry_ji`、`quarry_jizi`、`quarry_lang3`、
`quarry_lu2`、`quarry_pao`、`quarry_xiang`、`quarry_xiong2`、`quarry_zhang`、`quarry_niao2`

核查：`grep -rl "quarry_<名>" data/world/*.ucl` 全部 `NOT FOUND`；
LPC `clone/quarry/` 下确有对应 `.c`，但端口只移植了 26 个 quarry NPC。
**结论**：这些 NPC 的「未移植」属世界数据范围问题，不是尸体/掉落系统的代码缺口；
对应的 11 件物品定义仍按 LPC 预置，将来移植 NPC 时可直接引用。本计划不再为其排期。

**8.2 计数与名称错误**

- 初版写「共 22 个新建 item」，表格实列 23 条 → 按实际 23 结案（第一阶段 3 + 第三阶段 20）。
- 初版把 `quarry_diao` 写成「雕 / 雕肉」，LPC `diao.c` 实为**紫貂**，
  `diaorou.c` 是**貂肉** → 已按 LPC 修正。
- 初版「10 种蛇类」→ 实际 LPC `clone/beast/` 有 11 种，Elixir 有 26 个 `characters` 块
  （跨区重名定义），已全部配置。
- 初版 §6 「代码端已就绪，无需代码改动」被证伪，见 §4.4。

---

**参考文档**：`docs/corpse-drop-system.zh-CN.md`（尸体掉落系统实现详情与 LPC 对照）
