# UCL 转换问题汇总与待办

> 范围：`scripts/lpc_converter.py`、`scripts/assign_room_coords.py`、
> `scripts/validate_ucl.py` 在把 `C:\files\git\mud\d\<zone>` 的 LPC 源码转换成
> `data/world/<zone>.ucl` 过程中发现的问题。
>
> 不含 `.comments.txt`（转换器的注释旁路输出，仅供人工查阅，本身不参与加载）。
>
> 状态图例：**已修** = 代码已改并重跑全部区域；**未修** = 问题确认存在、尚未处理。

---

## 1. `_merge_vals` 空元组越界（已修）

**现象**　`city` / `baituo` / `jingzhou` / `luoyang` 四区转换直接崩溃：

```
IndexError: tuple index out of range
```

**根因**　`base_exits[0] == "mapping"` 在 `base_exits` 为空元组时越界。

**影响**　这 4 个区完全无法产出 `.ucl`，整个世界无法启动。

**修复**　先判断长度再取下标。

---

## 2. 跨区出口被当成本区引用（已修）

**现象**　`city/beimen -north->` 源码是 `/d/shaolin/yidao`，产物写成

```
north = rooms.yidao.id
```

加载器在**本区**找不到 `yidao`，返回 `nil`，被 `parse_exits` 的
`Enum.filter(not is_nil)` 静默丢弃 → 全世界 71 个区是互不连通的孤岛。

更糟的是**同名撞车会连到错误的房间**：

```
beijing/ximenwai -west-> /d/heimuya/road3   # 应去黑木崖
```

但 `beijing` 自己有 `road3`，于是走西变成了走到**北京的 road3**。共 **15 条**
这种静默连错。

**根因**　`lpc_converter.py` 的 `_room_id_from_path()` 把 `/d/` 前缀剥掉、只取
basename，**丢掉了区名**。

**修复**　跨区目标输出 `<区名>.rooms.<房名>.id`。
`Kantele.World.Loader.dereference/3`（`lib/kantele/world/loader.ex:1315-1343`）
本来就把参考第一段当区名查找，这个形式可直接解析。

**结果**　206 条跨区引用接通；15 条静默连错全部修正；从 `city:guangchang`
可达房间 **4115/4455（92.4%）**，不可达 340 间（分类见 G 项）。

---

## 3. 方向名含数字，elias 无法分词（已修）

**现象**　容器启动失败：

```
Kantele.World.LoaderError ... elias ... syntax error before: ', ['"6"']'
```

**根因**　`huashan/s.c` 的出口方向名是 `"hole1"`..`"hole6"`。elias 的
`Word` token 排除 `0-9`，`Digit = [0-9]+` 是独立 token，于是 `hole6` 被切成
`word "hole"` + `digit "6"`，而语法只接受 `assignment -> word equality ...`，
赋值闭合不了。**UCL 的 key 不能含任何数字。**

实测：`hole` / `hole_` 可解析；`hole6` / `hole_6` / `6hole` 全部失败。
**值侧不受影响**（`rooms.lockroom6.id` 正常）。

**修复**　`_EXIT_DIR_RE` 收紧为 `^[A-Za-z_][A-Za-z_]*$`，非法方向跳过并留注释。

**附带**　这 6 条 `hole*` 是冗余反向链接（每个 `lockroomN` 自己都有
`out = rooms.s.id`，且 `kuihua_2 -up-> lockroom1`），跳过不造成不可达。

---

## 4. 方向名含中文，elias 无法分词（已修，注释文案亦已修正）

**D 已修（2026-09-30）**　`_is_valid_exit_dir()` 换成 `_exit_dir_skip_reason()`，
按**真实原因**分三类给出文案，不再一律写成「C comment artefact」：

| 方向 | 新文案 |
|------|--------|
| 空（剥掉 C 注释后没剩东西） | `direction became empty after stripping a C comment` |
| 含 CJK（shaolin 八卦） | `direction is not ASCII; elias's Word token is ASCII-only, so this key cannot be lexed` |
| 含数字（huashan `hole1..6`） | `direction contains a digit; elias lexes Digit as a separate token, so the assignment cannot close` |
| 其它非标识符 | `direction is not a bare identifier` |

同时删掉了已无引用的 `_EXIT_DIR_RE`（判定逻辑并入新函数），
并在 `scripts/test_lpc_path_rules.py` 补 17 项断言：12 个合法方向必须返回 `None`，
三类原因各锁一条文案，另有 3 项专门断言**非空方向的消息里不得出现 "C comment"**
——正是旧文案误导排查的地方。


**现象**　同问题 3，报错 token 是 `"6"` 之外的其它字符。

**根因**　`shaolin/bagua*.c` 的出口方向名是八卦卦名 `乾`/`巽`/`离`/`艮`/`兑`/
`坎`/`震`/`坤`。elias 的 `Word` 只接受 ASCII 标识符，中文连标识符都不是。
共 **64 条**（8 方向 × 8 房）。

**修复**　同问题 3，被同一条正则拦下。

**遗留问题（已修，见下）**　原先留下的注释文案是错的：

```
# skipped malformed exit direction '乾': not a bare identifier (C comment artefact)
```

「C comment artefact（误把 C 注释当出口）」**不是真实原因**。真实原因是
elias 的 key 限制，与 `huashan` 的 `hole6` 同类。注释会误导后续排查。

---

## 5. `item_desc` 的中文 key 归一化成空串（已修）

**现象**　`validate_ucl` 报 `Syntax: expected '=' (line 2307)`：

```
item_desc = {
  = "这张床似乎可以推开(push)。"      ← 没有 key
  = "这张床似乎可以推开(push)。"
```

**根因**　`changan/qunyuys8.c` 的 `item_desc` key 是中文（`床`、`大床`）。
`_normalize_item_keyword()` 把非 ASCII 全替换成 `_` 再剥掉首尾 `_` → 空串，
但 `if keyword != ""` 检查的是**归一化前**的原值，所以空 key 漏过。

**修复**　改为对**归一化后**的 keyword 判空。

---

## 6. 行尾 C 注释被当成 mapping 的一项（已修）

**现象**　`room/xiaoyuan` 的 `dating` 房多出一条无方向名的出口：

```
room_exits "dating" {
    up   = rooms.dulewu.id
    = rooms.nil.id        ← 语法错误
```

**根因**　源码是

```c
"south" : __DIR__"xiaoyuan",   /* EXAMPLE */
```

`_HEREDOC_RAW` 把注释也 capturing 进来，`_parse_mapping_pairs()` 遇到没有 `:`
的 pair 就走兜底分支 `(key, ("var","nil"))`，渲染成 `= rooms.nil.id`。

**修复**　丢弃以 `/*`、`//`、`*` 开头的 pair；另加 `_is_valid_exit_dir()`
作为双保险。

---

## 7. `accept` 布尔/列表混淆，泄漏 Python repr（已修）

**现象**　`validate_ucl` 报 `Syntax: expected '=' (line 929)`，内容是

```
accept = [{'kind': 'item_name', 'name': '金刚经', ...}]
```

单引号 Python dict 漏进了 UCL。

**根因**　`taishan` 的 `_parse_accept_body()` 里
`has_specific_rules = money_rule is not None or item_id_rules or item_name_rules`
返回的是**非空 list** 而不是 bool（Python 的 `or` 返回最后一个操作数），
`_build_accept_ucl()` 随后把 `str(list)` 直接插值进产物。

**修复**　显式 `bool(...)` 归一化。

---

## 8. elias 无法分词：数字紧邻逗号（已修，转换器侧）

**现象**　容器反复崩溃重启：

```
Kantele.World.Kickoff terminating
elias ... syntax error before: ', ['","']
```

**根因**　**elias 0.2.8 自身的 leex 分词缺陷**。`xiangyang/wuxiuwen.c` 的
`inquiry` 值是 LPC 闭包 `(: ask_me_1, "weibo" :)`：

```
Word = [^0-9{}\*\/#\n\[\]=\s'":\;\\-]+
```

排除集里**没有逗号**，所以 leex 最长匹配会把 `a,` 吞成一个 word
（`(: a, 'b' :)` 侥幸能解析）；但只要逗号前紧邻**数字**，数字打断 word，
逗号就独立成 `comma` token，而 `elias_parser.yrl` 的 `words -> ...` 没有
comma 产生式。

实测：`(: a, 'b' :)` `(: ab, 'c' :)` `(: a_b, 'c' :)` 可解析；
`(: a1, 'b' :)` `(: ask_me_1, 'b' :)` **不能**。

值内容不可改，且**没有任何可解析写法**（`words` 既无 comma 也无 newline
产生式，反斜杠和多层引号都藏不住逗号）。

**修复**　`_elias_safe_value()` 跳过该值并留 `#` 注释说明原因。

---

## 9. elias 无法分词：反斜杠接空白（已修）

**现象**　`mingjiao` 报 `syntax error before: ', ['" "']`——报错 token 是**空格**。

**根因**　`mingjiao/miaorenbuluo.c` 的 `@TEXT` 块某行以 `口\` 结尾，是 LPC 的
**行尾续行符**（本意换行续接成 `口中`）。转换器却先把换行折成空格、留下
反斜杠，产出 `口\ 中`。而 elias 的 `words` 只有
`back_slash word` / `back_slash quotes` 产生式，反斜杠接空格无规则可走。

**修复**　新增 `_LPC_CONTINUATION`，在 `_sanitize_ucl_sval()` 里
**先于**「换行转空格」执行（那是所有字符串的最终出口，heredoc 与普通字面量
都覆盖）；`_parse_heredocs_from_raw()` 另加一道。

产出已从 `口\ 中` 恢复为正确的 `口中`（符合 LPC 续行语义，不是简单删字符）。

---

## 10. 静态校验器漏掉三类 elias 错误（已修）

**现象**　上述问题 3、8、9 **全部只能靠容器报错发现**，纯静态校验一律放行。

**根因**　`validate_ucl.py` 缺少对应的检查项，且文本类检查没有先剥离注释。

**修复**　新增三项检查 + fixture，并给所有文本扫描加 `_strip_comments()`
（否则转换器自己写的说明注释会误报）：

| 检查项 | 捕获的问题 | fixture |
|--------|-----------|---------|
| `_ELIAS_BAD_KEY_RE` | key 含数字 | 45 |
| `_ELIAS_UNLEXABLE_RE` | 引号值内「数字 + 逗号」 | 44 |
| `_ELIAS_STRAY_BACKSLASH_RE` | 引号值内 `\` 接空白 | 46 |

---

## 11. 纯物件区被误判为非法（已修）

**现象**　`tangmen` 报 `Structure: missing rooms, room_exits` +
`Integrity: no rooms defined`。

**根因**　`tangmen` 源码只有 `obj/feidao.c`、`obj/jili.c`，产物就是
1 个 `zones` 块 + 2 个 `items` 块，**0 房间**。这类文件是合法的——elias 能
解析，`Loader.load/1` 也能带着它加载全世界——但校验器的 Structure /
Integrity 假定每个区都必须有房间。

**难点**　它与 fixture `22_bad_integrity_zero_rooms`（"只有 zones 块"）
**结构完全相同**，静态检查无法区分「合法的纯物件区」和「转换器把房间全丢了」。

**修复**　`_is_object_only_zone()` 做**窄化豁免**：`zones` 存在 +
`rooms` 与 `room_exits` 均为 0 + **至少一个 `items`/`characters` 块**
（证明转换器确实跑过）。这样「转换器把房间全丢了」仍抓得到——
`22_bad_integrity_zero_rooms`（无任何物件）**仍然失败**，
`21_bad_structure_no_exits` 仍失败。新增 fixture `47_ok_object_only_zone`。

---

## 12. 垂直连接因方向被占用而跳过，导致孤儿房不可达（已修）

**现象**　`city` 的 `xsmidao*` 6 间房不可达。

**根因**　`city/xdmidao1 -up-> /d/xuedao/sroad8` 跨区接通后，
`_add_vertical_exits()` 原本的 `has_up` 判定把「目标不在本区」一律当
phantom，跳过合成；改成「跨区即占用」后又会**重复写 `up` 键**，而 elias 会把
重复键并成数组、loader 的 `String.split` 收到数组就崩（shaolin `zhonglou6`
就是这个 bug）。

**修复**　按 SOP 错误表既有要求实现 `UP_DIR_CANDIDATES` /
`DOWN_DIR_CANDIDATES`：**跳到空闲复合方向，而不是 `continue`**。
`xdmidao1` 的真实跨区 `up` 接上后，合成链接退到 `northup`，6 间房恢复可达。

---

## 13. `+random(n)` 的物件路径被整体丢弃（已修）

**修复（A-1，2026-09-30）**　新增 `_split_runtime_suffix()` / `_random_candidates()`：把 `"<路径>" + random(n)` 拆成「字面路径 + 候选枚举」，不再因路径含括号就整体丢弃。

关键点是 LPC 的 `+` 为**字符串直接拼接十进制数字**，所以

```c
"d/shaolin/obj/fojing1" + random(2)   ->  "...fojing10" 或 "...fojing11"
```

这与磁盘上的文件完全吻合——`shaolin/obj/` 只有 `fojing10.c` `fojing11.c` `fojing20.c` `fojing21.c`，**没有** `fojing1.c` / `fojing2.c`（若按 stem+序号 理解会错生成 `fojing1` / `fojing11`）。

同时修掉一个被暴露的回归：`CLASS_D("...") + "/dao-yi"` 这类惯用写法（前缀含括号，原先匹配不上拼接正则）改为取末段字面量，`dao_yi` / `wuming` / `tao_yi` 等常规物件不再被误判为动态。

无法枚举的表达式（如 `"/clone/book/" + books[random(sizeof(books))]`）仍会跳过，但**现在会留注释**。

新增 `scripts/test_lpc_path_rules.py` 锁定该行为（28 项）。


**现象**　`shaolin` 的 `cjlou` 与 `jianyu` 少了两件佛经：

```
旧 room_items "cjlou":  dao_yi, wuming, fojing1+random(2), fojing2+random(2)
新 room_items "cjlou":  dao_yi, wuming
```

**根因**　源码是

```c
"d/shaolin/obj/fojing1"+random(2) : 1,   // random(2) -> 0 或 1
"d/shaolin/obj/fojing2"+random(2) : 1,
```

**路径主体 `/d/shaolin/obj/fojing1` 是确定的**，只有尾部 `random(2)` 随机，
LPC 里 `random(2)` 只返回 0/1，即在 fojing1/fojing2 间二选一——完全可以
静态表达（例如两条都列出）。

但 `_is_dynamic_expr()` 的规则是 `[\[\]()]`，**只要路径里出现括号就整体判为
动态并丢弃**。

**性质**　真实功能倒退——旧版虽然写成 `items.fojing1+random(2).id` 这种非标准
形式，但**保留了信息**；新版直接没了，且**连注释都没留**。

**全库统计**　3 项，全部在 shaolin。

---

## 14. `__FILE__` 自引用产生悬空房间名（已修，现为真实自环）

**`__FILE__` 已真实修正为自环（B 项扩展，2026-09-30）**

原先只是「跳过 + 注释」，现按你的要求**真实指向自己房间**：
`_resolve_exit_target()` 新增 `room_id` 参数，遇到 `__FILE__` 时输出
`rooms.<本房间>.id`。

规模：**137 条出口 / 50 个房间 / 11 个区**（`baituo` `city` `gumu` `huanghe`
`mingjiao` `motianya` `taohua` `tiezhang` `xiakedao` `xiyu` `xueshan`）。

风险排查结论（都验证过，不是推测）：

- **0 条是 up/down**（全是 west/north/east/south 与四个斜向），所以
  `assign_room_coords.py` 的垂直连接合成、`_phantom_updown` 完全不受影响
- 运行时安全：`room/events.ex` 用
  `Enum.find(exits, &(&1.exit_name == exit_name))` 查表后取
  `to: room_exit.end_room_id`，自环即回到本房间 id，
  Zone → Voting → `MoveEvent` 只把 `room_id` 设为同值，原地不动
- 坐标脚本不会死循环：`_drain` 用 `visited` 集合、
  `_find_topmost_via_up_rec` 带 `visited` 参数，都有防重入
- 加载器不再丢弃：`parse_exits` 的 `not is_nil` 过滤不再命中

`test/cross_zone_wiring_test.exs` 新增一条测试锁定：`baituo:cao1` 的
`west` / `south` 必须回到 `baituo:cao1`，且全库不得残留 `__file__` 字面量。


**修复（A 项，2026-09-30）**　新增 `_split_runtime_suffix()` / `_random_candidates()`：把 `"<路径>" + random(n)` 拆成字面路径 + 候选枚举，不再因含括号整体丢弃。
LPC 的 `+` 是**字符串直接拼接十进制数字**，所以 `"d/shaolin/obj/fojing1" + random(2)` 实际指向 `fojing10` / `fojing11`——这与磁盘上的文件完全吻合（`shaolin/obj/` 只有 `fojing10.c` `fojing11.c` `fojing20.c` `fojing21.c`，**没有** `fojing1.c` / `fojing2.c`）。
同时修掉一个由此暴露的回归：`CLASS_D("...") + "/dao-yi"` 这类惯用写法（前缀含括号，原先匹配不上拼接正则）改取末段字面量，`dao_yi` / `wuming` 等常规物件不再被误判为动态。
新增 `scripts/test_lpc_path_rules.py` 锁定该行为。


**现象**　133 条出口从 `rooms.__file__.id` 变成被跳过。

**根因**　源码里 `"west" : __FILE__` 表示「出口通回本房间」。转换器把它解析成
字面量房间名 `__file__`，写出 `west = rooms.__file__.id`；该房间在世界里
不存在。

**性质**　**运行时无倒退**——旧版那 133 条出口加载器解析为 `nil` 后就被
`parse_exits` 丢弃，从来没生效过。新版只是提前丢掉。

**但仍需处理**　① 属于静默删除，没有注释；② 丢弃理由未被记录，后续无法追溯。
建议至少补一条 `# skipped exit west: self-referential (__FILE__)` 注释。

**分布**　`xiakedao` 41、`xiyu` 26、`gumu` 16、`city` 14、`tiezhang` 10、
`motianya` 9、`huanghe` 6、`mingjiao` 4、`xueshan` 4、`baituo` 3。

---

## 15. 同区子目录路径被误判为跨区（已修）

**修复（A 项，2026-09-30）**　新增 `_split_runtime_suffix()` / `_random_candidates()`：把 `"<路径>" + random(n)` 拆成字面路径 + 候选枚举，不再因含括号整体丢弃。
LPC 的 `+` 是**字符串直接拼接十进制数字**，所以 `"d/shaolin/obj/fojing1" + random(2)` 实际指向 `fojing10` / `fojing11`——这与磁盘上的文件完全吻合（`shaolin/obj/` 只有 `fojing10.c` `fojing11.c` `fojing20.c` `fojing21.c`，**没有** `fojing1.c` / `fojing2.c`）。
同时修掉一个由此暴露的回归：`CLASS_D("...") + "/dao-yi"` 这类惯用写法（前缀含括号，原先匹配不上拼接正则）改取末段字面量，`dao_yi` / `wuming` 等常规物件不再被误判为动态。
新增 `scripts/test_lpc_path_rules.py` 锁定该行为。


**现象**　3 条**同区**链接被跳过并留下误导性注释：

| 位置 | LPC 源码 | 新版产物 | 应为 |
|------|----------|----------|------|
| `city/liaotian -east->` | `__DIR__ "qiyuan/qiyuan1"` | `# skipped ... unrecognised relative path` | `rooms.qiyuan1.id` |
| `room/xiaoyuan -panlong->` | `__DIR__"panlong/dayuan"` | 同上 | `rooms.dayuan.id` |
| `room/xiaoyuan -dule->` | `__DIR__"dule/xiaoyuan"` | 同上 | `rooms.xiaoyuan.id` |
| `room/xiaoyuan -caihong->` | `__DIR__"caihong/xiaoyuan"` | 同上 | `rooms.xiaoyuan.id` |

**根因**　`_classify_exit_path()` 遇到含 `/` 的路径时，会检查首段是否等于当前
区名，不等就判为「无法识别的相对路径」并跳过。但 `qiyuan`、`panlong`、`dule`、
`caihong` 都只是**本区的子目录**，首段与区名无关。

**性质**　真实功能倒退。`city/qiyuan1`、`room/dayuan` 都是存在的房间，
旧版的链接是可用的（虽然 `room` 的链接因三个子区都有 `xiaoyuan.c` 拍平后撞名，
实际是自环）。

---

## 16. `d/<区名>/` 缺前导斜杠未被识别（已修）

**修复（A 项，2026-09-30）**　新增 `_split_runtime_suffix()` / `_random_candidates()`：把 `"<路径>" + random(n)` 拆成字面路径 + 候选枚举，不再因含括号整体丢弃。
LPC 的 `+` 是**字符串直接拼接十进制数字**，所以 `"d/shaolin/obj/fojing1" + random(2)` 实际指向 `fojing10` / `fojing11`——这与磁盘上的文件完全吻合（`shaolin/obj/` 只有 `fojing10.c` `fojing11.c` `fojing20.c` `fojing21.c`，**没有** `fojing1.c` / `fojing2.c`）。
同时修掉一个由此暴露的回归：`CLASS_D("...") + "/dao-yi"` 这类惯用写法（前缀含括号，原先匹配不上拼接正则）改取末段字面量，`dao_yi` / `wuming` 等常规物件不再被误判为动态。
新增 `scripts/test_lpc_path_rules.py` 锁定该行为。


**现象**　`tiezhang/hunanroad1 -east->` 被跳过。

**根因**　源码写的是

```c
"east" : "d/xiangyang/caodi6",      // 缺前导 /
```

这是 `docs/mud-d-zone-center-connections.zh-CN.md` 早已记载的数据 bug
（原文：「`hunanroad1.c` 的出口字符串缺前导 `/`，导致铁掌帮→襄阳单向失效」）。

`_classify_exit_path()` 只认 `/d/` 开头的绝对路径，缺斜杠的写法落到
「无法识别的相对路径」被跳过。

**性质**　旧版产出 `rooms.caodi6.id`，而 `tiezhang` 没有 `caodi6` 房间，
所以旧版也是悬空的——运行时无倒退。但这是文档已知的数据 bug，本可顺手修好
（补上斜杠即变成 `xiangyang.rooms.caodi6.id`，恢复铁掌帮↔襄阳的连接）。

---

## 17. 动态选房被截断成错误的指向（**未修**）

**现象**　`gaochang/shulin1` 的 `west` 与 `north` 都指向 `rooms.shulin.id`，
但 `gaochang` **没有** `shulin` 这个房间。

**根因**　源码是

```c
"west" : __DIR__"shulin" + (random(10) + 2),
```

运行时在 `shulin2`..`shulin11` 中随机选一个。转换器的 LPC 表达式解析在
`+` 处截断，只保留了左操作数 `shulin`，于是产出一个**指向不存在房间的错误
引用**。

**性质**　比丢失更隐蔽——写出去的是一条看起来合法的区内引用，但目标不存在。
加载器会解析为 `nil` 并丢弃，所以运行时表现与「丢失」相同，但产物里留下的是
**错误数据**而非缺失。

**全库规模**　**103 条**，涉及 12 个区：

| zone | 条数 |
|------|------|
| `shaolin` | 46 |
| `gaochang` | 17 |
| `test` | 10 |
| `kunlun` | 8 |
| `global` | 7 |
| `huashan` | 5 |
| `city` | 3 |
| `quanzhou` | 3 |
| `lingxiao` | 1 |
| `suzhou` | 1 |
| 另 2 个区 | 各 1 |

其中 `gaochang` 的 17 条主要就是 `__DIR__"shulin" + (random(10) + 2)` 这个模式。

---

## 18. `.comments.txt` 行序抖动（未处理）

**现象**　同一份源码重跑，`UNHANDLED FUNCTION` 注释行的顺序会变，
导致 `.comments.txt` 出现纯顺序差异的「假变更」。

**根因**　这些行来自 Python set / dict 的迭代顺序，跨进程不稳定。

**影响**　只影响 `.comments.txt`（不参与加载），但会让 git diff 出现噪音，
干扰人工比对——本轮排查信息丢失时就被它干扰过一次。

---

## 19. 测试用物品名模糊匹配（已修）

**现象**　`loader_meta_test` / `loader_combat_test` 出现 3 个失败。

**根因**　测试用 `Enum.find(world.items, &String.contains?(&1.name, "布袍"))`
这类**名字模糊匹配**取第一个命中项。`taohua` 转换进来后，它那件没有
`armor` 字段的「布袍」遮住了 `liuxi` 那件 `armor=2` 的。

**修复**　改为按 id 精确匹配（`liuxi:bupao` / `liuxi:baozi` / `liuxi:douli` /
`liuxi:yaodai` / `liuxi:jianpu`）。

**影响**　顺带让 `秘籍物品解析 book 五元组`、`武器/护甲 meta 解析`、
`armor_type 归一化` 三个失败一并消失。

---

## 20. NPC 闲聊自激反馈环（已修，非转换问题）

**现象**　容器日志刷屏，`ChatAction` 队列涨到 47、46、29…

```
Delaying Kantele.Character.ChatAction for 0ms with %{"lines" => ["巫士一声大喊: ..."]}
Processing Kantele.Character.ChatAction, 47 left in the queue.
```

**根因**　三个因素叠加：

1. `SpawnController.event/2` 对 NPC 收到的**每个事件**都跑一遍 `Brain.run`；
2. NPC 订阅了 `rooms:<room>`，而 `ChatAction` 把闲聊发到**同一频道**，
   于是**发言者收到自己刚发的消息**；
3. LPC 里 `chat_chance` 是在 `call_out` **心跳**上评估的，不是每条消息。

数学上每条消息引发房间内 N 个 NPC 各掷一次骰，**繁殖率 = N × chance/100**。
`mingjiao/miaorenbuluo` 放 4 个 `miaozuwushi`、每个 `chat_chance=30`
→ **4 × 0.3 = 1.2 > 1**，超临界，指数发散。单 NPC（0.3 < 1）不会发散，
所以只有多 NPC 房间才触发。

**修复**　新增 `Kantele.Brain.Conditions.ChatChance`（时间冷却 + 概率，
默认 **500 ms**），把过程从「无界繁殖」变成「有界速率」。
`ChatAction` 在**发布之前**写 session 时间戳（必须如此，否则自己触发的下一次
求值看不到）。

> `@@###$$!!! @@@! &*%%%%@!!!` **不是乱码**，是 LPC 作者自己写的占位符
> （`mingjiao/npc/miaozuwushi.c:25` 原文）。

---

# 需要继续做的

## A. 修问题 13 / 15 / 16（都是 `_classify_exit_path` 的分类规则）

三处同源，都在这一条链路：

- **13**　`+random(n)` 且路径主体可静态解析 → 应列出全部候选，而不是整体丢弃。
  建议把 `_is_dynamic_expr()` 的判据从「含括号」改成「去掉 `+ expr` 后仍有
  可解析的路径主体」，并对 `random(n)` 展开为 n 个候选 id。
- **15**　含 `/` 的路径若首段不是已知区名，应按**本区子目录**处理（取
  basename），而不是判为无法识别。
- **16**　`d/<区名>/...`（缺前导斜杠）应按 `/d/...` 处理。

改完需重跑全部 71 区并复验。

## B. 问题 14 补注释

`__FILE__` 的丢弃行为本身正确（运行时无倒退），但应补
`# skipped exit <dir>: self-referential (__FILE__)` 注释，避免静默。

## C. 问题 17 的处理策略待定

103 条同区悬空引用（`__DIR__"shulin" + (random(10)+2)` 这类动态选房）。
可选做法：

1. 展开候选（若候选房间都在本区，列出全部）；
2. 保留一条 `# skipped ...` 注释说明是运行时随机；
3. 保持现状但在文档登记为已知限制。

分布已列在问题 17（`shaolin` 46、`gaochang` 17、`test` 10、`kunlun` 8、
`global` 7、`huashan` 5 等），需要逐条判断是「可展开的 random」还是
「LPC 源本身写错」。

## D. 问题 4 的注释文案修正

把 `# skipped malformed exit direction '乾': ... (C comment artefact)` 改成
准确描述（elias key 只接受 ASCII 标识符），与问题 3 的说明统一。

## E. 两条 LPC 源本身的悬空出口（2026-10-01 已解决，都不必改 LPC 语料）

原先判断是「无法在转换侧修」，两条都不成立，各有各的真实原因：

| 位置 | 源码 | 原判断 | 真实原因与现状 |
|------|------|------|------|
| `baituo/gebi -east->` | `/d/xiyu/shamo10` | LPC 源本身悬空 | **误判**。`gebi` 的 `set("exits")` 写在宏里，宏继承没解析出来导致出口整体丢失；`xiyu:shamo10` 一直存在。随 B 项宏继承修复恢复，产物为 `east = xiyu.rooms.shamo10.id` |
| `city/guangchang -liuxi->` | `/d/minimal_world/guangchang` | 靶场按设计不转换 | 事实成立但结论下早了。修法是**通用规则**：`scripts/lpc_converter.py` 新增 `_INSTALLED_ZONE_IDS`（`main()` 开头扫 `--output` 得出已安装 zone id），`/d/<目录>/` 的目录没有已安装产物时，若出口方向名本身是已安装 zone id 就用它。LPC 把这类出口按目的地命名，`"liuxi"` 正是已安装的柳溪镇 `data/world/liuxi.ucl` |

两条都刻意避开的做法：

- **不用房间名反查**：`guangchang`（镇广场）在 12 个已安装区里都存在，定位不了任何东西。
- **不做区名别名**：`minimal_world` 与 `liuxi` 是不同的地方（前者 10 房、描述纯中文；后者 8 房、双语），宣称同名既误导，也会顺手改掉别的区里任何 `/d/minimal_world/...` 引用。

运行时配套（否则出口仍走不通）：

- `Kantele.Character.LiuxiCommand` 从「柳溪系统暂未开放」桩改为 `request_movement("liuxi")`（保留 `柳溪` 中文别名与 LPC `cmds/std/liuxi.c` 出处，故不并入 `MoveCommand`）。
- `data/world/liuxi.ucl` 的 `guangchang` 补 `yangzhou = city.rooms.guangchang.id` 作回城方向（LPC 原文：「镇口东北方向的官道(yangzhou)直通扬州府」）。
- `north = signature.rooms.yinyi.id` 保留 —— 它是「隐世之境」区唯一入口，全仓库仅此一处引用。

验证：`test_lpc_path_rules.py` E 段 7/7；`liuxi_command_test` + `move_command_test` +
`custom_direction_command_test` 46/46；`test/kantele/world/` 190 tests / 1 failure
（即 I 项那个预存基线 `liandan_lin1`）。

## F. 71 区的人工验收（自动化全绿，**逐区巡游记录缺失**）

SOP Step 5 / checklist 步骤 8、9（巫师巡游、玩家验收）**没有可核查的完成记录**：

- `test_logs/` 目录不存在，`git log --all -- test_logs` 无任何提交 —— 从未落过文件；
- `docs/zone-conversion-checklist.zh-CN.md` 的逐区表里，**72 个区行的「巫师测试」与
  「玩家测试」两列仍是 `?`**，只有「转换」「校验」「赋坐标」等自动化列为 `✅`。

**已具备的是自动化证据**：`mix test` 3018 tests / 0 failures、SOP 70/70（含容器内
elias 解析）、产出新鲜度 69/70 字节一致、全库可达 4115/4455（92.4%）。

**唯一可核查的人工产物**：`liuxi` 的往返连线（E 项）在验收中被发现并修掉 ——
`city:guangchang --liuxi--> liuxi:guangchang` 此前因 `LiuxiCommand` 是占位桩而走不通，
已改为真移动并补 `yangzhou` 回城方向。

若巡游确实做过，需要补 `test_logs/<zone>_wizard_<date>.md`；否则 F 应保持未完成。

## G. 跨区连通性 92.4%，剩余 340 间不可达（2026-10-01 已分类完毕）

当前从 `city:guangchang` 可达 **4115/4455**（**92.4%**），**340** 间不可达，
**全部属于设计/语料层面的原因，无一是转换缺陷**：

| 类别 | 区 | 间数 |
|------|----|------|
| 设计孤立（`mud-d-zone-connectivity` §4.4 的 6 孤立区） | `taohua`31 / `shenlong`21 / `huanggong`14 / `sky`6 / `special`6 | 78 |
| 非 mud 语料区 | `test`34 / `global`27 | 61 |
| 语料本身从未接入（全语料零条 inbound 引用） | `tulong`60 / `register`7 | 67 |
| 只能靠脚本传送抵达（`startroom=` / `me->move()` / 物件表） | `death`76 / `jinshe`4 | 80 |
| 区可达但源码内部断连（比对源码图与产物图，丢失边 0 条） | `lingjiu`38 / `wanjiegu`12 / `motianya`2 | 52 |
| 无出口房间（`liuxi:nether` / `liuxi:zixu_guan`，后者由 MirrorDaemon 投放 NPC） | `liuxi`2 | 2 |

诊断工具 `scripts/world_reachability.py`（BFS + 分类 + `--show-sources` 回查 LPC 源码）。

### G-x 工具自身的三个缺陷（值得单列，因为它反向污染了结论）

初版工具报 4099/4455 / 369 间，而 `cross_zone_wiring_test.exs` 里 loader 侧的真实 BFS 报
4115/4455。三处原因：

1. **出口值带双引号被丢弃** —— `liuxi:shanlu -south-> "sammatti.rooms.blacksmith.id"` 这类手工
   维护的写法，Elias 解析成字符串、`Loader.dereference/3` 照样解引用，正则却匹配不上。
   少了这三条边，`sammatti`(16) / `kissa-jarvi`(11) / `lepakko-luola`(2) 会被误判成不可达。
2. **区名正则不允许连字符** —— `kissa-jarvi.rooms.gates.id` 的区名段 `[a-z][a-z0-9_]*` 匹配不上。
3. **BFS 不检查目标房间是否存在** —— 58 条出口指向不存在的房间（即已登记的悬空出口，loader 用
   `parse_exits` 的 `not is_nil` 丢弃），工具却把它们计进 `seen`，虚增 13。

修完 Python 与 loader 数字完全一致。**教训：诊断工具必须与被诊断对象对账，
否则工具的 bug 会被当成数据的 bug。**

### G-1 唯一真缺陷：`set("exits")` 写在 `create()` 之外被丢弃

`death/god1.c` 把出口声明放在 `void reset()` 里：

```c
void reset()
{
    ::reset();
    set("exits", ([ "up" : __DIR__"god2", "down": "/d/city/wumiao" ]));
}
```

转换器只从 `create()` 抽 `set()`（`_parse_lpc` → `_extract_create_body`），
`reset` 不在 `handled` 集合里，只在 `.comments.txt` 留 `# RAW BLOCK: reset`。

**真正的危害不是少两条边**：`god1` 成了无出口孤儿房后，`assign_room_coords.py` 按既定行为
给它合成 `up`/`down`，**静默顶替**了作者的 `down : "/d/city/wumiao"`（冥界回扬州武馆的
唯一设计连线），换成通往本地 `emptyroom` 的假路。

修法：`_backfill_exits_outside_create()` —— **`create()` 保持权威**，只在它完全没声明出口时
才回退到全文扫描。4287 个含 `set("exits")` 的语料文件里只有 **1 个房间**受影响；
另 2 个是 `taohua` 的物件（`env->query("org_exits")`，不产 `room_exits`）。

顺带去掉一条伪边：`death/god2` 源码本就没有出口，之前被合成成 `up = rooms.hantan1.id`
（凭空多出一条通往寒潭的路）。

### 已复查、确认**不是**缺陷的疑似丢失

| 位置 | 实际原因 |
|------|----------|
| `death/baihuxue -south->`、`death/jimiesi -north->` | `death/heisenlin/` 目录不存在，源码本身悬空（已在 18 条悬空登记里） |
| `death/qiao2` 缺 `north -> hell1` | 源码里是 `// "north" : ...`，已被注释 |
| `jinshe/yongdao2` 缺 `north -> shandong` | 同上，`//"north" : ...` |
| `tulong/xuedi1` 缺 `dongcheng` / `xuedi2` | 同上，两条都是 `//` 注释 |

## H. 跨区边大多是单向的 —— 实际是 23/218，且全部原生单向（2026-10-01 已验证）

`docs/mud-d-zone-center-connections.zh-CN.md` 指出「大量区域间是单向出口」，文档说引擎允许单向，
但此前**未验证**。结论：全库 218 条跨区边里 **195 条双向**（186 条反向方向名恰为相反罗盘方向、
6 条自定义方向 `in`/`out`/`liuxi`/`yangzhou`/`river`、3 条有意不对称），**23 条单向**。

### 23 条单向边：逐条回查 LPC 源码，全部原生单向

对每条 `<A:a> -dir-> <B:b>`，检查 **`<B:b>` 自己有没有出口指向 `<A:a>`**。
不能用「反向索引按源过滤」—— 那会找到正向边自己（本项第一版探针就犯了这个错，
误报成「213 条全部双向且全部不对称」）。19 条 mud 语料区的单向边全部重新读了目标房的
`set("exits")` 并解析出邻居集合，**没有一条声明回边**：

| 成因 | 条数 | 例子 |
|------|------|------|
| 目标房根本没有 `set("exits")` | 1 | `baituo:gebi -east-> xiyu:shamo10` |
| 密室/迷宫的脱身出口 | 7 | `gumu:mishi8 -out-> city:guangchang`、`register:room{e,n,s,w} -out->` |
| 垂直单向支线 | 6 | `emei:midao5 -up-> chengdu:qingyanggong`、`death:god1 -down-> city:wumiao` |
| 死胡同支线 | 6 | `suzhou:taihu -west-> yanziwu:hupan`（`hupan` 唯一出口是 `northeast -> suzhou:road5`） |
| 同名房间歧义 | 2 | `heimuya:bridge -east-> baituo:xijie` —— `baituo/xijie.c` 的 `"west" : __DIR__"bridge"` 解析到 **`baituo:bridge`**（两个 `bridge` 房都真实存在，只是不同区） |
| 非语料区 | 1 | `tulong:haigang -west-> beijing:road10` |

**决定：不补反向出口。** SOP 明写「不要在转换器里"发明"目标」；这 23 条的作者意图就是单向。
补边会凭空造出作者没写的路。

### 3 条双向但方向名不对称

| 边 | 正向 | 回程 | 说明 |
|----|------|------|------|
| `shenfeng:caoyuan5 -south-> xiyu:nanjiang2` | `south` | `northeast` | 源码里 `caoyuan5` 有 `south` 与 `southwest` 都通 `nanjiang2`，而 `nanjiang2` 只有 `northeast` 一条回程 |
| `liuxi:guangchang -north-> signature:yinyi` | `north` | `north` | 手工维护区，两侧都叫 north |
| `signature:yinyi -north-> liuxi:guangchang` | `north` | `north` | 同上 |

后两条语义不理想（同一句「向北」既进又出），但不由本转换器产出，不是转换缺陷。

### `valid_leave` 出口守卫：已数据化，运行时**故意不拦截**

- `data/world` 有 **183 处** `valid_leave` 块 / **48 个区**。`pk:entry` 的守卫完整保留：
  `direction = "north"` + `message = "乌老大喝道：给我站住！那儿不能随意进入。"`
- loader 解析进 `Room.exit_vetoes`（`loader.ex:290`），但**全仓库没有任何消费方** ——
  `grep exit_vetoes` 只命中 loader 自己的解析函数。玩家可以直接从 `pk:entry` 往北进 `pk:ready`。
- **为什么不做拦截**：每条阻挡都带 LPC 条件表达式（`! me->query_temp("rent_paid") && dir == "up"`、
  `objectp(present("mang she", environment(me)))`），没有 LPC 求值器；且 UCL 字符串里不能出现
  `(`、`)`、`,`，条件只能以 `# 阻挡条件（原样保留）：...` 注释留存，loader 拿到的 `condition`
  恒为 `nil` —— **运行时无法区分「有条件」与「无条件」阻挡**，强行拦截会误封。
- `taohua` 幻阵**不是** `valid_leave` 守卫：31 个房间的 `valid_leave` 数量为 **0**，
  它靠 `__FILE__` 自指出口（4 条自环）实现，本来就不与外界相连。

### 新增回归

`test/cross_zone_wiring_test.exs` 加了 3 条断言（8/8 通过）：

- 每条无回边的跨区边必须在 `@one_way` 白名单里（23 条，逐条注明成因）；
- 双向边的回程方向必须是相反罗盘方向，或落在 `@custom_dirs` / `@asymmetric` 显式例外里；
- 白名单自身不许漂移（有回边可删 / 边不存在，需处理，都失败）。

## I. 一个长期失败的测试（2026-10-01 已解决：是测试自己的 bug）

`mix test test/kantele/world/loader_meta_test.exs` 长期失败：

```
1) test liandan_lin1 房间：宏继承合并属性生效（名称/描述），悬挂出口被丢弃
   悬挂出口 south 不应被保留
```

**既不是 loader 的宏继承合并问题，也不是 `parse_exits` 的 `not is_nil` 过滤失效。**

原代码 `Enum.find(world.rooms, &(&1.key == "liandan_lin1"))`。房间 `key` 不带区名，
在全库**大量重名 —— 432 个 key 有多个属主**（`majiu` 22 个区、`chufang` 20 个、
`road2` 19 个、`kedian` 19 个），而 `liandan_lin1` **同时属于 `beijing` 和 `test`**。
`Enum.find` 按迭代顺序取第一个，拿到的是 `beijing:liandan_lin1` —— 一个四条出口
**全部接通**的房间。测试声称要验的 `test:liandan_lin1` 行为其实一直正确：

```
test:liandan_lin1  name="城西后林"   exits (1):  "down" -> "test:liandan_lin"
```

失败信息「悬挂出口 south 不应被保留」是对的 —— `beijing:liandan_lin1` 确实有 `south`。
断言对象一直是错的。

修法：一律按带区名的 `id` 定位。同一文件另外三处（`bet` / `cave` / `kedian`）同样按 `key`，
其中 `kedian` 重名 19 个区，属同一隐患，一并修掉。

**教训**：跨区世界里 `key` 不是唯一键。要断言某个区的某个房间，必须用 `id`。

**全量基线**：`mix test --seed 12345` → **3018 tests, 0 failures**（此前长期 3008/1）。
