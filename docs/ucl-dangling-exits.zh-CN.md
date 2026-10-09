# 剩余同区悬空出口清单

> 生成时间：2026-09-30　数据源：`data/world/*.ucl` + `C:\files\git\mud\d\<zone>`
> 重新生成：重跑扫描脚本即可刷新本文

本文记录 C 项（动态选房 / 悬空引用）处理完之后**仍然存在**的同区悬空出口。
每条都在 `data/world/<zone>.ucl` 里写成了 `rooms.<目标>.id`，但 `<目标>`
这个房间在该区并不存在，因此 `Kantele.World.Loader.parse_exits/3` 的
`dereference/3` 返回 `nil`，这条出口在运行时被丢弃。

**这些都不是转换器的缺陷**——它们的 LPC 源码里就写着这些不存在的房间名，
属于源数据（`C:\files\git\mud`）自身的问题，转换侧无法修正。

## 1. 总览

| 指标 | 数值 |
|------|------|
| 悬空出口总数 | **18** |
| 涉及区域 | 9 |
| 目标房间有同名 `.c` 但仍未转换 | 0 |
| 目标房间在语料里根本不存在 | 18 |

### 按区域分布

| zone | 条数 |
|------|------|
| `quanzhou` | 5 |
| `suzhou` | 3 |
| `tulong` | 3 |
| `death` | 2 |
| `heimuya` | 1 |
| `huashan` | 1 |
| `lingxiao` | 1 |
| `wudang` | 1 |
| `zhongzhou` | 1 |

## 2. 逐条明细

| # | zone | 房间 | 方向 | 目标 | LPC 源码 | 判定 |
|---|------|------|------|------|-----------|------|
| 1 | `death` | `baihuxue` | `south` | `exit` | `"south" : __DIR__"heisenlin/exit",` | 目标 `.c` 不存在 |
| 2 | `death` | `jimiesi` | `north` | `entry` | `"north" : __DIR__"heisenlin/entry",` | 目标 `.c` 不存在 |
| 3 | `heimuya` | `didao2` | `down` | `mishi` | `"down" : __DIR__"mishi",` | 目标 `.c` 不存在 |
| 4 | `huashan` | `doctorroom` | `east` | `road1` | `"east" : __DIR__"road1",` | 目标 `.c` 不存在 |
| 5 | `lingxiao` | `yuan` | `south` | `bingqiao` | `"south" : __DIR__"bingqiao",` | 目标 `.c` 不存在 |
| 6 | `quanzhou` | `xijie` | `north` | `laozhai` | `"north" : __DIR__"laozhai",` | 目标 `.c` 不存在 |
| 7 | `quanzhou` | `zhulin` | `east` | `wuqiku` | `"east" : __DIR__"wuqiku",` | 目标 `.c` 不存在 |
| 8 | `quanzhou` | `zhulin` | `north` | `zhulin3` | `"north" : __DIR__"zhulin3",` | 目标 `.c` 不存在 |
| 9 | `quanzhou` | `zhulin` | `south` | `zhulin1` | `"south" : __DIR__"zhulin1",` | 目标 `.c` 不存在 |
| 10 | `quanzhou` | `zhulin` | `west` | `hsyuan2` | `"west" : __DIR__"hsyuan2",` | 目标 `.c` 不存在 |
| 11 | `suzhou` | `taihu` | `east` | `jiaxing` | `"east"  : __DIR__"jiaxing",` | 目标 `.c` 不存在 |
| 12 | `suzhou` | `taihu` | `north` | `qzroad1` | `"north" : __DIR__"qzroad1",` | 目标 `.c` 不存在 |
| 13 | `suzhou` | `taihu` | `south` | `qzroad3` | `"south" : __DIR__"qzroad3",` | 目标 `.c` 不存在 |
| 14 | `tulong` | `shimen` | `west` | `tongdao` | `"west"    : __DIR__"tongdao",` | 目标 `.c` 不存在 |
| 15 | `tulong` | `songlin` | `east` | `song2` | `"east"  : __DIR__"song2",` | 目标 `.c` 不存在 |
| 16 | `tulong` | `songlin` | `west` | `baihe` | `"west"    : __DIR__"baihe",` | 目标 `.c` 不存在 |
| 17 | `wudang` | `langmei` | `east` | `lameigt` | `"east" : __DIR__"lameigt",` | 目标 `.c` 不存在 |
| 18 | `zhongzhou` | `guandao7` | `north` | `guandao6` | `"north" : __DIR__"guandao6",` | 目标 `.c` 不存在 |

## 3. 归因

### 3.1 目标房间在语料里不存在（18 条，全部）

这些方向在 LPC 源码中就指向一个**没有对应 `.c` 文件**的房间。可能原因：

1. **房间被作者后来删除**，但引用它的出口没同步改（最常见）；
2. **房间在另一个区**，作者用了裸名而非 `/d/<区>/` 路径——
   按 MudOS 语义裸名解析为同目录，所以这是作者的笔误；
3. **子目录路径写错**，例如 `__DIR__"heisenlin/exit"` 而 `heisenlin/` 下没有 `exit.c`。

典型：

- `death/baihuxue` 的 `south` → 源码 `"south" : __DIR__"heisenlin/exit",`
- `death/jimiesi` 的 `north` → 源码 `"north" : __DIR__"heisenlin/entry",`
- `heimuya/didao2` 的 `down` → 源码 `"down" : __DIR__"mishi",`
- `huashan/doctorroom` 的 `east` → 源码 `"east" : __DIR__"road1",`

### 3.2 与跨区出口无关

这批全是**同区**引用。跨区出口（`/d/<其他区>/...`）在 A 项已全部接通，
写成 `<区名>.rooms.<房间>.id`，共 210 条，无悬空。

## 4. 影响

| 方面 | 影响 |
|------|------|
| 加载 | 无。`parse_exits/3` 丢弃 `nil`，`LoaderError` 不会触发 |
| elias 解析 | 无。`rooms.<x>.id` 是合法语法，静态校验全绿 |
| 玩家 | 看不到也走不了这个方向——出口在加载时就没了 |
| 坐标 | 无。`assign_room_coords.py` 的 BFS 同样只跟随存在的房间 |

换句话说：**产物是自洽的**，只是比源数据少了几条走不通的出口。

## 5. 建议处置

三个选项：

1. **保持现状 + 登记**（推荐）　不动产物，把本文作为已知限制留档。
   理由：转换器的职责是忠实转换，源数据的悬空引用不应在转换阶段"发明"目标。
2. **改 LPC 语料**　若这些房间本该存在，补上 `.c`；若确实已废弃，
   改掉引用它们的出口。语料是外部只读参考，需你确认是否可写。
3. **转换期加注释**　在产物里为每条悬空出口留 `# skipped` 注释。
   代价是产物噪音变大（SOP 的 `validate_ucl.py` 需相应放宽），收益是可追溯。

当前选择：**选项 1**。

## 6. 相关文档

- `docs/ucl-conversion-issues.zh-CN.md` —— 20 个转换器问题（本清单的来源）
- `docs/ucl-conversion-fix-checklist.zh-CN.md` —— 修复核对单
- `docs/data-world-info-loss.zh-CN.md` —— 信息丢失排查报告
- `docs/zone-conversion-sop.zh-CN.md` —— 转换 SOP（错误定位表）

