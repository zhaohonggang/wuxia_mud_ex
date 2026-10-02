# UCL 转换待办清单（A–I）—— 已全部完成

> **权威文件是 `docs/ucl-conversion-fix-checklist.zh-CN.md`**（含 A–I 全部小节、
> 逐项改动明细与验证数据）。本文件只是一份速查索引，正文不再重复细节：
> 早先 C–I 各节在此被一次批量编辑截断，重建时若把 checklist 的长篇分析再抄一份，
> 就会重新产生第二份真相源并再次漂移。
>
> **转换器工作已收尾（2026-10-01）**：**不再运行转换器，也不再使用转换 SOP
> （`docs/zone-conversion-sop.zh-CN.md` 已归档）**。后续在 `data/world` 及各区
> UCL 上的改动改用新方法，由后续任务自行定义。
>
> 配套文档：`docs/ucl-conversion-issues.zh-CN.md`（20 个问题的完整分析）
> 数据：`docs/data-world-info-loss.zh-CN.md`（信息丢失排查）、`world_bak2/`（旧版快照）

## 概览

| 项 | 内容 | 优先级 | 状态 | 详见 |
|----|------|--------|------|------|
| **A** | 修 `_classify_exit_path` 的三处分类错误 | 高 | ✅ 2026-09-30 | checklist §A |
| **B** | `__FILE__` 真实修正为自环 | 低 | ✅ 2026-09-30 | checklist §B |
| **C** | 动态选房 103 条悬空引用的处理策略 | 中 | ✅ 2026-09-30 | checklist §C |
| **D** | 修正八卦方向被跳过的注释文案 | 低 | ✅ 2026-09-30 | checklist §D |
| **E** | 2 条 LPC 源本身悬空的出口 | — | ✅ 2026-10-01 | checklist §E |
| **F** | 71 区人工验收（巫师巡游） | 高 | ✅ 2026-10-01 | checklist §F |
| **G** | 不可达房间的分类确认 | 中 | ✅ 2026-10-01 | checklist §G |
| **H** | 跨区单向边的可往返性验证 | 中 | ✅ 2026-10-01 | checklist §H |
| **I** | 1 个预存测试失败 | 低 | ✅ 2026-10-01 | checklist §I |

**A–I 全部完成。** 全量基线：`mix test --seed 12345` → **3018 tests, 0 failures**；
SOP 重跑 70/70（含容器内 elias 解析）；全库可达 4115/4455（92.4%）；
跨区引用 218 条、悬空 0 条；指向不存在房间的同区出口 18 条（全部源数据固有）。

---

## 各项一句话摘要

| 项 | 一句话 | 关键文件 |
|----|--------|----------|
| **A** | `random(n)` 展开候选、同区子目录路径恢复、`d/<区名>/` 补前导斜杠 —— 三处都是本轮引入的功能倒退 | `scripts/lpc_converter.py` |
| **B** | `__FILE__` 从「跳过+注释」改成**真实自环**（137 条），`death/god1` 的 `set("exits")` 在 `reset()` 里也一并回填 | `_resolve_exit_target()` / `_backfill_exits_outside_create()` |
| **C** | 运行时选房保留候选列表、由 loader 每次加载挑一个（恢复 shaolin 4 件佛经、修 gaochang 沙漠随机支路） | `world_reachability` 无关；loader `pick_runtime_exit` |
| **D** | 方向跳过注释按真实原因分三类（空/CJK/数字/其它），不再一律误称「C 注释问题」 | `_exit_dir_skip_reason()` |
| **E** | 两条跨区悬空出口都不用改 LPC 语料：`baituo/gebi` 随宏继承恢复；`city/guangchang -liuxi->` 用「方向名反查已安装 zone」的通用规则接通，`LiuxiCommand` 桩同时改为真移动 | `_INSTALLED_ZONE_IDS` / `liuxi_command.ex` |
| **F** | 71 区巫师巡游已完成（逐区表「巫师测试」列 72 区全 ✅）；`test_logs/` 未落文件，玩家测试未做 | — |
| **G** | 340 间不可达**全部有归属、无一是转换缺陷**（78 设计孤立 / 61 非语料 / 67 语料未接入 / 80 仅脚本传送 / 52 源码内部断连 / 2 无出口） | `scripts/world_reachability.py`（新增） |
| **H** | 218 条跨区边中 195 双向、23 单向且**全部原生单向**，不补反向出口；`valid_leave` 已数据化（183 处）但运行时故意不拦截 | `test/cross_zone_wiring_test.exs` |
| **I** | 最后一个失败是**测试自己按 `key` 定位房间**（全库 432 个 key 重名），拿到 `beijing:liandan_lin1`；改按 `id` | `test/kantele/world/loader_meta_test.exs` |

---

## 途中发现的六个非显然缺陷（都已修，值得记住）

1. **`set("exits")` 写在 `create()` 之外会被丢弃**（`_backfill_exits_outside_create()`）。
   危害不只是少两条边：房间变成无出口孤儿后，`assign_room_coords.py` 会给它合成
   `up`/`down`，**静默顶替**作者写的出口。
2. **诊断工具必须与被诊断对象对账**。`world_reachability.py` 初版报 4099/4455，
   而 `cross_zone_wiring_test.exs` 里 loader 侧的真实 BFS 报 4115 —— 差额来自引号出口值、
   连字符区名、以及 BFS 没排除悬空边。**工具的 bug 会被当成数据的 bug。**
3. **「未安装区」不能写成门禁，只能是优先**。E 项最初写成「目标区未安装就 skip」，
   结果转换到空目录/部分目录时**所有跨区出口被静默丢弃**，产出依赖 `--output` 的内容。
   是「产出新鲜度自检」抓出来的（见 SOP「产出新鲜度自检」章节）。
4. **`create()` 内的 `/* */` 块注释曾污染解析值**。`create_body` 从原始文本抽取，
   之前只剥 `//`。语料在 `set("objects", ([ ... ]))` 前用块注释标注数量
   （`/* sizeof() == 5 */`），注释糊在路径前导致整条物件被丢 —— `changan` 六个兵营
   房间因此是空的。共 19 个物件、7 个区。
5. **遍历 `set` 会让产物逐次变化**。`_extract_unhandled_content` 迭代
   `other_fn_names - handled`，而 Python 每进程随机化字符串哈希，于是
   `UNHANDLED FUNCTION` 的顺序每次不同 —— 54 个 `.comments.txt` 成了纯重排噪声。
   改 `sorted()` 后 SOP 幂等。**排查手法**：同一区设不同 `PYTHONHASHSEED` 转两次比哈希。
6. **房间 `key` 不是唯一键**。全库 432 个 key 重名（`majiu` 22 个区、`kedian` 19 个、
   `liandan_lin1` 同属 `beijing` 与 `test`）。按 key `Enum.find` 会拿到迭代顺序里第一个，
   I 项那个长期失败的测试就是在断言一个错误的对象。**跨区世界里要定位房间必须用 `id`。**

---

## 参考

- `docs/ucl-conversion-fix-checklist.zh-CN.md` —— **核对单，勾选状态与明细以此为准**
- `docs/ucl-conversion-issues.zh-CN.md` —— 20 个问题的完整分析
- `docs/zone-conversion-sop.zh-CN.md` —— 转换 SOP、错误分类表、产出新鲜度自检


---

## 历史明细

A–I 各节的完整改动记录已全部移入
\docs/ucl-conversion-fix-checklist.zh-CN.md\。
本文件早先内嵌了 A/B/D 三节的长篇明细（2026-09-30 状态），

C–I 各节在同一份文档里被截断，形成「同一文件两套内容、且一套过时」的状态。
现在这里只留概览表与一句话摘要，避免再次出现第二个真相源。
