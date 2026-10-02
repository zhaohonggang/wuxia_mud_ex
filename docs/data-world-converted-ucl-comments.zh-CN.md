# `data/world` 转换区 UCL 注释汇总（源：`C:\files\git\mud\d`）

> 本文件统计 `data/world/*.ucl` 中**由当前 Python 转换器**（`scripts/lpc_converter.py`）从
> `C:\files\git\mud\d\<zone>` 转换出来的 **71 个 `.ucl`** 文件内的全部 `#` 注释行，按含义归类。
> 判定方法：文件**首条** `# Generated from ... by LPCConverter` 的路径含 `C:/files/git/mud/d/`。
> 生成日期：2026-10-01；数据基线：git `cf44dfa`。

## 0. 范围

统计对象：71 个转换区（与 `docs/zone-conversion-checklist.zh-CN.md` 一致，含 `special` 等多源文件区）。

**不包含**（转换器工作之外、非本来源的文件）：

| 文件 | 排除原因 |
|------|----------|
| `global.ucl` | 旧 Elixir 转换器从 `test_minimal_world_v2_modified` 转出；`UNHANDLED FUNCTION`（514）、`UNHANDLED CONTENT`（164）、`Requires manual conversion`（122）、`Generic LPC file`（122）、`COMPLEX`（33）、`SWITCH`（30）、`RAW`（2）共 **987** 条未转换标记集中在这里，**与本 mud/d 来源无关** |
| `test.ucl` | 转换器靶场（`test_minimal_world_v2_modified` 语料），未接入正式世界 |
| `liuxi` / `kissa-jarvi` / `lepakko-luola` / `sammatti` / `signature` | 手工维护区，非转换产物（无 `<zone>.comments.txt`） |

## 1. 总览

71 个文件共 **14483** 条注释行。分类如下：

| # | 类别 | 条数 | 含义 | 需关注 |
|---|------|-----:|------|:------:|
| 1 | `# Generated from ... by LPCConverter`（来源标注） | 6843 | 每个 LPC 源 `.c` 一个区块，记录源文件绝对路径 | — |
| 2 | `# Zone: <zone>`（区块头） | 6843 | 与 #1 一一配对（每次转换一对），标识每块所属区 | — |
| 3 | `# skipped ...`（被跳过项） | 96 | 转换时被跳过的出口/物件/inquiry，**带原因** | ✅ |
| 4 | `# 阻挡条件（原样保留）` | 183 | `valid_leave` 的 LPC 条件原文，仅注释留存，运行时不拦截 | ☑ |
| 5 | `# vendor_goods: "<路径>" (file not found)` | 464 | NPC 兜售表里**未解析**成 `goods` 条目的引用 | ⚠ |
| 6 | `# River ...` / `# - ...` 渡船动作说明 | 54 | 黄河/湖泊渡船的 `yell` 唤船、`cross` 渡河动作说明注释 | — |

> #1/#2 共 13686 条（两行一组、一一配对）是纯区块标注，不含信息。
> 真正代表「代码被跳过/丢弃」的只有 #3（96）、#5（464），#4 是「保留了原文但移出了逻辑」。

## 2. `# skipped ...` —— 被跳过的出口/物件（96 条 / 18 个区）

| 原因 | 条数 | 涉及区 | 示例 |
|------|-----:|--------|------|
| 出口指向 `d/` 之外（`/clone`/`/b`）：目标不是已转换区，没有 `data/world/<zone>` 可引用 | 17 | `beijing`、`changan`、`chengdu`、`city`、`dali`、`foshan`、`fuzhou`、`hangzhou`、`hengyang`、`jingzhou`、`kaifeng`、`luoyang`、`suzhou`、`xiangyang`、`zhongzhou` | `skipped exit up: target outside d/: /b/yitian/jiulou: no data/world zone to reference` |
| 方向名非 ASCII（CJK）：elias 的 `Word` token 只认 ASCII | 64 | `shaolin` | `skipped exit direction '乾': direction is not ASCII; elias's Word token is ASCII-only, so this key cannot be lexed` |
| 方向名含数字：elias 把 `Digit` 当独立 token，赋值闭合不了 | 6 | `huashan` | `skipped exit direction 'hole1': direction contains a digit; elias lexes Digit as a separate token, so the assignment cannot close` |
| inquiry 值是 LPC 闭包，elias 无法解析（数字紧邻逗号） | 6 | `xiangyang` | `skipped inquiry "铁护腕": value "(: ask_me_1, 'huwan' :)" is unparseable by elias (digit immediately before a comma)` |
| 物件路径运行时拼接（`+`/`random(...)`），无确定 id | 2 | `wudang` | `skipped unresolvable object path '"/clone/book/" + books[random(sizeof(books))]': no determinate object id` |
| 非房间型出口（LPC portal/mapping） | 1 | `city` | `skipped non-room exit 'enter': LPC portal/mapping target` |

其中「出口指向 `d/` 之外」的目标分布：`/clone/...` **15** 条（`/clone/shop/*` 城主商铺、`/clone/weapon|cloth|book` 标准物件库）、`/b/...` **2** 条（`/b/yitian/jiulou`、`/b/tulong/haigang`）。

结论：全部是 elias/UCL 语法限制或外部未转换目标导致的**必然跳过**，转换期已逐条核查登记：
- 非 ASCII 方向的 64 条全在 `shaolin`（八卦方位 `乾`/`巽`/`离`…）—— elias 的 `Word` token 只认 ASCII，`#` 注释是唯一可留的落点；
- 含数字方向的 6 条在 `huashan`（`hole1..hole6`），为冗余反向链接（目标房各带 `out`），跳过不造成不可达；
- inquiry 6 条是 `xiangyang` 铁匠的 `(: ask_me_N, '...' :)` 闭包，elias 对「数字紧邻逗号」必然失败（leex 缺陷）；
- 物件路径 2 条是 `wudang` 藏经阁的 `"/clone/book/" + books[random(sizeof(books))]`，运行时才能确定；
- 非房间型 1 条是 `city` 的 `enter`（portal）。

## 3. `# 阻挡条件（原样保留）` —— `valid_leave` 情况（183 条 / 43 区）

这些是 `valid_leave`（房内 LPC 函数）里的放行判断原文。转换器把出口的两边（`exit_vetoes`）解析出来，
但**条件本身只能以注释留存**：UCL 字符串不能含 `(` `)` `,`，且运行时没有 LPC 求值器。
loader 侧 `Room` 的 `exit_vetoes` 字段会填充，但 `condition` 恒为空、`valid_leave` 不拦截（**故意不拦截**，登记在 checklist §H）。本文件统计口径：注释所在区 **43** 个。

条件类型分布（按匹配到的特征词，可能重复计数无 —— 每条只归第一个命中的类型）：

| 类型 | 条数 | 示例 |
|------|-----:|------|
| 持有/在场物件 `present(...)` | 87 | `dir == "in" && objectp(present("mang she", environment(me)))` |
| 临时标志 `query_temp` | 45 | `!me->query_temp("rent_paid") && dir == "up"` |
| 其它函数/表达式 | 24 | `(int)inv[i]->query("weapon_prop")` |
| 方向/位置断言 | 15 | `dir == "west" && (int)me->query("combat_exp") < 600 && guarder` |
| 身份/属性查询 `query(...)` | 10 | `(string)me->query("gender")=="女性"` |
| 技能/内力门槛 `query_skill` | 2 | `(int)me->query_skill("force") < 100` |

## 4. `# vendor_goods: "<路径>" (file not found)` —— 丢弃的兜售引用（464 条 / 36 区）

LPC 商贩在 `set("vendor_goods", ...)` 里挂的售卖对象。转换器**能**解析的条目产出为
`goods = [ { id = items.<名>.id } ... ]`（19 区 / 54 块，另见 `docs/data-world-ucl-inventory.zh-CN.md`）；
**解析不到**的条目被丢弃，只留这条注释保留原路径。

目标分布（前 6）：
- `/d/xiyu/obj/fire` ×12
- `/clone/weapon/tudao` ×7
- `/clone/weapon/gangdao` ×7
- `/clone/weapon/changjian` ×6
- `/clone/weapon/tiegun` ×6
- `/d/city/obj/jitui` ×6
- `/d/city/obj/jiudai` ×6
- `/d/city/obj/baozi` ×6

> 说明：`(file not found)` 不代表源文件一定不存在——本区与其它区源码都可能在。
> 已抽查：`/d/xiyu/obj/fire` 的源文件存在、`xiyu.ucl` 里也有 `items "fire"`，但兜售条目仍未解析，
> 说明该判定是**保守规则**（等价于「本次转换不接入 vendor 对象表」），并非简单判文件存在性。
> 影响：这些 NPC 运行时没有对这些对象的兜售（UCL `goods` 字段为准）。相对 `cli/` 等原世界的完整
> 商业链是已知偏差，未在转换期处理。

## 5. `# River ...` / `# - ...` —— 渡船动作说明（54 条 = 18 条 `River actions:` 头 + 36 条 `- ` 明细 / 9 个 mud 区）

黄河/湖泊渡船的动作说明：`# River actions: yell [boat] / cross` 之外，每条 `- (yell|cross) ...` 具体说明触发条件。涉及区：`guanwai`、`heimuya`、`huanghe`、`lanzhou`、`lingzhou`、`shaolin`、`wudu`、`yanziwu`、`zhongzhou`。

```
# River actions: yell [boat] / cross
# - yell boat: summons river_boat to arrive_room (3s)
# - cross: requires dodge>=270 & neili>=300, moves to arrive_room
```

纯说明注释，无代码丢弃。

## 6. 区块标注（13686 条）—— 每源文件一组的来源对

每个 LPC 源 `.c` 转换为 UCL 区块时写两行：

```
# Generated from C:/files/git/mud/d/baituo/bridge.c by LPCConverter
# Zone: baituo
```

两组数字相等（6843 对），因为转换器逐个源文件生成区块。含区为 71 个转换区的全部源码文件。

## 7. 逐区统计

| 区 | 注释行 | skipped | 阻挡条件 | vendor_goods |
|----|-------:|--------:|----------:|-------------:|
| shaolin | 686 | 64 | 26 | 8 |
| death | 569 | 0 | 6 | 81 |
| luoyang | 484 | 1 | 3 | 74 |
| city | 602 | 2 | 18 | 42 |
| hengyang | 378 | 1 | 1 | 54 |
| beijing | 890 | 3 | 9 | 36 |
| xiangyang | 345 | 7 | 4 | 26 |
| changan | 556 | 1 | 3 | 14 |
| jingzhou | 342 | 1 | 8 | 5 |
| lanzhou | 137 | 0 | 2 | 9 |
| lingzhou | 148 | 0 | 4 | 7 |
| fuzhou | 187 | 1 | 3 | 7 |
| lingxiao | 213 | 0 | 2 | 9 |
| tulong | 247 | 0 | 11 | 0 |
| kaifeng | 415 | 1 | 3 | 7 |
| xiyu | 210 | 0 | 5 | 5 |
| hangzhou | 400 | 1 | 2 | 7 |
| quanzhou | 117 | 0 | 1 | 8 |
| shenfeng | 151 | 0 | 1 | 8 |
| tiezhang | 203 | 0 | 5 | 4 |
| chengdu | 213 | 1 | 4 | 4 |
| zhongzhou | 249 | 1 | 1 | 7 |
| suzhou | 202 | 1 | 2 | 5 |
| baituo | 210 | 0 | 2 | 6 |
| huashan | 226 | 6 | 2 | 0 |
| heimuya | 242 | 0 | 7 | 1 |
| guiyun | 127 | 0 | 5 | 2 |
| wuguan | 129 | 0 | 7 | 0 |
| kunming | 157 | 0 | 3 | 4 |
| wudang | 257 | 2 | 5 | 0 |
| foshan | 107 | 1 | 1 | 3 |
| taishan | 113 | 0 | 3 | 2 |
| huanghe | 172 | 0 | 2 | 3 |
| emei | 263 | 0 | 2 | 3 |
| mingjiao | 413 | 0 | 5 | 0 |
| xueshan | 132 | 0 | 2 | 2 |
| kunlun | 156 | 0 | 0 | 4 |
| guanwai | 212 | 0 | 2 | 2 |
| quanzhen | 332 | 0 | 3 | 1 |
| songshan | 91 | 0 | 0 | 3 |
| wudu | 339 | 0 | 3 | 0 |
| dali | 645 | 1 | 2 | 0 |
| wizard | 19 | 0 | 1 | 0 |
| motianya | 29 | 0 | 1 | 0 |
| pk | 31 | 0 | 1 | 0 |
| tianlongsi | 71 | 0 | 0 | 1 |
| tangmen | 4 | 0 | 0 | 0 |
| special | 12 | 0 | 0 | 0 |
| jinshe | 18 | 0 | 0 | 0 |
| xuanminggu | 26 | 0 | 0 | 0 |
| item | 28 | 0 | 0 | 0 |
| register | 28 | 0 | 0 | 0 |
| gaibang | 34 | 0 | 0 | 0 |
| huanggong | 42 | 0 | 0 | 0 |
| xuedao | 58 | 0 | 0 | 0 |
| xiaoyao | 60 | 0 | 0 | 0 |
| sky | 64 | 0 | 0 | 0 |
| qingcheng | 66 | 0 | 0 | 0 |
| gaochang | 74 | 0 | 0 | 0 |
| hengshan | 74 | 0 | 0 | 0 |
| room | 80 | 0 | 0 | 0 |
| shenlong | 84 | 0 | 0 | 0 |
| village | 104 | 0 | 0 | 0 |
| taohua | 112 | 0 | 0 | 0 |
| lingjiu | 118 | 0 | 0 | 0 |
| meizhuang | 118 | 0 | 0 | 0 |
| jueqing | 128 | 0 | 0 | 0 |
| yanziwu | 140 | 0 | 0 | 0 |
| wanjiegu | 146 | 0 | 0 | 0 |
| gumu | 160 | 0 | 0 | 0 |
| xiakedao | 288 | 0 | 0 | 0 |

## 8. 结论

- 71 个转换区共 **14483** 条注释；**13686** 条（#1/#2）是区块标注，54 条（#6）是渡船说明。
- 代表「被跳过/丢弃」的注释：#3 `skipped` 96（全部原因明确、可解释）、#4 `阻挡条件` 183（条件原文保留）、#5 `vendor_goods` 464（解析规则保守所致）。三者合 743 条，占注释总量的 5.1%。
- 除 `global.ucl` 外，mud/d 转换区**没有** `UNHANDLED FUNCTION` / `Requires manual conversion` / `Generic LPC file` 等「未转换」标记——那些全在旧转换器产出的 `global.ucl` 里（本文件范围外）。

## 附录 A. 生成方法

一次性扫描脚本（在 `C:\Users\honggang\AppData\Local\Temp\opencode\classify_conv2.py` 基础上扩展，未入库）。
判定口径：`#` 开头 → 剥 `#` → 按首词分词归类；`skipped` 再按原因正则细分。
