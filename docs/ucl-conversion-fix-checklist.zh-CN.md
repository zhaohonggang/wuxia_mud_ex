# UCL 转换修复核对单（Checklist）

> 配套文档：
> - `docs/ucl-conversion-issues.zh-CN.md` —— 20 个问题的完整分析（**先读这个**）
> - `docs/ucl-conversion-todo.zh-CN.md` —— A–I 待办详解
> - `docs/data-world-info-loss.zh-CN.md` —— 信息丢失排查报告
> - `docs/data-world-ucl-inventory.zh-CN.md` —— `data/world` 现状清单
> - `docs/zone-conversion-sop.zh-CN.md` —— 转换 SOP
>
> 生成时间：2026-09-30　基线 git HEAD：`1c97437`

---

## 使用说明

- 每个方框是一个**可验证**的具体条件，完成后把 `- [ ]` 改成 `- [x]`
- 大项下方的子项**全部打勾**才能把大项标 ✅
- 完成即 `git commit`，并在本文件「完成记录」表追加一行
- 重跑任何区域都按 `docs/zone-conversion-sop.zh-CN.md` 的 5 步流程，不要手改 `.ucl`
- 改 `scripts/validate_ucl.py` 后必须跑 `test\fixtures\validate_ucl` 全部 fixture 回归

---

## 进度总览

| 项 | 内容 | 优先级 | 状态 |
|----|------|--------|------|
| **A** | 修 `_classify_exit_path` 三处分类错误 | 高 | ☐ |
| **B** | `__FILE__` 丢弃补注释 | 低 | ☐ |
| **C** | 动态选房 103 条悬空引用策略 | 中 | ☐ 待决策 |
| **D** | 修正八卦方向注释文案 | 低 | ☐ |
| **E** | 2 条 LPC 源本身悬空 | — | ☐ 需决策 |
| **F** | 71 区人工验收 | 高 | ☐ |
| **G** | 380 间不可达房间分类 | 中 | ☐ |
| **H** | 跨区单向边可往返性验证 | 中 | ☐ |
| **I** | 1 个预存测试失败 | 低 | ☐ |

---

## 一、转换器缺陷修复

### ☐ A. 修 `_classify_exit_path` 三处分类错误

高优先级。三项同源于 `scripts/lpc_converter.py`，一起改。

**A-1　`+random(n)` 的物件路径被整体丢弃（问题 13）**

- [ ] `_is_dynamic_expr()` 判据从「含括号」改为「剥掉 `+ <表达式>` 后仍有可解析路径主体」
- [ ] `random(n)` 展开为 n 个候选 id，全部写入 `room_items`
- [ ] `shaolin/cjlou` 的 `room_items` 恢复含 `items.fojing1.id` / `items.fojing2.id`
- [ ] `shaolin/jianyu` 同上
- [ ] 确认加载器对同一房间多物品的处理无副作用
- [ ] 新增 fixture 锁定该行为

**A-2　同区子目录路径被误判为跨区（问题 15）**

- [ ] 含 `/` 且首段非已知区名时，按本区子目录处理（取 basename）
- [ ] `city/liaotian` 出现 `east = rooms.qiyuan1.id`
- [ ] `room/xiaoyuan` 出现 `panlong = rooms.dayuan.id`
- [ ] `room/xiaoyuan` 的 `dule` / `caihong` 两条能解析（注意：因三子区
      都有 `xiaoyuan.c` 拍平撞名，解析结果是自环，与改动前一致，属已知限制）

**A-3　`d/<区名>/` 缺前导斜杠未被识别（问题 16）**

- [ ] `_classify_exit_path()` 识别缺前导斜杠的 `d/<区名>/...`
- [ ] `tiezhang/hunanroad1` 出现 `east = xiangyang.rooms.caodi6.id`
- [ ] 恢复铁掌帮 ↔ 襄阳的连接

**A 的整体验证**

- [ ] 71 区全部重跑 SOP
- [ ] 71 区 `validate_ucl.py` 全 exit 0
- [ ] 71 区 `check_room_coords.py` 全 exit 0
- [ ] 容器内 `Elias.parse/1` 逐个解析全 exit OK
- [ ] `mix test test/kantele/world/` 无新增失败
- [ ] `mix test` 无新增失败
- [ ] `test/cross_zone_wiring_test.exs` 的 15 条同名撞车边仍全绿
- [ ] 重新生成信息丢失报告，「无注释丢失」降到 **0**

### ☐ B. `__FILE__` 丢弃补注释

低优先级。运行时无倒退（旧的 133 条本就被加载器丢弃），只为消除静默删除。

- [ ] `_resolve_exit_target()` 的 `("self", None)` 分支输出注释
- [ ] 注释形如 `# skipped exit west: self-referential (__FILE__): ...`
- [ ] 重跑后 133 条在产物里都有对应注释
- [ ] 信息丢失报告中「`__FILE__` self-reference」归零

### ☐ D. 修正八卦方向被跳过的注释文案

低优先级。纯文案，但错误文案会误导排查。

- [ ] 把 `# skipped malformed exit direction '乾': ... (C comment artefact)`
      改成准确描述：elias 的 key 只接受 ASCII 标识符
- [ ] 与问题 3（数字 key）的注释统一措辞
- [ ] 重跑 `shaolin`

---

## 二、数据层待决策

### ☐ C. 动态选房 103 条悬空引用的处理策略

**先分类，再决策。** 103 条 / 12 个区：

| zone | 条数 | 备注 |
|------|------|------|
| `shaolin` | 46 | 非 `random(n)` 模式，需单独确认 |
| `gaochang` | 17 | 典型 `__DIR__"shulin" + (random(10)+2)` |
| `test` | 10 | 非 mud 语料区 |
| `kunlun` | 8 | |
| `global` | 7 | 非 mud 语料区 |
| `huashan` | 5 | |
| `city` / `quanzhou` | 各 3 | |
| `lingxiao` / `suzhou` / 另 2 区 | 各 1 | |

- [ ] 逐条判定：可展开的 `random` / LPC 源本身写错
- [ ] 决策：展开候选 / 跳过并注释 / 登记为已知限制
- [ ] 按决策实现
- [ ] 重跑受影响区域
- [ ] 在 `docs/zone-conversion-sop.zh-CN.md` 错误表登记该模式

---

## 三、外部问题（转换侧无法修）

### ☐ E. 2 条 LPC 源本身悬空的出口

- [ ] 决定是否修改 LPC 语料（`C:\files\git\mud`，外部只读参考）
- [ ] 或接受现状并在 SOP 登记

| 位置 | 源码 | 情况 |
|------|------|------|
| `baituo/gebi -east->` | `/d/xiyu/shamo10` | `xiyu` 无此房间 |
| `city/guangchang -liuxi->` | `/d/minimal_world/guangchang` | 靶场，按设计不转换 |

---

## 四、验收

### ☐ F. 71 区人工验收（巫师巡游 / 玩家测试）

高优先级。**当前完全没有做**，完成记录表里「巫师测试」「玩家测试」两列全是 `?`。

**前置自动化**

- [ ] `mix test test/kantele/world/` 通过
- [ ] `mix test` 通过

**优先验收区**（本轮改动动过或有已知缺陷）

- [ ] `shaolin` —— 64 条八卦方向被跳过；佛经物件丢失（A-1 修完再验）
- [ ] `beijing` —— 曾有 15 条同名撞车静默连错
- [ ] `city` —— 跨区出口最多的枢纽（13 条）
- [ ] `mingjiao` —— 4 个 NPC 曾触发闲聊指数刷屏
- [ ] `room` —— 三个子区拍平后房间撞名
- [ ] `huashan` —— 6 条 `hole*` 方向被跳过
- [ ] `taohua` / `special` / `huanggong` —— 设计上孤立，确认是否符合预期

**逐区验收**（`goto` 语句见 `docs/zone-conversion-checklist.zh-CN.md` 各行）

- [ ] Layer 0 · city
- [ ] Layer 1（20 个区）已完成转换，逐区巡游记录到 `test_logs/`
- [ ] Layer 2（22 个区）已完成转换，逐区巡游记录到 `test_logs/`
- [ ] Layer 3（20 个区）已完成转换，逐区巡游记录到 `test_logs/`
- [ ] Layer 4（3 个区）已完成转换，逐区巡游记录到 `test_logs/`
- [ ] Unreachable（8 个区）已完成转换，逐区巡游记录到 `test_logs/`
- [ ] 玩家验收（可选，从 city 走官道进区跑主线/战斗/技能）

**每区记录**　`test_logs/<zone>_wizard_<date>.md`

---

## 五、连通性排查

### ☐ G. 380 间不可达房间的分类确认

现状：从 `city:guangchang` 可达 **4061/4441** 间（91.4%），380 间不可达。

**已确认属设计预期**（无需处理，仅需在文档登记）

- [ ] `taohua`（`__FILE__` 自指幻阵）
- [ ] `special`（六道轮回，LPC 里完全没有 `set("exits")`）
- [ ] `huanggong`（皇宫，无对外出口）
- [ ] 非 mud 语料区：`test` / `global` / `kissa-jarvi` / `sammatti` /
      `signature` / `lepakko-luola` / `liuxi`

**待查**

- [ ] 写脚本：每间不可达房间回 `mud/d/<zone>` 找同名 `.c`，打印其 `set("exits", ...)`
- [ ] `lingjiu`（`changl*` 长廊群）
- [ ] `death` 的 `road4` / `road6` / `gateway` / `sky12`
- [ ] `wanjiegu` 的 `left_room` / `stone_room` / `backyard`
- [ ] `tulong:was_*`
- [ ] `shenlong`
- [ ] `register:prison` / `register:roomw`
- [ ] 每条判定：源数据本来悬空 / 转换丢失
- [ ] 转换丢失的回填到 A 组统一处理

### ☐ H. 跨区单向边的可往返性验证

- [ ] 在 `test/cross_zone_wiring_test.exs` 加对性检查：
      对每条 `<A:a> -dir-> <B:b>`，检查 `<B:b>` 是否有出口指回 `<A:a>`
- [ ] 列出全部单向边，人工过一遍
- [ ] 确认双向边的**反向方向名**是否对称
      （例：`shaolin/yidao -south-> city/beimen`，`city/beimen` 往回是 `north` 吗？）
- [ ] 确认有 `valid_leave` 守卫的房间（`pk` 入口、`taohua` 幻阵）是否拦住回路
- [ ] 决定是否需要为单向边补反向出口

---

## 六、遗留

### ☐ I. 1 个预存测试失败

与转换无关。已用 `git stash` 对照确认在改动前就存在。

```
mix test test/kantele/world/
  1) test liandan_lin1 房间：宏继承合并属性生效（名称/描述），悬挂出口被丢？(LoaderMetaTest)
```

- [ ] 确认 `data/world/test.ucl` 里 `liandan_lin1` 的悬挂出口是否与
      `parse_exits` 的 `not is_nil` 过滤有关
- [ ] 判断该测试的预期是否已过时
- [ ] 或定位 loader 的宏继承合并逻辑问题

---

## 七、已完成（回归基线，勿回退）

以下 20 个问题已修复并提交，**改动这些脚本时不得回退**。

**`scripts/lpc_converter.py`**

- [x] `_merge_vals` 空元组越界 —— 4 区无法转换（问题 1）
- [x] 跨区出口被当本区引用 —— 15 条静默连错（问题 2）
- [x] 方向名含数字 —— `huashan` 的 `hole1..6`（问题 3）
- [x] 方向名含中文 —— `shaolin` 八卦 64 条（问题 4，注释文案待 D 项修）
- [x] `item_desc` 中文 key 归一化成空 —— `changan`（问题 5）
- [x] 行尾 C 注释被当 mapping 项 —— `room`（问题 6）
- [x] `accept` 布尔/列表混淆泄漏 Python repr —— `taishan`（问题 7）
- [x] elias 分词：数字紧邻逗号 —— `xiangyang`（问题 8）
- [x] elias 分词：反斜杠接空白 —— `mingjiao`（问题 9）
- [x] LPC 行尾续行符 `\` 折叠（`_LPC_CONTINUATION`）

**`scripts/assign_room_coords.py`**

- [x] 垂直连接方向被占用时跳过，导致孤儿房不可达 —— `city` 的 `xsmidao*`（问题 12）
- [x] 跨区 `up`/`down` 视为方向已占用，避免重复键（elias 并成数组 → loader 崩）
- [x] 新增 `UP_DIR_CANDIDATES` / `DOWN_DIR_CANDIDATES`，跳到空闲复合方向

**`scripts/validate_ucl.py`**

- [x] 新增 `_ELIAS_BAD_KEY_RE`（key 含数字）+ fixture 45（问题 10）
- [x] 新增 `_ELIAS_UNLEXABLE_RE`（数字+逗号）+ fixture 44（问题 10）
- [x] 新增 `_ELIAS_STRAY_BACKSLASH_RE`（`\` + 空白）+ fixture 46（问题 10）
- [x] 新增 `_strip_comments()`，避免转换器的说明注释误报
- [x] 新增 `_is_object_only_zone()` 窄化豁免 + fixture 47 —— `tangmen`（问题 11）

**Elixir 侧**

- [x] `Kantele.Brain.Conditions.ChatChance` 冷却+概率，切断 NPC 闲聊自激（问题 20）
- [x] `ChatAction` 发布前写 session 时间戳
- [x] 测试改用 id 精确匹配，不再用物品名模糊匹配（问题 19）

**测试基线**

- [x] `test/fixtures/validate_ucl` 回归 **24/24**
- [x] `mix test test/kantele/world/` 190 tests / 1 failure（仅问题 I）
- [x] `mix test` 2988 tests / 1 failure（仅问题 I）
- [x] 71 区 `validate_ucl` + `check_room_coords` 全 exit 0
- [x] 容器内 elias 解析 70 个 `.ucl` 全通过

---

## 统计汇总

| 指标 | 数值 |
|------|------|
| 待办大项 | 9（A–I） |
| 已完成问题 | 20 |
| 未完成问题 | 5（13 / 14 / 15 / 16 / 17） |
| 待验收区域 | 71 |
| 无注释丢失 | 136 |
| 有注释的省略 | 25 |
| 同区悬空引用 | 103 |
| 不可达房间 | 380 / 4441 |

---

## 完成记录

| 日期 | 项 | 内容 | 验证方式 |
|------|----|------|----------|
| 2026-09-30 | 跨区接通 | 206 条跨区引用接通；15 条静默连错修正；可达率 0 → 91.4% | `mix test` 2988/1；elias 70 文件全过 |
| 2026-09-30 | NPC 闲聊刷屏 | `ChatChance` 冷却 500ms 切断指数发散 | `chat_runtime_test.exs` 12/12 |
| 2026-09-30 | 测试脆弱性 | 6 处物品名模糊匹配改 id 精确匹配，顺带修好 3 个失败 | `mix test` 2988/1 |
| | | | |
