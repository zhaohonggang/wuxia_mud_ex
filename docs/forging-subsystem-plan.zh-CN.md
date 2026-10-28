# 莫邪/干将 锻造子系统 — 实现计划（分解文档）

> 本文件是「交互式自定义锻造」(LPC `moye.c` + `ganjiang.c`) 的移植分解，按「逐个建、每完成一个先验证」原则推进。
> **铁律**：未经用户明确许可，**不执行 `git commit`**。每切片在 Docker 容器内跑绿后再进入下一切片。

---

## 0. 目标与范围

把 LPC 双 NPC 实时锻造工坊（莫邪接待议价、干将实际锻造、玩家自定义并生成物品）忠实移植到 Kalevala 事件驱动架构。

**做**：`show` 估价 → 给材料/付钱 → `answer <类型>` 选类型 → 干将锻造链（即时可视化 + 可选「注内力」）→ `name/desc/wieldmsg/unwieldmsg/finish` 定制 → 动态生成物品 → 可选 `discard` 退款 / 乾坤袋升级。
**不做（明确偏差，见 §6）**：`call_out` 实时步进折叠为即时可视化；30 秒 `time_out` 暂不自动触发；护甲 `armor_prop` 公式简化；LPC 写 `.c` 文件改为 ETS 模板 + JSON 落盘。

**输入源（已确认）**
- `tmp/conv_sandbox/adm/npc_/moye.c`（莫邪，24 个 closure，议价 + 乾坤袋）
- `tmp/conv_sandbox/adm/npc_/ganjiang.c`（干将，5 个 closure，锻造链 + 定制 + 生成 + 退款）
- `data/world/signature.ucl` 已含 `ganjiang`(L150) / `moye`(L198) 的 `inquiries` 数据（ask 入口答语齐全），**无需补数据**；缺的是引擎代码。

---

## 1. 架构决策

### 1.1 交易会话状态：共享存储（取代 LPC 跨进程 `set_temp("item/...")`）
LPC 在莫邪、玩家、干将三个进程各持一份 `item/*` 临时变量。Kalevala 中跨进程读写对方 `meta.temp` 代价高，故引入：

- 新模块 `Kantele.World.Forging`（ETS 表 `:forging_sessions`，key = `character.id`）。
- 会话记录结构：
  ```
  %{
    status,            # look_working | waiting | accept | item_gived | answer_type | inputing
    value,             # 估价（内部币值，见 §6 货币说明）
    material_item_id,  # 材料 item_id（取 can_make/not_make/power_point）
    material_instance_id, money_instance_id,  # 实物实例，物理上在莫邪背包
    owner_id, owner_name,
    types,             # 允许类型列表（来自 can_make/not_make）
    ctype, stype, unit, point, prop, wscale,  # 选型后填充
    can_help,          # 是否可「注内力」
    name, sid, long, wield_msg, unwield_msg,  # 定制输入
    item_make          # 生成物标记
  }
  ```
- API：`get/1`、`put/2`、`update/2`、`delete/1`、可选 `set_timeout/2`（S4 用）。

### 1.2 GiveEvent 钩子（莫邪的 `accept_object`）
- `signature.ucl` 的 `moye` 块加 `accept = [{ kind = "forge" }]`（结构参考 `baituo.ucl:1392` 的 `accept` 块）。
- `lib/kantele/character/events/give_event.ex`：
  - `match_accept_rule` 增加 `rule_hit(%{kind: "forge"}, _item)` → 返回 `:forge` 信号（L155 兜底分支前插）。
  - `handle_accept_give` 收到 `:forge` 时改调 `Kantele.World.ForgingAccept.handle(conn, npc, item_instance, data, from_id)`，由其产出定制 vision 并更新会话（替代通用 `take_message`）。
- `ForgingAccept` 实现 LPC `accept_object` 状态机：状态 `look_working`/`waiting`（拒收）、`accept`（同客人校验）、`qiankun stone`（乾坤袋分支，S4）、`material_attrib && power_point`（估价、记 `item_gived`）、`money_id`（枚举 `types`、记 `answer_type`）。

### 1.3 命令动词与冲突处理
| LPC 动词 | 动作 | 本系统处理 | 门控 |
|---|---|---|---|
| `show <材料>` | 估价 | **新** `ShowCommand`（`show` 当前未被占用，需调研确认） | 莫邪在场 |
| `answer <类型>` | 选型 | **扩展** `AnswerCommand`（`lib/.../answer_command.ex` 现为未开放 stub，可安全接管） | 会话 `status==answer_type` |
| `name/desc/wieldmsg/unwieldmsg` | 定制 | **新** `ForgeCustomizeCommand`（一个模块挂多 verb） | 会话 `status==inputing` |
| `finish`/`完成` | 生成 | 同上 | 会话 `status==inputing` 且 `name` 已设 |
| `help`/`帮助`（注内力） | 注内力 | **改名** `注内力`（全局 `help` 是帮助系统，`commands.ex:257`，不可占用） | 会话 `status==waiting` 且 `can_help` |
| `discard` | 退款 | 复用或新 `ForgeDiscardCommand`（需先确认 `discard` 未被占用） | 持有 `item_make` 且 `owner_id==玩家` |

> **动词冲突已确认**：`answer`（stub，可接管）、`help`（占用，锻造改用 `注内力`）。`show`/`finish`/`discard` 实现时再 grep 确认。

### 1.4 锻造链（S2）跨进程编排
`answer` 在**玩家进程**执行，需把材料实例从莫邪移到干将并触发锻造链：
- 发 `forge/handoff` 事件给干将进程（参考 `give` 事件的跨进程 `send` 模式，`give_event.ex:54`）。
- 干将进程收到后：把材料实例移入自身背包 → 即时爆发 6 段 room-vision（开炉→绿火→锤打→淬火→检视→移交莫邪命名）→ 设会话 `status=inputing` → 提示 `name`。
- `注内力` 在 `waiting` 期间可用（单次，`can_help` 标志），门槛：精≥180/气≥300/内力≥800/最大内力≥1000，耗 200 内力，`point += point*force/800`。

### 1.5 物品生成（S3）
- 新模板 `item_id = "forge:#{owner_id}-#{sid}"`，经 `Kalevala.Cache.put`（ETS，需确认 `Kantele.World.Items` 的 put API）注册，并落盘 `data/forge/<item_id>.json` 以便重启恢复（启动期加载，挂在 loader 或 forge bootstrap）。
- 字段计算：
  - `type`=weapon/armor，`stype`（sword/blade/…/armor/cloth/…），`unit` ← 类型表（§2）。
  - `weight = material.meta.weight * wscale / 100`。
  - `value` = 估价（§6 货币）；`point`（伤害）= `material.power_point * 类型表[arg].point / 100`（+ 注内力加成）。
  - `material = material_attrib`，`item_make = true`，`owner_id/owner_name`，`name`，`long` = 玩家 desc + 炼制铭文（`owner_name(owner_id)`），`wield_msg`/`unwield_msg`（玩家输入或默认）。
- 实例化 `%Kalevala.World.Item.Instance{id: generate_id(), item_id:, created_at:}` 入玩家背包；消耗莫邪处的材料+钱币实例；爆发 vision「干将把 X 交给了你」；清会话。

---

## 2. 类型表（moye.c L22–92，S1c/S3 选型与生成的唯一真源）

| 中文类型 ctype | type | stype | unit | 分量 weight | 点数 point | prop |
|---|---|---|---|---|---|---|
| 刀 | weapon | blade | 把 | 150 | 100 | 0 |
| 剑 | weapon | sword | 柄 | 150 | 100 | 0 |
| 棍 | weapon | club | 根 | 150 | 100 | 0 |
| 杖 | weapon | staff | 根 | 150 | 100 | 0 |
| 锤 | weapon | hammer | 把 | 350 | 100 | 0 |
| 斧 | weapon | axe | 把 | 220 | 100 | 0 |
| 鞭 | weapon | whip | 根 | 150 | 100 | 0 |
| 短兵 | weapon | dagger | 支 | 30 | 100 | 0 |
| 护甲 | armor | armor | 张 | 150 | 80 | armor_prop(parry/armor) |
| 战衣 | armor | cloth | 件 | 200 | 100 | 0 |
| 靴子 | armor | boots | 双 | 60 | 40 | armor_prop(dodge/armor) |
| 头盔 | armor | head | 顶 | 75 | 50 | 0 |
| 腰带 | armor | waist | 条 | 80 | 40 | 0 |
| 护腕 | armor | wrists | 对 | 50 | 25 | armor_prop(技能/armor) |
| 箫 | weapon | xsword | 支 | 30 | 100 | 0 |
| 铁掌 | armor | hands | 双 | 45 | 100 | armor_prop(cuff/strike/…) |
| 指套 | armor | hands | 套 | 35 | 100 | armor_prop(claw/finger/…) |

> 该表**硬编码**进 `Kantele.World.Forging` 模块（对应 LPC `item_type` mapping），`can_make`="all" → 全部键，`not_make` 从中剔除。

---

## 3. 子切片分解（每个切片独立可验证）

### S0 — 字段 + loader 解析 + 材料回填
- **目标**：物品具备锻造所需元数据。
- **改动**：
  1. `lib/kantele/world/item.ex` `Item.Meta` 默认表（L330 附近）加 `{:material_attrib, nil}` 与 `{:item_make, false}`（注：`can_make/not_make/power_point/item_origin` 已存在 L330-333）。
  2. `lib/kantele/world/loader.ex` `parse_item_meta`（L1403-1437）补 `material_attrib: Map.get(meta, :material_attrib)`、`item_make: to_bool(Map.get(meta, :item_make))`。
  3. 写回填脚本 `scripts/backfill_forge_materials.py`：为锻造材料（玄铁石/天蚕丝/乾坤石 等，从 `tmp/conv_sandbox` 或源 `.c` 抽取 `material_attrib`/`power_point`/`can_make`/`not_make`）写 UCL `meta`。
- **验收**：`probe` 脚本验证 loader 读到值；`mix test` 全绿；无行为变化（P7）。

### S1a — ShowCommand 估价 ✅ 已完成（2026-10-27）
- 新 `lib/kantele/character/commands/show_command.ex`：`run(conn, %{"rest"=>arg})` 取背包物品 → 查 `material_attrib`/`power_point` → 无则「这种东西也能用来炼制，我没听说过」/「这样原料看来已经是锻造不了了」；有则 `value = power_point*2+20`，发「只需要 X 两黄金」。
- `commands.ex` 注册 `show` verb。
- **验收**：单元测试（有/无 material_attrib、无 power_point 三路）→ `show_command_test.exs` 7/0；回归 show+fuse 19/0、in_game_commands 664/0 全绿。
- 注意：注册表用 `Kantele.World.Items`（非 `Kalevala.World.Items`，后者本仓 `nofile`）。

### S1b — forge accept 议价（给材料/付钱给莫邪）✅ 已完成（2026-10-27）
- `signature.ucl` 莫邪加 `accept = [{ kind = "forge" }]`。
- 新 `lib/kantele/world/forging.ex`（共享 ETS `:forging_sessions` + 17 项类型表 + `types_for/2`）。
- 新 `lib/kantele/world/forging_accept.ex`（`ForgingAccept.handle`，实现 §1.2 状态机：material→item_gived / money→answer_type / 异常分支）。
- `give_event.ex` 加 `kind:"forge"` 分支 + 玩家侧 `forge_accept/2`。
- **验收**：`forging_accept_test.exs` 10/0（材料估价+记 item_gived、钱币足额枚举 types+answer_type、金额不足拒绝、未交先给拒绝、非材料非钱拒绝、玩家侧 ok:true 移除+ok:false 保留、端到端 GiveEvent.receive 命中 forge、Forging.types_for 全量/剔除/列表/字符串）。

### S1c — AnswerCommand 选型 ✅ 已完成（2026-10-27）
- `lib/kantele/world/forging_answer.ex`（`ForgingAnswer.answer`，对应 LPC `moye.c do_answer` L484-554）：校验 `type ∈ session.types` 且 `type_entry` 存在 → 填 `ctype/stype/unit/point/owner*/wscale/prop`；干将在场→`status=handoff`+发 `forge/handoff`；不在→退材料退钱+清会话+发 `forge/refund`。
- `answer_command.ex` 扩展 `answer` 动词（`text(:rest)`），活跃会话时经 `room/forge_answer` 转交莫邪；`room.ex` 新增 `ForgeAnswerRequestEvent`；`events.ex` 注册 `forge/answer`(NonPlayerEvents) 与 `forge/refund`(GiveEvent)；`give_event.ex` 玩家侧 `forge_refund/2` 重新入背包。
- **验收**：`forging_answer_test.exs` 8/0（handoff 填字段+转交+事件 / refund 退材料退钱清会话+事件 / 非法类型会话不变 / 无会话返回 / AnswerCommand 解析与 stub 路由）；S1b 10/0、show 7/0 全绿。

### S2 — 干将锻造链
- 干将进程收 `forge/handoff`：移材料、即时 6 段 vision、`status=inputing`、提示 `name`/`show_order` 规则。
- `注内力` 命令（新 verb，门控 `waiting`+`can_help`）：stat 门槛 + 扣内力 + `point += point*force/800`。
- **验收**：锻造链 vision 序列、注内力门槛与加成、单次限制。

### S3 — 定制 + 生成物品
- `ForgeCustomizeCommand`：`name`（中/英代号、长度/非法字符校验）、`desc`/`wieldmsg`/`unwieldmsg`（默认文案、非法字符）、`finish`（展示摘要 → 确认 → 动态模板 + 实例化 + 入包 + 清会话）。
- 动态模板注册（§1.5）+ 落盘。
- **验收**：完整走通生成物品且字段正确；未起名拒绝 finish；默认文案兜底。

### S4 — 边界：退款/乾坤袋/超时
- `discard` 退款：`n=(value*8/10+9999)/10000` 金，仅 `item_make && owner_id==玩家`，移除物品、给退款。
- 乾坤袋：`qiankun stone` 分支 → 背包 +5（需确认角色 `storage_bag` 模型，可能依赖既有背包系统，若缺则标记待定）。
- time_out：暂不自动触发（偏差，§6）；玩家可 `discard`/重 `give` 取回。
- **验收**：退款金额、非本人/非自制拒绝、乾坤袋分支（若实现）。

---

## 4. 验证与回归
- 每切片：本地 `mix test <本切片测试路径>` 先绿，再走 Docker：
  ```
  docker exec -e MIX_ENV=test -e TEST_DATABASE_URL=postgresql://postgres:postgres@db:5432/ex_venture_test \
    wuxia_mud_dev-app-1 sh -c "cd /app && mix test <paths>"
  ```
- 全量：容器内生成 `/tmp/chunk_XX` 分 4 块跑（宿主机 `/tmp` 与容器不共享）。
- 收尾（Task #154）：Docker 4 块全绿。

## 5. 任务清单（已在 tracker）
#146 总 umbrella · #147 S0 · #148 S1a · #149 S1b · #150 S1c · #151 S2 · #152 S3 · #153 S4 · #154 全量回归。

## 6. 已知偏差与风险
1. **无 `call_out`**：锻造链折叠为即时 vision；「注内力」由 `can_help` 标志而非时间窗门控。
2. **time_out 跳过**：不自动退款；玩家手动 `discard`/重 `give` 取回材料（可接受简化）。
3. **护甲 `armor_prop`**：LPC 用 `apply_armor()` 动态公式，v0 简化为按 `point` 推导 armor 值（在 `prop_segment` 阶段明确标注为近似）。
4. **物品持久化**：LPC 写 `.c` 文件 → ETS 模板 + `data/forge/*.json` 落盘，启动加载。
5. **货币**：LPC 内部以「文」存储（`val*=10000`）、显示「X 两黄金」。本系统币制以 `Item.is_currency?`/`currency_amount` 为准（实现 S0/S1b 时确认），估价与退款映射到对应币种。
6. **动词**：`help` 被帮助系统占用，锻造「注内力」改用 `注内力`；`answer` 为未开放 stub 可接管；`show`/`finish`/`discard` 实现时 grep 确认未被占用。
7. **乾坤袋**：依赖角色背包(`storage_bag`)模型，若本仓库无对应系统则 S4 该支标记待定，不影响主线。

## 7. 铁律
- 未经明确许可**不 commit**。
- 每切片 Docker 跑绿后再进下一切片。
- `docs/data-world-comments-progress.zh-CN.md` 每完成一批回填 §0 四件事。
