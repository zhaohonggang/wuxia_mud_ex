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
- [x] **guiyun** · 中心 `dating` · 产出 `guiyun.ucl` `guiyun.comments.txt` ✅ 2026-09-29
- [x] **gumu** · 中心 `daxiaochang` · 产出 `gumu.ucl` `gumu.comments.txt` ✅ 2026-09-29
- [x] **huanghe** · 中心 `guangchang` · 产出 `huanghe.ucl` `huanghe.comments.txt` ✅ 2026-09-29
- [x] **jingzhou** · 中心 `guangchang` · 产出 `jingzhou.ucl` `jingzhou.comments.txt` ✅ 2026-09-29
- [x] **luoyang** · 中心 `center` · 产出 `luoyang.ucl` `luoyang.comments.txt` ✅ 2026-09-29
- [x] **quanzhen** · 中心 `datang1` · 产出 `quanzhen.ucl` `quanzhen.comments.txt` ✅ 2026-09-29
- [x] **register** · 中心 `entry` · 产出 `register.ucl` `register.comments.txt` ✅ 2026-09-29
- [x] **shaolin** · 中心 `guangchang2` · 产出 `shaolin.ucl` `shaolin.comments.txt` ✅ 2026-09-29
- [x] **taishan** · 中心 `nantian` · 产出 `taishan.ucl` `taishan.comments.txt` ✅ 2026-09-30
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
| 1 | `python scripts\lpc_converter.py C:\files\git\mud\d\<zone> --zone <zone> --output data\world` | `<zone>.ucl` `<zone>.comments.txt` | - [ ] |
| 2 | `python scripts\validate_ucl.py data\world\<zone>.ucl` | 5 项全绿、退出码 0。赋坐标**之前**跑一次，**Integrity 失败属正常**（孤儿房尚无 `room_exits` 块） | - [ ] |
| 3 | 备份 + 赋坐标：`Copy-Item` 到 `data\world_backup` 后 `python scripts\assign_room_coords.py data\world\<zone>.ucl <center>` | `.ucl` 写入 `x`/`y`/`z` 坐标 | - [ ] |
| 4 | `python scripts\validate_ucl.py data\world\<zone>.ucl` **+** `python scripts\check_room_coords.py data\world\<zone>.ucl` | 前者 5 项全绿、退出码 0（`✅ All checks passed`）；后者确认每房有 x/y/z、从中心房 BFS 可达全部房间、无孤立 `room_exits` 块，退出码 0。`W1`（同坐标多房）/`W2`（方向与坐标不符）为**源数据固有的 WARNING，不需修**——见 SOP Step 4 的说明 | - [ ] || 5 | 加载校验 `docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test test/kantele/world/'` | 无报错（走 `Kantele.World.Loader.load/1`，仓库无按区热更函数） | - [ ] |
| 6 | `git add/commit` 两文件 | commit 记录 | - [ ] |
| 7 | 自动化冒烟 `MIX_ENV=test mix test` | 全绿 | - [ ] |
| 8 | 巫师测试（goto/walk/call/任务） | `test_logs/<zone>_wizard_<date>.md` | - [ ] |
| 9 | 玩家测试（主线/战斗/技能/传送） | `test_logs/<zone>_player_<date>.md` | - [ ] |
| 10 | 本文件把该区域大项标 ✅ | `git commit --amend` | - [ ] |

---

## 统计汇总

| 指标 | 数值 |
|------|------|
| 总区域数 | 71 |
| 已完成 | 13 |
| 进行中 | 0 |
| 待处理 | 58 |

> 实时更新：每完成一个区域，在对应大项打勾，并在下方填入完成日期、测试人、关键修复 commit。

---

## 完成记录（示例）

| 区域 | 完成日期 | 巫师测试 | 玩家测试 | 关键修复 commit |
|------|----------|----------|----------|-----------------|
| city | 2026-09-29 | ✅ | ✅ | 完整 Python 转换：111 rooms, 111 room_exits, 187 characters, 45 items (含 coords) |
| baituo | 2026-09-29 | ? | ? | 完整 Python 转换：49 rooms, 49 room_exits (含 coords) |
| death | 2026-09-29 | ? | ? | 完整 Python 转换：76 rooms, 76 room_exits (含 coords) |
| gaibang | 2026-09-29 | ? | ? | 完整 Python 转换：4 rooms, 4 room_exits (含 coords) |
| guiyun | 2026-09-29 | ? | ? | 完整 Python 转换：25 rooms, 25 room_exits (含 coords) |
| gumu | 2026-09-29 | ? | ? | 完整 Python 转换：74 rooms, 74 room_exits (含 coords) |
| huanghe | 2026-09-29 | ? | ? | 完整 Python 转换：56 rooms, 56 room_exits (含 coords) |
| jingzhou | 2026-09-29 | ? | ? | 完整 Python 转换：90 rooms, 90 room_exits (含 coords) |
| luoyang | 2026-09-29 | ? | ? | 完整 Python 转换：157 rooms, 157 room_exits (含 coords) |
| quanzhen | 2026-09-29 | ? | ? | 完整 Python 转换：109 rooms, 109 room_exits (含 coords) |
| register | 2026-09-29 | ? | ? | 完整 Python 转换：7 rooms, 7 room_exits (含 coords) |
| shaolin | 2026-09-29 | ? | ? | 完整 Python 转换：206 rooms, 206 room_exits (含 coords)。修 `assign_room_coords.py` 重复 `up` 键（elias 并成数组 → loader `String.split` 崩） |
| taishan | 2026-09-30 | ? | ? | 完整 Python 转换：33 rooms, 33 room_exits (含 coords)。修 `_parse_accept_body` 布尔/列表混淆导致 `accept = [{'kind': ...}]` 泄漏 Python repr；新增 `validate_ucl.py` Python-repr 检查 + 2 个 fixture |
| ... |  |  |  |  |

> 2026-09-30 全量复验：13 个已转区域全部重跑「备份 → 赋坐标 → 静态校验 → 坐标唯一性 + BFS 可达性」，
> 并跑 `MIX_ENV=test mix test test/kantele/world/`（183 tests, 0 failures，含全量世界加载）。
> 期间修掉 3 个缺陷：`assign_room_coords.py` 坐标重叠（taishan 2 处）、垂直连接因方向已被占用而
> 直接跳过导致 city 的 `xsmidao*` 6 间房不可达、菱形环路导致的同坐标重叠（新增 `_place`/`_free_coord`）。