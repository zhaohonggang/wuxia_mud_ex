# Plan D — Remaining unplanned failing performs (F4 migration)

> 动态清单：每次全量严格验收扫描后重新生成，仅列出仍 FAIL 的未计划文件。
> 已排除计划 A / B / C / E。**Plan E**（`scripts/f4-plan-E-rel.json`，60 个 B 级文件）
> 由另一 session 执行，见 `docs/F4-migration-plan-E.zh-CN.md`；本清单与 Plan E 互不重叠。
> 验收工具：`scripts/perf_acceptance.py`（`check_one`，严格 multiset 比对，MISSING=0 为 PASS）。
> 约定（沿用 plan A/B）：手工 `.ex` 必须保留 `# ===== 原始 LPC 源码 =====` 注释块；
> 文案字面量必须在代码字符串中（注释被验收工具剥除）；按 `scripts/protected_performs.txt` 登记保护；按顶层目录批次提交。

## 统计
- 剩余文件数：**41**
- 缺失字面量合计（miss 之和）：**438**
- 严重度：A严重(>=15) / B中等(5-14) / C轻微(1-4)

| 严重度 | 文件数 | miss 合计 |
|--------|--------|-----------|
| A严重(>=15) | 0 | 0 |
| B中等(5-14) | 41 | 438 |
| C轻微(1-4) | 0 | 0 |

## 按顶层目录分组（提交批次）

### lutou_zhang（1 个）
- [ ] ❌ `lutou_zhang/tong.ex` ← `lutou-zhang/tong.c` (miss=11)

### mantian_xing（1 个）
- [ ] ❌ `mantian_xing/shan.ex` ← `mantian-xing/shan.c` (miss=10)

### mantianhuayu_zhen（1 个）
- [ ] ❌ `mantianhuayu_zhen/zheng.ex` ← `mantianhuayu-zhen/zheng.c` (miss=11)

### miaojia_jian（1 个）
- [ ] ❌ `miaojia_jian/qian.ex` ← `miaojia-jian/qian.c` (miss=12)

### mingwang_jian（2 个）
- [ ] ❌ `mingwang_jian/ruo.ex` ← `mingwang-jian/ruo.c` (miss=12)
- [ ] ❌ `mingwang_jian/xiang.ex` ← `mingwang-jian/xiang.c` (miss=10)

### nianhua_zhi（1 个）
- [ ] ❌ `nianhua_zhi/fuxue.ex` ← `nianhua-zhi/fuxue.c` (miss=10)

### ningxue_zhang（1 个）
- [ ] ❌ `ningxue_zhang/xue.ex` ← `ningxue-zhang/xue.c` (miss=8)

### pangen_cuojiefu（1 个）
- [ ] ❌ `pangen_cuojiefu/cuo.ex` ← `pangen-cuojiefu/cuo.c` (miss=13)

### panlong_suo（1 个）
- [ ] ❌ `panlong_suo/chan.ex` ← `panlong-suo/chan.c` (miss=13)

### pichen_jian（1 个）
- [ ] ❌ `pichen_jian/ao.ex` ← `pichen-jian/ao.c` (miss=10)

### pidi_shenzhen（1 个）
- [ ] ❌ `pidi_shenzhen/huan.ex` ← `pidi-shenzhen/huan.c` (miss=11)

### poguang_dao（1 个）
- [ ] ❌ `poguang_dao/bing.ex` ← `poguang-dao/bing.c` (miss=14)

### pomie_jinzhen（1 个）
- [ ] ❌ `pomie_jinzhen/du.ex` ← `pomie-jinzhen/du.c` (miss=13)

### qiankun_jian（2 个）
- [ ] ❌ `qiankun_jian/qian.ex` ← `qiankun-jian/qian.c` (miss=12)
- [ ] ❌ `qiankun_jian/riyue.ex` ← `qiankun-jian/riyue.c` (miss=11)

### qianye_shou（1 个）
- [ ] ❌ `qianye_shou/qianye.ex` ← `qianye-shou/qianye.c` (miss=8)

### qingliang_jian（1 个）
- [ ] ❌ `qingliang_jian/ming.ex` ← `qingliang-jian/ming.c` (miss=11)

### qishi_ji（1 个）
- [ ] ❌ `qishi_ji/juan.ex` ← `qishi-ji/juan.c` (miss=12)

### qiufeng_chenfa（1 个）
- [ ] ❌ `qiufeng_chenfa/chan.ex` ← `qiufeng-chenfa/chan.c` (miss=8)

### qiulin_shiye（1 个）
- [ ] ❌ `qiulin_shiye/wu.ex` ← `qiulin-shiye/wu.c` (miss=8)

### qixing_jian（1 个）
- [ ] ❌ `qixing_jian/xing.ex` ← `qixing-jian/xing.c` (miss=11)

### quanzhen_jian（2 个）
- [ ] ❌ `quanzhen_jian/chan.ex` ← `quanzhen-jian/chan.c` (miss=11)
- [ ] ❌ `quanzhen_jian/ding.ex` ← `quanzhen-jian/ding.c` (miss=11)

### raozhi_roujian（1 个）
- [ ] ❌ `raozhi_roujian/chuan.ex` ← `raozhi-roujian/chuan.c` (miss=11)

### riyue_bian（1 个）
- [ ] ❌ `riyue_bian/shang.ex` ← `riyue-bian/shang.c` (miss=8)

### ruanhong_zhusuo（1 个）
- [ ] ❌ `ruanhong_zhusuo/teng.ex` ← `ruanhong-zhusuo/teng.c` (miss=11)

### sanhua_zhang（1 个）
- [ ] ❌ `sanhua_zhang/san.ex` ← `sanhua-zhang/san.c` (miss=9)

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
