# 区域转换核对单（Checklist）

> 基于 `docs/zone-conversion-plan.zh-CN.md`，**跳过 `minimal_world` 与 `minimal_world_v2`**（测试区，不接入正式世界）。
> 共 71 个正式区域，按 BFS 层序逐个勾选。
>
> **游戏环境与热更/测试详见：** `docs/dev-reload-guide.zh-CN.md`
>
> **标准化转换流程（SOP）详见：** `docs/zone-conversion-sop.zh-CN.md`

---

## 使用说明
- 每个区域一个复选框组，**全部 ✅ 才能进下一区域**
- 完成即在对应 `- [ ]` 改为 `- [x]` 并 `git commit --amend` 更新本文件
- 关键产出文件：`data/ucl/<zone>.ucl`、`data/ucl/<zone>_comments.txt`、`test_logs/<zone>_*.md`

---

## Layer 0 · 世界中枢

- [x] **city** · 中心 `guangchang` · 产出 `city.ucl` `city.comments.txt` ✅ 2026-09-29

---

## Layer 1 · 直连扬州（20 个，已去掉 minimal_world*）

- [x] **baituo** · 中心 `guangchang` · 产出 `baituo.ucl` `baituo.comments.txt` ✅ 2026-09-29
- [x] **death** · 中心 `yanluodian` · 产出 `death.ucl` `death.comments.txt` ✅ 2026-09-29
- [x] **gaibang** · 中心 `undertre` · 产出 `gaibang.ucl` `gaibang.comments.txt` ✅ 2026-09-29
- [ ] **guiyun** · 中心 `dating`
- [ ] **gumu** · 中心 `daxiaochang`
- [ ] **huanghe** · 中心 `guangchang`
- [ ] **jingzhou** · 中心 `guangchang`
- [ ] **luoyang** · 中心 `center`
- [ ] **quanzhen** · 中心 `datang1`
- [ ] **register** · 中心 `entry`
- [ ] **shaolin** · 中心 `guangchang2`
- [ ] **taishan** · 中心 `nantian`
- [ ] **wizard** · 中心 `hall`
- [ ] **wudang** · 中心 `guangchang`
- [ ] **wudu** · 中心 `nanyuan`
- [ ] **xuedao** · 中心 `sroad3`
- [ ] **xueshan** · 中心 `guangchang`
- [ ] **zhongzhou** · 中心 `shizhongxin`

---

## Layer 2 · 距离 2（23 个）

- [ ] **beijing** · 中心 `di_dajie1`
- [ ] **changan** · 中心 `beian-daokou`
- [ ] **chengdu** · 中心 `guangchang`
- [ ] **dali** · 中心 `zhengdian`
- [ ] **emei** · 中心 `hcaguangchang`
- [ ] **foshan** · 中心 `street4`
- [ ] **fuzhou** · 中心 `dongjiekou`
- [ ] **hangzhou** · 中心 `duanqiao`
- [ ] **heimuya** · 中心 `chengdedian`
- [ ] **hengyang** · 中心 `zhurongdian`
- [ ] **kaifeng** · 中心 `hh_zhengting`
- [ ] **kunming** · 中心 `jinrilou`
- [ ] **lanzhou** · 中心 `guangchang`
- [ ] **lingxiao** · 中心 `dadian`
- [ ] **room** · 中心 `xiaoyuan`
- [ ] **songshan** · 中心 `dadian`
- [ ] **suzhou** · 中心 `zhongxin`
- [ ] **village** · 中心 `square`
- [ ] **xiangyang** · 中心 `guangchang`
- [ ] **xiaoyao** · 中心 `qingcaop`
- [ ] **xiyu** · 中心 `shanjiao`
- [ ] **quanzhou** · 中心 `zhongxin`

---

## Layer 3 · 距离 3（21 个）

- [ ] **guanwai** · 中心 `longmen`
- [ ] **hengshan** · 中心 `beiyuemiao`
- [ ] **huashan** · 中心 `square`
- [ ] **item** · 中心 `road1`
- [ ] **jinshe** · 中心 `shandong`
- [ ] **jueqing** · 中心 `dating`
- [ ] **lingjiu** · 中心 `damen`
- [ ] **meizhuang** · 中心 `gate`
- [ ] **mingjiao** · 中心 `dadian`
- [ ] **motianya** · 中心 `mtdating`
- [ ] **pk** · 中心 `entry`
- [ ] **qingcheng** · 中心 `sanqingdian`
- [ ] **shenfeng** · 中心 `dadian`
- [ ] **tianlongsi** · 中心 `baodian`
- [ ] **tiezhang** · 中心 `guangchang`
- [ ] **tulong** · 中心 `yubifeng/damen`（容器区，三子区统一）
- [ ] **wanjiegu** · 中心 `hall`
- [ ] **wuguan** · 中心 `guofu_dating`
- [ ] **xiakedao** · 中心 `dating`
- [ ] **yanziwu** · 中心 `canheju`

---

## Layer 4 · 距离 4（3 个）

- [ ] **gaochang** · 中心 `dadian`
- [ ] **jinshe** 已在 Layer 3 列出
- [ ] **kunlun** · 中心 `guangchang`

---

## Unreachable · 不可达孤立区（8 个）

- [ ] **huanggong** · 中心 `qihedian`
- [ ] **lingzhou** · 中心 `center`
- [ ] **shenlong** · 中心 `dating`
- [ ] **sky** · 中心 `tianmen`
- [ ] **special** · 无房间（仅六道轮回展示）
- [ ] **tangmen** · 无房间（仅 obj）
- [ ] **taohua** · 中心 `dating`
- [ ] **xuanminggu** · 中心 `xuanminggu`

---

## 单区域执行步骤（每区必做）

| 步骤 | 动作 | 产出/验证 | 勾选 |
|------|------|-----------|------|
| 1 | `python scripts\lpc_converter.py C:\files\git\mud\d\<zone> --zone <zone>` | `<zone>.ucl` `<zone>.comments.txt` | - [ ] |
| 2 | `python scripts\assign_room_coords.py data\world\<zone>.ucl <center>` | `.ucl` 写入 `x`/`y`/`z` 坐标 | - [ ] |
| 3 | `python scripts\validate_ucl.py data\world\<zone>.ucl` | 5 项全绿、退出码 0（`✅ All checks passed`）。本步在赋坐标**之后**；若在步骤 1 之后提前跑一次，**Integrity 失败属正常**（孤儿房尚无 `room_exits` 块） | - [ ] |
| 4 | `git add/commit` 两文件 | commit 记录 | - [ ] |
| 5 | 热更加载 `World.load_zone("<zone>")` | 无报错 | - [ ] |
| 6 | 自动化测试 `mix test test/zone_<zone>_test.exs` | 全绿 | - [ ] |
| 7 | 巫师测试（goto/walk/call/任务） | `test_logs/<zone>_wizard_<date>.md` | - [ ] |
| 8 | 玩家测试（主线/战斗/技能/传送） | `test_logs/<zone>_player_<date>.md` | - [ ] |
| 9 | 本文件把该区域大项标 ✅ | `git commit --amend` | - [ ] |

---

## 统计汇总

| 指标 | 数值 |
|------|------|
| 总区域数 | 71 |
| 已完成 | 1 |
| 进行中 | 0 |
| 待处理 | 70 |

> 实时更新：每完成一个区域，在对应大项打勾，并在下方填入完成日期、测试人、关键修复 commit。

---

## 完成记录（示例）

| 区域 | 完成日期 | 巫师测试 | 玩家测试 | 关键修复 commit |
|------|----------|----------|----------|-----------------|
| city | 2026-09-29 | ✅ | ✅ | 完整 Python 转换：111 rooms, 111 room_exits, 187 characters, 45 items (含 coords) |
| baituo | 2026-09-29 | ? | ? | 完整 Python 转换：49 rooms, 49 room_exits (含 coords) |
| death | 2026-09-29 | ? | ? | 完整 Python 转换：76 rooms, 76 room_exits (含 coords) |
| gaibang | 2026-09-29 | ? | ? | 完整 Python 转换：4 rooms, 4 room_exits (含 coords) |
| ... |  |  |  |  |