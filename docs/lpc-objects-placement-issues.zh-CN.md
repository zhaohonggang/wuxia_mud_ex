# LPC `set("objects", ...)` 落地问题清单

> 基线：`mix test --seed 12345` → **3272 tests, 0 failures**
> `valid_leave` 门禁：**155/166 会拦人**（含 12 条 `all_dirs` 全方向门禁，
> 其中 10 条因触发状态未移植而永不触发，详见 §6.3）（`scripts/audit_veto_effectiveness.exs`）
> 本文记录 2026-10 一轮排查中发现的问题。相关：[[ucl-comment-todo.zh-CN]]、
> [[ucl-conversion-issues.zh-CN]]、[[data-world-info-loss.zh-CN]]

---

## 一、结论速览

| 问题 | 规模 | 状态 |
|---|---|---|
| LPC `set("objects")` 被写成 `room_items`（人物当物品） | 20 处 | **已修 8 处**（见 §3） |
| `room_characters` 引用了本区没有的定义（跨区） | 2 处 | **已修** |
| NPC 名字被转换器写倒 | 1 处 | **已修** |
| `room_items` 引用彻底不存在的 `items.X` | **674 处** | **未修**，见 §5 |
| 门禁条件外层方向守卫丢失 | 4 条 | 见 §6.1 |
| 审计把 `all_dirs` 全方向门禁误判成「丢了守卫」 | 12 条 | **已修**，见 §6.2 |
| 门禁条件要求不存在的方向 | 7 条 | 未修 |
| 审计脚本把析取当合判 | 2 条误报 | **已修** |

一个反复出现的教训：**转换器的错误是静默的**。
loader 对解析不到的引用一律 `if is_nil(...)` 跳过，不报错、不警告。
所以「数据里有引用」完全不代表「运行时存在」，必须用运行时数据核对。

---

## 二、三种错法（本轮已修的 10 条都属这类）

### ① 写进了 `room_items`，当成物品

```lpc
// mud/d/baituo/cave.c
set("objects", ([ "/clone/beast/mangshe" : 1, ]));
if (dir == "in" && objectp(present("mang she", environment(me)))) ...
```

```elixir
# data/world/baituo.ucl  —— 转换前
room_items "cave" {
  room_id = rooms.cave.id
  items = [ { id = items.mangshe.id } ]
}
```

`mangshe` 在 LPC 里有 `set_name()`，是**人物**，该进 `room_characters`。
而 `Loader.parse_items/3` 解析不到 `items.mangshe` 就静默跳过：

```elixir
# lib/kantele/world/loader.ex
item_id = dereference(zones, zone, item_id)
# 物品数据缺失（引用不存在）时跳过，避免悬挂引用
if is_nil(item_id) do
  zone
else
  parse_room_item(zone, room_id, item_id)
end
```

结果 `baituo:cave` 运行时**一个人都没有**，「蟒蛇封路」的门禁永不触发。

同类 8 处（本轮已修）：

| 房间 | 被误填成 | 实为 |
|---|---|---|
| `wudu:wandu1` | `items.hehongyao` | `characters.hehongyao` |
| `zhongzhou:miaojia_houting` | `items.miao` | `characters.miao` |
| `emei:cangjinglou` | `items.daoming` | `characters.daoming` |
| `heimuya:chengdedian` | `items.ren` | `characters.ren` |
| `baituo:cave` | `items.mangshe` | `characters.mangshe` |
| `wudang:gyroad1` | `items.mangshe` | `characters.mangshe` |
| `kaifeng:hh_jianlou1` | `items.wuchen` | `characters.wuchen` |
| `mingjiao:rjqyuan` 等 13 处 | `items.shuobude` 等 | `characters.*`（未修，见 §5） |

### ② `room_characters` 引用了本区没有的定义

```elixir
# data/world/luoyang.ucl —— 转换后
room_characters "bingyindamen" {
  room_id = rooms.bingyindamen.id
  characters = [ { id = characters.guanbing.id }, { id = characters.guanbing.id } ]
}
```

`characters.guanbing` 确实存在，但定义在 `changan.ucl` / `kaifeng.ucl`。
而解析只在本区找：

```elixir
# lib/kantele/world/loader.ex
case Enum.find(zone.characters, &match_character(&1, character_id)) do
```

所以 `luoyang:bingyindamen` 运行时是空的。同类：`jingzhou:wanghouse` →
`characters.shang2`（定义在 `shaolin.ucl`）。

### ③ 名字被写倒

```lpc
// mud/d/jingzhou/npc/jing.c
set_name("凌退思", ({ "ling tuisi", "ling", "tuisi" }));
```

```elixir
# data/world/jingzhou.ucl —— 转换后（错）
name = "凌思退"
aliases = ["ling situi", "ling"]
```

「退」与「思」颠倒，`present("ling tuisi")` 永远匹配不上，
`jingzhou:ymzhengting` 的门禁永不触发。已改正。

> 注意：`characters "jing"` 这个 id 也和 LPC 文件名对不上，容易误判为无关 NPC。

---

## 三、本轮补的 NPC

放置数量按各房间 LPC `set("objects", ...)` 原样照搬。

| 房间 | NPC | LPC 源 | skills |
|---|---|---|---|
| `luoyang:bingyindamen` | 官兵 ×2 | `d/kaifeng/npc/guanbing.c` | 5 |
| `jingzhou:wanghouse` | 家丁 ×2 | `d/shaolin/npc/shang2.c` | 2 |
| `zhongzhou:miaojia_houting` | 苗人凤 | `kungfu/class/miao/miao.c` | 23 |
| `heimuya:chengdedian` | 任我行 | `kungfu/class/riyue/ren.c` | 30 |
| `wudu:wandu1` | 何红药 | `kungfu/class/wudu/hehongyao.c` | 20 |
| `baituo:cave` | 蟒蛇 | `clone/beast/mangshe.c` | 0 |
| `wudang:gyroad1` | 蟒蛇 | `clone/beast/mangshe.c` | 0 |
| `emei:cangjinglou` | 道明小师父 | `kungfu/class/emei/daoming.c` | 4 |
| `kaifeng:hh_jianlou1` | 无尘道长 | `kungfu/class/honghua/wuchen.c` | 13 |

### 同名不同人：必须按 LPC 的 `CLASS_D(...)` 取源

| 目标 | LPC 写法 | 正确源 | 错误源（数据里已有，别用） |
|---|---|---|---|
| `heimuya:chengdedian` 任我行 | `CLASS_D("riyue")+"/ren"` | `kungfu/class/riyue/ren.c`（日月神教教主，30 技能） | `d/meizhuang/npc/ren.c`（上任教主，在梅庄） |
| `wudu:wandu1` 何红药 | `CLASS_D("wudu")+"/hehongyao"` | `kungfu/class/wudu/hehongyao.c`（五毒教长老 / 疤面丐婆） | `d/dali/npc/hehongyao.c`（大理） |
| `zhongzhou:miaojia_houting` 苗人凤 | `CLASS_D("miao")+"/miao"` | `kungfu/class/miao/miao.c`（48 岁，23 技能） | `d/shaolin/npc/miao.c` |
| `kaifeng:hh_jianlou1` 无尘 | `CLASS_D("honghua")+"/wuchen"` | `kungfu/class/honghua/wuchen.c`（13 技能） | `d/hangzhou/honghua/wuchen.c`（8 技能） |

### 别名：LPC 的 `present()` 会忽略空格，我们不会

```lpc
// kungfu/class/emei/daoming.c
set_name("道明小师父", ({ "daoming","xiaoshifu",}));     // id 无空格
// d/emei/cangjinglou.c
present("dao ming", environment(me))                      // 查询有空格
```

LPC 匹配前会去掉空格，所以原文能命中。`LpcCondition` 的别名匹配
（`ExitVetoContext.present/4`）不做规范化，**两种写法都得写进 `aliases`**。

---

## 四、审计脚本自身的两个 bug（已修）

### ① 把析取当合判

LPC 门禁里 `present()` 常出现在 `||` 里：

```lpc
// mud/d/shaolin/qyping.c
present("fumo dao", me) || present("jingang zhao", me) || ...
```

审计和测试（两份重复实现）却要求**所有** `present()` 都满足，于是误判：

- `fumo dao` 在 LPC 里**根本不存在**（只有伏魔杖 `fumo-zhang`、
  伏魔剑 `fumo-jian`、大伏魔拳 `dafumo-quan`），
  而同一条件里的 `jingang zhao` 有定义 → **这条门禁一直有效**
- `mingjiao:square` 是五个 NPC 的析取，`shuo bude` / `leng qian` 在场就够

已新增 `LpcCondition.satisfiable?/2`（复用已有 AST，不另写解析器）：
把每个 `present()` 换成给定的真假，其余子表达式**乐观当成真**
（只问「有没有可能成立」），再按 `&&`/`||`/`!` 求值。

> 实现坑：`!` 只能作用在含 `present()` 的子表达式上才取反。
> 否则 `!wizardp(me)` 会先乐观成 `true` 再被翻成 `false`，
> 等于凭空断言「这条永远不拦」。

### ② `present_refs` 用正则会漏

`~r/present\('([^']+)'/` 匹配不到双引号写法。
已改为走解析器（`LpcCondition.present_refs/1`）。

---

## 五、未修：`room_items` 大面积悬空（量级最大）

### 数字

| 指标 | 值 |
|---|---|
| 全库 `room_items` 引用总数 | 694 |
| 引用了本区不存在的 `items.X` | 694 |
| 其中**彻底悬空**（`items`/`characters` 两边都没定义） | **674** |
| 其中 NPC 被当物品（本文 §2①那类） | 20 |
| 房间总数 | 4470 |
| **运行时真的有物品的房间** | **163（3.6%）** |
| 运行时物品实例总数 | 315 |
| `items` 定义总数 | 1134 |

### 后果

LPC `set("objects", ...)` 里**物品**的部分基本没落地。
例：`baituo.ucl` 定义了 27 个 `items` 块，
而 `items.jinshe.id`（金蛇）被 `cao1` / `cao2` 引用 3 次，**从未定义**。
白驼山的金蛇/青蛇/毒蛇、各类丹药物品等等都没有生成。

### 建议处理方式

不适合手改（674 处）。两条路：

1. **补定义**：从 LPC 的 `clone/item/` `d/*/obj/` 批量生成 `items` 块，
   参照本轮 NPC 的做法。缺点是工作量仍大，且要逐个核对数值。
2. **修转换器**：`scripts/lpc_converter.py` 里 `set("objects")` 的分流逻辑
   本该按 LPC 文件里有没有 `set_name()` 决定进 `room_items` 还是
   `room_characters`。修好后重跑转换 —— 但重跑会覆盖已有的人工修正，
   需要先隔离。

另：至少该在 loader 里对**解析不到的引用**打一条 warning，
不要静默跳过。否则这类问题永远查不出来。

---

## 六、剩余 11 条不拦人的门禁

| 原因 | 条数 | 说明 |
|---|---|---|
| 未限定方向 | 4 | 见 §6.1，真·丢了守卫的只剩这 4 条 |
| 要求不存在的方向 `west` | 5 | `xiyu:kedian` `lingzhou:biangate` `chengdu:kedian` `fuzhou:rongcheng` `tiezhang:kedian` |
| 要求不存在的方向 `enter` | 1 | `city:mudren`，旧 todo 的 F 项，建议正式免除 |
| 要求不存在的方向 `south` | 1 | `foshan:pm_restroom`（条件是 `balance < 5000000 \|\| weiwang < 30`） |

「未限定方向」那 17 条**不能直接执行** —— 会把该房所有出口变成同一道门禁，
可能把玩家锁死。`LpcCondition.direction_scoped?/1` 就是在防这个。

### 6.1 逐条分类：只有 2 条能安全补守卫

排查后发现这 16 条**不是同一种病**，之前笼统叫「丢了外层守卫」是不准确的。

> **教训：不要用正则去切房间块。**
> `re.search(r'rooms\s+"X"\s*\{(.*?)\n  \}', s, re.S)` 会在房间内部
> 提前截断（条件块里有 `\n  }` 这种两空格缩进的结尾），把条件算到隔壁房间头上。
> 我据此一度报出「6 条转换器编造的条件」，还差点删掉 `qunyulou` /
> `bingqifang` / `dmyuan2` 的**正版**条件 —— 那三个房间其实都有 LPC `valid_leave`。
> 正确做法是**括号配平**定位房间块，或者直接信 `scripts/audit_veto_effectiveness.exs`
> 的输出（它走 loader，房间归属是对的）。
>
> 同理，删除条件时也必须限定房间范围：同一个条件字符串在别的房间是合法的。

#### (a) 能安全补回守卫：2 条（都已做）

**`xiyu:xxh6` 的 gender 那条** → `dir == 'in' && present('caihua zi',environment(me)) && me->query('gender') == '无性'`，与原文逐字对应。「无性」是玩家固有属性，不存在「先做点什么才能解开」，不会锁死。

**`changan:qunyulou`** → LPC：

```lpc
if (dir == "south" && objectp(ob = present("da shou", this_object())) && living(ob)) {
    if (wizardp(me)) return ::valid_leave(me, dir);
    if ((string)me->query("gender")=="女性") return notify_fail(...);
}
```

房里有 `dashou` ×4，出口 `south`/`north`，守卫方向就是 `south`。
补成 `dir == 'south' && objectp(ob = present('da shou',this_object())) && living(ob) && (string)me->query('gender')=='女性'`。

同一函数里还有一条「不准带武器进入」，是遍历 `all_inventory` 的 `for` 循环，
条件语言表达不了，仍留在注释里。

#### (b) 补了守卫反而更宽（误拦）：1 条 —— 我踩过，已还原

`beijing:kediandayuan`。LPC 除了方向，还要求**目的地房间**里有拉马和毒匕神尼
（条件语言只能看自己这个房间）。加 `dir == 'east'` 的结果是**所有**内力<100 的
玩家都过不去，比 LPC 宽得多。是既有测试
`exit_veto_runtime_test.exs`（「依赖目的地房间内容，无法表达」）把它挡下来的。
已还原。

> 教训：**给条件加 `dir ==` 不等于「修好了」**。要先确认 LPC 的**全部**前置条件
> 都已表达出来，否则只是把一条死条件变成一条误拦条件。

#### (c) 表达能力不足，补不了：3 条

| 房间 | 条件 | 为什么补不了 |
|---|---|---|
| `beijing:kediandayuan` | `force < 100` | 要看目的地房间内容 |
| `huashan:bingqifang` | `j > 1` | LPC 是 `for(...) if (inv[i]->query("id")=="zhujian") j++;`，即「背包里竹剑超过 1 把」。`j` 是 LPC 循环变量，条件语言没有「按 id 统计背包」的概念 |
| `taishan:nantian` | `me->query('id') != mengzhu` | `mengzhu` 是 LPC 局部变量（`find_living("mengzhu")->query("winner")`），裸标识符无法求值 |

#### (d) 必须保持禁用（会锁死）：1 条

`xiyu:xxh6` 的 `marks/花` 那条。`marks/花` 全库只由
`mud/d/xiyu/npc/caihua.c` 的 action 设置，而采花子的 action 没移植 ——
搜遍 `lib/` 和 `data/` 没有任何地方写这个标记。加 `dir == 'in'` 守卫后，
`xiyu:xiaoyao` 会对**所有人**封死（不是只封非星宿海）。
已在数据里写明原因，并加了回归测试钉住这条不许被加上。

#### 6.2 真正的「未限定方向」只剩 4 条 —— 因为有 12 条其实标了 `all_dirs`

这是本轮最大的一个审计口径错误。

数据里有 **12 条** veto 标了 `all_dirs = true`，意思是「这条就拦这个房间的
**所有**方向」。这是**故意**的 —— 它们的 LPC 原文本来就没有 `dir` 判断：

| 房间 | LPC 原文的行为 |
|---|---|
| `d/lingxiao/wave.c` | `if (objectp(present("xuanbing chimang", environment(me))))` —— 玄冰莽封住冰洞，**只有一个出口也照样拦** |
| `d/city/nproom.c` / `sproom.c` / `eproom.c` / `wproom.c` | `if (me->query_temp("pigging_seat"))` —— 坐在拱猪桌前哪儿都去不了 |
| `d/city/qiyuan/qiyuan2..4.c` | `if (me->query_temp("weiqi_seat"))` —— 下棋时不能走 |
| `d/city/lichunyuan2.c` | `if (me->query_condition("prostitute"))` |
| `d/huashan/chufang.c` / `d/xiangyang/juyichufang.c` | `if (present("soup", me) \|\| present("rice", me))` —— 端着饭不许走 |
| `d/shaolin/dmyuan2.c` | `if (! present("xisui jing", this_object()))` —— 心法不见了不许走 |

而审计脚本（和测试里那份同样逻辑的 `do_classify/4`）只看
`condition` 字符串里有没有 `"dir"` 字样：

```elixir
not LpcCondition.direction_scoped?(c) -> {:dead, "未限定方向"}
```

于是这 12 条**全部**被误判成「丢了外层守卫」。
`LpcCondition.direction_scoped?/1` 的本意是「防止把该房所有出口变成同一道门禁」，
而 `all_dirs = true` 恰恰是数据里**显式声明**「就是要拦所有方向」——
两者语义相反，不能混。已修（先判 `all_dirs`），并加了回归测试钉住 12 这个数。

修正后：会拦人 **143 → 155**，未限定方向 16 → **4**（真的只剩
`beijing:kediandayuan`、`huashan:bingqifang`、`taishan:nantian`、`xiyu:xxh6`）。

### 6.3 那 12 条「会拦人」其实大多永不触发（更正我上一条消息）

我上一条消息说「`city:qiyuan2/3/4` 的 `weiqi_seat` 启用即死锁」。**这个说法是错的。**

逐个查了触发状态的写入点（扫 `lib/` + `data/` 全文）：

| 门禁依赖 | 谁在 LPC 里写它 | 我们这边 |
|---|---|---|
| `pigging_seat` | `d/city/{n,s,e,w}proom.c` 的 action | **无任何代码 set** |
| `weiqi_seat` | `d/city/qiyuan/qiyuan2.c` | **无任何代码 set** |
| `prostitute` | `kungfu/condition/prostitute.c` | **无任何代码 set** |
| `marks/花` | `d/xiyu/npc/caihua.c` | **无任何代码 set** |
| `xuanbing chimang` | `clone/beast/xuanmang.c` | **NPC 未定义** |
| `xisui jing` | `clone/book/xisuijing.c` | 物品已定义，且**已放在** `shaolin:dmyuan2` |

前四种是**玩家身上的 temp / condition**，没人写就恒为 `nil`，
条件恒假 —— 所以启用它们**既不会死锁，也永远不会拦人**（是「无效」而不是「危险」）。
真正缺的是拱猪桌 / 棋苑 / 丽春院 / 采花子这些**玩法本身没移植**。

后两个不同：

- `xisui jing`：**洗髓经已经在房里**，所以 `! present(...)` 当前为假 → 放行。
  等玩家把经捡走就会变成真 → 拦下**所有**出口。这与 LPC 一致
  （原文消息：「本寺最高心法不见了，你怎敢就走？」），但会让 `shaolin:dmyuan2`
  变成一个必须带经才能出的房间。要不要保留请定夺。
- `xuanbing chimang`：**玄冰莽压根没定义**，而 `lingxiao:wave` 的 `room_items`
  里还挂着一个悬空的 `items.xuanmang.id`（见 §5）。这是本轮唯一「补了就能真生效」
  的一条，但要注意 `lingxiao:wave` 有 **up / down / out 三个出口**，
  全被玄冰莽封住就等于把房间锁死，必须能打死它。**未动，等确认。**

---

## 七、复现命令

```bash
# 门禁生效性总账
docker exec wuxia_mud_dev-app-1 sh -lc \
  "cd /app && mix run --no-start scripts/audit_veto_effectiveness.exs"

# 全量测试
docker exec -e MIX_ENV=test wuxia_mud_dev-app-1 sh -lc \
  "cd /app && mix test --seed 12345"
```

核对「数据里的引用」与「运行时是否存在」必须分别做，例如：

```elixir
# 运行时房间在场人物
world = Kantele.World.Loader.load()
Enum.filter(world.characters, &(&1.room_id == "baituo:cave"))

# 运行时房间物品实例（注意字段名是 :item_instances，不是 :items）
Enum.count(Enum.get(world |> Enum.find(&(&1.id == "baituo:cave")), :item_instances))
```

`Room` 结构体**没有** `:items` 字段；loader 用 `Map.put(room, :item_instances, ...)`。
用错字段名会得到 `KeyError`，而不是空列表 —— 这点容易误判成「房间没有物品」。

---

## 八、生成 NPC 数据时的踩坑（供后续复用）

批量从 LPC 生成 `characters` 块时踩到的，按发生顺序：

1. **别把 LPC 的 ANSI 拼接整体去色**
   `set("title", HIR "明教" NOR + WHT "五散人" NOR)` 去掉颜色宏后
   会留下 `"明教" + "五散人"`，换掉引号仍是坏 UCL。
   改为在整段里 search 第一个字符串字面量。

2. **`long` 是多行字符串续行，含字面换行**
   UCL 字符串不跨行。`\s{2,}` 压不掉**单个** `\n`
   （`瘦\n小`），Elias 直接语法错。必须用 `\s+`。

3. **`set_name` 的第一个字面量是名字，不是别名**
   `set_name("官兵", ({ "guan bing", "bing" }))` —— 对整段做
   `findall('"([^"]*)"')` 会把名字也塞进 `aliases`。

4. **改已有 `room_characters` 列表时别混用下标**
   内层列表匹配的相对下标要加上外层块的偏移才能用于替换：
   `m.start(1) + lm.start(1)`。直接用内层下标会把文件开头写坏。

5. **优先用括号配对定位块范围**，别用正则 + 下标拼接。
   正则方案我写坏过 `heimuya.ucl` / `lingxiao.ucl` / `mingjiao.ucl` 三个文件。

6. **别用正则切房间块**
   `rooms "X" { ... }` 要用**括号配平**定位。`.*?` 会在房间内部提前截断
   （条件块结尾是 `
}`，若写成 `
  }` 更会错位），把条件算到隔壁房间头上。
   我据此误报过「6 条转换器编造的条件」，还差点删掉 `qunyulou` /
   `bingqifang` / `dmyuan2` 的**正版**条件 —— 那三个房间其实都有 LPC
   `valid_leave`。要么括号配平，要么直接信 loader 驱动的审计脚本输出。

7. **删条件也要限定房间范围**
   同一个条件字符串在别的房间可能是合法的：`pigging_seat` 有 4 个房间、
   `weiqi_seat` 有 3 个、`soup/rice` 有 2 个。按字符串全局删会误伤正版。

8. **自检要检查「每行引号配对」**，而不是 `assert '\n' not in blk`
   —— 块本身就是多行文本，那个断言必然失败。