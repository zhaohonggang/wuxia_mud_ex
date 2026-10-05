# LPC 移植缺口清单（转换器静默丢弃 / 运行时未接）

> 2026-10-04 建。记录「LPC 原文里存在、数据里也可能有痕迹，但**我们这边跑不起来**」的项。
> 与 `dangling-room-items-report.zh-CN.md`（悬空引用，数据层）分开：
> 那份说的是「引用指向不存在的定义」，这份说的是「定义在，但行为没接上」。

---

## 判定标准

一条缺口要同时满足：

1. LPC 原文里**确实有**这个行为；
2. 我们这边 `grep` 不到任何实现；
3. 不是「有意不实现」（有意不做的写进 `docs/lpc-objects-placement-issues.zh-CN.md`）。

**核心教训：转换器对不认识的东西是静默丢弃，不是报错。**
所以这一类问题不会自己冒出来 —— `walker` 已经补进 35 个区、139 个实例，
但它的两个核心行为一个都没接上（见 §一），而这件事**只有读 LPC 原文才发现**。

---

## 一、`chat_msg` 里的表达式元素被静默丢弃 🔴

**影响面：所有带自定义行为的 NPC，不止 walker。**

```c
// clone/npc/walker.c
set("chat_chance", 10);
set("chat_msg", ({ (: do_walk :) }));   // ← 元素是表达式，不是字符串
```

`lpc_converter.ex` 的 `build_chat/1`：

```elixir
chats = Map.get(sets, "chats") || Map.get(sets, "chat_msg")
case {chance, chats} do
  {{:int, c}, {:array, lines}} when c > 0 ->
    chat_lines =
      lines
      |> Enum.flat_map(fn
        {:string, s} -> [...]     # ← 只认字符串
        _ -> []                   # ← 其它元素全丢
      end)
    if chat_lines == [], do: nil  # ← 整块变 nil
```

**后果**：`chat_msg` 全是表达式时，整个 `chat_chance` / `chats` 块消失，
转换器不报错、不警告。实测 `data/world/beijing.ucl` 的
`characters "walker"` 块里确实没有 `chat_chance` 也没有 `chats`。

**要做的**：

- [ ] `build_chat/1` 遇到无法识别的元素时**至少留下标记**（比如生成
      `# UNHANDLED chat: (: do_walk :)` 注释），别让整块静默消失；
- [ ] 判定表达式能否静态求值（`(: some_static_string :)` 之类），
      能求值的转成字符串；
- [ ] 不能求值的落到「待实现」清单，不要假装没有。

---

## 一之一、`brains.X` 是转换器编造的假引用 🟡

> ⚠️ **本节初版写的是「feature 已移植但派发层缺失，商店/门卫/钱庄全是死代码」——
> 那是错的，已更正。** 错在两处：
> 1. 说 `Kantele.Npc.*` 六个模块「零引用」—— 错，它们**全都接好了**
>    （见下面 §一之一之二）。我当时用 `grep 'Npc\.Dealer'` 找引用，
>    但代码里是 `alias Kantele.Npc.Dealer` 之后裸调 `Dealer.f()`，grep 漏了。
> 2. 说「派发层缺失、店小二买不了东西」—— 错，`buy`/`list` 的链路是完整的。

### 真实情况：派发层是通的

```
玩家输入 "buy 包子"
  → Kantele.Character.BuyCommand.run/2        （character/commands/shop_commands.ex）
    → event("shop/buy", %{item_name:, quantity:})
      → ShopRequestEvent（world/room.ex:723）转发给在场 NPC
        → events.ex:274 路由到 NpcShopEvent.buy/2
          → Dealer.do_buy/4（已用）
            → reply "shop/buy-result" → 玩家
```

`list` 同理走 `NpcShopEvent.list/2` → `Dealer.build_list/2`。
`SellCommand` → `Dealer.do_value/1` + `do_sell/2`。
`BankCommand` → `Banker` 的 4 个函数。`room.ex:437/446/2733/2738`
→ `Guarder` 的 3 个函数。

### 那 `add_actions` 为什么没人读？

因为**不需要读**。LPC 的 `add_action("do_buy","buy")` 是**NPC 侧注册**
（谁提供这个命令）；我们这边 `BuyCommand` 是**玩家侧命令**，无条件广播给
在场 NPC，谁应答就谁回。这是有意的架构差异，不是缺口。

`meta.init.add_actions` 目前只是**没被消费的数据**，唯一用途是将来做
「这个 NPC 卖不卖东西」的过滤/校验。真正决定应答的是 `meta.goods` 非空。

顺带更正另一处：`data/verbs.ucl` 里没有 `buy`/`list` —— 这是**正常的**。
verbs.ucl 只管**物品动词**（`get`/`drop`/`look`/`wield`…），
玩家命令走 `Kalevala.Character.Command` 框架，根本不查 verbs.ucl。

### `brains.X` 是转换器编造的 —— **但先别删**

`data/world` 里 228 处 `brain = brains.dealer` 之类的引用，
**不是 LPC 数据**。`lpc_converter.ex` 的 `infer_brain/1`：

```elixir
defp infer_brain(inherits) do
  Enum.any?(inherits, &String.contains?(&1, "VENDOR")) -> "vendor"
  Enum.any?(inherits, &String.contains?(&1, "DEALER")) -> "dealer"
  Enum.any?(inherits, &String.contains?(&1, "GUARD"))  -> "guarder"
  Enum.any?(inherits, &String.contains?(&1, "BANKER")) -> "banker"
  Enum.any?(inherits, &String.contains?(&1, "QUEST"))  -> "quester"
end
```

LPC 那边根本没有 `brain` 这个概念，只有 `inherit F_XXX` 和 `add_action`。
例：`kungfu/class/mingjiao/lengqian.c` 只有 `inherit F_GUARDER;`，
产物 `data/world/mingjiao.ucl` 里就有了 `brain = brains.guardert`。

`Kantele.Brain.process/2` 找不到就返回 `NullNode{}`，所以这 228 处全是
空节点。

### ✅ 已处理：228 处编造引用注释掉（保留线索，不删）

**为什么不删而注释**：这些引用是「这个 NPC 在 LPC 里 `inherit` 了 `F_X`」
的唯一记录，删了就再也没法回溯某个 NPC 该有哪些命令。

**注释掉是安全的 —— 已实测证明等价**：

```
Kantele.Brain.parse_node("brains." <> key_path, brains) do
  parse_node(brains[key_path], brains)     # brains["dealer"] -> nil
end
defp parse_node(nil, _brains), do: %Kalevala.Brain.NullNode{}

process("brains.dealer") -> NullNode      # 保留
process(nil)              -> NullNode      # 注释掉之后
```

6 种编造名（`dealer` / `vendor` / `guarder` / `banker` / `quester` /
`guardert`）全部实测为 `NullNode`，与注释掉后的 `nil` **完全一致**。

**但有 4 处真实定义，一个都没碰**：

| brain | 引用处数 | 处理 |
|---|---|---|
| `heihu` | 1 | ✅ 保留（`Sequence`） |
| `town_crier` | 1 | ✅ 保留（`Sequence`） |
| `villager` | 1 | ✅ 保留（`FirstSelector`） |
| `wandering_villager` | 1 | ✅ 保留（`FirstSelector`） |

改动：228 处 / 56 个 `.ucl`，每处改成

```uc
# brain = brains.dealer  <- 转换器 infer_brain 编造，data/brains 无此定义；
#   注释掉前后都是 NullNode（见 docs/lpc-port-gaps.zh-CN.md §一之一）
```

**验证**：改动前后导出全部 2677 个 NPC 的 brain 指纹
（NullNode 2470 / Sequence 204 / 其它 3），排序后**逐行一致**。
全量测试 3354 通过、门禁审计 166/155/11、悬空 815 条 —— 均无变化。

- [x] 注释掉 228 处编造引用（已完成）
- [ ] `infer_brain/1` 不再编造（下次重转时才会用到；
      本轮**故意没改**，避免覆盖手工补的 NPC）
- [ ] `Kantele.Brain.process/2` 遇到未定义 brain 名时 warn 一次
- [ ] 8 个 `F_*` feature 的行为逐个核实完后，再决定这些注释行是彻底删除
      还是改名成 `feature = "X"`

---

## 一之一之二、feature 移植的函数级差距（这条是准确的）

对着 LPC 原文逐个核了一遍 —— **这一节的结论经过复核，没有误报**：

| LPC | 函数 | Elixir | 状态 |
|---|---|---|---|
| `feature/guarder.c` | 4 | `guarder.ex` 4 | ✅ 齐（`room.ex` 已接） |
| `feature/banker.c` | 5 | `banker.ex` 5（`do_*`→去 `do_`） | ✅ 齐（`bank_command.ex` 已接） |
| `feature/vendor.c` | 4 | `vendor.ex` **3** | ❌ 缺 `compelete_trade` ✅已补 |
| `feature/dealer.c` | 8 | `dealer.ex` **5** | ❌ 缺 3 个 ✅已补 |

### `vendor.ex` 缺 `compelete_trade` —— 买了没货交付 ✅ **已补**

```c
void compelete_trade(object me, string what) {
    if( stringp(ob_file = query("vendor_goods/" + what)) ) {
        ob = new(ob_file);
        ob->move(me);          // ← 货真的交到买家手上
    }
}
```

`vendor.ex` 之前只有 `buy_object` / `price_string` / `vendor_list` 三个纯查询，
没有任何"把货交给买家"的逻辑。接上派发层后 vendor 系商店买了也拿不到货。

已补 `Vendor.complete_trade/2`（纯决策，产出 `%{action: :deliver_item, …}`，
真正 `move` 由派发层落地，与 `Dealer` 的约定一致）。未命中返回
`{:error, :not_found}` —— 对应 LPC 里 `query()` 非 stringp 时整个 if 块跳过、
**静默什么都不做**。

### `dealer.ex` 缺 3 个 ✅ **已补**

| LPC | 作用 | Elixir |
|---|---|---|
| `destruct_it(ob)` | 0 秒延迟销毁临时造出的物品（防泄漏） | ✅ `destruct_it_plan/1` |
| `enough_rest()` | 1 秒后清 `busy` 标记 | ✅ `enough_rest_plan/0` |
| `reset()` | 库存 ≥100 件或总重 ≥1000000 时清理 | ✅ `reset_plan/2` |

`*_plan` 后缀表示**只产出动作描述**，真正的定时/销毁由派发层落地 ——
和 `Dealer` / `Vendor` 一律保持"纯逻辑"的既有约定。

### `do_buy` 少了 4 道前置检查中的 3 道 ✅ **已补**

LPC `do_buy` 在算价前有 4 道检查，`dealer.ex` 只保留了第 4 道
（一次最多 100 件）。已补 `check_buy_preconditions/1`：

```c
// 1. 跑偏了自动传送回 startroom（同时是防 NPC 走丢的自愈机制）
if (!query("carried_goods")) {
    if ((room = find_object(query("startroom"))) != environment()) {
        message_vision("$N说道：咦？我怎么跑到这儿来了？\n");
        ... destruct(this_object());
    }
}
// 2. 身上东西太多
if (sizeof(...) >= MAX_ITEM_CARRIED) { write("你身上的东西太多了…"); return 1; }
// 3. 对方正忙（busy 冷却）
// 4. 一次最多 100 件 —— ✅ 原本就有
```

第 1 条返回 `{:recover, %{action: :teleport_home | :despawn, …}}`，
和 §二 里 `walker` 的 15 分钟自杀是同一类自愈机制。

`MAX_ITEM_CARRIED` 原 LPC 是宏，取 **100**（`@max_item_carried`）。

### 一个真 bug：`:amount` 默认值导致两处死代码 ✅ **已修**

`dealer.ex:57` 与 `dealer.ex:77` 原来写的是：

```elixir
max_count < 1 and amount > 1 -> {:reject, "这种东西不能拆开来卖。"}
amount > 1 and Map.get(item, :amount, 1) < 1 -> {:reject, "只能一个一个的买。"}
```

`Map.get(item, :amount, 1)` 默认值是 **1**，所以 `< 1` **永远不成立** ——
两条分支都是死代码。

LPC 原意（`dealer.c:455`）：

```c
if (amount > 1 && ! ob->query_amount())   // query_amount() 对不可叠加物品返回 0
```

即"**不可叠加的物品**不能一次买多个"。我们默认 1、LPC 是 0，语义反了。

已抽出 `stackable?/1`：`:amount` 缺失或非正整数 = 不可叠加。
注意 `:amount` 在别处（bag / instance）也有用到，改语义要连带确认。

顺带修了 `sell_value/3` 的条件：LPC 判的是**库存数量** `max_count > 1`
而不是本次卖出的 `amount` —— 叠了 4 件卖 1 件，仍走 `base_value * amount`。
这一点是写测试时才发现的（第一版测试断言写错了）。

### 仍然缺失

- **`compelete_trade` 之外，`vendor` / `guarder` / `banker` 都还没接派发层** ——
  本节只补齐了纯函数层面的差距，派发本身见 §一之一 的计划。
- `dealer.ex` 的 `do_list` 少一处：LPC 里若库存与目录同名，
  `count[short_name] = -1`（覆盖成"大量供应"），我们保留库存数字。

**这一条是本轮最严重的发现，比 §一 影响面大得多。**

`data/brains/` 实际只有：

```
heihu.ucl   town_crier.ucl   villager.ucl
```

但 UCL 里引用到的 brain 有 9 种：

| brain | 引用处数 | 文件 |
|---|---|---|
| `dealer` | **135** | ❌ 不存在 |
| `vendor` | **43** | ❌ 不存在 |
| `guarder` | **37** | ❌ 不存在 |
| `banker` | **11** | ❌ 不存在 |
| `guardert` | 1 | ❌ 不存在 |
| `quester` | 1 | ❌ 不存在 |
| `wandering_villager` | 1 | ❌ 不存在 |
| `heihu` | 1 | ✅ |
| `town_crier` | 1 | ✅ |
| `villager` | 1 | ✅ |

**合计 229 处引用落空**（7 种缺失）。

### 后果

`Kantele.Brain.process/2` 找不到 brain 定义时返回 `NullNode{}`，
**不报错、不警告**。于是：

- 全库 **135 个店小二**（`brains.dealer`）没有任何买卖 AI；
- 43 个小贩（`vendor`）、37 个门卫（`guarder`）、11 个钱庄（`banker`）同理。

注意 `NonPlayerMeta` 里根本没有 `:brain` 字段 —— brain 是 loader 的
`build_brain/2` 单独组装的 `%Kalevala.Brain{}`，挂在 character 上。
所以从 meta 上**看不出**这个问题，只有去看 `character.brain` 才会发现
它是 `NullNode`。

（`chat_chance` / `chats` 同理：不在 meta 里，而是被 `build_brain/2` 包成
`ChatChance` → `ChatAction` 的闲聊节点挂到 brain 上。**这两个是接上了的**，
和 §一 的 `chat_msg` 表达式元素丢失是两回事 —— 字符串数组能转，
`(: do_walk :)` 转不了。）

### 要做的

> ⚠️ **本节初版的建议是错的**（"从 LPC 的 `brains/` 目录补出 7 个 brain 定义"）。
> LPC 里**没有** `brains/` 目录 —— NPC 行为来自 `feature/*.c` 的 inheritable
> object，不是 brain 树。正确做法见 §一之一 的核查结论与 §二 的接线。

- [x] 核查清楚：这 228 处引用是 `infer_brain/1` 编造的，功能**不依赖**它们
      （详见 §一之一 / §一之二）
- [x] 228 处已注释掉、保留线索（见 §一之一）
- [ ] `Kantele.Brain.process/2` 遇到未定义 brain 名时**warn 一次**，
      别静默返回 `NullNode`（`brain.ex:66` 的注释说明这是有意降级，
      但至少该留个日志）
- [x] 转换器生成 `brain = brains.X` 时的存在性校验 —— 改为按 §一之一 处理

---

## 一之二、`data/brains` 只有 6 个定义，228 处引用落空 🔴

> **更正本节初版的两处错误**：① 初版写「只有 3 个文件、229 处落空」——
> `data/brains/villager.ucl` 其实定义了**两个** brain（`villager` 和
> `wandering_villager`），当时只扫了文件名没扫 `brains "X"` 键；
> ② `wandering_villager` 是有定义的。
> 实际是 **6 个定义 / 5 种未定义 / 228 处落空**。根因见 §一之一。

实际定义的：

```
heihu                    <- heihu.ucl
generic_hello            <- town_crier.ucl
town_crier               <- town_crier.ucl
town_crier_conversation  <- town_crier.ucl
villager                 <- villager.ucl
wandering_villager       <- villager.ucl
```

被引用但**未定义**的：

| brain | 引用处数 |
|---|---|
| `dealer` | 135 |
| `vendor` | 43 |
| `guarder` | 37 |
| `banker` | 11 |
| `guardert` | 1 |
| `quester` | 1 |

合计 **228 处**，`Kantele.Brain.process/2` 全部返回 `NullNode{}`，不报错不警告。

> ⚠️ 这些 `brain = brains.X` 引用本身是 `infer_brain/1` 从 `inherit F_XXX`
> **编造**的（见 §一之一），所以"去 mud 补 brain 定义"这条路不成立。

`NonPlayerMeta` 里没有 `:brain` 字段 —— brain 是 loader 的 `build_brain/2`
单独组装挂在 `character.brain` 上的，所以从 meta 看不出问题。

`chat_chance` / `chats` 同理：不在 meta 里，而是被 `build_brain/2` 包成
`ChatChance` → `ChatAction` 闲聊节点。**这两个是接上了的**，
和 §一 的 `chat_msg` 表达式元素丢失是两回事 —— 字符串数组能转，
`(: do_walk :)` 转不了。

- [ ] 按 §一之一 的计划接派发层，让 feature 标记不再冒充 brain

---

## 一之三、`vendor_goods` 的相对路径解析不了 🟡

`xiaoer2`（店小二）的货品在 LPC 里写的是**相对路径**：

```c
// d/city/npc/xiaoer2.c
set("vendor_goods", ({ "obj/jitui", "obj/jiudai", "obj/baozi", "obj/kaoya",
                       "/clone/fam/pill/food", "/clone/fam/pill/water", }));
```

转换器把解析不了的标成注释：

```uc
# vendor_goods: "obj/jitui" (file not found)
# vendor_goods: "/clone/fam/pill/food" (file not found)
```

连**绝对路径**的 `/clone/fam/pill/food` 也没找到（`data/world` 里没有）。
结果 `goods` 为 `nil`，店小二两手空空。

对比：`changan` / `beijing` 的 `xiaoer2` 有 `goods`（`changan:jiudai` 等），
说明**同一个 LPC 文件在不同区的产物不一样** —— 谁的相对路径碰巧解析成功了就有货。

- [ ] `vendor_goods` 的路径解析要按 LPC 的 `clone` / `d` 根去试；
- [ ] 至少把"解析不到"的原因分开（相对路径找不到 vs 绝对路径缺文件）。

---

## 二、`Guarder`：4 个函数里只有 1 个真的接上了

`feature/guarder.c` 与 `lib/kantele/npc/guarder.ex` 函数名**1:1 对应**，
但**接线**（谁在调）情况完全不同：

| LPC | Elixir | 调用点 | 实际生效 |
|---|---|---|---|
| `is_guarder()` | `is_guarder?/1` | `room.ex:437`、`room.ex:2733` | ✅ |
| `permit_pass(ob, dir)` | `permit_pass/1` | `room.ex:446` | ✅ |
| `check_enemy(ob, type)` | `check_enemy/1` | **无** | ❌ |
| `kill_enemy(ob)` | `kill_enemy/1` | **无** | ❌ |

### `permit_pass` 是真通的

`room.ex:433-455` 的 `check_guarders_for_dir/2` 在**每次移动**时执行，
对应 LPC 里 `baituo/damen.c` 那个模式：

```c
if (present("men wei") && dir == "north") return guarder->permit_pass(me, dir);
```

数据侧也确认有料：**20 个守卫 / 9 个区，`guarder.family` 20/20 全部非空**：

```
xiyu 5 / huashan 4 / baituo 3 / shenlong 2 / xuedao 2
dali 1 / guanwai 1 / hengyang 1 / taohua 1
样本：黄药师 @ taohua  ->  %{family: "桃花岛", msgs: %{}}
```

三条 LPC 规则里前两条（叛门者 / 外门派不得入内）生效。

### ✅ `check_enemy` 已接进开战流程

原先 `room.ex:2728` 的注释写着「守卫敌对判定（`Guarder.check_enemy` 接线）」，
但 `guarder_config?` / `guarder_decision` / `guarder_deny?` / `guarder_kill?` /
`guarder_refuse_msg` 五个函数全都只出现在自己的定义行，整条链止步于定义。

已在 `combat/*` dispatch 的 `cond` 链里（`guarded_deny?` 与 `engage_rule_deny?`
之间）插入两路：

- `guarder_refuse?/3` → 渲染拒绝语，不开战（LPC `return 0`）
- `guarder_counter_kill?/3` → `engage(context, target, attacker, "kill")`（LPC 的 `kill_ob`）

接线时还发现 `check_enemy` 对「外门派 + fight」返回 `{:ignore}`，**与 LPC 相反**
—— `guarder.c:152-157` 是「我现在没空」后 `return 0`（拒绝交战），
而 `ignore` 会让战斗正常开打。已修正，LPC 的四种反应现在全覆盖：

| 条件 | LPC | 返回 |
|---|---|---|
| 外门派 + fight | 「我现在没空」`return 0` | `{:refuse, ...}` |
| 外门派 + hit/kill | 「活得不耐烦了！来这里撒野？」`kill_ob` | `{:kill, id}` |
| 同门 + hit/kill | 「你今日是要造反吗？」`kill_ob` | `{:kill, id}` |
| 同门 + fight | 「找你的师傅比划去」`return 0` | `{:refuse, ...}` |

### ✅ `kill_enemy` 已接进 `engage/4`

先查清了 LPC 里它**唯一的调用点**（`feature/attack.c:104-108`）：

```c
enemy += ({ ob });
if (this_object()->is_guarder() && is_killing(ob->query("id")))
    this_object()->kill_enemy(ob);      // guarder will look for help
```

两个容易搞错的点：

1. 是**攻击方**（`this_object()`）为守卫时才调，**不是被打方**；
2. 只有「杀」才呼唤帮手，`fight` / `hit` 不调。

已按此在 `engage/4` 末尾接上 `maybe_summon_coagents/4`。

**当前是 no-op，但这是正确的**：全库 `coagents` 非空的 NPC 定义数是 **0**，
而 LPC 里 `coagents` 为空时是**直接 return、一句话都不说**：

```c
if (!pointerp(co = me->query("coagents"))) return;
if (sizeof(co) < 1) return;
```

所以行为一致。等有了「雇帮手」的数据来源才会真正生效。

> 注意 `lpc_example/ex/feature_attack/` 里那个 `kill_enemy` 是**同名的无关
> 函数**，别混淆。

### ❌ 第三条规则（背着他派的人闯门）**不能靠加字段接线**

`permit_pass` 第三条检查恒假，因为 `room.ex:466` 读 `mover.meta[:carrying]`
而 `PlayerMeta` 没有这个字段。

查完之后结论变了：**这不是「补个字段」能解决的**。

LPC 用 `deep_inventory(ob)` + `userp()` 判断，也就是「玩家被塞进了另一个
玩家的背包里」—— 这依赖 LPC 的**背人机制**。

而我们**完全没有这个机制**：

- `lib/kantele/character/commands/` 下没有 `carry` / `tuo` / `drag` /
  `haul` 任何一个命令；
- `backpack` 是储物袋（存 item instance），不是背人；
- `give` 只处理物品实例，不能给玩家。

所以给 `PlayerMeta` 加一个 `:carrying` 字段，只会让它**恒为 nil** ——
把「读一个不存在的字段」换成「读一个永远为 nil 的字段」，死代码照旧，
还多一次迁移。**没做**。

要实现这条规则，前置条件是先做「背人」这个玩法（LPC 里对应
`feature/carry*.c` 一类的东西 + 相应命令），属于**新功能**而非移植补漏。

### ⚠️ 关键：`brain = brains.guardert` 与以上无关

守卫能工作**不是因为**那行（它已被注释掉，见 §一之一）。真正生效的是
`meta.guardert` —— 由 `lpc_converter.ex:1310-1312` 的 `extract_guarder`
从 LPC 的 `permit_pass()` 函数体抽取，`room.ex` 读的是 `c.meta.guardert`。

- [x] `check_enemy` 接进 `engage` 流程
- [x] `kill_enemy` 接进 `engage` 流程（当前 no-op，与 LPC 一致）
- [ ] 第三条规则：等「背人」玩法落地后再做，不要单独加 `:carrying` 字段

---

## 三、`do_walk`（拾荒者清道夫）完全未实现 🔴

LPC 里 `walker` 的**全部**行为，都在 `do_walk()` 里，三个机制一个都没有：

| LPC 行为 | 代码 | 我们 |
|---|---|---|
| 清场：销毁房间里所有非角色 / 未穿戴 / 非 `no_get` 的物品 | `destruct(ob)` | 无 |
| 15 分钟未归则自我了断（防 NPC 泄漏） | `if (time()-check_time > 900) … destruct(this_object())` | 无 |
| `random_move()` 随机走动 | `random_move()` | **全库没有 `random_move`** |

**后果**：139 个拾荒者现在是纯静态 NPC —— 不走动、不说话、不扫地、也不会走。

**注意一个反向影响**：LPC 里拾荒者会**销毁玩家掉在地上的物品**。
我们没实现，反而"更安全"。但这也意味着**不能简单照抄 LPC** ——
一旦实现了清场，线上玩家丢东西会凭空消失，需要先想清楚
`no_get` 语义和物品 `is_head()`（已穿戴）判定在新数据模型里怎么表达。

**依赖**：§三 的 `random_move`，以及一个 `no_get` / 装备态的判定。

---

## 四、`random_move` 不存在 🟡

LPC 里大量 NPC 用它乱走（`walker` 只是其中之一）。
我们没有等价物，`Kalevala.World.Room` 有 `exits`，但没有"随机选一条能走的"。

- [ ] 确认 Kalevala 有没有现成的随机移动原语可用；
- [ ] 没有的话加一个，注意要排除单向出口 / `exit_vetoes` 拦住的 / 没开门的。

---

## 五、`attitude` 全是哑值 🟡

`grep -rn heroism lib/` **零命中**。

`attitude` 只在 `npc.ex:91` 被当成字符串读出来：

```elixir
def attitude(npc), do: Map.get(npc, :meta, %{})["attitude"] || "neutral"
```

战斗里真正认的是 `combat_event.ex:861` 的

```elixir
t when t in ["kill", "aggressive", "duel"]
```

—— 但那是**战斗类型**（谁发起的），不是 NPC 的 attitude。

**后果**：`heroism` / `peaceful` / `friendly` / `aggressive` 目前**都不影响行为**。
包括已补的 76 个 `bing`（`attitude = "peaceful"`）——
"官兵不该主动攻击"这条现在**没有任何代码在保证**。

> 文档里凡是标注"语义保留"的地方，指的是**数据写对了**，
> 不是运行时生效。这个区别容易被误读成"已经支持了"。

- [ ] 决定 `attitude` 要不要接，接的话语义是什么
      （LPC 里 `peaceful` 是"不主动攻击但不被动挨打"，
      和我们的战斗模型对不对得上要单独确认）；
- [ ] 未接之前，`docs/lpc-objects-placement-issues.zh-CN.md` 里
      相关表述统一加一句"仅数据保留，运行时未接"。

---

## 六、`carry` 是死数据 🟡

上一轮（`caea599`）发现的：转换器会输出

```uc
carry = [ { id = items.blade.id }, { id = items.junfu.id } ]
```

但 **loader 根本不解析 `carry`**，`NonPlayerMeta` 也没有这个字段
（实测字段只有 accept / aliases / apprentice / combat / engage / goods /
greetings / guarder / init / loot / quest / stats / vitals / zone_id …）。

**后果**：所有 NPC 的 `carry_object()` 装备一律失效。76 个 `bing` 空着手站在城门口。

**已知的连带问题**：`items.cloth` / `items.blade` 这些 carry 专用物品，
为了数据自洽在各区都抄了一份（`caea599` 补了 11 个区的 blade/junfu）。
如果 `carry` 一直不实现，这些是纯冗余定义。

- [ ] 要么实现 `carry`（顺带解决 §六 的跨区物品解析），
      要么把 `carry` 从转换器输出里去掉并清理已抄的物品定义。

---

## 七、跨区引用只能在同区解析 🟡

**这是悬空引用的根因**，也是 §五 的障碍。

LPC 里 NPC 用**完整路径**引用物品：

```c
carry_object("/clone/weapon/blade")->wield();
```

所以一个 `bing` 无论出现在哪个区，拿到的都是同一把刀。
我们把路径丢成裸 id，`dereference/3` 又是
`zone |> flatten_items() |> ...`，于是每个区都得自己定义一份。

**现状**：靠"把定义抄到每个引用它的区"绕过（马匹 87 条、NPC 若干）。
数据量上去了，但每次新增 NPC 都要抄一遍。

- [ ] 真正的解法是让 `characters.X.id` / `items.X.id` 的解析**带 fallback 源区**，
      并保留 LPC 的原始路径信息（现在 `Generated from` 注释只到房间级，
      `carry_object` 的路径转换后就丢了）。

---

## 八、`Items.get!/1` 还有 88 处 🔴

`Kalevala.Cache` 的 `get!/1` 在 key 不存在时 `raise`。

上一轮（`08f46da`）修了登录路径（`InventoryEvent.list/2`、
`InventoryCommand.run/1`），加了 `Kantele.World.Item.fetch/1` 返回占位物品。
**但全库还有 88 处 `Items.get!/1`**（各种 command / room / npc 脚本）。

**后果**：背包里有一件查不到定义的物品，登录不会崩了，但玩家执行到相关
命令（give / drop / eat / wield / sell / equip …）时照样崩，且崩的是 Foreman。

- [ ] 按触发频率排优先级，把 `room.ex` 和常用 command 逐个换成
      `WorldItem.fetch/1` + 友好提示；
- [ ] 至少给"物品定义缺失"加一条限流日志，别静默。

---

## 九、两个编译告警（先前就存在，未动）🟢

```
lib/kantele/character/commands/combine_command.ex:193
  Kantele.World.Items.known?/1 is undefined or private

lib/kantele/character/commands/drive_command.ex:59
  Kantele.Item.Transport.can_drive_by?/2 is undefined
  (Did you mean can_drive_by?/1)
```

`known?/1` 看着像**真 bug**（调用了不存在的能力，合并物品的路径可能永远走不通）。
`can_drive_by?/2` 更像是参数写错。

- [ ] 查清 `known?/1` 是不是漏实现了；
- [ ] 修 `can_drive_by?/2` 的参数。

---

## 十、已核实为「转换器编造」的清单 🔴

> 这几项**不是** LPC 行为缺失，是转换器凭空造的。修的时候要改转换器，
> 不能靠补数据文件。

| 编造的东西 | 数量 | 造它的代码 | 真相 |
|---|---|---|---|
| `brain = brains.{dealer,vendor,guarder,banker,quester,guardert}` | 228 处 | `infer_brain/1` | LPC 只有 `inherit F_XXX`，没有 brain 概念 |
| `name = "NPC"` | walker、xunbu 等 | 转换器遇 `generate_cn_name()` 只能填空 | LPC 运行时随机生成人名 |
| `characters "city_xiaoer2"` 这类带区名前缀的 id | 4 处 | 按路径推 id | 其余 9 个区的 `jiading.c` 都叫 `jiading` |

`infer_brain/1` 还映射了 `HORSE -> horseboss`，但当前无引用。

## 十一、数据层已完成的部分（备查）

这些是**数据**层，做完了，但对应行为仍受上面各节限制：

| 项 | 提交 | 备注 |
|---|---|---|
| `test` / `global` 夹具区移出 `data/world` | `7efcd43` | 默认不加载；`load_fixture_world/0` 仅测试用 |
| 数据库清掉 `global:`/`test:` 物品引用 | `08f46da` | `inventory` 是 `jsonb[]`，不是 jsonb |
| `mafu` / `bing` / `guanbing` 跨区补齐 | `caea599` | −119 条悬空 |
| `walker` 跨区补齐 + 2 处误命名修正 | `c31af50` | −141 条悬空 |
| `ducha`/`liumang`/`wujiang`/`kid1`/`xunbu`/`xiaoer2`/`guest`/`duke` | 本轮 | −140 条悬空 |

`character` 悬空合计 **751 → 351**（−400），`item` 仍是 464。

**数据补齐 ≠ 功能可用**：这些 NPC 里接上了的是走通用路径的部分 ——
`bing` 的 engage、`mafu` 的 accept / greetings、`xunbu` 的 engage、
`duke` 的 chat（ChatChance 闲聊）、`xiaoer2` 的 buy/list 命令注册。
没接上的是自定义行为（`do_walk` 之类）、`carry` 装备、`brain` AI（§一之二）。