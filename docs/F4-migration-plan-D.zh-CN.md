# Plan D — Remaining unplanned failing performs (F4 migration)

> 动态清单：每次全量严格验收扫描后重新生成，仅列出仍 FAIL 的未计划文件。
> 已排除计划 A / B / C / E。**Plan E**（`scripts/f4-plan-E-rel.json`，60 个 B 级文件）
> 由另一 session 执行，见 `docs/F4-migration-plan-E.zh-CN.md`；本清单与 Plan E 互不重叠。
> 验收工具：`scripts/perf_acceptance.py`（`check_one`，严格 multiset 比对，MISSING=0 为 PASS）。
> 约定（沿用 plan A/B）：手工 `.ex` 必须保留 `# ===== 原始 LPC 源码 =====` 注释块；
> 文案字面量必须在代码字符串中（注释被验收工具剥除）；按 `scripts/protected_performs.txt` 登记保护；按顶层目录批次提交。

## 统计
- 剩余文件数：**13**
- 缺失字面量合计（miss 之和）：**138**
- 严重度：A严重(>=15) / B中等(5-14) / C轻微(1-4)

| 严重度 | 文件数 | miss 合计 |
|--------|--------|-----------|
| A严重(>=15) | 0 | 0 |
| B中等(5-14) | 13 | 138 |
| C轻微(1-4) | 0 | 0 |

## 按顶层目录分组（提交批次）

### sanwu_shou（1 个）
- [ ] ❌ `sanwu_shou/wei.ex` ← `sanwu-shou/wei.c` (miss=12)

### shangjia_dao（1 个）
- [ ] ❌ `shangjia_dao/juan.ex` ← `shangjia-dao/juan.c` (miss=11)

### shunv_jian（1 个）
- [ ] ❌ `shunv_jian/ning.ex` ← `shunv-jian/ning.c` (miss=12)

### songshan_jian（1 个）
- [ ] ❌ `songshan_jian/meng.ex` ← `songshan-jian/meng.c` (miss=12)

### sun_finger（1 个）
- [ ] ❌ `sun_finger/dian.ex` ← `sun-finger/dian.c` (miss=8)

### suqin_beijian（1 个）
- [ ] ❌ `suqin_beijian/can.ex` ← `suqin-beijian/can.c` (miss=11)

### suxin_jian（1 个）
- [ ] ❌ `suxin_jian/lian.ex` ← `suxin-jian/lian.c` (miss=10)

### taiji_jian（2 个）
- [ ] ❌ `taiji_jian/chan.ex` ← `taiji-jian/chan.c` (miss=10)
- [ ] ❌ `taiji_jian/zhuan.ex` ← `taiji-jian/zhuan.c` (miss=10)

### tiangang_zhi（1 个）
- [ ] ❌ `tiangang_zhi/ling.ex` ← `tiangang-zhi/ling.c` (miss=10)

### wudang_jian（1 个）
- [ ] ❌ `wudang_jian/sheng.ex` ← `wudang-jian/sheng.c` (miss=11)

### xiyang_jian（1 个）
- [ ] ❌ `xiyang_jian/ci.ex` ← `xiyang-jian/ci.c` (miss=10)

### yunhe_jian（1 个）
- [ ] ❌ `yunhe_jian/chong.ex` ← `yunhe-jian/chong.c` (miss=11)
