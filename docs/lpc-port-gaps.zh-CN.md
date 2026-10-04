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

## 一之一、feature 已移植但**派发层缺失**，商店/门卫/钱庄全是死代码 🔴🔴

### 结论先说

`Kantele.Npc.{Dealer,Vendor,Guarder,Banker,Coagent,AskHandler}` 六个模块
**零引用** —— `lib/` 和 `test/` 里没有任何地方调用它们。功能写好了，插头没插。

### 数据链断在中间

```
LPC:   inherit F_DEALER;  add_action("do_buy", "buy");
         ↓ 转换器搬 add_action
UCL:   init = { add_actions = ["buy", "list"] }
         ↓ loader 解析进 meta.init.add_actions   （loader.ex:725-733 有做）
       ??? 谁读 meta.init.add_actions
         ↓
Elixir: Kantele.Npc.Dealer 的纯函数            ← 写好了，没人调
```

关键证据：`add_actions` 这个词在整个 `lib/` 里只出现在
`character.ex:297` 的**文档字符串**里，没有任何实际消费点。

所以：店小二身上挂着 `["buy","list"]`，玩家输入 `list` 什么也不会发生
（`data/verbs.ucl` 里没有 `buy`/`list`/`value` 动词，`lib/` 下也没有
`BuyCommand`/`ListCommand`）。

### `brains.X` 是转换器编的，别去补 brain 文件

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

**所以「去 mud 里找 brains/ 目录补定义」这条路是错的** ——
LPC 里没有这个目录（`feature/` 才是）。Kalevala 的 brain 是
`type=first` + `nodes` 的行为树，和 `feature/dealer.c` 那种命令实现
不是一个东西，语义上对不上。

**这些引用的正确归宿**：当作 feature 标记（`feature = "dealer"`），
由派发层消费，而不是当成 brain 去找定义。

### 计划

1. **派发层**：让 `meta.init.add_actions` 真正生效 ——
   玩家输入 `buy` 时找到在场 NPC，若其 feature 标记含 `buy`，
   转给 `Kantele.Npc.Dealer`。NPC 身份从 `brain = brains.X` 改读
   一个明确的 feature 字段。
2. **`dealer` 系先跑通**（135 处引用，收益最大）：
   `buy` / `list` / `value` / `sell`。
3. `vendor`（43）、`guarder`（37）、`banker`（11）各自接。
   `guarder` 与门禁系统有交叉（第 155 条门禁那套），要单独设计。

---

## 一之一之二、feature 移植的函数级差距

对着 LPC 原文逐个核了一遍：

| LPC | 函数 | Elixir | 状态 |
|---|---|---|---|
| `feature/guarder.c` | 4 | `guarder.ex` 4 | ✅ 齐 |
| `feature/banker.c` | 5 | `banker.ex` 5（`do_*`→去 `do_`） | ✅ 齐 |
| `feature/vendor.c` | 4 | `vendor.ex` **3** | ❌ 缺 `compelete_trade` |
| `feature/dealer.c` | 8 | `dealer.ex` **5** | ❌ 缺 3 个 |

### `vendor.ex` 缺 `compelete_trade` —— 买了没货交付

```c
void compelete_trade(object me, string what) {
    if( stringp(ob_file = query("vendor_goods/" + what)) ) {
        ob = new(ob_file);
        ob->move(me);          // ← 货真的交到买家手上
    }
}
```

`vendor.ex` 只有 `buy_object` / `price_string` / `vendor_list` 三个纯查询，
没有任何"把货交给买家"的逻辑。接上派发后 vendor 系商店买了也拿不到货。

### `dealer.ex` 缺 3 个

| LPC | 作用 | Elixir |
|---|---|---|
| `destruct_it(ob)` | 0 秒延迟销毁临时造出的物品（防泄漏） | 无 |
| `enough_rest()` | 1 秒后清 `busy` 标记 | 无 |
| `reset()` | 库存 ≥100 件或总重 ≥1000000 时清理 | 无 |

`busy` 是 `do_buy` 里"正忙着呢，慢慢来"那 1 秒冷却，
`dealer.ex` 的 `do_buy/4` 里也没有对应判断，所以冷却机制一并没了。

### `do_buy` 少了 4 道前置检查中的 3 道

LPC `do_buy` 在算价前有 4 道检查，`dealer.ex` 只保留了第 4 道：

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
// 4. 一次最多买 100 件 —— ✅ 这条有
```

第 1 条和 §二 里 `walker` 的 15 分钟自杀是同一类自愈机制。

### 一个真 bug：`:amount` 默认值导致两处死代码

`dealer.ex:57` 与 `dealer.ex:77`：

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
注意 `:amount` 在别处（bag / instance）也有用到，改语义要连带确认。

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

- [ ] 从 LPC 的 ` brains/` 目录补出这 7 个 brain 定义
      （`dealer` / `vendor` / `guarder` / `banker` / `guardert` /
      `quester` / `wandering_villager`）；
- [ ] `Kantele.Brain.process/2` 遇到不存在的 brain 名时**至少 warn 一次**，
      别静默返回 `NullNode`；
- [ ] 转换器生成 `brain = brains.X` 时校验 `data/brains/X.ucl` 存在。

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

## 二、`do_walk`（拾荒者清道夫）完全未实现 🔴

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

## 三、`random_move` 不存在 🟡

LPC 里大量 NPC 用它乱走（`walker` 只是其中之一）。
我们没有等价物，`Kalevala.World.Room` 有 `exits`，但没有"随机选一条能走的"。

- [ ] 确认 Kalevala 有没有现成的随机移动原语可用；
- [ ] 没有的话加一个，注意要排除单向出口 / `exit_vetoes` 拦住的 / 没开门的。

---

## 四、`attitude` 全是哑值 🟡

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

## 五、`carry` 是死数据 🟡

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

## 六、跨区引用只能在同区解析 🟡

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

## 七、`Items.get!/1` 还有 88 处 🔴

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

## 八、两个编译告警（先前就存在，未动）🟢

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

## 九、已核实为「转换器编造」的清单 🔴

> 这几项**不是** LPC 行为缺失，是转换器凭空造的。修的时候要改转换器，
> 不能靠补数据文件。

| 编造的东西 | 数量 | 造它的代码 | 真相 |
|---|---|---|---|
| `brain = brains.{dealer,vendor,guarder,banker,quester,guardert}` | 228 处 | `infer_brain/1` | LPC 只有 `inherit F_XXX`，没有 brain 概念 |
| `name = "NPC"` | walker、xunbu 等 | 转换器遇 `generate_cn_name()` 只能填空 | LPC 运行时随机生成人名 |
| `characters "city_xiaoer2"` 这类带区名前缀的 id | 4 处 | 按路径推 id | 其余 9 个区的 `jiading.c` 都叫 `jiading` |

`infer_brain/1` 还映射了 `HORSE -> horseboss`，但当前无引用。

## 十、数据层已完成的部分（备查）

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