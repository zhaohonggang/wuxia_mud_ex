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
  - **实现（S3 后续）**：落盘/恢复统一走 `Kantele.World.ForgeTemplates`（`encode/1`、`decode/1`、`save/1`、`load_all/1`、`file_name/1`）；启动加载挂在 `Kantele.World.Items.initialize/1`（`Kalevala.Cache` 建表后的 `{:continue, :initialize}` 回调，早于 Kickoff）。
  - **不能直接用 `Jason.encode!(%Kalevala.World.Item{})`**：该 struct 的 `Jason.Encoder` 走 `Kalevala.Meta.Trim`，而 `Kantele.World.Item.Meta` 的 trim 只留 `:damage`/`:armor`（那是给事件传输裁剪的）。直接落盘会丢 `item_make`/`owner_id`/`owner`/`skill_type`/`unit`/`weight`/`value`/`material`/`messages`，重启后 `discard` 退款失效、自定义文案消失。故改用显式字段编码 + `version`。
  - **落盘文件名**：`item_id` 里的 `:` 在 Windows 是非法文件名字符（Docker Desktop 绑定挂载会写成私用区 `U+F03A`，仓库里出现过这种文件），`file_name/1` 统一换成 `-`；`id` 仍从 JSON 内容读，不受文件名影响。
  - **目录可配**：`config :ex_venture, :forge_dir`（默认 `data/forge`；`config/test.exs` 指到 `tmp/forge_test`，避免测试把 JSON 写进仓库）。
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

#### S1b 勘误 — 币值单位漏乘 10000（2026-10-28 修正）
初版 `handle_material` 把 `power_point*2+20` 直接写进 `session.value`，但该值是要跟
`KItem.currency_amount/1`（单位**文**）比较的。对照 LPC `moye.c`：

```c
val = ob->query("power_point") * 2 + 20;                       // L377 报价（两黄金）
message_vision(..."需要" + chinese_number(val) + "两黄金。\n"...);  // L378
val *= 10000;                                                  // L381 ← 换算成文
if (wizardp(me)) { ... val = 1; }                              // L382-388
ob->set("item/value", val);                                    // L389
```

`ob->value()` 的定义在 `inherit/item/money.c` L6：`query_amount() * base_value`，而
`clone/money/gold.c` 的 `base_value = 10000`，确实是文。少了这个 `* 10000`，
实际只收 220 **文**而不是 220 **两黄金**（差 1 万倍），等于白送。

- 修正：`value = price * 10_000`；报价文案仍用 `price`（两黄金）。
- 顺带补上 LPC L382-388 的**巫师特权**：`wizardp(me)` 时多一句「原来是巫师啊，那么你随便给点好了。」且实收 1 文。
  巫师标记沿 `give` 事件链下发（`give_command` 用 `Kantele.Admin.Access.wizardp/1` 取值 → `room/give` 的 `wizard:` → `characters/give`），因为莫邪进程看不到玩家角色本体。
- 连带修正：`session.value` 是文，`forge_customize` 把它写进 `item.meta.value`（LPC `ganjiang.c` L1018 `set("value", info["value"])` 同源），`discard` 退款 `(value*8/10+9999)/10000` 才得出「两黄金」——整条链因此自洽。
- 测试：`forging_accept_test` 金额断言改为 `2_200_000` 文；新增「巫师 → value=1 + 巫师文案」用例。


### S1c — AnswerCommand 选型 ✅ 已完成（2026-10-27）
- `lib/kantele/world/forging_answer.ex`（`ForgingAnswer.answer`，对应 LPC `moye.c do_answer` L484-554）：校验 `type ∈ session.types` 且 `type_entry` 存在 → 填 `ctype/stype/unit/point/owner*/wscale/prop`；干将在场→`status=handoff`+发 `forge/handoff`；不在→退材料退钱+清会话+发 `forge/refund`。
- `answer_command.ex` 扩展 `answer` 动词（`text(:rest)`），活跃会话时经 `room/forge_answer` 转交莫邪；`room.ex` 新增 `ForgeAnswerRequestEvent`；`events.ex` 注册 `forge/answer`(NonPlayerEvents) 与 `forge/refund`(GiveEvent)；`give_event.ex` 玩家侧 `forge_refund/2` 重新入背包。
- **验收**：`forging_answer_test.exs` 8/0（handoff 填字段+转交+事件 / refund 退材料退钱清会话+事件 / 非法类型会话不变 / 无会话返回 / AnswerCommand 解析与 stub 路由）；S1b 10/0、show 7/0 全绿。

### S2 — 干将锻造链 ✅ 已完成（时序于 2026-10-28 按 LPC 补全，见 §6.6）
- 干将进程收 `forge/handoff`：材料入包 → `status="waiting"` → 按 LPC `call_out`
  时序分七跳广播 vision（`prepare` 1s → step1 5s → step2 6s → step3 3s →
  step4 5s → step5 3s → step6 2s）→ step6 才 `status="inputing"` 并排 240s 等待。
- `注内力` 命令（新 verb，门控 `status=="waiting"` + `can_help`，即 step1→step2 的
  6 秒窗口）：stat 门槛 + 扣内力 + `point += point*force/800`。
- **验收**：`ganjiang_event_test` 6/0、`zhuneili_command_test` 12/0、`forging_timeout_event_test` 8/0。

### S3 — 定制 + 生成物品
- `ForgeCustomizeCommand`：`name`（中/英代号、长度/非法字符校验）、`desc`/`wieldmsg`/`unwieldmsg`（默认文案、非法字符）、`finish`（展示摘要 → 确认 → 动态模板 + 实例化 + 入包 + 清会话）。
- 动态模板注册（§1.5）+ 落盘。
- **验收**：完整走通生成物品且字段正确；未起名拒绝 finish；默认文案兜底。

#### S3 后续 — 持久化可恢复（已完成）
原实现用 `Jason.encode!(%Kalevala.World.Item{})` 落盘，且**没有任何启动加载**，等于「写了但恢复不了、且写的内容还缺字段」。本次补齐：
- 新增 `lib/kantele/world/forge_templates.ex`：显式字段编码（保留 `meta` 全量字段）、`decode` 还原 `%Meta{}` 并把 `messages` 键还原成 atom（消费端 `wield_command` 用 `Map.get(messages, :wield)`）、`save` 写盘、`load_all` 容错加载（坏文件跳过 + warning）。
- `Kantele.World.Items.initialize/1` 调 `load_all/0`，`try/rescue` 兜底（模板坏了不能让物品缓存起不来）。
- `config :ex_venture, :forge_dir`（dev `data/forge` / test `tmp/forge_test`）；`forge_customize_command_test` 改用临时目录，删除误提交的 `data/forge/forge：player-....json`。
- **验收**：`forge_templates_test.exs` 9/0（往返保真 / messages atom 键 / 未知键忽略 / save+load_all / 坏文件跳过 / 目录缺失 / 启动钩子 / 目录不可用仍 `:ok`）；`forge_customize_command_test` 13/0 且新增「落盘保留 item_make/owner_id/messages」断言。

### S4 — 边界：退款/乾坤袋/超时
- `discard` 退款：`n=(value*8/10+9999)/10000` 金，仅 `item_make && owner_id==玩家`，移除物品、给退款。✅ 已完成（#153）
- 乾坤袋：`qiankun stone` 分支 → 背包 +5。✅ 已完成（见下）
- time_out：✅ 已实现（`forge/quote_timeout`，30s；玩家不在场则把材料/定金掉在房间地上）。
- **验收**：退款金额、非本人/非自制拒绝、乾坤袋分支。

#### S4 乾坤袋 — 已完成
LPC 三条路径（`moye.c` `do_show` L213 / `accept_object` L328-366 / 付钱 L433）：
- `show 乾坤石` → 两段说明（可炼制 500 两黄金 / 可免费升级 +5 格），**不是**估价 → `ShowCommand`。
- `give 乾坤石`（玩家无背包）→ 报价 `value/60` = 500 两黄金，`status=item_gived`、`qiankun: true`，石头收进莫邪背包 → `ForgingAccept.handle_qiankun/7`。
- `give 乾坤石`（已有背包）→ 免费 +5 格，**不建会话**；`≥100` → 「已经强化到极限了」。
  - 偏差：LPC 对 `space == 100` 无分支（掉到函数末尾返回 0），这里按「已到极限」处理。
- 付足钱 → 给如意乾坤袋（`grant_item_id`），石头 `destruct`（从莫邪背包移除），清会话。

关键实现约束：**本仓没有角色级 `storage_bag` 属性**，扩展格挂在背包**实例** meta 上。
- 玩家背包格数由 `give_command` 随 `room/give` → `characters/give` 事件带到莫邪进程（`bag_extra`），莫邪据此判定「升级 or 报价」。
- 升级由**玩家进程**落地（`forge/accept` 回执带 `upgrade_bag: 5`），只写该实例 `meta["storage_bag"]`，
  绝不改全局物品定义 —— 否则一个玩家的升级会摊到所有人身上。
- `Forging.instance_extra/1` 统一「实例 meta 覆盖定义 meta」的取值规则，`backpack_command.bag_state/1` 也改走它，
  这样升级后 `bag`/`store`/`take` 的容量立即生效。

数据（`data/world/signature.ucl`）：新增 `qiankun_stone`（value=30000 → 报价 500 两黄金，别名 `qiankun stone`）
与 `qiankun_bag`（`storage_bag = 1`）。乾坤石目前**没有刷新点**（无掉落/任务来源），属有意留白。

**验收**：`forging_qiankun_test.exs` 7/0（show 两段说明 / 无背包报价 / 有背包 +5 / 达 100 拒绝 / 付钱给袋+销毁石头 / 玩家侧给袋 / 玩家侧升级且定义不变）；
`signature_npc_test` 同步物品清单并校验元数据。

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
1. **`call_out`**：已用 `Process.send_after` + 令牌复刻（`Kantele.World.ForgingTimeout`，
   见 §6.6）。仍有一处语义差异：LPC `in_input(me)`（玩家正在输入编辑器里）本仓没有
   对应概念，`waiting` 的「催促」分支一律按「不在输入」处理。
2. **time_out**：已实现（`forge/quote_timeout`，30s 退料退款；玩家不在场则掉地上）。
3. **护甲 `armor_prop`**：LPC 用 `apply_armor()` 动态公式，v0 简化为按 `point` 推导 armor 值（在 `prop_segment` 阶段明确标注为近似）。
4. **物品持久化**：LPC 写 `.c` 文件 → ETS 模板 + `data/forge/*.json` 落盘，启动加载。
5. **货币**：LPC 内部以「文」存储（`val*=10000`）、显示「X 两黄金」。本系统币制以 `Item.is_currency?`/`currency_amount` 为准（实现 S0/S1b 时确认），估价与退款映射到对应币种。
6. **动词**：`help` 被帮助系统占用，锻造「注内力」改用 `注内力`；`answer` 为未开放 stub 可接管；`show`/`finish`/`discard` 实现时 grep 确认未被占用。
7. **乾坤袋**：本仓背包系统（`storage_bag` + `bag/store/take`）已具备，S4 该支**已实现**。
   与 LPC 的差异：LPC 用角色属性 `query("storage_bag")`，本仓用背包实例 meta（见 §3 S4 乾坤袋）；
   `space == 100` 的 LPC 空分支按「已到极限」处理。乾坤石暂无刷新点。

## 6.5 LPC 对齐复查（2026-10-28，逐条对照源文件后修正）

用户要求「都按照 LPC 来做」，于是把此前只记录、未处理的偏差全部按源文件改掉：

| # | 问题 | LPC 依据 | 处理 |
|---|---|---|---|
| 1 | 材料报价漏乘 10000（实收 220 文而非 220 两黄金） | `moye.c` L377-381 `val *= 10000`；`money.c` L6 + `gold.c` `base_value=10000` | ✅ 已修（见 §3 S1b 勘误） |
| 2 | 巫师打造无折扣 | `moye.c` L382-388 `wizardp(me)` → `val = 1` + 专属台词 | ✅ 已补，标记沿 give 事件链下发 |
| 3 | 报价用阿拉伯数字 | `moye.c` L240/L356/L379 `chinese_number(val)` | ✅ 新增 `Kantele.Util.ChineseNumber`（逐分支移植 `chinesed.c`），并让 `Kantele.Economy.Money` 也复用它 |
| 4 | `注内力` 失败无代价 | `ganjiang.c` `do_help` L324-352：逐项扣、逐项判，失败把该项**归零**（jing→0 / qi→0 / neili→0），已扣的 jing/qi 不退 | ✅ 已按原语义重写 `ZhuneiliCommand`，文案也用原文 |
| 5 | `注内力` 门控文案 | `do_help` L313-323：`没你什么业务。` / `现在不是你帮忙的时候！` | ✅ 已改（status 放行 `waiting` 与 `inputing`，见下注） |
| 6 | `Stats.effective/2` 未折半 | `feature/skill.c query_skill(skill)`：`apply + skills[skill]/2 + skills[map[skill]]` | ✅ 改为 `div(skills[usage],2) + skills[special] + apply_of(applies)`，并新增可选 `applies` 参数 |
| 7 | 6 段锻造 vision 从未送达玩家 | LPC `message_vision` 是房间广播 | ✅ `ganjiang_event` 改走 `Helpers.broadcast_vision/4`（原用 `Room.message_vision/3`，该函数发 `{:vision_message, ...}` 而角色进程只处理 `{:room_message, ...}`，等于扔进黑洞） |

**关于 #5 的状态名**：LPC 判的是玩家 temp `item/status == "waiting"`。本仓把干将
6 段 vision 合并成即时广播，`waiting` 与 `inputing`（起名阶段）同时成立，所以两者
都放行；真正的窗口判据是 `can_help`（LPC 在 `work_step_1` 置位、`work_step_2` 删除）。

**关于 #6 的 `apply` 部分**：`effective/3` 新增可选 `applies` 参数，并新增
`Kantele.Character.Combat.skill_applies/1`（安全取值：角色无 `combat` 时返回 `%{}`）。
全部 21 个调用点已接线，装备 `armor_prop`（如护腕加各兵器技能）现在会计入有效等级：

- 命令：`cut` / `jingzuo` / `skill` / `skills` / `注内力`
- 事件：`exercise` / `respirate` / `jingzuo`
- 战斗：`performs/simple`（`{:effective, id}` 表达式）、`chousui_zhang/dan`、
  `furong_jinzhen/xian`、`riyue_bian/chan`、`riyue_bian/he`
- 地形：`terrain_move`（eyutan 轻功阈值）

**连带影响**（折半后必须同步的既有断言，全部按 LPC 语义改为新值）：
`skills_command_test`（有效 75→45）、`skill_command_test`（30→15、30→25）、
`cut_command_test`（force 20→10）、`furong_jinzhen_test`（ap 180→90）、
`riyue_bian_test`（ap 200→150、240→180）、`room_actions_terrain_move_test`
（eyutan 轻功阈值 dodge 200/100 → 260/240，因为判据是有效等级）。
新增 `stats_effective_test`（11 例）锁住 `effective/3` 与 `skill_applies/1` 的语义。

## 6.6 `call_out` 定时链（2026-10-28，S2/S3 时序补全）

LPC 的锻造是**有时序**的：开炉 1 秒、注内力窗口 6 秒、报价 30 秒不付就退款、
起名最多拖 4×5 分钟。此前本仓把整条链折叠成 `handoff` 里的即时广播，
`can_help` 一置上就再没清过，等于「注内力」随时可用、材料永不退回。

### 机制

本仓没有 `call_out`，用 `Process.send_after/3` 把事件投回**排程的那个 NPC 进程**
（`exercise/tick`、`combat/tick` 同一套做法），再由 `Kalevala.Character.Foreman`
的 `%Event{}` 分支分发。

- `Kantele.World.ForgingTimeout` —— 排程原语：`schedule/4`、`cancel/1`、`valid?/2`
  + 四个 LPC 常量（30 / 240 / 300 / 4）。
- `Kantele.Character.ForgingTimeoutEvent` —— 两个处理器：
  `forge/quote_timeout`（莫邪进程）、`forge/waiting`（干将进程）。
- `Kantele.Character.GanjiangEvent.step/2` —— `forge/step`，`prepare` 与 `1..6` 七跳。

**取消机制用令牌而非 ref**：每次排程往会话写 `:timer_token`，事件带上排程时的令牌，
触发时与会话不符即视为已被新排程取代。这样跨进程（莫邪排程、玩家进程 `answer`）
也能取消 —— LPC 的 `remove_call_out` 在跨进程场景下本来也做不到。

**时间缩放**：`config :ex_venture, :forge_timing_scale`（生产 1，测试 0）。

### 时序表（LPC 秒数）

| 跳 | 间隔 | 内容 | 会话变化 |
|---|---|---|---|
| `start_work` | — | 材料入干将背包 | `status="waiting"`，`waited=4` |
| `prepare` | 1 | 开炉、抛料入炉 | — |
| `step 1` | 5 | 炉火转绿 + 请「注内力」 | `can_help=true`（玩家在场时） |
| `step 2` | 6 | 炉火转红 | `can_help=false` ← **窗口只有这 6 秒** |
| `step 3` | 3 | 锤打成型 | — |
| `step 4` | 5 | 淬火 | — |
| `step 5` | 3 | 抽出成品 | — |
| `step 6` | 2 | 起名提示 + `tell_rules`（私发 `forge/notice`） | `status="inputing"`，排 240s |
| `waiting` | 240 / 之后每 300 | 催prompt（在场）/「人怎么跑掉了」（不在场） | `waited` 递减 |
| 超时 | — | **销毁成品、不退款** | 会话清空 |

### 顺带修掉两个「整条链走不通」的 bug

1. **`find_ganjiang` 的 id 比对错了**（S1c 起就存在）：`ForgingAnswer` 拿裸
   `"ganjiang"` 比对房间角色的 `:id`，而真实 id 是 `signature:ganjiang`
   —— 生产路径**永远找不到干将**，`answer` 之后一律走「我夫君呢？」退款，
   S2/S3 整条链根本到不了。测试因为注入了 `ganjiang_pid` 没暴露。
   现统一用 `Forging.ganjiang_id/0`、`Forging.moye_id/0`。
2. **`forge/answer` 注册到了不存在的模块**：`events.ex` 里 `module(ForgingAnswer)`
   在 `scope(Kantele.Character)` 下展开成 `Kantele.Character.ForgingAnswer`，
   而模块实际叫 `Kantele.World.ForgingAnswer` —— 路由到 `apply/3` 会
   `UndefinedFunctionError`。已把该模块移入 `Kantele.Character` 命名空间
   （`lib/kantele/character/events/forging_answer.ex`），与 `GanjiangEvent` 一致。
   `ForgingTimeout` 同样拆成「World 原语 + Character 事件」两层。

### 验收

- `forging_timeout_event_test.exs` 8/0（报价超时在场退款 / 不在场掉地上 / 已付款
  连定金一起退 / 令牌过期不动作 / 催促并重排 / 归零销毁不退款 / 玩家进程消失 /
  玩家离开房间只提醒）
- `ganjiang_event_test.exs` 6/0（`start_work` 状态、七段文案按序、`$N` 留 `{npc}`、
  `can_help` 开关、step 6 进 `inputing` 并排等待、莫邪/玩家缺席的两条中止分支、
  陈旧令牌不生效）
- `forging_answer_test.exs` 新增「房间快照里能找到 `signature:ganjiang`」回归


## 7. 铁律
- 未经明确许可**不 commit**。
- 每切片 Docker 跑绿后再进下一切片。
- `docs/data-world-comments-progress.zh-CN.md` 每完成一批回填 §0 四件事。
