# LPC 世界区域速查表：中心房间与跨区连接

> 数据来源：`C:\files\git\mud\d\`（73 个区域，7140 个 `.c`），对全部 `set("exits", ...)` 块做静态解析。
> 关联文档：`docs/mud-d-zone-connectivity.zh-CN.md`（机制与统计）；`docs/mud-d-directory-analysis.zh-CN.md`（规模与可迁移性）。

## 排序方法

1. **拓扑分层**：以 `city`（扬州）为起点做无向 BFS 最短距离分层，层 0 = city 本身。
2. 每层内部按**区域名称字母序**；跨层按 BFS 距离由近到远。
3. 无法从 city 到达（eg:crada 孤立区）作为最后一层「不可达区」按名称排序。
4. **中心 room 选取依据**：优先取「区内被 `set("exits")` 引用次数最高」的房间；同入度时取语义中心（广场/大殿/大厅/城门/渡口等地标）。
5. 连接行格式：`本区房间 --(方向)--> 目标区域/目标房间`（方向为本区视角的出口方向）。

---

## 层 0 · 世界中枢

### `city`（扬州）｜中心：`guangchang`（中央广场）

**中心依据**：区内入度第 2（5 次，仅次于东门 9），但承担 9 条外部入边，是全世界的汇聚点；register 四向全部汇入。

| 本区房间 | 方向 | 目标 |
|---|---|---|
| `guangchang` | in | `gaibang/inhole`（丐帮 · 树洞内部） |
| `guangchang` | liuxi | 接入ex里的柳溪镇 （不做`minimal_world/guangchang`（柳溪镇 · 镇广场）） |
| （不做 `guangchang` | — | `minimal_world_v2/guangchang`（测试世界）） |
| `beimen` | north | `shaolin/yidao`（少林 · 大驿道） |
| `beimen` | west | `huanghe/caodi1`（黄河 · 草地） |
| `dongmen` | east | `taishan/yidao`（泰山 · 大驿道） |
| `nanmen` | south | `wudang/wdroad1`（武当 · 青石大道） |
| `ximen` | south | `zhongzhou/yangzhoudu`（中州 · 扬州渡） |
| `ximenroad` | southwest | `jingzhou/road1`（荆州 · 官道） |
| `ximenroad` | west | `luoyang/road8`（洛阳 · 关洛道） |
| `wumiao` | down | `wizard/herodoor`（巫师区 · 英雄之门）／`death/god1`、`death/god2`（地府） |
| `xdmidao1` | up | `xuedao/sroad8`（雪道 · 山路） |
| `xsmidao5` | south | `xueshan/mishi`（雪山 · 密室） |
| `majiu` | up | `clone/shop/yangzhou_shop`（扬州商铺 · 系统商区） |

---

## 层 1 · 直连扬州（距离 1）

### `baituo`（白驼山）｜中心：`guangchang`

**依据**：区内入度 4（并列第 2），白驼山庄主广场。

- `midao --east--> city/beidajie1`（扬州 · 密道）
- `gebi --east--> xiyu/shamo10`（西域 · 沙漠）
- `bridge --east/northwest--> heimuya/xijie、heimuya/guangchang`(见层2反向)

### `death`（地府）｜中心：`yanluodian`（阎罗殿）

**依据**：区内入度 4，北斗主殿，hantan 群房环伺。

- `god1 --down--> city/wumiao`（扬州 · 武庙，生死枢纽）
- `god2 --down--> city/wumiao`
- `yanluodian` 经地府内部传送链接 `death/liudaolunhui/*`（六道轮回）

### `gaibang`（丐帮）｜中心：`undertre`（大树下）

**依据**：区内入度 3，goto 传送枢纽（`b→goto` 直达 16 城市）。

- `inhole --out--> city/guangchang`（扬州 · 中央广场树洞）

### `guiyun`（归云庄）｜中心：`dating`（大厅）

**依据**：区内入度 3（并列第 3），庄院主厅。

- `shulin1 --northwest--> city/jiaowai4`（扬州 · 郊外密林）
- `yixing --northwest--> wudang/wdroad2`（武当 · 青石大道·宜兴）
- `shanlu2 --southeast--> suzhou/road1`（苏州 · 官道）

### `gumu`（古墓）｜中心：`daxiaochang`（重阳宫大门·大校场）

**依据**：区内入度 3（并列），古墓入口气氛主房。密道 mumen 控制开关。

- `mishi8 --out--> city/guangchang`（扬州 · 林朝英居室密道）
- `daxiaochang --northup--> quanzhen/shijie1`（全真 · 试剑石）
- `shanlu13 --south--> quanzhen/shanjiao`（全真 · 山脚）

### `huanghe`（黄河）｜中心：`guangchang`

**依据**：区内入度 4，黄河北岸渡口广场。

- `caodi1 --east--> city/beimen`（扬州 · 北门）
- `yongdeng --southup--> changan/tulu4`（长安 · 土路）
- `xiaojiaqiao --south--> lanzhou/river-bei`（兰州 · 河北）
- `huanghe5 --east--> taishan/daizong`（泰山 · 岱宗坊）
- `liupanshan --eastdown--> village/wexit`（村庄 · 西村口·六盘山）
- `dukou2 --southwest--> heimuya/huanghe_1`；`weifen --southwest--> heimuya/road5`

### `jingzhou`（荆州）｜中心：`guangchang`

**依据**：区内入度 4，荆州主广场。

- `road1 --northeast--> city/ximenroad`（扬州 · 西门大道）
- `jzximen --west--> chengdu/shudao1`（成都 · 蜀道）
- `nanshilu1 --south--> kunming/road1`（昆明 · 碎石路）
- `jzbeimen --northup--> wudang/wdroad5`（武当 · 青石大道·荆州北门）
- `majiu --up--> clone/shop/jingzhou_shop`

### `luoyang`（洛阳）｜中心：`center`

**依据**：区内入度 4，交通枢纽；~30 条跨区出口。

- `road8 --east--> city/ximenroad`（扬州 · 西关大道）
- `guandaow4 --west--> changan/road2`（长安 · 大官道）
- `guandaon4 --north--> village/hsroad1`（村庄 · 横山道）
- `guandaos6 --south--> xiangyang/caodi3`（襄阳 · 草地）
- `majiu --up--> clone/shop/luoyang_shop`

### `minimal_world`（柳溪镇，转换器靶场）｜中心：`guangchang`

**依据**：区内入度 4，柳溪镇中心。

- `guangchang --yangzhou--> city/guangchang`（扬州 · 青石小路）

### `minimal_world_v2`（测试世界）｜中心：`test_guangchang`

**依据**：连接 city 的入口房；房间在 `room/` 子目录（违反区域根约定）。

- `test_guangchang --yangzhou--> city/guangchang`（扬州）

### `quanzhen`（全真）｜中心：`datang1`（重阳宫大堂）

**依据**：区内入度 4（datang2 亦 4），重阳宫主轴大殿。密道 mishi 通扬州。

- `mishi --eastup--> city/guangchang`（扬州 · 全真密室密道）
- `guandao1 --northeast--> changan/nan-chengmen`（长安 · 南城门·官道）
- `shanjiao --north--> gumu/shanlu13`（古墓 · 山脚）
- `shijie1 --southdown--> gumu/daxiaochang`（古墓 · 大校场试剑石）

### `register`（世外桃源·注册区）｜中心：`entry`

**依据**：区内入度 4，注册区总入口。

- `roome/roomn/rooms/roomw --out--> city/guangchang`（扬州 · 中央广场，四向全部汇入）

### `shaolin`（少林）｜中心：`guangchang2`（少林寺·演武场）

**依据**：区内入度 5（并列第 1），木人巷/演武场群；山门 sfficient 主轴。跨区入口为 `yidao`（大驿道）与 `ruzhou`（汝州）。

- `yidao --south--> city/beimen`（扬州 · 北门·大驿道）
- `yidao2 --east--> room/xiaoyuan`（鲁班民居 · 小院）
- `ruzhou --north--> beijing/road10`（北京 · 大驿道·小道）
- `ruzhou --west--> songshan/taishique`（嵩山 · 太室阙）
- `shijie1 --east--> songshan/taishique`（嵩山 · 太室阙）
- `majiu --up--> clone/shop/…`

### `taishan`（泰山）｜中心：`nantian`（南天门）

**依据**：区内入度 4，登山主干终点。

- `yidao --west--> city/dongmen`（扬州 · 东门·大驿道）
- `yidao1 --southeast--> quanzhou/qzroad1`（泉州 · 大驿道）
- `daizong --west--> huanghe/huanghe5`（黄河 · 岱宗坊）

### `wizard`（巫师区）｜中心：`hall`

**依据**：巫师开发大厅。

- `herodoor --up--> city/wumiao`（扬州 · 武庙）
- `hall --north--> u/mudren/mailcenter`（玩家住宅邮局）

### `wudang`（武当）｜中心：`guangchang`（真武广场）

**依据**：广场主轴；`wdroad1/4/5/9` 青石大道负责全部跨区。

- `wdroad1 --north--> city/nanmen`（扬州 · 南门）
- `wdroad2 --southeast--> guiyun/yixing`（归云庄 · 宜兴）
- `wdroad4 --southup--> hengyang/hsroad1`（衡阳 · 青石大道）
- `wdroad4 --east--> xiaoyao/shulin3`（逍遥 · 树林）
- `wdroad5 --southdown--> jingzhou/jzbeimen`（荆州 · 北门）
- `wdroad5 --north--> xiangyang/caodi6`（襄阳 · 草地）
- `wdroad9 --southeast--> hengyang/hsroad8`（衡阳 · 山路）
- `sanbuguan --southwest--> emei/wdroad`（峨眉 · 三不管）

### `wudu`（五毒教）｜中心：`nanyuan`（南苑）

**依据**：区内入度 5（并列第 1）。药山/竹林环绕，密道通扬州菜房。

- `midao5 --up--> city/ma_chufang`（扬州 · 镖局菜房·密道）
- `cun8 --east--> dali/zhulin2`（大理 · 竹林·村口）
- `road1 --north--> dali/luyuxi`（大理 · 绿玉溪）

### `xuedao`（雪道/大雪山路）｜中心：`sroad3`（山路）

**依据**：区内入度 4，雪原主干十字。

- `sroad1 --north--> chengdu/nanheqiaos`（成都 · 南河桥）
- `sroad1 --northwest--> lingxiao/boot`（凌霄城 · 登城入口）
- `sroad8 --down--> city/xdmidao1`（扬州 · 密道出口）
- `nroad4 --westup--> xueshan/shanmen`（雪山 · 山门）
- `nroad7 --eastdown--> xueshan/shanjiao`（雪山 · 山脚）

### `xueshan`（雪山派）｜中心：`guangchang`

**依据**：区内入度 4，雪山派校场。

- `mishi --north--> city/xsmidao5`（扬州 · 密室·密道）
- `bieyuan --east--> beijing/road5`（北京 · 大驿道·雪山别院）
- `caoyuan --northeast--> xiyu/silk4`（西域 · 丝绸之路）
- `shanjiao --westup--> xuedao/nroad7`（雪道 · 山路）
- `shanmen --eastdown--> xuedao/nroad4`（雪道 · 山路）

### `zhongzhou`（中州）｜中心：`shizhongxin`（市中心）

**依据**：区内入度 4，中州环形官道中心；苗家庄 zhengting。

- `yangzhoudu --north--> city/ximen`（扬州 · 西门·扬州渡）
- `wroad3 --west--> kaifeng/tokaifeng`（开封 · 官道）
- `dongmeng --east--> suzhou/road4`（苏州 · 官道）
- `toyy --west--> xiangyang/eastgate2`（襄阳 · 青龙外门）
- `majiu --up--> clone/shop/zhongzhou_shop`

---

## 层 2 · 距离 2

### `beijing`（北京）｜中心：`di_dajie1`（城东大街）

**依据**：北京为皇城+大街网络，`di_dajie1/2` 为主街。跨区入口 `road10`（小道，连少林汝州/东海）。

- `road3 --northeast--> guanwai/laolongtou`（关外 · 老龙头/大驿道）
- `road5 --west--> xueshan/bieyuan`（雪山 · 别院）
- `road6 --southwest--> hengshan/jinlongxia`（恒山 · 金龙峡）
- `road10 --south--> shaolin/ruzhou`（少林 · 汝州）
- `road10 --east--> b/tulong/haigang`（倚天·屠龙 · 东海港）
- `ximenwai --west--> heimuya/road3`（黑木崖 · 黄土路）
- `huiying --up--> b/yitian/jiulou`（倚天 · 酒楼）
- `majiu --up--> clone/shop/beijing_shop`

### `changan`（长安）｜中心：`beian-daokou`（北岸道口）

**依据**：区内入度 6（并列第 1），长安滨河道口网（beian/nanan/dongan/xian）。

- `tulu4 --northdown--> huanghe/yongdeng`（黄河 · 永登）
- `caroad2 --northwest--> lanzhou/caroad8`（兰州 · 青石大道）
- `lzroad --west--> lanzhou/dongmen`（兰州 · 东门）
- `road2 --east--> luoyang/guandaow4`（洛阳 · 官道）
- `yongtai-dadao2 --east--> pk/entry`（屠人场 · 入口）
- `nan-chengmen --southwest--> quanzhen/guandao1`（全真 · 官道）
- `majiu --up--> clone/shop/changan_shop`

### `chengdu`（成都）｜中心：`guangchang`

**依据**：区内入度 4，city 缺，成都主广场。

- `road1 --east--> emei/qsjie1`（峨眉 · 青石大道）
- `shudao1 --east--> jingzhou/jzximen`（荆州 · 西门·蜀道）
- `fuheqiaon --north--> qingcheng/qcroad1`（青城 · 府河桥）
- `nanheqiaos --south--> xuedao/sroad1`（雪道 · 南河桥）
- `majiu --up--> clone/shop/chengdu_shop`

### `dali`（大理）｜中心：`zhengdian`（正殿·大理皇宫）

**依据**：区内入度 4（并列），段氏皇宫大殿；`road1` 官道承担跨区。

- `road1 --northeast--> emei/qsjie2`（峨眉 · 青石大道）
- `road1 --east--> kunming/xroad2`（昆明 · 碎石路）
- `road5 --southeast--> foshan/road1`（佛山 · 官道）
- `heisenlin --northeast--> kunming/htroad3`（昆明 · 黑杉林）
- `hongsheng --south--> tianlongsi/damen`（天龙寺 · 宏圣寺塔·大门）
- `road3 --northwest--> wanjiegu/riverside2`（万劫谷 · 江边）
- `luyuxi --south--> wudu/road1`（五毒 · 绿玉溪）
- `zhulin2 --west--> wudu/cun8`（五毒 · 竹林·村口）
- `majiu --up--> clone/shop/dali_shop`

### `emei`（峨眉）｜中心：`hcaguangchang`（华藏庵广场）

**依据**：区内入度 4（并列），金顶华藏庵寺院群主轴。

- `qsjie1 --west--> chengdu/road1`（成都 · 青石大道）
- `qsjie2 --southwest--> dali/road1`（大理 · 官道）
- `midao5 --up--> chengdu/qingyanggong`（成都 · 密道）
- `wdroad --northeast--> wudang/sanbuguan`（武当 · 三不管）

### `foshan`（佛山）｜中心：`street4`（佛山街）

**依据**：区内入度 4（并列第 1），佛山主街。

- `road1 --northwest--> dali/road5`（大理 · 官道）
- `nanling --northup--> hengyang/hsroad9`（衡阳 · 南岭山口）
- `road14 --east--> quanzhou/westbridge`（泉州 · 西门吊桥）
- `southgate --south--> xiakedao/xkroad3`（侠客岛 · 石径）
- `majiu --up--> clone/shop/foshan_shop`

### `fuzhou`（福州）｜中心：`dongjiekou`（东街口）

**依据**：区内入度 4（并列），福州东街口地标。

- `fzroad7 --northwest--> hengyang/hsroad2`（衡阳 · 闽赣古道）
- `fzroad1 --northdown--> quanzhou/qzroad4`（泉州 · 土路）
- `puxian --south--> quanzhou/beimen`（泉州 · 北门）
- `majiu --up--> clone/shop/fuzhou_shop`

### `hangzhou`（杭州）｜中心：`duanqiao`（断桥）

**依据**：杭州西湖地标，`road*` 网中心。

- `road1 --northwest--> quanzhou/jxnanmen`（泉州 · 嘉兴南门）
- `gushan --westup--> meizhuang/shijie`（梅庄 · 孤山林荫道）
- `majiu --up--> clone/shop/hangzhou_shop`
- （子区域 `honghua/` 红花会 21 房，内部 3 处通 `/d/wudang`）

### `heimuya`（黑木崖·日月神教）｜中心：`chengdedian`（成德殿·教主大殿）

**依据**：黑木崖总坛大殿；`didao1` 区内入度 5 为秘密地宫轴心。

- `road3 --east--> beijing/ximenwai`（北京 · 黄土路）
- `road6 --southeast--> village/wexit`（村庄 · 西村口）
- `bridge --east--> baituo/xijie`（白驼山 · 西街）
- `bridge --northwest--> baituo/guangchang`（白驼山 · 广场）
- `dukou2 --southwest--> huanghe/huanghe_1`（黄河 · 渡口）
- `road5 --northeast--> huanghe/weifen`（黄河 · 土路）

### `hengyang`（衡阳）｜中心：`zhurongdian`（祝融殿）

**依据**：衡山派主轴祝融殿；区内入度 4。「南岭山口」hsroad9 承担跨区。

- `hsroad9 --southdown--> foshan/nanling`（佛山 · 南岭山口）
- `hsroad2 --southeast--> fuzhou/fzroad7`（福州 · 古道）
- `hsroad5 --west--> motianya/mtroad1`（摩天崖 · 林间大道）
- `hsroad1 --northdown--> wudang/wdroad4`（武当 · 青石大道）
- `hsroad8 --northwest--> wudang/wdroad9`（武当 · 山路）
- `majiu --up--> clone/shop/hengyang_shop`
- （子区域 `yueqi/` 为乐器物品包，非房间）

### `kaifeng`（开封）｜中心：`hh_zhengting`（红花会正厅）

**依据**：开封为红花会总舵所在，`hh_*` 前缀厅堂群；区内入度 4。

- `tokaifeng --east--> zhongzhou/wroad3`（中州 · 官道）
- `yezhulin --west--> huashan/path1`（华山 · 夜竹林·华山脚下）
- `shanlu2 --north--> songshan/taishique`（嵩山 · 太室阙）
- `majiu --up--> clone/shop/kaifeng_shop`

### `kunming`（昆明）｜中心：`jinrilou`（近日楼）

**依据**：区内入度 5（第 1），昆明城门地标。

- `htroad3 --southwest--> dali/heisenlin`（大理 · 黑杉林）
- `xroad2 --west--> dali/road1`（大理 · 官道）
- `road1 --north--> jingzhou/nanshilu1`（荆州 · 碎石路）

### `lanzhou`（兰州）｜中心：`guangchang`

**依据**：区内入度 4（并列），兰州主广场；「兰州西门」`ximen` 出西域。

- `caroad8 --southeast--> changan/caroad2`（长安 · 青石大道青）
- `dongmen --east--> changan/lzroad`（长安 · 官道）
- `river-bei --north--> huanghe/xiaojiaqiao`（黄河 · 黄河桥）
- `guandao1 --west--> shenfeng/road`（神峰 · 荒道）
- `ximen --west--> xiyu/xxroad3`（西域 · 丝绸之路）

### `lingxiao`（凌霄城）｜中心：`dadian`（凌霄大殿）

**依据**：凌霄城大殿；`boot` 为登城入口。

- `boot --southeast--> xuedao/sroad1`（雪道 · 山路）

### `room`（鲁班民居·建房系统）｜中心：`xiaoyuan`（小院）

**依据**：建房系统入口房，三出口分别进入三个户型子区。

- `xiaoyuan --west--> shaolin/yidao2`（少林 · 大驿道）
- （盘龙/彩虹/独乐子区经小院进入）

### `songshan`（嵩山）｜中心：`dadian`（中岳大殿）

**依据**：嵩山中岳庙主轴大殿；`taishique`（太室阙）承担全部跨区。

- `taishique --south--> kaifeng/shanlu2`（开封 · 大驿道）
- `taishique --east--> shaolin/ruzhou`（少林 · 汝州）
- `taishique --west--> shaolin/shijie1`（少林 · 试剑石）

### `suzhou`（苏州）｜中心：`zhongxin`（苏州市中心）

**依据**：区内入度 4，苏州市中心十字大街。

- `road1 --northwest--> guiyun/shanlu2`（归云庄 · 山路）
- `road5 --east--> item/road1`（物品锻造区 · 官道）
- `road5 --southwest--> yanziwu/hupan`（燕子坞 · 太湖畔）
- `taihu --west--> yanziwu/hupan`（燕子坞 · 太湖）
- `dongmen --east--> quanzhou/qzroad2`（泉州 · 东门）
- `road4 --west--> zhongzhou/dongmeng`（中州 · 官道）
- `majiu --up--> clone/shop/suzhou_shop`

### `village`（新手村）｜中心：`square`（村中央广场）

**依据**：村庄十字路口放射网中心；`wexit`（西村口）承接跨区。

- `wexit --northwest--> heimuya/road6`（黑木崖 · 黄土路）
- `wexit --eastdown--> huanghe/liupanshan`（黄河 · 六盘山）
- `eexit --east--> huashan/path1`（华山 · 东村口·华山脚下）
- `hsroad2 --northeast--> huashan/jzroad1`（华山 · 青石大道）
- `hsroad1 --south--> luoyang/guandaon4`（洛阳 · 大官道）

### `xiangyang`（襄阳）｜中心：`guangchang`

**依据**：区内入度 4，襄阳主广场；城防主线连武当/中州/洛阳。

- `caodi3 --north--> luoyang/guandaos6`（洛阳 · 官道）
- `shanlu1 --northup--> jueqing/shanjiao`（绝情谷 · 山脚）
- `caodi6 --west--> tiezhang/hunanroad1`（铁掌 · 湖南路）
- `caodi6 --south--> wudang/wdroad5`（武当 · 青石大道）
- `eastgate2 --east--> zhongzhou/toyy`（中州 · 青龙外门）
- `westjie1 --north--> wuguan/guofu_gate`（郭府 · 大门）
- `majiu --up--> clone/shop/xiangyang_shop`

### `xiaoyao`（逍遥谷）｜中心：`qingcaop`（青草坪）

**依据**：区内入度 5（第 1），山谷腹地。

- `shulin3 --west--> wudang/wdroad4`（武当 · 树林）

### `xiyu`（西域）｜中心：`shanjiao`（天山山脚）

**依据**：区内入度 6（第 1），丝绸之路分流点。

- `xxroad3 --east--> lanzhou/ximen`（兰州 · 西门）
- `tianroad2 --northup--> lingjiu/shanjiao`（灵鹫宫 · 天山山路）
- `silk2 --west--> mingjiao/westroad1`（明教 · 丝绸之路）
- `nanjiang1 --east--> shenfeng/caoyuan5`（神峰 · 南疆沙漠）
- `nanjiang2 --northeast--> shenfeng/caoyuan5`（神峰 · 戈壁）
- `silk4 --southwest--> xueshan/caoyuan`（雪山 · 草原）

---

## 层 3 · 距离 3

### `guanwai`（关外/塞外）｜中心：`longmen`（龙门）

**依据**：塞外关口，区内入度 4（并列）。

- `laolongtou --southwest--> beijing/road3`（北京 · 大驿道·老龙头）

### `hengshan`（恒山）｜中心：`beiyuemiao`（北岳庙）

**依据**：区内入度 4，北岳庙大殿；`square` 山门广场。

- `jinlongxia --northeast--> beijing/road6`（北京 · 大驿道·金龙峡）

### `huashan`（华山）｜中心：`square`（玉女峰广场）

**依据**：区内入度 6，华山门派广场；`path1` 承担全部跨区。

- `path1 --east--> kaifeng/yezhulin`（开封 · 夜竹林）
- `path1 --west--> village/eexit`（村庄 · 东村口）
- `jzroad1 --southwest--> village/hsroad2`（村庄 · 青石大道）

### `item`（锻造材料区）｜中心：`road1`

**依据**：锻造区入口官道。

- `road1 --west--> suzhou/road5`（苏州 · 青石官道）

### `jinshe`（金蛇山洞）｜中心：`shandong`（山洞）

**依据**：金蛇郎君藏宝洞。

- `shanbi --up--> huashan/ziqitai`（华山 · 紫气台）

### `jueqing`（绝情谷）｜中心：`dating`（大厅）

**依据**：区内入度 4（并列），绝情谷正厅。

- `shanjiao --southdown--> xiangyang/shanlu1`（襄阳 · 山脚）

### `lingjiu`（灵鹫宫）｜中心：`damen`（宫门）

**依据**：天山缥缈峰宫门，`changl*` 长廊群环伺。

- `shanjiao --southdown--> xiyu/tianroad2`（西域 · 天山山路）

### `meizhuang`（梅庄）｜中心：`gate`（庄门·梅园）

**依据**：梅庄四友庄园主门；区内入度 6。

- `shijie --eastdown--> hangzhou/gushan`（杭州 · 孤山石级）
- `hupan --west--> quanzhou/nanhu1`（泉州 · 南湖）

### `mingjiao`（明教）｜中心：`dadian`（明教总舵大殿）

**依据**：光明顶大殿；`didao*` 地下迷宫为区内轴心。

- `shanjiao --westup--> kunlun/zhenyuanqiao`（昆仑 · 镇远桥）
- `didao2 --out--> lanzhou/guangchang`（兰州 · 明教密道出口）
- `westroad1 --east--> xiyu/silk2`（西域 · 丝绸之路）

### `motianya`（摩天崖）｜中心：`mtdating`（摩天大厅）

**依据**：崖顶大厅；`mtroad*` 盘山道。

- `mtroad1 --east--> hengyang/hsroad5`（衡阳 · 林间大道）

### `pk`（屠人场/PvP 区）｜中心：`entry`

**依据**：屠人场入口，被 `valid_leave` 守卫。

- `entry --west--> changan/yongtai-dadao2`（长安 · 永泰大道）

### `qingcheng`（青城山）｜中心：`sanqingdian`（三清殿）

**依据**：青城山主轴道观大殿。

- `qcroad1 --south--> chengdu/fuheqiaon`（成都 · 府河桥）

### `shenfeng`（神峰）｜中心：`dadian`（神峰大殿）

**依据**：区内入度 3（并列），山庄大殿。

- `caoyuan7 --north--> gaochang/shulin1`（高昌 · 黑松林）
- `guandao1 --east--> lanzhou/road`（兰州 · 荒道）
- `caoyuan5 --south/southwest--> xiyu/nanjiang2`；`caoyuan5 --west--> xiyu/nanjiang1`

### `tianlongsi`（天龙寺）｜中心：`baodian`（宝殿）

**依据**：天龙寺大雄宝殿。`damen` 数码承担跨区。

- `damen --north--> dali/hongsheng`（大理 · 宏圣寺塔）
- `dadao1 --northeast--> emei/qsjie2`（峨眉 · 青石大道）

### `tiezhang`（铁掌帮）｜中心：`guangchang`

**依据**：区内入度 4，铁掌峰广场。

- （连 `xiangyang/caodi6`，但 `hunanroad1.c` 出口字符串缺前导 `/`，为单向死路 bug）

### `tulong`（屠龙刀 saga 区）｜中心：`yubifeng/damen`（玉笔峰大门）

**依据**：容器区域（根无房），三个子区域 `tulong/`、`yitian/`、`yubifeng/` 共享 `obj/`。

- `haigang --west--> beijing/road10`（北京 · 小道）
- `jiulou --down--> beijing/huiying`（北京 · 汇英楼）
- 与 `b/`（倚天同人区）双向交叉引用

### `b/tulong`（倚天·屠龙，`b/` 家系）｜中心：`haigang`（东海港）

**依据**：跨 `d/`/`b/` 边界的外部关联区。

- `haigang` 与 `d/beijing/road10` 互通；`18jingang-*` NPC 引用 `d/tulong/yitian/npc/obj/*`。

### `b/yitian`（倚天·倚天，`b/` 家系）｜中心：`jiulou`（酒楼）

**依据**：同上，与 `d/beijing/huiying` 与 `d/tulong/yitian` 双向引用。

### `wanjiegu`（万劫谷）｜中心：`hall`（正堂）

**依据**：区内入度 4，庄园正堂。

- `riverside2 --southeast--> dali/road3`（大理 · 江边小路）

### `wuguan`（郭府·襄阳防务总部）｜中心：`guofu_dating`（郭府大厅）

**依据**：郭府主轴正厅；区内入度 4。

- `guofu_gate --south--> xiangyang/westjie1`（襄阳 · 西大街）

### `xiakedao`（侠客岛）｜中心：`dating`（大厅）

**依据**：区内入度 6，迎宾/大厅/石室群。跨区经山道出岛。

- `xkroad3 --north--> foshan/southgate`（佛山 · 南门）
- `xkroad1 --northup--> hengyang/hsroad9`（衡阳 · 南岭山口）

### `yanziwu`（燕子坞·慕容家）｜中心：`canheju`（参合庄）

**依据**：慕容家正院；区内入度 4（并列）。

- `hupan --northeast--> suzhou/road5`（苏州 · 青石官道）
- （`taihu` 湖面与 suzhou 双向）

---

## 层 4 · 距离 4

### `gaochang`（高昌古城）｜中心：`dadian`（高昌大殿）

**依据**：高昌国大殿，区内入度 7（第 1）。

- `shulin1 --south--> shenfeng/caoyuan7`（神峰 · 高昌迷宫·草原）

### `jinshe`（金蛇洞，已列层3）｜中心：`shandong`

### `kunlun`（昆仑派）｜中心：`guangchang（昆仑广场）`

**依据**：区内入度 4（并列第 1），昆仑派山门广场。

- `zhenyuanqiao --eastdown--> mingjiao/shanjiao`（明教 · 山脚·镇远桥）

---

## 不可达区 · 不接入大地图（按名称序）

| 区域 | 中心 room | 说明 |
|---|---|---|
| `huanggong`（皇宫） | `qihedian`（祈和殿） | 区内入度 3；皇城，无对外出口 |
| `lingzhou`（灵州） | `center`（市中心） | 区内入度 4 |
| `shenlong`（神龙岛） | `dating`（大厅） | 区内入度 4 |
| `sky`（天界） | `tianmen`（南天门） | 区内入度 1；与 `death/sky` 双份 |
| `special`（六道轮回展示区） | `liudaolunhui/*` | 无根房间，子区与 death/liudaolunhui 重复 |
| `tangmen`（唐门） | —（仅 obj） | 无房间 |
| `taohua`（桃花岛） | `dating` (岛主厅) | `__FILE__` 自指幻阵 |
| `xuanminggu`（玄冥谷） | `xuanminggu`（谷主厅） | 区内入度 3 |

---

## 附：统计口径与注意

- 跨区连接 = 从一个区域的 room 出发、`exits` 指向**同区域外**绝对路径 `/d/<zone>/<file>`（或 `/b/...`、`/clone/shop/...`）。`__DIR__` 区内引用不计。
- 大量区域间是**单向出口**；上表所列连接以"本区出发出口为准"。反向未见可不补（引擎允许单向）。
- `yitian/tulong`（`b/`）与 `clone/shop`、`u/` 为 `d/` 之外的系统/剧情区，标注在连接中但不在主表。
- 数据 bug：`d/tiezhang/hunanroad1.c` 的 `"east" : "d/xiangyang/caodi6"` 缺前导 `/`，导致铁掌帮→襄阳单向失效。
- 中心房间为**静态启发式判定**（区内 exits 入度优先 + 地标语义），个别区域（如 `foshan/street4`）命名平淡但确为主街枢纽。