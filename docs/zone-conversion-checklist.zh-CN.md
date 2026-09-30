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

- [x] **city** · 中心 `guangchang` · `goto city:guangchang`

---

## Layer 1 · 直连扬州（20 个，已去掉 minimal_world*）

- [x] **baituo** · 中心 `guangchang` · `goto baituo:guangchang`
- [x] **death** · 中心 `yanluodian` · `goto death:yanluodian`
- [x] **gaibang** · 中心 `undertre` · `goto gaibang:undertre`
- [x] **guiyun** · 中心 `dating` · `goto guiyun:dating`
- [x] **gumu** · 中心 `daxiaochang` · `goto gumu:daxiaochang`
- [x] **huanghe** · 中心 `guangchang` · `goto huanghe:guangchang`
- [x] **jingzhou** · 中心 `guangchang` · `goto jingzhou:guangchang`
- [x] **luoyang** · 中心 `center` · `goto luoyang:center`
- [x] **quanzhen** · 中心 `datang1` · `goto quanzhen:datang1`
- [x] **register** · 中心 `entry` · `goto register:entry`
- [x] **shaolin** · 中心 `guangchang2` · `goto shaolin:guangchang2`
- [x] **taishan** · 中心 `nantian` · `goto taishan:nantian`
- [x] **wizard** · 中心 `hall` · `goto wizard:hall`
- [x] **wudang** · 中心 `guangchang` · `goto wudang:guangchang`
- [x] **wudu** · 中心 `nanyuan` · `goto wudu:nanyuan`
- [x] **xuedao** · 中心 `sroad3` · `goto xuedao:sroad3`
- [x] **xueshan** · 中心 `guangchang` · `goto xueshan:guangchang`
- [x] **zhongzhou** · 中心 `shizhongxin` · `goto zhongzhou:shizhongxin`

---

## Layer 2 · 距离 2（23 个）

- [x] **beijing** · 中心 `di_dajie1` · `goto beijing:di_dajie1` ✅ 2026-09-30
- [x] **changan** · 中心 `beian_daokou` · `goto changan:beian_daokou` ✅ 2026-09-30
- [x] **chengdu** · 中心 `guangchang` · `goto chengdu:guangchang` ✅ 2026-09-30
- [x] **dali** · 中心 `zhengdian` · `goto dali:zhengdian` ✅ 2026-09-30
- [x] **emei** · 中心 `hcaguangchang` · `goto emei:hcaguangchang` ✅ 2026-09-30
- [x] **foshan** · 中心 `street4` · `goto foshan:street4` ✅ 2026-09-30
- [x] **fuzhou** · 中心 `dongjiekou` · `goto fuzhou:dongjiekou` ✅ 2026-09-30
- [x] **hangzhou** · 中心 `duanqiao` · `goto hangzhou:duanqiao` ✅ 2026-09-30
- [x] **heimuya** · 中心 `chengdedian` · `goto heimuya:chengdedian` ✅ 2026-09-30
- [x] **hengyang** · 中心 `zhurongdian` · `goto hengyang:zhurongdian` ✅ 2026-09-30
- [x] **kaifeng** · 中心 `hh_zhengting` · `goto kaifeng:hh_zhengting` ✅ 2026-09-30
- [x] **kunming** · 中心 `jinrilou` · `goto kunming:jinrilou` ✅ 2026-09-30
- [x] **lanzhou** · 中心 `guangchang` · `goto lanzhou:guangchang` ✅ 2026-09-30
- [x] **lingxiao** · 中心 `dadian` · `goto lingxiao:dadian` ✅ 2026-09-30
- [x] **room** · 中心 `xiaoyuan` · `goto room:xiaoyuan` ✅ 2026-09-30
- [x] **songshan** · 中心 `dadian` · `goto songshan:dadian` ✅ 2026-09-30
- [x] **suzhou** · 中心 `zhongxin` · `goto suzhou:zhongxin` ✅ 2026-09-30
- [x] **village** · 中心 `square` · `goto village:square` ✅ 2026-09-30
- [x] **xiangyang** · 中心 `guangchang` · `goto xiangyang:guangchang` ✅ 2026-09-30
- [x] **xiaoyao** · 中心 `qingcaop` · `goto xiaoyao:qingcaop` ✅ 2026-09-30
- [x] **xiyu** · 中心 `shanjiao` · `goto xiyu:shanjiao` ✅ 2026-09-30
- [x] **quanzhou** · 中心 `zhongxin` · `goto quanzhou:zhongxin` ✅ 2026-09-30

---

## Layer 3 · 距离 3（21 个）

- [ ] **guanwai** · 中心 `longmen` · `goto guanwai:longmen`
- [ ] **hengshan** · 中心 `beiyuemiao` · `goto hengshan:beiyuemiao`
- [ ] **huashan** · 中心 `square` · `goto huashan:square`
- [ ] **item** · 中心 `road1` · `goto item:road1`
- [ ] **jinshe** · 中心 `shandong` · `goto jinshe:shandong`
- [ ] **jueqing** · 中心 `dating` · `goto jueqing:dating`
- [ ] **lingjiu** · 中心 `damen` · `goto lingjiu:damen`
- [ ] **meizhuang** · 中心 `gate` · `goto meizhuang:gate`
- [ ] **mingjiao** · 中心 `dadian` · `goto mingjiao:dadian`
- [ ] **motianya** · 中心 `mtdating` · `goto motianya:mtdating`
- [ ] **pk** · 中心 `entry` · `goto pk:entry`
- [ ] **qingcheng** · 中心 `sanqingdian` · `goto qingcheng:sanqingdian`
- [ ] **shenfeng** · 中心 `dadian` · `goto shenfeng:dadian`
- [ ] **tianlongsi** · 中心 `baodian` · `goto tianlongsi:baodian`
- [ ] **tiezhang** · 中心 `guangchang` · `goto tiezhang:guangchang`
- [ ] **tulong** · 中心 `yubifeng/damen`（容器区，三子区统一）
- [ ] **wanjiegu** · 中心 `hall` · `goto wanjiegu:hall`
- [ ] **wuguan** · 中心 `guofu_dating` · `goto wuguan:guofu_dating`
- [ ] **xiakedao** · 中心 `dating` · `goto xiakedao:dating`
- [ ] **yanziwu** · 中心 `canheju` · `goto yanziwu:canheju`

---

## Layer 4 · 距离 4（3 个）

- [ ] **gaochang** · 中心 `dadian` · `goto gaochang:dadian`
- [ ] **jinshe** 已在 Layer 3 列出
- [ ] **kunlun** · 中心 `guangchang` · `goto kunlun:guangchang`

---

## Unreachable · 不可达孤立区（8 个）

- [ ] **huanggong** · 中心 `qihedian` · `goto huanggong:qihedian`
- [ ] **lingzhou** · 中心 `center` · `goto lingzhou:center`
- [ ] **shenlong** · 中心 `dating` · `goto shenlong:dating`
- [ ] **sky** · 中心 `tianmen` · `goto sky:tianmen`
- [ ] **special** · 无房间（仅六道轮回展示）
- [ ] **tangmen** · 无房间（仅 obj）
- [ ] **taohua** · 中心 `dating` · `goto taohua:dating`
- [ ] **xuanminggu** · 中心 `xuanminggu` · `goto xuanminggu:xuanminggu`

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
| 已完成 | 41 |
| 进行中 | 0 |
| 待处理 | 31 |

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
| wizard | 2026-09-30 | ? | ? | 完整 Python 转换：9 rooms, 9 room_exits (含 coords)。中心 `hall`，全可达 |
| wudang | 2026-09-30 | ? | ? | 完整 Python 转换：102 rooms, 102 room_exits (含 coords)。修 `lpc_converter.py` 动态表达式泄漏：`"/clone/book/" + books[random(sizeof(books))]` 被 `_looks_like_path` 误判为路径，产出非法 id `items. + books[...].id`；新增 `_is_dynamic_expr()` + `_SAFE_ID_RE` 守卫跳过无法静态解析的 key（`daotong` 保留）；新增 fixture `43_bad_syntax_lpc_expr_leak.ucl` |
| wudu | 2026-09-30 | ? | ? | 完整 Python 转换：108 rooms, 108 room_exits (含 coords) |
| xuedao | 2026-09-30 | ? | ? | 完整 Python 转换：24 rooms, 24 room_exits (含 coords) |
| xueshan | 2026-09-30 | ? | ? | 完整 Python 转换：39 rooms, 39 room_exits (含 coords) |
| zhongzhou | 2026-09-30 | ? | ? | 完整 Python 转换：90 rooms, 90 room_exits (含 coords) |
| changan | 2026-09-30 | ? | ? | 修 `lpc_converter.py` `_generate_room_item_desc`：`item_desc` 的中文 key（`床`/`大床`）归一化后成空串却漏过判空，产出裸 ` = "..."`；改为对**归一化后**的 keyword 判空 |
| room | 2026-09-30 | ? | ? | 修 `lpc_converter.py` `_parse_mapping_pairs`：源码行尾 C 注释（`"south" : ..., /* EXAMPLE */`）被当成下一个 pair 且无 `:`，兜底成 `(comment, nil)` 渲染为 ` = rooms.nil.id`；改为丢弃注释 pair + 新增 `_is_valid_exit_dir()` 过滤非标识符方向 |
| beijing | 2026-09-30 | ? | ? | 完整 Python 转换：202 rooms, 202 room_exits (含 coords) |
| chengdu | 2026-09-30 | ? | ? | 完整 Python 转换：76 rooms, 76 room_exits (含 coords) |
| dali | 2026-09-30 | ? | ? | 完整 Python 转换：213 rooms, 213 room_exits (含 coords) |
| emei | 2026-09-30 | ? | ? | 完整 Python 转换：102 rooms, 102 room_exits (含 coords) |
| foshan | 2026-09-30 | ? | ? | 完整 Python 转换：32 rooms, 32 room_exits (含 coords) |
| fuzhou | 2026-09-30 | ? | ? | 完整 Python 转换：61 rooms, 61 room_exits (含 coords) |
| hangzhou | 2026-09-30 | ? | ? | 完整 Python 转换：120 rooms, 120 room_exits (含 coords) |
| heimuya | 2026-09-30 | ? | ? | 完整 Python 转换：80 rooms, 80 room_exits (含 coords) |
| hengyang | 2026-09-30 | ? | ? | 完整 Python 转换：107 rooms, 107 room_exits (含 coords) |
| kaifeng | 2026-09-30 | ? | ? | 完整 Python 转换：132 rooms, 132 room_exits (含 coords) |
| kunming | 2026-09-30 | ? | ? | 完整 Python 转换：54 rooms, 54 room_exits (含 coords) |
| lanzhou | 2026-09-30 | ? | ? | 完整 Python 转换：37 rooms, 37 room_exits (含 coords) |
| lingxiao | 2026-09-30 | ? | ? | 完整 Python 转换：78 rooms, 78 room_exits (含 coords) |
| songshan | 2026-09-30 | ? | ? | 完整 Python 转换：28 rooms, 28 room_exits (含 coords) |
| suzhou | 2026-09-30 | ? | ? | 完整 Python 转换：72 rooms, 72 room_exits (含 coords) |
| village | 2026-09-30 | ? | ? | 完整 Python 转换：30 rooms, 30 room_exits (含 coords) |
| xiangyang | 2026-09-30 | ? | ? | 完整 Python 转换：119 rooms, 119 room_exits (含 coords)。**容器加载失败修复**：`wuxiuwen.c` 的 inquiry 值是 LPC 闭包 `(: ask_me_1, "weibo" :)`，其中「数字紧邻逗号」触发 elias 0.2.8 的 leex 分词缺陷（Word 正则排除集不含逗号 → 逗号独立成 `comma` token → 语法无 comma 产生式）→ `Elias.parse/1` 报 `syntax error before: ','`，整个世界无法启动。修 `lpc_converter.py` 新增 `_elias_safe_value()` 跳过不可解析值并留注释；`validate_ucl.py` 新增 `_ELIAS_UNLEXABLE_RE` 检查 + `_strip_comments()`（避免转换器自己的说明注释误报）+ fixture `44_bad_chars_elias_unlexable.ucl` |
| xiaoyao | 2026-09-30 | ? | ? | 完整 Python 转换：22 rooms, 22 room_exits (含 coords) |
| xiyu | 2026-09-30 | ? | ? | 完整 Python 转换：51 rooms, 51 room_exits (含 coords) |
| quanzhou | 2026-09-30 | ? | ? | 完整 Python 转换：36 rooms, 36 room_exits (含 coords) |
| ... |  |  |  |  |

> 2026-09-30 全量复验：13 个已转区域全部重跑「备份 → 赋坐标 → 静态校验 → 坐标唯一性 + BFS 可达性」，
> 并跑 `MIX_ENV=test mix test test/kantele/world/`（183 tests, 0 failures，含全量世界加载）。
> 期间修掉 3 个缺陷：`assign_room_coords.py` 坐标重叠（taishan 2 处）、垂直连接因方向已被占用而
> 直接跳过导致 city 的 `xsmidao*` 6 间房不可达、菱形环路导致的同坐标重叠（新增 `_place`/`_free_coord`）。

> 2026-09-30 Layer 1 补完（wizard/wudang/wudu/xuedao/xueshan/zhongzhou）+ **Layer 2 全 22 区**，
> 累计 41 区。41 区 `validate_ucl.py` 与 `check_room_coords.py` 全 exit 0，`test/fixtures/validate_ucl`
> 回归 20/20。期间修掉 4 个转换器缺陷（均只改脚本、不改产物）：
> 1. `lpc_converter.py` `_is_dynamic_expr()` / `_SAFE_ID_RE`——运行时拼接的对象路径
>    （`"/clone/book/" + books[random(sizeof(books))]`）被误判为路径，产出非法 id（wudang）
> 2. `lpc_converter.py` `_generate_room_item_desc()`——`item_desc` 的中文 key 归一化后成空串
>    却漏过判空，产出裸 ` = "..."`（changan）
> 3. `lpc_converter.py` `_parse_mapping_pairs()`——源码行尾 C 注释被当成下一个 mapping pair
>    且无 `:`，兜底成 `(comment, nil)`，渲染为 ` = rooms.nil.id`（room）
> 4. `lpc_converter.py` `_is_valid_exit_dir()`——方向名必须是裸标识符，非标识符一律跳过并留注释
> 另修正 checklist 数据错误：`changan` 中心房 `beian-daokou` → `beian_daokou`（`_norm_id` 把 `-` 归一为 `_`）。
>
> 2026-09-30 容器加载故障修复（`xiangyang`）：`Kantele.World.Kickoff` 因
> `elias ... syntax error before: ', ['","']` 反复崩溃重启。根因是 **elias 0.2.8 自身的 leex 分词缺陷**，
> 不是转换器写出了非法字符——`Word` 正则的排除集里没有逗号，`(: a, 'b' :)` 里的逗号被吞进 word 侥幸能过，
> 而 `(: ask_me_1, 'weibo' :)` 里数字打断了 word，逗号遂独立成 `comma` token，语法又缺 comma 产生式。
> 值内容不可改、也没有任何可解析写法，故转换器跳过该值并留注释。
> **权威验证**：容器内 `Elias.parse/1` 逐个解析 `data/world/*.ucl`，**48 个文件全部 OK，0 失败**。
> 静态侧 41 区 `validate_ucl` + `check_room_coords` 全 exit 0，fixture 回归 21/21。
> 遗留：`mix test test/kantele/world/` 183 tests / 2 failures（`loader_meta_test.exs` 的
> 「秘籍物品解析 book 五元组」与「liandan_lin1 宏继承」），已用 `git stash` 对照确认
> **在改动前就存在**（原版脚本同样 2 failures），与本轮工作无关。
