# LPC→UCL 转换器扩展计划（accept_fight/hit/kill + switch + 条件链）

> 计划日期：2026-09-23
> 关联代码：`lib/kantele/world/lpc_converter.ex`、`lib/kantele/world/loader.ex`、
> `lib/kantele/character.ex`（NonPlayerMeta）、`lib/kantele/world/room.ex`、
> `lib/kantele/npc/guarder.ex`
> 语料：`C:\files\git\mud\d\`（7140 个 .c，6.78 MB）

---

## 一、现状与目标

转换器目前已支持：`init()` / `greeting()` / `accept_object()` 的语义抽取、
`permit_pass()` → 守卫（guarder）meta 抽取，以及"未处理内容"整体写入 `# UNHANDLED
CONTENT` 注释块（含函数名、switch、复杂条件、raw code block 原文）。

本计划扩展三块：

1. **`accept_fight` / `accept_hit` / `accept_kill`（+`accept_touxi`）语义抽取**
2. **`switch` 语句**：可语义化的 case 表 → 数据；不可的 → 结构化注释
3. **`else-if` 链** 与 **嵌套 `if/else`（花括号形式）**：抽台词/行为 → decisions，保留条件为参考注释

### 语料统计（真实世界覆盖）

| 模式 | 文件数 | 说明 |
|---|---|---|
| `accept_fight` | 68 | 是否接受切磋（return 0/1） |
| `accept_hit` | 23 | 是否接受被 hit（通常接受即反杀） |
| `accept_kill` | 25 | 是否接受被杀（拒绝则自保/召唤帮手） |
| `accept_touxi` | 1 | wudunru 特有偷袭判定 |
| fight+hit+kill 三位一体 | 20 | 一个 NPC 同时定义三个（如 shouwei） |
| `switch` 语句 | 121 | 含 case-assign 简单赋值风 5 个 |
| `else-if` 链 | 103 | 多分支条件行为 |
| 嵌套 `if/else`（花括号） | 115 | 与 else-if 有重叠；总计含任意复杂结构 290 |

---

## 二、设计总览

### 2.1 语义抽取分级

| 级别 | 含义 | 适用 |
|---|---|---|
| **L1 语义化** | 转成可运行的 UCL 数据 + Loader + 运行时接线 | accept_fight/hit/kill，case-assign switch |
| **L2 半语义** | 转成结构化数据保留，但运行时只做展示/记录 | 台词池 switch、条件台词 decisions |
| **L3 注释** | 原文保留到注释（现状），但**改进格式，标注函数名+行号** | 复杂 if/else 行为逻辑、状态机 switch |

### 2.2 运行时语义（LPC 对照）

| LPC 函数 | return 语义 | 本框架落点 |
|---|---|---|
| `accept_fight(ob)` | 0 拒绝切磋 / 1 接受 | `combat/attack` 事件（`room.ex`），`engage` 前判断 |
| `accept_hit(ob)` | 0 拒绝 / 1 接受并反击 | 同上 |
| `accept_kill(ob)` | 0 拒绝被杀 / 1 接受死，或自保 | 同上 |
| `kill_ob(ob)` | 触发反杀 | 抽取为 `retaliate = true`，运行时对攻击者发 `combat/start` |
| `destruct(this_object())` | 离开场景 | 抽取为行为标记（暂不自动执行） |
| `call_out(...)` / 召唤 | 定时/召唤帮手 | 抽取为 `spawn` 目标，运行时映射 Coagent |

---

## 三、`accept_fight` / `accept_hit` / `accept_kill` 语义抽取

### 3.1 AST 扩展

`lib/kantele/world/lpc_converter/ast.ex` 新增字段：

```elixir
defstruct [..., :engage]   # %{fight: %{...}, hit: %{...}, kill: %{...}} | nil
```

### 3.2 Converter 抽取（`lpc_converter.ex`）

仿照 `extract_guard`（基于 `extract_function_body/2`），新增：

```elixir
defp extract_engage(content) do
  %{
    fight: extract_accept_fn(content, "accept_fight"),
    hit:   extract_accept_fn(content, "accept_hit"),
    kill:  extract_accept_fn(content, "accept_kill"),
  }
  # nil 化空的键
end
```

`extract_accept_fn(content, name)` 解析单一函数（复用 `get_last_return/1`）：

```elixir
# %{accept: true|false, mssg: nil|台词, retaliate: bool, spawn: [id], note: 原文}
defp extract_accept_fn(content, fn_name) do
  with body <- extract_function_body(content, fn_name) do
    %{
      accept:    get_last_return(body) == 1,          # 最后一个 return 0/1
      msg:       extract_engage_msg(body),            # command("say ...")/message_vision 首条
      retaliate: Regex.match?(~r/kill_ob\s*\(/, body), # 是否反杀
      spawn:     extract_spawn_ids(body),             # new/present 的帮手 id
      note:      body                                # 原文保留（L3 兜底）
    }
  end
end
```

### 3.3 UCL 输出（`build_engage_ucl`）

```ucl
  engage = {
    fight = { accept = false, msg = "小女子哪里是您的对手？" }
    hit   = { accept = true, retaliate = true, msg = "找死。" }
    kill  = { accept = false, spawn = ["bao_biao"], msg = "要杀人了，快来人救命啊！" }
  }
```

`accept` 值映射规则（沿用 `get_last_return` 的启发式）：
- 只有 `return 0` → `accept = false`
- 只有 `return 1` → `accept = true`
- 两者皆有 → 取**最后一个** return（与 accept_object 默认规则一致）
- 检测 `kill_ob` 但 return 0 → `accept = false, retaliate = true`（拒绝但反杀，如 wudunru/huangyi）

### 3.4 规则边界（启发式优先级）

| 条件模式 | 抽取结果 | 例子 |
|---|---|---|
| `if (userp(ob)) { message_vision(...); return 0; } return ::accept_x(ob);` | `accept=false` + 拒绝台词；`::` 继承调用注记到 `note` | shouwei |
| `if (mark == X) { command("say ..."); return 0; } else { command("say 找死"); kill_ob; return 1; }` | `accept=true, retaliate=true, msg=最后分支台词` | wudunru |
| `command("say ..."); return 0;` | `accept=false + 台词` | huangyi accept_fight |
| 满血量 + 次数限制 + `call_out("checking")` + `return 1` | `accept=true`，`note` 保留 call_out/限制原文 | jiang |

> 原则：**只自动抽取到"是否接受 + 台词 + 反杀 + 召唤"四类可运行信息**，其余逻辑原文进 `note`，
> 宁可不猜也不误杀行为。

### 3.5 Loader 解析

`loader.ex` `parse_character` 增加：

```elixir
engage: parse_engage(Map.get(character_data, :engage)),
```

```elixir
defp parse_engage(nil), do: nil
defp parse_engage(e) when is_map(e) do
  Enum.reduce([:fight, :hit, :kill], %{}, fn key, acc ->
    case Map.get(e, key) do
      %{} = r -> Map.put(acc, key, %{
                    accept: to_bool(Map.get(r, :accept, true)),
                    msg:    string_or_nil(Map.get(r, :msg)),
                    retaliate: to_bool(Map.get(r, :retaliate, false)),
                    spawn: List.wrap(Map.get(r, :spawn, [])) |> Enum.map(&to_string/1)
                  })
      _ -> acc
    end
  end)
  |> case do %{} -> nil; parsed -> parsed end
end
```

### 3.6 NonPlayerMeta 扩展

`lib/kantele/character.ex` `NonPlayerMeta` defstruct 增加 `:engage`（nil = 无规则），
文档注释补一段。

### 3.7 运行时接线（`room.ex` + `guarder.ex`）

`combat/attack` 的 `dispatch`（room.ex:2255）在 `engage` 之前，追加（放在守卫判定之后、
`trigger_guarded_allies` 之前）：

```elixir
engage_deny?(target, attacker, event) ->
  # 读取 target.meta.engage[type]，type∈fight/hit/kill
  # accept=false → 渲染拒绝台词并返回上下文（不开战）
```

并在 `engage` 后若 `engage.retaliate == true`（对 NPC 被 kill/hit 且选择反杀），
向攻击者发 `combat/start`（ref 反转），使 NPC 主动开战——对应 LPC `kill_ob`。
> **实现注**：未单独做 ref 反转；`engage/3`→`start_combat` 本就对双方各发一次 `combat/start`
> （room.ex:2468-2480），被攻击 NPC 同样入场，反杀效果等效达成。`retaliate` 键已落 loader/meta。

`spawn` 处理：本轮**只落位不自动执行**（似 `coagents` 现状：loader 落表，运行时 Coagent
接线是独立的后续任务）。`Guarder.check_enemy` 仍是 kill 类场景的守卫专属路径，两者并存：
守卫逻辑优先（guarder_deny/kill），普通 NPC 走 `engage` 规则。

> 现有优先级（不改动）：`no_fight` → 名字缺失/未找到 → `dead?` → `guarded_deny?`
> → 守卫判定（guarder） →（新增）engage 规则 → engage。

### 3.8 测试计划（新增）

`test/kantele/world/lpc_converter_engage_test.exs`：

- shouwei：`accept_fight/hit/kill` 都 `accept=false`，msg 含 `{npc}/{name}`，`::accept_*` 注记
- wudunru：`accept_hit/kill` 是 `accept=true, retaliate=true`；`accept_fight` 是 false
- jiang：`accept_fight=true`，note 含 `call_out` 原文
- huangyi：`accept_kill` 抽取 `spawn=["bao_biao"]`
- duke（无 engage 函数）→ `enggage nil`

`test/kantele/world/loader_engage_test.exs`：
- test.ucl 新增 engage 块解析 → NonPlayerMeta.engage 结构正确
- 缺省 `accept` 缺省 true、`retaliate` 缺省 false

`test/kantele/world/room_combat_attack_test.exs`（运行时）：
- NPC `engage.fight.accept=false` → 玩家 `fight` 被拒，不出 `combat/start`
- NPC `retaliate=true` → 玩家 `hit` 后 NPC 反向开战
- 守卫 vs engage 并存：守卫 NPC 击杀路径不变
> **未实现**：本文件未写（见 §六状态注）。运行时逻辑由 EnganeRule 纯函数单测 + fight_command_test 覆盖。

---

## 四、`switch` 语句处理

### 4.1 现状与分级

| switch 类型 | 例 | 文件数（估） | 处理 |
|---|---|---|---|
| **case-assign 表**（case→常量赋值） | xiaoer `do_exchange` 兑换表 | 5 | **L1：转 mapping** |
| **台词池** switch(random(N)) | accept_ask/greeting 随机台词 | ~40 | **L2：转台词池**（并入 greeting/inquiries 类似结构） |
| **状态机/命令分发** switch(arg) | 复杂逻辑 | ~75 | **L3：结构化注释** |

### 4.2 L1：case-assign 表 → mapping

识别模式（`case "键": 变量 = 值; [变量 = 值;] break;` 且有 default）：

样例 `do_exchange`：

```lpc
switch (arg) {
  case "血菩提": cost = 5; ob = new("/clone/fam/pill/puti1"); break;
  ...
  default: return notify_fail("你只能兑换规定范围内的物品。\n");
}
```

Converter 抽取为 `unhandled.switch_tables`：

```
# ==== SWITCH TABLE (do_exchange) ====
# 键          cost   产物
# "血菩提"    5      /clone/fam/pill/puti1
# ...
```

以**注释表格**而非 UCL 结构输出（本轮），因为兑换系统在 K 端无对应运行机制；
设计成规整注释便于 AI/人工迁移到任务/商店模块。

实现：`parse_switch_table(body)` —— 从函数体 `switch(arg){...}` 提取各 `case` 块，
按 `\w+\s*=\s*value` 拆分列。

### 4.3 L2：台词池 switch → 台词池

`random(N)` switch 且每个 case 都是单一 `return "..."` / `say("...")`（如 accept_ask/greeting）：

```lpc
switch (random(5)) {
  case 0: return "嗨！...";
  ...
  default: return "...";   # 或 case 4:
}
```

已有 `extract_greetings`/`render_dialogue` 能力 → **扩展 `accept_ask` 抽取**：
抽成 `unhandled` 或新增 `inquiries` 补充（accept_ask 按 topic 分发，见 4.4）。

### 4.4 `accept_ask`（ask 问答函数）

语料中有 `accept_ask(me, topic)`（xiaoer 有）。K 端已有 `inquiries` 问答表，但 accept_ask
运行时是一个函数。本轮范围：**如函数体为连续 `if (topic == "关键词") return 台词;` 或
switch(topic) 台词池 → 转为 inquiries 条目**（与 `set("inquiry")` 同构），否则 L3 注释。
> 标记为二期独立任务，本计划不展开实现，仅记录方向。

### 4.5 重构 `extract_unhandled_content` 的 switch 分桶

现状把所有 switch 原文塞进 `:switch_statements` 单一列表。重构为：

```elixir
switch_tables: [...],      # L1 case-assign，结构化
switch_pools: [...],       # L2 台词池（随机）
switch_other: [...],       # L3 命令分发/状态机原文
```

对应 `generate_unhandled_comments` 三段注释标题，标注所属函数与行号。

---

## 五、`else-if` 链 与 嵌套 `if/else` 处理

### 5.1 现状

`extract_unhandled_content` 用正则把"含 else-块"的 if 整体存入 `:complex_conditionals`。
正则 `if\s*\([^)]+\)\s*\{[\s\S]*?\}\s*else\s*\{` 对**行内 if** 效果尚可，但：
- 不跨 else-if 链（只匹配第一段）
- 不保留函数归属
- 嵌套层级多时 `[\s\S]*?` 截断混乱

### 5.2 目标（L2 + L3）

对每个含复杂条件的**函数**（正则由 `extract_function_body/2` 提供），输出：

```
# ==== CONDITIONAL BRANCHES (init) ====
#   if (ob->combat_exp < 5000 && !mark/guofu_ok ...) →  command("say 这位...")
#   else if (combat_exp >= 40000 && mark/guofu_ok)  →  command("look") command("haha")
#   ...

# ==== NESTED IF/ELSE (do_join) ====
# [原文保留]
```

即：
- **抽取分支行为**（条件串 → 该分支的 command()/tell_object/message_vision 台词列表），
  生成"条件 → 行为"参考行（L2）。
- **原文条件**整体保留在 `note`（L3），不尝试运行条件（涉及 query/运行时状态）。

实现（新私有函数）：

```elixir
# 对指定函数体，切分成顶层 if/else if/else 段
defp split_condition_branches(body) do
  # 顶层扫描：进入 if( 后找匹配右括号，再找对应 { } 块，判断后接 else/else if
end

# 每段抽：condition 串 + branch_actions（command/tell_object/message_vision/say 台词）
defp branch_actions(segment), do: ...
```

### 5.3 输出归并

`extract_unhandled_content` 增加 `:conditional_branches`（函数名 → 分支表）。
`generate_unhandled_comments` 生成 `CONDITIONAL BRANCHES` 节，置于现有 `COMPLEX
CONDITIONALS` 之上；`COMPLEX CONDITIONALS` 保留为原文兜底。

---

## 六、实施步骤（可分多次提交）

> **状态**：Step 1–5 全部完成（2026-09-23），全量 2936 tests 全绿；后续追加了 accept 台词池语义化（见 §五后补充）。偏差项：
> - §3.7 retaliate「ref 反转反开战」未单独实现——`start_combat` 本就双向开战（双方各收 `combat/start`），行为等效。
> - §3.8 / Step2 / Step5 的 **room 级 e2e**（`room_combat_attack_test.exs`）未写；engage 规则以 `EngageRule` 纯函数单测（`test/kantele/npc/engage_rule_test.exs`，4 tests）覆盖。
> - §4.4 accept_ask 转 inquiries 属于二期独立任务，未实现（方向已记录）。

### Step 1：engage 抽取（Converter + AST + UCL 输出）
- [x] `ast.ex` 加 `:engage` 字段
- [x] `extract_engage/1` + `extract_accept_fn/2` + msg/spawn/retaliate 辅助
- [x] `build_engage_ucl/1`；`generate_npc_ucl` 挂接
- [x] 移除 intercepted：`accept_fight/hit/kill` 从 `handled_functions` 白名单？**不自名单**，
      仍要进 UNHANDLED functions 名单（因为还有 note 原文需求），但改为列出并注明已有 engage 抽取

### Step 2：Loader + Meta + 运行时接线
- [x] `loader.ex` `parse_engage/1`；`parse_character` 挂接
- [x] `NonPlayerMeta` 加 `:engage`
- [x] `room.ex` `dispatch(combat/attack)` 插入 engage_deny 检查；retaliate 反开战
      （retaliate 反开战由 `start_combat` 双向开战等效达成，未单独 ref 反转）
- [ ] e2e：`fight`/`hit`/`kill` 对拒绝 NPC 的行为验证
      （未写 room 级 e2e；已用 `EngageRule` 纯函数单测覆盖，见 §3.8 偏差注）

### Step 3：switch 分桶重构
- [x] `extract_unhandled_content` switch 分三桶（tables/pools/other）
- [x] `parse_switch_table/1`（case-assign → 表格行）
- [x] `generate_unhandled_comments` 新三段注释 + 函数名/行号标注

### Step 4：条件分支抽取
- [x] `split_condition_branches/1`（顶层切分 if/else-if/else）
- [x] `branch_actions/1`（条件→台词行为）
- [x] `:conditional_branches` 落 AST + 注释输出

### Step 5：测试与回归
- [x] converter 单测（engage/switch/conditional）——见 3.8
- [x] loader/meta 单测
- [ ] room 运行时 e2e（未写，见上）
- [x] 全量 `MIX_ENV=test mix test` 保持全绿（基线 2915 → 2936）
- [x] 重新生成 `test.ucl`；抽查新 4 NPC（shouwei/wudunru/jiang/huangyi）输出

---

## 七、测试样例（test_minimal_world_v2_modified 新增真实例子）

| 文件 | accept_fight | accept_hit | accept_kill | 亮点 |
|---|---|---|---|---|
| `npc/shouwei.c` | userp 拒绝+`::`继承 | 同 | 同+destruct | 三位一体、继承回退 |
| `npc/wudunru.c` | mark 分支拒绝 | 反杀 kill_ob | 反杀+notify_fail | command 台词、kill_ob |
| `npc/jiang.c` | 满血+次数限制+call_out | — | — | accept_fight 最复杂 |
| `npc/huangyi.c` | 拒绝 | — | 召唤保镖 spawn | new/present 帮手 |

> 已加入测试世界（2026-09-23），当前以 UNHANDLED 注释保留函数体，Step 1 完成后这些样例即作为断言数据。

---

## 八、风险与取舍

1. **启发式误判**：`get_last_return` 遇复杂嵌套可能取错。兜底：同时要求 return 出现在函数
   尾部 1/3 范围内，否则 `accept` 置 nil → UCL 不输出该键（运行时按缺省放行）。
2. **`::accept_*` 继承回退**：父类行为不可见（KNOWER/NPC 模板），不猜测，仅 `note`。
3. **switch 正则健壮性**：`switch(arg)` 内嵌 `{...}` 会截断——改为借助 `find_matching_brace`
   提取，而非正则非贪婪。
4. **运行时范围**：spawn/call_out 只落位不执行（避免引入不确定的召唤 AI），执行属后续
   Coagent 接线任务。
5. **不新增 UNHANDLED 语义**：任何抽不出的内容一律保留在注释中，不允许静默丢失。

---

## 九、验收标准

- [x] 4 个真实样例 NPC 的 engage 数据与手写 LPC 语义一致（accept/msg/retaliate/spawn）
- [x] switch case-assign 表输出为规整注释表格，信息无损（键/值/产物）
- [x] 条件分支注释含"条件 → 行为"，原文仍可回溯
- [x] 不再有任何原始 .c 内容在转换时**丢失**（UNHANDLED 兜底保证）
- [x] 全量 2915 tests 保持全绿（当前 2936，仅新增测试引起数量增加）

---

## 十、追加：switch 随机台词池 → accept 语义化（修复 xiaoer 案例）

> 2026-09-23 复查时发现 xiaoer.c `accept_object` 的 `switch (random(6))` 台词池未被语义化：
> 只原样入 `# SWITCH POOL:` 注释，"好！好！"被 `List.first` 单条捞进 accept，"不需要的东西全给我！"静默丢失。
> 按 §4.3 L2（台词池 → 随机台词池）修复，已合入。

- [x] `extract_accept_dialogues/1`：`default` 保留完整台词池（剔 `command("say x")` 双抓的 `say ` 前缀、去重）
- [x] `build_accept_ucl/1`：msg 支持 `msg = ["a", "b"]` 列表输出
- [x] `loader.accept_msg/1`：字符串/列表统一归一为台词池；空池 nil（修复 `msg = ` 空值产生 UCL 语法错误）
- [x] `give_event.take_message/2`：命中规则时从台词池 `Enum.random` 取一条（此前规则 msg 完全未接线）
- [x] 影响面：xiaoer `accept.any.msg = ["好！好！", "不需要的东西全给我！"]`；converter/loader 测试更新；test.ucl 重生成

**遗留（二期，见 §4.4）**：`accept_ask(topic)` 连续 if/switch 台词 → `inquiries` 表未实现。