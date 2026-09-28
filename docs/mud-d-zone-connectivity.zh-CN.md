# LPC 世界跨区域连接与区域中心分析

> 分析时间：2026-09-28
> 源路径：`C:\files\git\mud\d\`（7140 个 `.c`，74 个顶级目录）
> 目的：回答三个问题——① 区域间如何连接；② 是否一个目录即一个区域；③ 每个区域的中心 room 在哪里
> 关联文档：`docs/mud-d-directory-analysis.zh-CN.md`（区域规模/可迁移性）；`docs/lpc-converter-usage.zh-CN.md`（LPC→UCL 转换器）

---

## 一、结论速览

1. **跨区连接 = 绝对路径 + 城门模型**：`__DIR__` 负责区内 96.6% 连接，跨区 100% 靠 `"/d/zone/file"` 绝对路径（共 305 条，占 3.4%）。无任何双向校验，单向出口是常态。
2. **一个目录≈一个区域，但不严格**：区域根放房间、`npc/`＝NPC、`obj/`＝物品的骨架 69/73 遵守；但存在 `d/sky`⊂`d/death/sky`、六道轮回双份、`d/tulong` 纯容器、`d/minimal_world_v2` 房间下沉等至少 6 组例外。
3. **世界中枢 = 扬州中央广场 `d/city/guangchang`**（度数 21、9 条外部入边），系统区全部挂在**扬州武庙 `d/city/wumiao`** 与少林大驿道两个锚点上。
4. **中心 room**：大型城市以中央广场/主干道为心，门派区域以大殿/广场为心，详见 §五。

---

## 二、目录/区域划分规则

### 2.1 权威规则（仅一句话共识）

- `docs/build/README.md:78-80`：「每个地区下面又包括这个地域的特定 NPC（`/d/city/npc`）和对象（`/d/city/obj`）」。
- `docs/design/game_content_map.md:13-24`：房间直接放区域根，`npc/`(65 区)、`obj/`(54 区)；区域分城市 / 门派驻地 / 特色区三类。
- `d/minimal_world/README.md:95`：`__DIR__"xxx"` **仅限向下**（房间在根、npc/obj 为子目录）；跨目录用绝对路径；驱动禁止含 `../` 的加载路径。
- `d/` 内**无 README、无 CI 校验、无机器可读 schema**。

### 2.2 实际结构（73 个区域统计）

| 子目录 | 出现区域数 | 语义 |
|---|---|---|
| `npc/` | 67/73 | 区域专属 NPC |
| `obj/` | 56/73 | 区域专属物品 |
| 区域根直接放 `.c` | 69/73 | 房间层（39 个区域根 100% 是 `inherit ROOM`） |

命名模式：小写拼音/英文；同名房用数字后缀（`hantan1~8`、`bagua0~7`）；成组房用共同前缀（`aofu_`、`caolian`、`qiyuan`）；罕见的连字符（`d/shaolin/npc/da-shou.c`）。

### 2.3 "一个目录≠一个区域"的 6 组例外

| 编号 | 类型 | 证据 |
|---|---|---|
| A | **逻辑区域分裂**：天界 = `d/sky`(32) ∪ `d/death/sky`(42)，18 个同名文件字节相同，各自被活代码引用 | `d/death/npc/dizangwang.c:211` 送 `/d/death/sky/tianmen`；`d/beijing/...`、`u/mudren/workroom.c:21` 用 `/d/sky/tianmen`；区内自链各自封闭（`d/sky/sky1.c:59` vs `d/death/sky/sky1.c:59`） |
| B | **六道轮回双份**：`d/special/liudaolunhui`(6) == `d/death/liudaolunhui`(7)，6 文件字节全同，`wujiandao.c` 无间道仅 death 版有 | `kungfu/skill/lunhui-jian/hui.c` 用 `/d/special/...`；`dizangwang.c:262-268` 用 `/d/death/...` |
| C | **倚天屠龙跨 `d/`/`b/` 边界**：逻辑区 = `b/{yitian,tulong,yubifeng}` ↔ `d/tulong/{yitian,tulong,yubifeng}`，双向交叉引用 | `d/beijing/road10.c:13` → `/b/tulong/haigang`；`b/yitian/npc/18jingang-4zhang.c:58` → `/d/tulong/yitian/npc/obj/tiezhang`；`adm/daemons/story/bizhen.c:100` → `/d/tulong/tulong/obj/xuantie-ling`（仅 d 侧存在） |
| D | **区域内子区域下沉**（5 处）：`city/qiyuan`、`hangzhou/honghua`(21)、`death/sky`、`room/{panlong,caihong,dule}`、`tulong/{tulong,yitian,yubifeng}` | 子区域出口回父区域用绝对路径（向上）：`d/city/qiyuan/qiyuan1.c:29` → `/d/city/liaotian` |
| E | **`d/room` 名义独立实为少林附属**：`d/room/xiaoyuan.c:21` ↔ `d/shaolin/yidao2.c:17` 互指；`d/room/qianting.c` 与 `d/room/panlong/qianting.c` **MD5 相同**的孤儿副本；`roomnpc/` 5 个 NPC 全为死代码 | `adm/npc/luban.c:108,142` 只登记 `/d/room/panlong/qianting.c` |
| F | **`d/minimal_world_v2` 伪装成区域的工具靶场**：27 房间放 `room/` 子目录（违反约定），含 `*_test.c`、`.vs/` VS 工程产物、`adm/daemons/rankd.c` 守护进程；`d/minimal_world`(10 房在根) 才是真 v2 前身 | 与 `d/minimal_world` 仅 `kedian.c/kedian2.c` 同名且内容不同 |

另含**名不副实**目录：`d/death/HellZhen/`（18 个文件全是 `inherit NPC` 恶鬼，由 `d/death/npc/yanluo.c:724-1130` new 生成）、`d/hengyang/yueqi/`（20 个 `inherit ITEM` 乐器）、`d/tangmen`（仅 obj 无房间）、`d/tulong`/`d/special`（纯容器根无 `.c`）。

---

## 三、跨区域连接机制（7 种）

### 3.1 路径写法规范（9076 条出口统计）

| 写法 | 用途 | 数量 |
|---|---|---|
| `__DIR__"relative"` | 区内相对路径 | 8769（96.6%） |
| `"/d/zone/file"` 绝对路径 | **跨区唯一机制** | 305（3.4%） |
| 裸相对名（不含前导 `/`） | 遗留/错误 | 2 |

引擎解析：`cmds/std/go.c:176-215`，`exits[dir]` 可为字符串（→`load_object`）、object、或 mapping（坐标型 area 世界）。**不做双向校验**。

### 3.2 七种机制

| 机制 | 说明 | 典型例 |
|---|---|---|
| **城门/关口** | 每城四门是"区界"，24 个城门房承担跨区 | `d/city/beimen.c`：`north:/d/shaolin/yidao`、`west:/d/huanghe/caodi1`；`dongmen`→泰山、`nanmen`→武当、`ximen`→中州 |
| **大驿道/官道网** | 17 段跨区主干，分布于 beijing(road1-9)、shaolin(yidao1-3)、taishan(yidao1-3) | `d/shaolin/yidao`→`/d/city/beimen`★；`d/taishan/yidao1`→泉州 |
| **山口/关隘** | 相邻三区各建同名关口跳链 | `foshan/nanling ↔ hengyang/hsroad9 ↔ xiakedao/xkroad1`（南岭山口） |
| **密道/密室** | 27 密道 + 16 密室汇入扬州，解释 guangchang 9 入边 | `gumu/mishi8`、`quanzhen/mishi`、`gaibang/inhole` → `out:/d/city/guangchang` |
| **系统区域挂载** | `d/room`(少林大驿道东)、`d/wizard`(武庙下)、`d/register`(四向→guangchang)、`d/item`(苏州 road5 东)、`d/pk`(长安永泰大道)、`/clone/shop`(15 城 majiu 上)、`/b`(北京 road10 东) | 武庙 `d/city/wumiao` 是生死枢纽：`d/death/god1 --down--> wumiao`、`wizard/hall --north--> /u/` |
| **自定义方向名** | 仅 3 处，`go` 驱动无方向名白名单 | `d/city/guangchang.c` `"liuxi":/d/minimal_world/guangchang`；反向 `"yangzhou"` |
| **动态出口** | 177 处 `set/delete("exits/<dir>")`，2 处跨区，多为剧情秘道 | `heimuya/up2~4`、`xiakedao/midao4/8`、`gumu/mumen`、`lingxiao/gate`、`meizhuang/gate` |

---

## 四、区域间连接图

### 4.1 枢纽辐射图

```
                   ┌── 扬州城 d/city（中央广场，度数21，唯一中心枢纽）──┐
   register×4  gaibang  gumu  quanzhen  xueshan  minimal_world  ...│
                   └──────────────┬──────────────────────┬────────┘
                     shaolin ── wudang ── taishan ── huanghe ── lanzhou/changan
                        │          │  │                 │
                     songshan  xiangyang  guiyun    village
                        │       │     │  zhongzhou──kaifeng
                     kaifeng  hengyang  xueshan/xuedao   suzhou
                                   |           item  yanziwu
                        foshan/xiakedao   hangzhou──quanzhou
                           motianya          meizhuang
```

### 4.2 连接度排行榜（区域 → 相邻区域数）

| 度数 | 区域 | 相邻区域 |
|---|---|---|
| **21** | **city（扬州）** | baituo, clone, death, gaibang, guiyun, gumu, huanghe, jingzhou, luoyang, minimal_world, minimal_world_v2, quanzhen, register, shaolin, taishan, wizard, wudu, xuedao, xueshan, zhongzhou |
| 8 | beijing | clone, guanwai, heimuya, hengshan, shaolin, tulong, xueshan, yitian(/b) |
| 7 | dali / wudang / xiangyang | 见 §4.3 |
| 6 | changan / hengyang / huanghe / quanzhou / suzhou / xiyu | — |
| 5 | chengdu / foshan / jingzhou / lanzhou / luoyang / zhongzhou | — |
| 4 | emei / heimuya / kaifeng / shaolin / village / xuedao / xueshan | — |
| 3 | baituo / fuzhou / guiyun / hangzhou / huashan / mingjiao / quanzhen / shenfeng / taishan | — |
| 2 | gumu / kunming / meizhuang / songshan / tianlongsi / wizard / wudu / xiakedao | — |
| 1 | death / gaibang / gaochang / guanwai / hengshan / item / jinshe / jueqing / kunlun / lingjiu / lingxiao / lingzhou / minimal_world / minimal_world_v2 / motianya / pk / qingcheng / register / room / tiezhang / tulong / wanjiegu / wuguan / xiaoyao / xuanminggu / yanziwu | — |
| **0** | **huanggong / shenlong / sky / special / tangmen / taohua** | 完全孤立（仅区内出口） |

### 4.3 高频门户房间（被 ≥2 个不同区域引用）

| 引用数 | 房间 | 名称 | 被引用方 |
|---|---|---|---|
| **9** | `/d/city/guangchang` | **扬州中央广场（世界第一枢纽）** | register, gaibang, gumu, quanzhen, xueshan, minimal_world, minimal_world_v2, … |
| 3 | `/d/songshan/taishique` | 太室阙 | shaolin, kaifeng |
| 2（×16） | `/d/huashan/path1`、`/d/hengyang/hsroad9`、`/d/village/wexit`、`/d/city/{beimen,wumiao,ximenroad}`、`/d/beijing/road10`、`/d/shaolin/ruzhou`、`/d/emei/qsjie2`、`/d/dali/road1`、`/d/xiyu/nanjiang2`、`/d/yanziwu/hupan`、`/d/suzhou/road5`、`/d/wudang/{wdroad4,wdroad5}`、`/d/xuedao/sroad1`、`/d/shenfeng/caoyuan5` | 关口/驿道/城门 | — |

### 4.4 跨区连接中的异常

- **路径 bug（唯一裸相对出口，导致单向死路）**：`d/tiezhang/hunanroad1.c:14` 写着 `"east" : "d/xiangyang/caodi6"`（缺前导 `/`），`load_object` 解析失败。
- **34 个单向区域对**（引擎无校验）：heimuya→baituo、huanghe→village、xiakedao→hengyang、xiangyang→tiezhang、mingjiao→lanzhou 等。
- **多通道区界**：`shenfeng/caoyuan5` 与 `xiyu/nanjiang2` 互为双向三通道（南/西南/西）。
- **6 孤立区**：`taohua` 用 `__FILE__`/`file_name(env)` 造"桃花迷宫"自指出口（独立玩法）；`sky`、`shenlong`、`huanggong`、`special`、`tangmen` 不接入大地图。

---

## 五、区域中心 room 分析

> 界定方法：中心 room = 区域内**承担汇聚/发散功能**的房间——大型城市取中央广场、主干道交叉、或最大门面房；门派取大殿/广场；识别依据为区内被 `__DIR__` 引用次数最多、且带跨区出口的门户房。

### 5.1 大型城市

| 区域 | 中心 room | 依据 |
|---|---|---|
| city（扬州） | **`guangchang` 中央广场** | 世界中枢；9 条外部入边；register 四向全部汇入 |
| beijing（北京） | **`road1~9` 大驿道网 + `majiu`** | 驿道贯穿城市、连 guanwai/雪山/衡山；majiu(TRANS_ROOM) 传送 |
| luoyang（洛阳） | `road1`/`ganluo` 一带主干道 | 交通枢纽，~30 条跨区出口、经 `ximenroad` 连 city |
| changan（长安） | **`da-duomen` 大门/`yongtai-dadao`** | 永泰大道连 pk、青石大道连兰州，`gongmen`/城门体系 |
| kaifeng（开封） | `neixiang`/中心大街 | 连 zhongzhou(官道)、songshan(大驿道)、huashan |
| hangzhou（杭州） | 西湖/`shizhongxin` 中心 | 连 quanzhou、meizhuang(孤山)；sub 区 `honghua` |
| xiangyang（襄阳） | **`guangchang`/`caodi*` 城防带** | 城防主线连 wudang/zhongzhou/luoyang；郭府 `wuguan` |

### 5.2 门派区域

| 区域 | 中心 room | 依据 |
|---|---|---|
| shaolin | **`dadian` 大雄宝殿（及山门 `shandao*/yidao`）** | 少林主轴：山门→大殿；`yidao` 大驿道连 city/room |
| wudang | **`guangchang` 真武广场** | 主轴广场；`wdroad1/4/5` 青石大道负责全部跨区 |
| quanzhen | **`sanqingdian`/`guangchang`** | 道观主轴；大校场/山脚出密道连 gumu、city |
| emei | `bgs`/`hca` 寺院群山门 | 青石大道(`qsjie2`)连 dali/tianlongsi/chengdu/wudang |
| huashan | `shanmen` 山门 + `path1` | `path1`(华山脚下) 被 village/kaifeng 双引用；守卫 NPC 控入口 |
| mingjiao | **`dadian`/`guangchangdian`** + `didao` 迷宫中枢 | 地下迷宫导航枢纽；连 kunlun/lanzhou/xiyu |
| heimuya | `qibao` 教坛/`dadian` | 连 beijing(黄土路)、huanghe、village |
| gaibang | **`undertre` 大树下** | goto 传送枢纽：16 城市（fuzhou/xiangyang/…/lanzhou） |
| gumu | **`mishi8`（林朝英居室）** | `out` 直通 city/guangchang；`mumen` 墓门开合 |
| taohua | `zongqu` 总盟（桃花迷宫核心） | 无外部连接，自成自指迷宫 |
| songshan | `taishique` 太室阙 | 被 shaolin/kaifeng 双方引用（3 引用） |

### 5.3 地理/野外区域

| 区域 | 中心 room | 依据 |
|---|---|---|
| huanghe | `caodi1`（连 city beimen） | 沙漠传送枢纽；连 changan/lanzhou/taishan/village/heimuya |
| xiyu | `sikulu`（丝绸之路集散） | 连 baituo/lanzhou(西门)/lingjiu/mingjiao/xueshan |
| shenfeng | `caoyuan5`（戈壁三重通口） | 与 xiyu/nanjiang2 双向三通道；连 gaochang/lanzhou |
| xueshan | `bieyuan`（雪山别院） | 被 beijing road5 引用；连 city(密室)/xiyu/xuedao |
| village | **`wexit`（西村口）+ 十字路口网** | `wexit` 被 heimuya/huanghe 双引用；`eroad/hsroad/nwroad` 放射 |
| dali | `biluoshan`/`baiyiziguan` 北段官道 | `road1`(官道) 被 emei/kunming 双引用；连 wanjiegu/金山 road5 |

### 5.4 系统区挂载（非地理中心，是"锚点"）

| 系统区 | 锚点房间 |
|---|---|
| `d/room`（鲁班建房） | `d/shaolin/yidao2` --east--> `/d/room/xiaoyuan` |
| `d/wizard` + `d/death` | `d/city/wumiao`（武庙）：death/god1 --down--> wumiao；wizard/hall --north--> /u |
| `d/register`（新手村） | 4 个 room{n,s,e,w}.c --out--> `/d/city/guangchang` |
| `/clone/shop`（15 城店铺） | 各城 `majiu`(马厩) --up--> `/clone/shop/<city>_shop` |
| `d/pk`（屠人场） | `d/changan/yongtai-dadao2` --east--> `/d/pk/entry` |
| `/b`（同人岛链） | `d/beijing/{road10,huiying}` --east/up--> `/b*/...` |

---

## 六、方法论与建议

### 6.1 本次分析方法（可复用）

1. **路径三分法**：统计 `__DIR__` 相对（区内） vs `"/d/..."` 绝对（跨区） vs 裸路径（bug）。
2. **出口引用倒查**：对每个区域统计"被哪些外部区域引用 + 引用了哪些外部区域 + 各自入口房间"→ 得到连接图与门户房。
3. **中心定义启发式**：区内 `__DIR__` 入度最高 + 带跨区出口 + 位于主轴可视化，三者并取。
4. **MD5 去重**：识别重复文件（天界 18/32、六道轮回 6/6、qianting 1/1 字节相同）。

### 6.2 迁移到 Kantele 的启示

- **世界图可直接数据化**：305 条跨区绝对路径 → UCL `room_exits`（已支持绝对引用，见 `data/world/test.ucl`）；门户房信息可作为"大世界挂载点"清单。
- **区域划分校验**：转换器 `zone_id` 推断（目录名）对 69/73 区域成立；例外区（tulong/special/room/minimal_world_v2/death-sky）需手工指定 zone 归属，避免同 zone 多源覆盖（见 `docs/lpc-converter-usage.zh-CN.md` §五警告）。
- **单向出口是常态**：迁移时**不要**自动补反向出口，保留 LPC 原样（引擎本就允许）。
- **`d/room` 孤儿 `qianting.c`、`roomnpc/` 死代码**、`tiezhang/hunanroad1.c` 缺 `/` 的 bug：迁移时可直接忽略或单独修复。
- **六个孤立区**（taohua/sky/shenlong/huanggong/special/tangmen）可二期再处理。

---

## 七、附：数据统计口径

| 指标 | 数值 |
|---|---|
| 顶级区域目录 | 73（探索粒度）/ 74（含口径差异） |
| `.c` 文件总数（递归） | 7140 |
| 出口总数（分析口径） | 9076 |
| 跨区绝对路径出口 | 305（3.4%） |
| 有向区域对 | 196（162 双向 + 34 单向） |
| 涉及房间 | 209 |
| 被 ≥2 区域引用的门户房 | 19 |
| 密道房间 / 密室 | 27 / 16 |
| 城门房间 | 24 |
| 大驿道房间 | 17 |
| 动态出口写入 | 177 处（78 文件） |
| 完全孤立区域 | 6 |

*本文档基于 `C:\files\git\mud\d\` 静态文本分析；中文编码实为 UTF-8。*