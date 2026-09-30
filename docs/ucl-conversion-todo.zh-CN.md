# UCL 转换待办清单（A–I）

> 配套文档：`docs/ucl-conversion-issues.zh-CN.md`（20 个问题的完整分析）
> 数据：`docs/data-world-info-loss.zh-CN.md`（信息丢失排查）、`world_bak2/`（旧版快照）
>
> 生成时间：2026-09-30　当前 git HEAD：`1c97437`

## 概览

| 项 | 内容 | 优先级 | 状态 |
|----|------|--------|------|
| **A** | 修 `_classify_exit_path` 的三处分类错误 | 高 | 未开始 |
| **B** | `__FILE__` 真实修正为自环 | 低 | ✅ 2026-09-30 |
| **C** | 动态选房 103 条悬空引用的处理策略 | 中 | 待决策 |
| **D** | 修正八卦方向被跳过的注释文案 | 低 | 未开始 |
| **E** | 2 条 LPC 源本身悬空的出口 | — | 无法在转换侧修 |
| **F** | 71 区人工验收（巫师巡游 / 玩家测试） | 高 | 未开始 |
| **G** | 380 间不可达房间的分类确认 | 中 | 待排查 |
| **H** | 跨区单向边的可往返性验证 | 中 | 未开始 |
| **I** | 1 个预存测试失败 | 低 | 与转换无关 |

---

## A. 修 `_classify_exit_path` 的三处分类错误

**优先级**　高　**状态**　✅ 已完成 2026-09-30

这三项同源于 `scripts/lpc_converter.py` 的 `_classify_exit_path()` / `_is_dynamic_expr()`，
一起改最省事。**都是本轮改动引入的功能倒退**。

### A-1　问题 13：`+random(n)` 的物件路径被整体丢弃

**现状**

`shaolin` 的 `cjlou`、`jianyu` 各少两件佛经：

```
旧 room_items "cjlou":  dao_yi, wuming, fojing1+random(2), fojing2+random(2)
新 room_items "cjlou":  dao_yi, wuming
```

源码（`shaolin/cjlou.c`）：

```c
"d/shaolin/obj/fojing1"+random(2) : 1,   // random(2) -> 0 或 1
"d/shaolin/obj/fojing2"+random(2) : 1,
```

路径主体 `/d/shaolin/obj/fojing1` 是**确定的**，只有尾部随机，且 `random(2)`
只返回 0/1。但 `_is_dynamic_expr()` 的规则是 `[\[\]()]`，**只要路径含括号
就整体判为动态并丢弃**，连注释都不留。

**要改什么**　把判据从「含括号」改成「剥掉 `+ <表达式>` 后是否仍有可解析的
路径主体」。剥出主体后按 `random(n)` 展开为 n 个候选（`random(2)` → 2 个 id），
全部写入 `room_items`。

**涉及**　`scripts/lpc_converter.py` 的 `_is_dynamic_expr()` / `_SAFE_ID_RE` /
`_generate_room_objects()`

**注意**　展开会让同一房间的物品数量变多。需确认加载器对重复 id 的处理，
以及 `assign_room_coords.py` 是否受影响（应无影响，它不读 `room_items`）。

### A-2　问题 15：同区子目录路径被误判为跨区

**现状**　4 条**同区**链接被跳过：

| 位置 | LPC 源码 | 新版产物 | 应为 |
|------|----------|----------|------|
| `city/liaotian -east->` | `__DIR__ "qiyuan/qiyuan1"` | 跳过 | `rooms.qiyuan1.id` |
| `room/xiaoyuan -panlong->` | `__DIR__"panlong/dayuan"` | 跳过 | `rooms.dayuan.id` |
| `room/xiaoyuan -dule->` | `__DIR__"dule/xiaoyuan"` | 跳过 | `rooms.xiaoyuan.id` |
| `room/xiaoyuan -caihong->` | `__DIR__"caihong/xiaoyuan"` | 跳过 | `rooms.xiaoyuan.id` |

**根因**　`_classify_exit_path()` 遇到含 `/` 的路径时检查首段是否等于当前区名，
不等就判为「无法识别的相对路径」。但 `qiyuan` / `panlong` / `dule` / `caihong`
都只是**本区的子目录**，与区名无关。

**要改什么**　含 `/` 且首段不是已知区名、也不是 `d/` `b/` `clone/` 等根时，
按**本区子目录**处理（取 basename），不要判为无法识别。

**注意**　`room` 区的三个子区（`caihong` / `dule` / `panlong`）**各有
`xiaoyuan.c`**，拍平后房间 id 撞名，产物里只剩一个 `xiaoyuan`。因此
`dule` / `caihong` 两条注定解析成自环。这是 `room` 区固有的拍平撞名问题，
修完仍然是自环（与改动前行为一致），要彻底解决需要给子区房间加区名前缀，
属于另一件事。

### A-3　问题 16：`d/<区名>/` 缺前导斜杠

**现状**　`tiezhang/hunanroad1 -east->` 被跳过。

源码（`tiezhang/hunanroad1.c`）：

```c
"east" : "d/xiangyang/caodi6",      // 缺前导 /
```

这是 `docs/mud-d-zone-center-connections.zh-CN.md` 早已记载的数据 bug
（原文：「`hunanroad1.c` 的出口字符串缺前导 `/`，导致铁掌帮→襄阳单向失效」）。

**要改什么**　`_classify_exit_path()` 补一条：形如 `d/<区名>/...`（缺前导斜杠）
按 `/d/...` 处理，产出 `xiangyang.rooms.caodi6.id`。

**性质**　运行时无倒退（旧版产出 `rooms.caodi6.id`，而 `tiezhang` 没有该房间，
也是悬空的），但这是文档已知的 bug，本可顺手恢复铁掌帮↔襄阳的连接。

### A 的验证方法

```powershell
# 1. 重跑全部 71 区（SOP 见 docs/zone-conversion-sop.zh-CN.md）
# 2. 三项校验
python scripts\validate_ucl.py data\world\<zone>.ucl      # 期望 exit 0
python scripts\check_room_coords.py data\world\<zone>.ucl  # 期望 exit 0
# 3. 容器内 elias 权威验证（静态校验查不出 elias 类问题）
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix run --no-start <probe> data/world/<zone>.ucl'
# 4. 加载器测试
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test test/kantele/world/'
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test'
```

**完成标准**

- `city/liaotian` 有 `east = rooms.qiyuan1.id`
- `room/xiaoyuan` 有 `panlong = rooms.dayuan.id`
- `tiezhang/hunanroad1` 有 `east = xiangyang.rooms.caodi6.id`
- `shaolin/cjlou` 的 `room_items` 恢复含佛经条目
- 71 区 `validate_ucl` + `check_room_coords` 全 exit 0
- 容器内 elias 全部解析通过
- `test/cross_zone_wiring_test.exs` 的「15 条同名撞车边」仍全绿
- 重新生成信息丢失报告，确认无注释丢失降到 0

---


### A+B 的实际结果（2026-09-30）

| 目标 | 结果 |
|------|------|
| `shaolin/cjlou` 的 `room_items` | 恢复 `items.fojing10/11/20/21.id` |
| `shaolin/jianyu` | 恢复 `items.fojing10/11.id` |
| `city/liaotian -east->` | `rooms.qiyuan1.id`（不再跳过） |
| `room/xiaoyuan -panlong->` | `rooms.dayuan.id`（`dule`/`caihong` 仍为自环，属三子区撞名的已知限制） |
| `tiezhang/hunanroad1 -east->` | `xiangyang.rooms.caodi6.id`（恢复铁掌帮↔襄阳） |
| `__FILE__` 133 条 | 产物中确认有 `# skipped exit <dir>: self-referential (__FILE__)` 注释 |
| 新增单元测试 | `scripts/test_lpc_path_rules.py`，28 项全过 |
| 70 区 SOP | val=0 / chk=0 / elias=OK 全绿 |
| fixture 回归 | `validate_ucl` 24/24，`check_room_coords` 8/8 |
| `mix test` | `world/` 190/1、`cross_zone_wiring_test` 4/4、全量 2988/1（唯一失败是 I 项预存问题） |
| 可达率 | 4061/4441 不变 |
| **无注释丢失** | **136 → 0** |

### 实施过程中发现的一个关键事实

LPC 的 `+` 是**字符串直接拼接十进制数字**，不是「文件名 stem + 序号」。

```c
"d/shaolin/obj/fojing1" + random(2)   // -> fojing10 或 fojing11
```

`shaolin/obj/` 下只有 `fojing10.c` `fojing11.c` `fojing20.c` `fojing21.c`，
**没有** `fojing1.c` / `fojing2.c`。若按 stem+序号理解会错生成
`fojing1` / `fojing11`，前者在本区并不存在。实现时以磁盘上真实存在的文件为准。

顺带修掉一个被 A-1 暴露的回归：`CLASS_D("...") + "/dao-yi"` 这类前缀含括号的
惯用写法原先匹配不上拼接正则，改取末段字面量后，`dao_yi` / `wuming` / `tao_yi`
等常规物件不再被误判为动态。


## B. `__FILE__` 真实修正为自环

**优先级**　低　**状态**　✅ 已完成 2026-09-30

原先只做到「跳过 + 注释」，现按要求**真实指向自己房间**。规模：137 条 / 50 房 / 11 区。

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
