# `data/world` 信息丢失排查报告

> ## ⚠ 这是**历史快照**，不是当前状态
>
> 本报告是一次性排查的产物，基线已固定：
>
> - 对比基线：`world_bak2/`（git `d63dea6` "腊月 3"） → `data/world/`（git `1c97437` "script"）
> - 扫描范围：两个版本都存在的 **68 个 `.ucl`**
> - 数据源：`.ucl_loss_scan.json`（一次性产物，**生成脚本已不在仓库里**，无法重跑）
>
> 下面的数字对**那次比较**成立，但已被随后的修复全部推翻。当前状态见
> `docs/ucl-conversion-fix-checklist.zh-CN.md`：
>
> | 本报告的旧数字 | 现状 |
> |---|---|
> | 无注释丢失 **136** | **0** —— A 项恢复了 `random(n)` 候选与同区子目录路径，B 项把 `__FILE__` 133 条改成真实自环，`__FILE__ self-reference` 与 `runtime-built expression` 两类均已归零 |
> | 有注释的省略 **25** | **0** —— 补注释后无未记录的信息丢失 |
> | 扫描文件 **68** | **70**（SOP 清单；`data/world` 另有 8 个非 mud 语料区共 78 个 `.ucl`） |
> | 逐区分布（`xiakedao`41 / `xiyu`26 / `gumu`16 …） | 已失效，见 checklist A/B/D 项 |
>
> 想重新做一次全量丢失排查，需要重写扫描器（判定标准见下节「判定标准」）。

## 判定标准

按要求：**写了 `# skipped ...` 注释的不算丢失；静默删掉才算丢失。**

> 跨区改写**不算丢失**。旧版写 `north = rooms.yidao.id`（无区名前缀），新版写 `north = shaolin.rooms.yidao.id`，是同一处出口的正确化，不是删除。因此比对时目标房间统一归一化为 basename 再比对。

## 1. 结论（历史快照）

| | 数量 |
|---|---|
| 扫描文件 | 68 |
| 有丢失的文件 | 27 |
| **无注释丢失（真丢失）** | **136** |
| 有注释的省略（按标准不算丢失） | 25 |

### 无注释丢失分布

| zone | 丢失项 |
|------|--------|
| `xiakedao` | 41 |
| `xiyu` | 26 |
| `gumu` | 16 |
| `city` | 14 |
| `tiezhang` | 10 |
| `motianya` | 9 |
| `huanghe` | 6 |
| `mingjiao` | 4 |
| `xueshan` | 4 |
| `baituo` | 3 |
| `shaolin` | 3 |

### 无注释丢失的原因分布

| 原因 | 数量 | 性质 |
|------|------|------|
| __FILE__ self-reference | 133 | 转换器缺陷（我的实现），**应修** |
| runtime-built expression | 3 | 转换器缺陷（我的实现），**应修** |

## 2. 无注释丢失明细

### __FILE__ self-reference —— 133 项

旧版把 LPC 的 `__FILE__` 解析成字面量房间名 `__file__`，写出
`<方向> = rooms.__file__.id`。该房间在世界里并不存在，加载器
`dereference/3` 找不到会返回 `nil`，随后被 `parse_exits` 的
`Enum.filter(not is_nil)` **丢弃**——也就是说旧版这 133 条出口
**运行时从来没生效过**。新版改为识别 `__FILE__` 并跳过。

**判定：功能上无倒退，但属于静默删除（无注释），且丢弃理由未被记录。**

按 zone 统计：

| zone | 数量 | zone | 数量 |
|------|------|------|------|
| `baituo` | 3 | `motianya` | 9 |
| `city` | 14 | `tiezhang` | 10 |
| `gumu` | 16 | `xiakedao` | 41 |
| `huanghe` | 6 | `xiyu` | 26 |
| `mingjiao` | 4 | `xueshan` | 4 |

受影响的房间（每个房间若干条）：

- `baituo`：cao1(south), cao1(west), cao2(west)
- `city`：ml1(north), ml1(west), ml2(east), ml2(west), ml3(east), ml3(north), ml4(east), ml4(west), ml5(north), ml5(west), ml6(east), ml6(north), ml7(east), ml7(west)
- `gumu`：mishi2(north), mishi2(south), mishi4(east), mishi4(north), mishi4(south), mishi5(east), mishi5(north), mishi5(west), mishi6(east), mishi6(west), mishi7(south), mishi7(west), shulin5(north), shulin5(west), shulin6(east), shulin6(south)
- `huanghe`：shamo(east), shamo(north), shamo(west), shamo1(east), shamo1(north), shamo1(west)
- `mingjiao`：jmqjiguan(east), jmqjiguan(north), jmqjiguan(south), jmqjiguan(west)
- `motianya`：mtroad1(north), mtroad2(south), mtroad2(west), mtroad3(north), mtroad3(west), mtroad4(south), mtroad5(north), mtroad5(south), mtroad5(west)
- `tiezhang`：sslin_1(north), sslin_1(west), sslin_2(east), sslin_2(south), sslin_3(east), sslin_3(north), sslin_4(south), sslin_4(west), sslin_5(east), sslin_5(west)
- `xiakedao`：lin1(east), lin1(west), lin2(north), lin2(northeast), lin2(south), lin2(southeast), lin3(east), lin3(north), lin3(northeast), lin3(south), lin4(east), lin4(north), lin4(south), lin4(southeast), lin5(north), lin5(south), lin5(southeast), lin5(west), lin6(north), lin6(northwest), lin6(south), lin6(west), lin7(east), lin7(north), lin7(northwest), lin7(southeast), midao1(north), midao1(south), midao1(west), midao2(east), midao2(north), midao3(east), midao3(south), shidong2(south), shidong2(west), shidong3(east), shidong3(west), shidong4(east), shidong4(south), shidong5(east), shidong5(west)
- `xiyu`：nanjiang(east), nanjiang(north), nanjiang(northwest), nanjiang(south), nanjiang(southeast), nanjiang1(north), nanjiang1(northeast), nanjiang1(northwest), nanjiang1(southwest), nanjiang1(west), nanjiang2(north), nanjiang2(northwest), nanjiang2(southeast), nanjiang2(southwest), nanjiang2(west), nanjiang3(east), nanjiang3(north), nanjiang3(northwest), nanjiang3(south), nanjiang3(southeast), nanjiang3(southwest), nanjiang3(west), shamo(east), shamo(north), shamo(south), shamo(west)
- `xueshan`：shenghu(east), shenghu(north), shenghu(south), shenghu(west)

### runtime-built expression —— 3 项

LPC 源码里路径主体是**确定的**，只有尾部 `random(n)` 是随机的：

```c
"d/shaolin/obj/fojing1"+random(2) : 1,   // random(2) -> 0 或 1
"d/shaolin/obj/fojing2"+random(2) : 1,
```

`random(2)` 在 LPC 里只返回 0/1，即在 fojing1 与 fojing2 之间二选一，
完全可以静态表达。但 `lpc_converter.py` 的 `_is_dynamic_expr()` 规则是
`[\[\]()]`——**只要路径里出现括号就整体判为动态并丢弃**，于是这两条被
静默删除，且没有留任何注释。

对比：

```
旧 room_items "cjlou":  dao_yi, wuming, fojing1+random(2), fojing2+random(2)
新 room_items "cjlou":  dao_yi, wuming
```

| zone | 房间 | 丢失的引用 |
|------|------|-----------|
| `shaolin` | `cjlou` | `items.fojing1+random(2).id` |
| `shaolin` | `cjlou` | `items.fojing2+random(2).id` |
| `shaolin` | `jianyu` | `items.fojing1+random(2).id` |

**这是本轮改动引入的真实功能倒退**（旧版虽然写成 `items.fojing1+random(2).id`
这种非标准形式，但它至少保留了信息；新版直接没了）。

## 3. 有注释的省略（按标准不算丢失）

| 原因 | 数量 | 说明 |
|------|------|------|
| /clone/shop/* (outside d/) | 15 | `/clone/shop/` 在 `d/` 之外，没有对应的 `data/world` 区 |
| dangling (no such room) | 9 | 目标房间在本区不存在，旧版写出的是悬空引用 |
| dangling | 1 | 同上 |

### /clone/shop/* (outside d/)

| zone | 房间 | 方向/引用 | 旧值 |
|------|------|-----------|------|
| `beijing` | `majiu` | -up | `rooms.beijing_shop.id` |
| `changan` | `majiu` | -up | `rooms.changan_shop.id` |
| `chengdu` | `majiu` | -up | `rooms.chengdu_shop.id` |
| `city` | `majiu` | -up | `rooms.yangzhou_shop.id` |
| `dali` | `majiu` | -up | `rooms.dali_shop.id` |
| `foshan` | `majiu` | -up | `rooms.foshan_shop.id` |
| `fuzhou` | `majiu` | -up | `rooms.fuzhou_shop.id` |
| `hangzhou` | `majiu` | -up | `rooms.hangzhou_shop.id` |
| `hengyang` | `majiu` | -up | `rooms.hengyang_shop.id` |
| `jingzhou` | `majiu` | -up | `rooms.jingzhou_shop.id` |
| `kaifeng` | `majiu` | -up | `rooms.kaifeng_shop.id` |
| `luoyang` | `majiu` | -up | `rooms.luoyang_shop.id` |
| `suzhou` | `majiu` | -up | `rooms.suzhou_shop.id` |
| `xiangyang` | `majiu` | -up | `rooms.xiangyang_shop.id` |
| `zhongzhou` | `majiu` | -up | `rooms.zhongzhou_shop.id` |

### dangling (no such room)

| zone | 房间 | 方向/引用 | 旧值 |
|------|------|-----------|------|
| `beijing` | `huiying` | -up | `rooms.jiulou.id` |
| `beijing` | `road10` | -east | `rooms.haigang.id` |
| `city` | `liaotian` | -east | `rooms.qiyuan1.id` |
| `death` | `baihuxue` | -south | `rooms.exit.id` |
| `death` | `jimiesi` | -north | `rooms.entry.id` |
| `room` | `xiaoyuan` | -dule | `rooms.xiaoyuan.id` |
| `room` | `xiaoyuan` | -caihong | `rooms.xiaoyuan.id` |
| `room` | `xiaoyuan` | -panlong | `rooms.dayuan.id` |
| `tiezhang` | `hunanroad1` | -east | `rooms.caodi6.id` |

### dangling

| zone | 房间 | 方向/引用 | 旧值 |
|------|------|-----------|------|
| `death` | `youmingdian` |  | `characters.yanluo.id` |

## 4. 顺带发现的两个问题

### 4.1 注释文案有误导

shaolin 的 64 条八卦方向出口（`乾`/`巽`/`离`/`艮`/`兑`/`坎`/`震`/`坤` × 8 房）
新版留下的是：

```
# skipped malformed exit direction '乾': not a bare identifier (C comment artefact)
```

**「C comment artefact（误把注释当出口）」是错的**。真实原因是 elias 的
`Word` token 只接受 ASCII 标识符，中文方向名无法作为 key——与 `huashan` 的
`hole1`..`hole6`（key 含数字）属于同一类限制，只是这里连标识符都不是。

### 4.2 同区链接被误跳过（尚未修）

核查 157 条删除明细时发现 3 条**同区**链接在新版被跳过（属功能倒退，非跨区改动引起）：

| 位置 | LPC 源码 | 新版产物 | 应为 |
|------|----------|----------|------|
| `city/liaotian -east->` | `__DIR__ "qiyuan/qiyuan1"` | 跳过 | `rooms.qiyuan1.id` |
| `room/xiaoyuan -panlong->` | `__DIR__"panlong/dayuan"` | 跳过 | `rooms.dayuan.id` |
| `tiezhang/hunanroad1 -east->` | `"d/xiangyang/caodi6"`（缺前导 `/`） | 跳过 | `xiangyang.rooms.caodi6.id` |

第三条是 `docs/mud-d-zone-center-connections.zh-CN.md` 里已记载的数据 bug
（原文「`hunanroad1.c` 的出口字符串缺前导 `/`，导致铁掌帮→襄阳单向失效」）。

## 5. 复现方式

```powershell
# 单文件对比
git diff --no-index world_bak2\shaolin.ucl data\world\shaolin.ucl

# 全量差异概览
git diff --no-index --stat world_bak2 data\world
```

本文的数据由 `.ucl_loss_scan.json` 渲染，该 JSON 记录了每一项丢失的
zone / 房间 / 方向 / 原值 / 原因，可自行过滤。

---

## 6. `set("objects")` 分支随机化修复（2026-10-06）

`taohua/mushi`、`taohua/daojufang`、`wudu/dongxue` 等房间的 LPC `create()` 里
多次 `set("objects", ...)` 且后写覆盖前写、且带 `if (random(...))` 守卫。
旧转换器只保留最后一条，导致稀有掉落/分支内容永远不出现。

**已修复**：
- 转换器新增 `_parse_object_branches`，识别受守卫的最后一次 `set("objects")`，
  生成 `room_object_sets` 数据块（每支整组 `refs = [...]`）。
- 加载器新增 `parse_object_sets`，启动时 `Enum.random/1` 等概率抽取一支整组安装。
- `daojufang`、`dongxue` 已入库；`mushi` 待补 4 个 `clone/fam/*` 物品定义。

**修复的转换器 Bug**：
- `object_file` 只接受带引号字面量 → 同时接受裸路径与带引号路径（含 `/`、`-`）。
- 物品数量统计忽略 LPC mapping 重复键 → 按值重复引用。

