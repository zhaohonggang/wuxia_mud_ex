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

## 一之二、`data/brains` 只有 3 个文件，229 处引用落空 🔴🔴

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

## 九、数据层已完成的部分（备查）

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