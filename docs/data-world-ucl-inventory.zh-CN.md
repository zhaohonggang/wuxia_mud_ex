# `data/world/*.ucl` 清单与 git 差异

> 生成时间：2026-09-30　生成方式：`git show HEAD:<path>` 逐文件比对 + `validate_ucl.py` / `check_room_coords.py` 实跑。
> 数据源：`.ucl_inventory.json`（脚本产出，可重跑刷新）。

本文件记录 `data/world/` 下每个 `.ucl` 的 **git 溯源**、**内容统计**、**跨区引用**与**当前校验结论**。`data/world_backup/` 不在此列。

## 1. 总览

| 指标 | 数值 |
|------|------|
| `.ucl` 文件总数 | **78** |
| 与 git HEAD 相同 | **78** |
| 与 git HEAD 不同 | 0 |
| 未被 git 跟踪 | 0 |
| 房间 `rooms` 块 | 4455 |
| 出口 `room_exits` 块 | 4439 |
| NPC `characters` 块 | 1855 |
| 物品 `items` 块 | 841 |
| 区内引用 `rooms.<r>.id` | 16066 |
| **跨区引用 `<zone>.rooms.<r>.id`** | **210** |
| 悬空跨区引用 | 2 |

## 2. 与 git 的差异

**当前工作区与 `HEAD` 完全一致：78 个文件全部 `identical`，无未提交改动。**

跨区接通、elias 兼容修复、坐标脚本候选方向等改动均已提交，最新提交见下表 `最近提交` 列。

## 3. 文件来源分族

| 族 | 数量 | 说明 |
|----|------|------|
| LPC 转换产物 | 72 | 有同名 `.comments.txt` 兄弟文件，由 `scripts/lpc_converter.py` 从 `C:\files\git\mud\d\<zone>` 生成 |
| 非 LPC 语料 | 6 | 无 `.comments.txt`，来自 Elixir 侧既有数据或测试夹具 |

### 非 LPC 语料文件（不在 mud 转换范围）

| 文件 | rooms | 最近提交 | 说明 |
|------|-------|----------|------|
| `global.ucl` | 27 | `dd9adc9` 2026-09-25 | 全局/公共数据 |
| `kissa-jarvi.ucl` | 11 | `84c77bd` 2026-08-22 | 其它示例世界 |
| `lepakko-luola.ucl` | 2 | `84c77bd` 2026-08-22 | 其它示例世界 |
| `liuxi.ucl` | 8 | `eae5c98` 2026-09-13 | Elixir 侧转换的柳溪镇（`minimal_world` 语料） |
| `sammatti.ucl` | 16 | `756b09c` 2026-08-23 | — |
| `signature.ucl` | 5 | `a4e6398` 2026-09-16 | — |

## 4. 逐文件清单（LPC 转换产物 72 个）

`校验` 列：`validate_ucl.py` 退出码；`坐标` 列：`check_room_coords.py` 退出码。

| zone | rooms | exits | npc | item | 区内引用 | 跨区引用 | 跨区目标 | 校验 | 坐标 | KB | 最近提交 |
|------|-------|-------|-----|------|----------|----------|----------|------|------|----|----------|
| `baituo` | 49 | 49 | 25 | 27 | 187 | 2 | city, xiyu | 0 | 0 | 52.0 | `1c97437` 2026-09-30 |
| `beijing` | 202 | 202 | 198 | 21 | 796 | 5 | guanwai, heimuya, hengshan, shaolin, xueshan | 0 | 0 | 257.1 | `1c97437` 2026-09-30 |
| `changan` | 143 | 143 | 126 | 0 | 512 | 6 | huanghe, lanzhou, luoyang, pk, quanzhen | 0 | 0 | 146.6 | `1c97437` 2026-09-30 |
| `chengdu` | 76 | 76 | 25 | 1 | 278 | 4 | emei, jingzhou, qingcheng, xuedao | 0 | 0 | 69.2 | `1c97437` 2026-09-30 |
| `city` | 111 | 111 | 138 | 17 | 421 | 13 | gaibang, guiyun, huanghe, jingzhou, luoyang, minimal_wo… | 0 | 0 | 153.6 | `1c97437` 2026-09-30 |
| `dali` | 213 | 213 | 101 | 7 | 785 | 8 | emei, foshan, kunming, tianlongsi, wanjiegu, wudu | 0 | 0 | 188.0 | `1c97437` 2026-09-30 |
| `death` | 76 | 76 | 63 | 102 | 270 | 0 | — | 0 | 0 | 147.5 | `1c97437` 2026-09-30 |
| `emei` | 102 | 102 | 8 | 19 | 372 | 4 | chengdu, dali, wudang | 0 | 0 | 77.6 | `1c97437` 2026-09-30 |
| `foshan` | 32 | 32 | 14 | 5 | 121 | 4 | dali, hengyang, quanzhou, xiakedao | 0 | 0 | 28.5 | `1c97437` 2026-09-30 |
| `fuzhou` | 61 | 61 | 25 | 2 | 215 | 3 | hengyang, quanzhou | 0 | 0 | 48.0 | `1c97437` 2026-09-30 |
| `gaibang` | 4 | 4 | 12 | 1 | 16 | 1 | city | 0 | 0 | 14.1 | `1c97437` 2026-09-30 |
| `gaochang` | 31 | 31 | 5 | 1 | 134 | 1 | shenfeng | 0 | 0 | 24.4 | `1c97437` 2026-09-30 |
| `guanwai` | 67 | 67 | 25 | 9 | 237 | 1 | beijing | 0 | 0 | 64.5 | `1c97437` 2026-09-30 |
| `guiyun` | 25 | 25 | 34 | 1 | 87 | 3 | city, suzhou, wudang | 0 | 0 | 47.8 | `1c97437` 2026-09-30 |
| `gumu` | 74 | 74 | 2 | 4 | 241 | 3 | city, quanzhen | 0 | 0 | 49.7 | `1c97437` 2026-09-30 |
| `hangzhou` | 120 | 120 | 66 | 9 | 420 | 2 | meizhuang, quanzhou | 0 | 0 | 134.9 | `1c97437` 2026-09-30 |
| `heimuya` | 80 | 80 | 28 | 3 | 309 | 6 | baituo, beijing, huanghe, village | 0 | 0 | 65.9 | `1c97437` 2026-09-30 |
| `hengshan` | 26 | 26 | 11 | 0 | 83 | 1 | beijing | 0 | 0 | 23.3 | `1c97437` 2026-09-30 |
| `hengyang` | 107 | 107 | 31 | 23 | 367 | 5 | foshan, fuzhou, motianya, wudang | 0 | 0 | 93.2 | `1c97437` 2026-09-30 |
| `huanggong` | 14 | 14 | 4 | 3 | 46 | 0 | — | 0 | 0 | 11.1 | `e4b48c2` 2026-09-30 |
| `huanghe` | 56 | 56 | 26 | 0 | 198 | 8 | changan, city, heimuya, lanzhou, lingzhou, taishan, vil… | 0 | 0 | 49.6 | `1c97437` 2026-09-30 |
| `huashan` | 89 | 89 | 15 | 5 | 310 | 3 | kaifeng, village | 0 | 0 | 71.2 | `1c97437` 2026-09-30 |
| `item` | 6 | 6 | 1 | 7 | 17 | 1 | suzhou | 0 | 0 | 6.7 | `1c97437` 2026-09-30 |
| `jingzhou` | 90 | 90 | 30 | 44 | 320 | 4 | chengdu, city, kunming, wudang | 0 | 0 | 81.0 | `1c97437` 2026-09-30 |
| `jinshe` | 4 | 4 | 0 | 5 | 9 | 1 | huashan | 0 | 0 | 4.9 | `1c97437` 2026-09-30 |
| `jueqing` | 57 | 57 | 7 | 0 | 183 | 1 | xiangyang | 0 | 0 | 33.9 | `1c97437` 2026-09-30 |
| `kaifeng` | 132 | 132 | 68 | 2 | 483 | 3 | huashan, songshan, zhongzhou | 0 | 0 | 116.5 | `1c97437` 2026-09-30 |
| `kunlun` | 51 | 51 | 6 | 19 | 189 | 1 | mingjiao | 0 | 0 | 40.9 | `1c97437` 2026-09-30 |
| `kunming` | 54 | 54 | 19 | 2 | 196 | 3 | dali, jingzhou | 0 | 0 | 41.8 | `1c97437` 2026-09-30 |
| `lanzhou` | 37 | 37 | 22 | 1 | 139 | 5 | changan, huanghe, shenfeng, xiyu | 0 | 0 | 37.3 | `1c97437` 2026-09-30 |
| `lingjiu` | 46 | 46 | 7 | 6 | 161 | 1 | xiyu | 0 | 0 | 32.0 | `1c97437` 2026-09-30 |
| `lingxiao` | 78 | 78 | 12 | 11 | 291 | 1 | xuedao | 0 | 0 | 75.4 | `1c97437` 2026-09-30 |
| `lingzhou` | 50 | 50 | 17 | 0 | 181 | 2 | huanghe, xuanminggu | 0 | 0 | 47.5 | `1c97437` 2026-09-30 |
| `luoyang` | 157 | 157 | 46 | 0 | 570 | 4 | changan, city, village, xiangyang | 0 | 0 | 132.7 | `1c97437` 2026-09-30 |
| `meizhuang` | 37 | 37 | 9 | 13 | 133 | 2 | hangzhou, quanzhou | 0 | 0 | 33.1 | `1c97437` 2026-09-30 |
| `mingjiao` | 129 | 129 | 36 | 39 | 477 | 3 | kunlun, lanzhou, xiyu | 0 | 0 | 127.9 | `1c97437` 2026-09-30 |
| `motianya` | 10 | 10 | 4 | 0 | 35 | 1 | hengyang | 0 | 0 | 11.3 | `1c97437` 2026-09-30 |
| `pk` | 14 | 14 | 1 | 0 | 59 | 1 | changan | 0 | 0 | 9.0 | `1c97437` 2026-09-30 |
| `qingcheng` | 23 | 23 | 10 | 0 | 72 | 1 | chengdu | 0 | 0 | 19.7 | `1c97437` 2026-09-30 |
| `quanzhen` | 109 | 109 | 52 | 3 | 414 | 4 | changan, city, gumu | 0 | 0 | 100.6 | `1c97437` 2026-09-30 |
| `quanzhou` | 36 | 36 | 16 | 2 | 135 | 6 | foshan, fuzhou, hangzhou, suzhou, taishan | 0 | 0 | 29.0 | `1c97437` 2026-09-30 |
| `register` | 7 | 7 | 7 | 0 | 25 | 4 | city | 0 | 0 | 6.6 | `1c97437` 2026-09-30 |
| `room` | 25 | 25 | 5 | 9 | 83 | 1 | shaolin | 0 | 0 | 18.0 | `1c97437` 2026-09-30 |
| `shaolin` | 206 | 206 | 27 | 58 | 837 | 5 | beijing, city, room, songshan | 0 | 0 | 196.2 | `1c97437` 2026-09-30 |
| `shenfeng` | 51 | 51 | 13 | 7 | 168 | 5 | gaochang, lanzhou, xiyu | 0 | 0 | 41.7 | `1c97437` 2026-09-30 |
| `shenlong` | 21 | 21 | 12 | 9 | 74 | 0 | — | 0 | 0 | 27.2 | `e4b48c2` 2026-09-30 |
| `sky` | 6 | 6 | 17 | 9 | 24 | 0 | — | 0 | 0 | 18.3 | `e4b48c2` 2026-09-30 |
| `songshan` | 28 | 28 | 16 | 0 | 95 | 3 | kaifeng, shaolin | 0 | 0 | 30.4 | `1c97437` 2026-09-30 |
| `special` | 6 | 6 | 0 | 0 | 16 | 0 | — | 0 | 0 | 3.8 | `e4b48c2` 2026-09-30 |
| `suzhou` | 72 | 72 | 24 | 1 | 266 | 6 | guiyun, item, quanzhou, yanziwu, zhongzhou | 0 | 0 | 59.3 | `1c97437` 2026-09-30 |
| `taishan` | 33 | 33 | 21 | 0 | 116 | 3 | city, huanghe, quanzhou | 0 | 0 | 38.5 | `1c97437` 2026-09-30 |
| `tangmen` | 0 | 0 | 0 | 2 | 0 | 0 | — | 0 | **1** | 0.7 | `e4b48c2` 2026-09-30 |
| `taohua` | 31 | 31 | 7 | 18 | 104 | 0 | — | 0 | 0 | 28.5 | `1c97437` 2026-09-30 |
| `test` | 34 | 34 | 13 | 42 | 165 | 0 | — | **1** | 0 | 55.6 | `00c51c0` 2026-09-28 |
| `tianlongsi` | 28 | 28 | 4 | 3 | 104 | 2 | dali, emei | 0 | 0 | 20.0 | `1c97437` 2026-09-30 |
| `tiezhang` | 66 | 66 | 13 | 18 | 210 | 0 | — | 0 | 0 | 56.5 | `1c97437` 2026-09-30 |
| `tulong` | 60 | 60 | 46 | 12 | 222 | 2 | beijing | 0 | 0 | 84.5 | `1c97437` 2026-09-30 |
| `village` | 30 | 30 | 21 | 1 | 106 | 4 | heimuya, huashan, luoyang | 0 | 0 | 30.1 | `1c97437` 2026-09-30 |
| `wanjiegu` | 29 | 29 | 40 | 4 | 92 | 1 | dali | 0 | 0 | 30.5 | `1c97437` 2026-09-30 |
| `wizard` | 9 | 9 | 0 | 0 | 27 | 1 | city | 0 | 0 | 6.3 | `1c97437` 2026-09-30 |
| `wudang` | 102 | 102 | 10 | 13 | 378 | 8 | city, emei, guiyun, hengyang, jingzhou, xiangyang, xiaoyao | 0 | 0 | 71.0 | `1c97437` 2026-09-30 |
| `wudu` | 108 | 108 | 28 | 29 | 407 | 3 | city, dali | 0 | 0 | 87.5 | `1c97437` 2026-09-30 |
| `wuguan` | 39 | 39 | 15 | 7 | 134 | 1 | xiangyang | 0 | 0 | 44.5 | `1c97437` 2026-09-30 |
| `xiakedao` | 99 | 99 | 25 | 20 | 322 | 2 | foshan, hengyang | 0 | 0 | 83.2 | `1c97437` 2026-09-30 |
| `xiangyang` | 119 | 119 | 33 | 2 | 423 | 6 | jueqing, luoyang, tiezhang, wudang, wuguan, zhongzhou | 0 | 0 | 102.5 | `1c97437` 2026-09-30 |
| `xiaoyao` | 22 | 22 | 4 | 4 | 85 | 1 | wudang | 0 | 0 | 15.0 | `1c97437` 2026-09-30 |
| `xiyu` | 51 | 51 | 17 | 22 | 196 | 6 | lanzhou, lingjiu, mingjiao, shenfeng, xueshan | 0 | 0 | 53.1 | `1c97437` 2026-09-30 |
| `xuanminggu` | 13 | 13 | 0 | 0 | 43 | 1 | lingzhou | 0 | 0 | 6.6 | `1c97437` 2026-09-30 |
| `xuedao` | 24 | 24 | 4 | 1 | 84 | 4 | chengdu, lingxiao, xueshan | 0 | 0 | 15.6 | `1c97437` 2026-09-30 |
| `xueshan` | 39 | 39 | 7 | 18 | 142 | 5 | beijing, city, xiyu, xuedao | 0 | 0 | 32.2 | `1c97437` 2026-09-30 |
| `yanziwu` | 46 | 46 | 17 | 4 | 168 | 1 | suzhou | 0 | 0 | 38.8 | `1c97437` 2026-09-30 |
| `zhongzhou` | 90 | 90 | 27 | 0 | 326 | 4 | city, kaifeng, suzhou, xiangyang | 0 | 0 | 68.5 | `1c97437` 2026-09-30 |

## 5. 校验结论

### 5.1 `validate_ucl.py` 非零（5 个）

| 文件 | 退出码 | 说明 |
|------|--------|------|
| `global.ucl` | 1 | 非 LPC 语料（无 `.comments.txt`），不在 `validate_ucl.py` 约定范围内 |
| `kissa-jarvi.ucl` | 1 | 非 LPC 语料（无 `.comments.txt`），不在 `validate_ucl.py` 约定范围内 |
| `lepakko-luola.ucl` | 1 | 非 LPC 语料（无 `.comments.txt`），不在 `validate_ucl.py` 约定范围内 |
| `liuxi.ucl` | 1 | 非 LPC 语料（无 `.comments.txt`），不在 `validate_ucl.py` 约定范围内 |
| `test.ucl` | 1 | **需排查** |

> 非 LPC 语料不由 `scripts/lpc_converter.py` 生成（没有同名 `.comments.txt`），其校验失败与 LPC 转换流程无关。`data/world/test.ucl` 是转换器靶场，`test/fixtures/validate_ucl/expected.json` 已把它固化为「预期失败」，并非回归。

### 5.2 `check_room_coords.py` 非零（5 个）

| 文件 | 退出码 | 说明 |
|------|--------|------|
| `global.ucl` | 1 | 非 LPC 语料，不在坐标脚本约定范围内 |
| `kissa-jarvi.ucl` | 1 | 非 LPC 语料，不在坐标脚本约定范围内 |
| `lepakko-luola.ucl` | 1 | 非 LPC 语料，不在坐标脚本约定范围内 |
| `liuxi.ucl` | 1 | 非 LPC 语料，不在坐标脚本约定范围内 |
| `tangmen.ucl` | 1 | **预期**：纯物件区，0 房间，由 `validate_ucl.py` 的 `_is_object_only_zone()` 豁免，赋坐标步骤按设计跳过 |

## 6. 跨区引用明细

跨区出口在 UCL 里写成 `<zone>.rooms.<room>.id`。`Kantele.World.Loader.dereference/3`（`lib/kantele/world/loader.ex:1315-1343`）把参考的第一段当作 zone id 查找，因此这个形式可被加载器直接解析。

- 全库跨区引用总数：**210**
- 其中悬空：**0**（2026-10-01，原 2 条均已解决）

### 悬空跨区引用

- 悬空数已归零（2026-10-01，见 checklist E 项）。原表两条均已解决：

| 来源文件 | 原目标 | 原原因 | 现状 |
|----------|--------|--------|------|
| `baituo.ucl` | `xiyu/shamo10` | 记为「LPC 源本身悬空」 | 误判。`gebi` 出口写在宏里，宏继承修复后已恢复为 `east = xiyu.rooms.shamo10.id` |
| `city.ucl` | `minimal_world/guangchang` | 目标区未转换（测试区） | 已按出口方向名反查已安装 zone，接通 `liuxi.rooms.guangchang.id` |

### 按区域

| zone | 跨区出口数 | 指向 |
|------|-----------|------|
| `city` | 13 | gaibang, guiyun, huanghe, jingzhou, luoyang, liuxi, shaolin, taishan, wizard, wudang, xuedao, xueshan, zhongzhou |
| `dali` | 8 | emei, foshan, kunming, tianlongsi, wanjiegu, wudu |
| `huanghe` | 8 | changan, city, heimuya, lanzhou, lingzhou, taishan, village |
| `wudang` | 8 | city, emei, guiyun, hengyang, jingzhou, xiangyang, xiaoyao |
| `changan` | 6 | huanghe, lanzhou, luoyang, pk, quanzhen |
| `heimuya` | 6 | baituo, beijing, huanghe, village |
| `quanzhou` | 6 | foshan, fuzhou, hangzhou, suzhou, taishan |
| `suzhou` | 6 | guiyun, item, quanzhou, yanziwu, zhongzhou |
| `xiangyang` | 6 | jueqing, luoyang, tiezhang, wudang, wuguan, zhongzhou |
| `xiyu` | 6 | lanzhou, lingjiu, mingjiao, shenfeng, xueshan |
| `beijing` | 5 | guanwai, heimuya, hengshan, shaolin, xueshan |
| `hengyang` | 5 | foshan, fuzhou, motianya, wudang |
| `lanzhou` | 5 | changan, huanghe, shenfeng, xiyu |
| `shaolin` | 5 | beijing, city, room, songshan |
| `shenfeng` | 5 | gaochang, lanzhou, xiyu |
| `xueshan` | 5 | beijing, city, xiyu, xuedao |
| `chengdu` | 4 | emei, jingzhou, qingcheng, xuedao |
| `emei` | 4 | chengdu, dali, wudang |
| `foshan` | 4 | dali, hengyang, quanzhou, xiakedao |
| `jingzhou` | 4 | chengdu, city, kunming, wudang |
| `luoyang` | 4 | changan, city, village, xiangyang |
| `quanzhen` | 4 | changan, city, gumu |
| `register` | 4 | city |
| `village` | 4 | heimuya, huashan, luoyang |
| `xuedao` | 4 | chengdu, lingxiao, xueshan |
| `zhongzhou` | 4 | city, kaifeng, suzhou, xiangyang |
| `fuzhou` | 3 | hengyang, quanzhou |
| `guiyun` | 3 | city, suzhou, wudang |
| `gumu` | 3 | city, quanzhen |
| `huashan` | 3 | kaifeng, village |
| `kaifeng` | 3 | huashan, songshan, zhongzhou |
| `kunming` | 3 | dali, jingzhou |
| `mingjiao` | 3 | kunlun, lanzhou, xiyu |
| `songshan` | 3 | kaifeng, shaolin |
| `taishan` | 3 | city, huanghe, quanzhou |
| `wudu` | 3 | city, dali |
| `baituo` | 2 | city, xiyu |
| `hangzhou` | 2 | meizhuang, quanzhou |
| `lingzhou` | 2 | huanghe, xuanminggu |
| `meizhuang` | 2 | hangzhou, quanzhou |
| `tianlongsi` | 2 | dali, emei |
| `tulong` | 2 | beijing |
| `xiakedao` | 2 | foshan, hengyang |
| `gaibang` | 1 | city |
| `gaochang` | 1 | shenfeng |
| `guanwai` | 1 | beijing |
| `hengshan` | 1 | beijing |
| `item` | 1 | suzhou |
| `jinshe` | 1 | huashan |
| `jueqing` | 1 | xiangyang |
| `kissa-jarvi` | 1 | sammatti |
| `kunlun` | 1 | mingjiao |
| `lingjiu` | 1 | xiyu |
| `lingxiao` | 1 | xuedao |
| `liuxi` | 1 | signature |
| `motianya` | 1 | hengyang |
| `pk` | 1 | changan |
| `qingcheng` | 1 | chengdu |
| `room` | 1 | shaolin |
| `signature` | 1 | liuxi |
| `wanjiegu` | 1 | dali |
| `wizard` | 1 | city |
| `wuguan` | 1 | xiangyang |
| `xiaoyao` | 1 | wudang |
| `xuanminggu` | 1 | lingzhou |
| `yanziwu` | 1 | suzhou |

## 7. 备注

- **`.comments.txt` 缺失即非 LPC 语料**：转换器每次都会写 `<zone>.comments.txt`，因此该文件的有无是判断「是否由 `scripts/lpc_converter.py` 生成」的可靠依据。
- **`rooms` ≠ `room_exits` 表示存在无出口的孤儿房**：赋坐标前的正常中间态；转换完成的产物两者应相等。`special`（六道轮回 6 间房）例外，其 LPC 源码完全没有 `set("exits")`。
- **重新生成方式**：见 `docs/zone-conversion-sop.zh-CN.md`。重跑任何区都会整体覆盖 `data/world/<zone>.ucl` 并丢弃已赋坐标，务必按 SOP 顺序执行。
- **刷新本文件**：重跑生成脚本后重新采集 `.ucl_inventory.json` 并重新渲染本文。

