# UCL 注释实现计划（把注释变成实现）

> 前提：转换器工作已收尾（checklist A–I 全 ✅），**不再运行 `lpc_converter.py`，SOP 已归档**。
> 本文件定义了后续「把 `data/world` 转换区里遗留的注释变成真实实现」的路线图。
> 方法论已换 **新方法**：直接编辑 `data/world/*.ucl` + 在 `lib/kantele` 加运行时子系统 +
> `test/` 覆盖；loader 对账、`world_reachability.py` 等既有校验工具继续可用。
> 数据基线：`docs/data-world-converted-ucl-comments.zh-CN.md`（`8013adf`）。

> **本文档是「计划 + 实际结果对照」。** 待做项以
> `docs/ucl-comment-todo.zh-CN.md` 为准；已完成部分的实际数字与踩坑见本文
> §9。下面的 §1–§8 保持原计划形态，便于对照当初的判断与实际结果的差异。

## 0. 范围：哪些注释要「变成实现」

71 个 mud/d 转换区共 **14483** 条注释：

| 类别 | 条数 | 处理 |
|------|-----:|------|
| `# Generated from ...` / `# Zone:`（区块标注） | 13686 | **不做**，纯溯源 |
| `# River ...` / `# - ...`（渡船说明） | 54 | **不做**，纯说明（若要做渡船系统另开计划） |
| `# vendor_goods ... (file not found)` | **464** | 做 —— §1 |
| `# 阻挡条件（原样保留）` | **183** | 做 —— §2 |
| `# skipped ...` | **96** | 做 —— §3 |

三条「做」就是本计划的全部内容。共同验收口径见 §5。

---

## 1. `vendor_goods` —— 让商人真正能卖（464 条 / 36 区，290 个 distinct 目标）

### 1.1 实测现状

- 已实现对照：转换器把**能解析**的条目产出为 `goods = [ { id = items.<名>.id } ... ]`——
  现有 **19 区 54 块**，全部是**同区** `items.<名>.id`。
- 464 条未解析 → 290 个 distinct 目标，按前缀：
  - **`/d/<zone>/...` 211 个**（全部在转换区世界内）—— 其中 **130 个同区已有 `items "<名>"` 产物**（如 `/d/beijing/obj/luobo`、`/d/xiyu/obj/fire`），**81 个同区没有产物**；
  - **`/clone/...` 79 个**（标准物件库，如 `/clone/weapon/gangdao`）—— 源码全在 `C:\files\git\mud\clone`。
- 根因：转换期 vendor 解析规则**保守**（等价于「本次转换不接入 vendor 对象表」），并非目标不存在。抽查证实：`/d/xiyu/obj/fire` 源文件与 `xiyu.ucl` 的 `items "fire"` 都在，仍被丢。

### 1.2 做法

1. **数据迁移脚**（一次性，`scripts/` 新文件，直接读 `.ucl` 写 `.ucl`）：
   - 对 290 个目标逐一归类：
     - a) `/d/<zone>/<...>/<名>.c` 且目标区有 `items "<名>"` → 给引用该目标的 NPC 的 `goods` 块补 `{ id = items.<名>.id }`（同类内同区优先）；
     - b) `/d/<zone>/...` 目标区无产物 → 记入「待建物品」清单（子任务）；
     - c) `/clone/...` → 记入「标准库搬运」清单（子任务）。
   - 补完的 `goods` 条目**替换掉**对应注释（注释→实现，不留孤儿）。
2. **待建物品（81 个目标）**：对 `C:\files\git\mud\d` 对应 `.c` 逐个新法转出为 `items` 块。若目标 `.c` 缺失或属未转换目录，登记到白名单并显式保留注释（写明后续处理），**不允许静默丢**。
3. **标准库搬运（79 个目标）**：`/clone/weapon|cloth|book|shop|...` 的 `.c` 在 `C:\files\git\mud\clone`。新法转出，建议集中到一个新区（如 `data/world/clone_lib.ucl`），避免散落各商业 NPC 里。
4. **联动 §3.3**：`/clone/shop/<city>_shop` 同时是 §3.3 那 15 条 `outside d/` 出口的目标——店铺区域建好后，出口与兜售一起贯通。

### 1.3 开放问题（先验证再动手）

- **跨区 `items` 引用形式**：现有 `goods` 全是同区 `items.<名>.id`。跨区（如 `changan` 的 NPC 卖 `xiyu` 的火把）是可写 `items.<名>.id`（loader 当前按区加载 items 命名空间还是全局合并？）还是需要别的写法？—— 先查 `loader.ex` 的 items 解析，写一个跨区 goods 用例验证。

---

## 2. 阻挡条件 —— `valid_leave` 真正拦人（183 条 / 43 区）

### 2.1 实测现状

- 转换器把 `valid_leave` 拆为 `exit_vetoes`，条件原文只留注释；loader 填了 `exit_vetoes` 但 `condition` 恒为空、**运行时不拦截**（刻意，见 checklist §H）。
- 183 条 → 79 种归一化形态。用到的构件（按频次）：`present()`101 `environment()`86 `objectp()`80 `query()`52 `query_temp()`51 `wizardp()`8 `check_dirs()`8 `living()`6 `query_skill()`5 `refuse()`5 `check_out()`5 `this_object()`4 `this_player()`2 `userp()`2 `query_condition()`1 `id()`1。
- 三种**自定义函数**形态无法纯表达式化（共约 18 条）：`check_dirs(me, dir)`(8)、`ob->refuse(me)`(5)、`check_out(me)`(5)。

### 2.2 方案：受限条件求值器（推荐）

1. **求值器**（`lib/kantele/world/lpc_condition.ex`）：解析并求值一个**受限 LPC 布尔表达式**子集：
   - 逻辑：`&&`/`and`/`&`、`||`/`or`、`!`、括号；
   - 比较：`==` `!=` `<` `<=` `>` `>=`（int/string/bool/nil，字符串比较按 LPC 语义）；
   - 属性读：`me->query("...")`（含 `"family/family_name"`、`"gender"` 等）、`me->query_temp(...)`、`me->query_skill(...)`、`me->query_condition(...)`；
   - 存在/身份：`present("<id>", environment(me))`、`objectp(...)`、`living(...)`、`wizardp/me`、`userp(me)`、`this_object()`/`this_player()`；
   - 类型前缀：`(int)` `(string)`。
2. **数据层**：给 `Room.exit_vetoes` 的 UCL 块加 `condition = "<表达式>"` 字段（迁移脚本把 183 条中「纯表达式」形态从注释搬进字段；注释→实现）。
3. **自定义函数**：`check_dirs`/`refuse`/`check_out` 不套求值器，改在 `exit_vetoes` 上登记 `kind = "call"` + 函数名，loader 映射到 Elixir 端已实现的守卫/hook（先挑行为明确的做，如 `check_out`，semver 记录保留）。
4. **运行时**：`move_command.ex` 在移动前求值 `exit_vetoes`，不满足则拒绝，消息沿用房内 `description`/统一文案。
5. **灰度**：开启拦截是**行为变更** → 先做**配置开关**（如 `config` 里 `kantele :enforce_exit_vetoes true/false`），默认关；逐区开启 + 全量回归。防「把玩家锁死在房内」。

### 2.3 备选方案（小范围）

- 只对手工挑选的重点房在 `move_command.ex` 里硬编码守卫（如租金 `rent_paid`、性别门）。成本低但 183 条不会全做——**不推荐作为默认**，其余留给求值器。

---

## 3. `skipped` —— 实现被跳过的出口/物件/inquiry（96 条 / 18 区）

| 子项 | 条数 | 现状要点 | 实现路径 |
|------|-----:|----------|----------|
| 3.1 八卦方向（CJK） | 64 | 8 个名字 `乾兑坎坤巽离艮震` 各 8 次，`shaolin`；elias 的 key 只接受 ASCII | 给相关房间建 **ASCII 别名方向**（如 `qian`…，或映射到 `nw/ne`…），拓扑保持原意；先盘点这 8×8 的目标房间在 `data/world/shaolin.ucl` 里的存在性与当前可达性 |
| 3.2 含数字方向 | 6 | `huashan` `hole1..hole6`，**冗余**反向链（目标房各带 `out`），跳过不造成不可达 | 低优先：重建为**纯字母** ASCII key（elias 要求 `^[A-Za-z_][A-Za-z_]*$`；`hole_a` 可行、`hole_1`/`hole_6` 已实测失败），或经核对正式免除 |
| 3.3 `outside d/` | 17 | 目标全在原始世界：**15 个** `/clone/shop/<城>_shop`（`up`，城=beijing/changan/chengdu/dali/foshan/fuzhou/hangzhou/hengyang/jingzhou/kaifeng/luoyang/suzhou/xiangyang/yangzhou/city/zhongzhou）＋**2 个** `/b` 房（`/b/yitian/jiulou`、`/b/tulong/haigang`）；**源码全在 `C:\files\git\mud\clone`、`mud\b`** | 新法把被引用的 `<city>_shop.c`（15 个）＋2 个 `/b` 房转为 UCL（进 `data/world`，如统一放 `data/world/` 下新区），把这些出口改成真实引用；与 §1.3 店铺联动 |
| 3.4 inquiry 无法用 elias 表达 | 6 | `xiangyang` 铁匠 `(: ask_me_N, '<物品>' :)` 闭包 | inquiry `value` 改为 UCL 可表达的手柄（如 `value = "ask_me/1/huwan"`），`ask` 命令层注册实现，6 条变真实可答 |
| 3.5 物件路径运行时拼接 | 2 | `wudang` 藏经阁 `"/clone/book/" + books[random(sizeof(books))]` | 用**候选列表＋运行时挑一个**机制（既有：loader `pick_runtime_exit` 已支持 exit 候选；给 items/objects 侧补同类或复用） |

### 3.1 附：兜底判断

若某个子项经核对是**必然不可行/无意义**（如 CJK 方向在 elias 下连值都只 ASCII、某目标 `.c` 在语料里就没有），
在该区 `.ucl` 注释里**显式登记原因并改标题为「已确认不实现」**，纳入 §4 的「决定清单」，
不允许留成待办黑洞。

---

## 4. 抑制清单（明确不在本计划内）

- **`押技能的 check_dirs/refuse`**：除非求值器完工后仍缺，才退回 §2.3 硬编码。
- **渡船（River 54 条）**：若要完整渡船玩法，另开「水系交通」计划。
- **`global.ucl`（987 条未转换标记）**：旧 Elixir 转换器产物的测试语料区，不接正式世界。
- **`minimal_world`/测试靶场**：不动。

---

## 5. 验证策略

1. **静态引用完整性**：新增/复用一次性脚本，断言 `data/world` 里 `goods`、`room_exits`、inquiry 值
   的所有引用都能解析到房间或 `items`，不带 `#` 注释替代。
2. **可达性对账**：`world_reachability.py` 重跑——**已完成**：4115/4455 → **4190/4470**，实现 §3 后应**不降且期望升**（八卦房、店铺、`/b` 房若原本不可达则减少不可达数）。
3. **`mix test --seed 12345`**：**已完成**：3018 → **3072 tests / 0 failures**，并新增：
   - §1：商人 `buy` 流程测试（goods 可购、库存可扣）；
   - §2：求值器单测（表驱动 79 形态样本）＋ `move` 拦截集成测试（开关开/关各一遍）；
   - §3：八卦/jhole/inquiry/物件各一条可达或应答测试。
4. **跨区对账**：`test/cross_zone_wiring_test.exs` 保持绿（新增边只增不改）。
5. **灰度**：`enforce_exit_vetoes` **已默认开启**（`config/config.exs`）。未采用 CI 双跑，改为线上人工抽查 —— 见 §9.3。

---

## 6. 建议执行顺序

| 阶段 | 内容 | 依赖 | 理由 |
|------|------|------|------|
| P0a | §1 vendor 数据迁移脚本 + 130 个「同区已有产物」先落地 | — | 收益最大、只动数据 |
| P0b | §1.2 待建物品（81）+ `/clone` 搬运（79）→ `clone_lib` | P0a | 商人真正能卖全套 |
| P1 | §3.3 `outside d/` 店铺/`/b` 房 | P0 的店铺部分 | 与 vendor 联动、补连通 |
| P2 | §2 求值器＋迁移＋灰度 | 1.3 开放问题确认 | 行为变更，放后端 |
| P3 | §3.1 八卦、§3.2 hole、§3.4 inquiry、§3.5 wudang 书 | — | 小改、验证耗时短 |
| P4 | §3.1 若必要：盘点 shaolin 拓扑与可达性 | P3 | 需现场核对 |

（P0–P4 每个子任务做完成即提交，沿用 checklist「完成即 commit + 记录」风格。）

---

## 7. 开放问题清单（开工前必须先答复，避免返工）

- [x] **Q1** 跨区 `goods`：`loader.ex` 的 items 命名空间是**全局**的。故支持 `<zone>.items.<name>.id` 显式跨区解引用（`0818ace`）。
- [x] **Q2** elias key 不能以数字结尾（`hole_6` 实测失败，故用 `hole_a..hole_f`）。八卦用拼音 `qian/dui/kan/kun/xun/li/gen/zhen` 作 ASCII 别名（`6d157ba`）。重命名（`hole_a`…）是否可接受。
- [x] **Q3** 进 `config/config.exs`，且**已置 `true`**。
- [x] **Q4` 整类搬运：`clone_lib.items` 下补齐 weapon/cloth/book 等标准库（`74f41a0`）。

---

## 8. 验收清单（实际结果）

- [x] §1：`vendor_goods` 注释 → **0 条残留**；商人可 `buy`（`0818ace`/`9e83dea`/`74f41a0`）
- [x] §2：`阻挡条件` → `condition` 字段实现；166 条中 **133 条生效**
      （`e33d984`、`1cdd66a`、`8558a2f`、`cc0eead`）
- [x] §3.1：八卦房间 64 条 ASCII 方向可达（`6d157ba`，顺带修掉 `bagua0` 死锁）
- [x] §3.2：`hole_a..hole_f` 六扇石门已登记（`6d157ba`）
- [x] §3.3：17 条 `outside d/` → 真实引用；15 个店铺房可进（`f7d3d92`）
- [ ] §3.4：inquiry 6 条可应答 —— **未做**，见 todo 文档 E 节
- [x] §3.5：藏经阁 7 本书 + 2 条随机候选可开出（`6d157ba`）
- [x] `mix test --seed 12345` **3072 / 0**
- [x] `world_reachability.py` **4190/4470**（较基线 +75）

---

## 9. 计划执行后的实际情况（计划未预见到的部分）

### 9.1 规模与计划不一致的地方

| 计划预估 | 实际 |
|---|---|
| `vendor_goods` 464 条 / 290 个 distinct | 168 条实际引用需落地（P0a），后续补齐到 0 注释 |
| 阻挡条件 183 条 | **166 条** |
| `skipped` 96 条 / 18 区 | **299 条注释 → 剩 7 条** |
| 基线 3018 tests | 3072 tests |
| 待建物品 81 + `/clone` 79 | 227 + 108（分类与计划不同） |

### 9.2 计划未预见的缺陷（都已修）

1. **Elias 的 `true` 实际解析成字符串 `"true"`** —— `all_dirs` 判定要同时接受
   `true` / `:true` / `"true"`（`71e5338`）。
2. **`get_in/2` 不能读角色 meta** —— `meta` 是结构体，没实现 `Access` 协议，
   会抛 `Kalevala.Meta.Trimmed.fetch/2 is undefined`。凡是涉及角色 meta 的
   取值都必须用 `Map.get` 链（`cc0eead`）。
3. **`Meta.Trim` 保留清单的字段必须能 JSON 编码** —— 裁剪后的角色副本要发给
   web 客户端，给 `Kantele.Character.Stats` 加 `Jason.Encoder` 之前会让
   websocket 进程崩溃。

### 9.3 灰度方式改了

计划里写的是「CI 双跑 + 默认关闭」。实际改成：`enforce_exit_vetoes` 默认**开启**，
配合三道**失败即放行**的守卫（解析失败 / 未限定方向 / 依赖缺失数据），
用线上人工抽查代替 CI 双跑。

理由：这三道守卫保证了「求值器有缺陷时最坏结果是少拦，而不是锁死玩家」，
所以不需要为开关跑两遍测试。代价是**缺陷会隐身** —— 第 9.2 条第 2 点就是这么
被发现的，现在 `rescue` 分支已加 `Logger.warning`。

---

## 10. 仍然待做

见 `docs/ucl-comment-todo.zh-CN.md`：B（`guarded_exit`）、C（自定义函数）、
D（性别数据）、E（铁匠 inquiry）、F（`city:mudren` 建议免除）。
