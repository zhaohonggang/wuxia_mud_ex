# MUD 世界区域分批转换与接入计划

> 基于 `docs/mud-d-zone-center-connections.zh-CN.md` 的 BFS 排序（city → 层1 → 层2 → 层3 → 层4 → 不可达）。
> 目标：把 `C:\files\git\mud\d\` 73 个区域逐个转换为 UCL，赋坐标，接入游戏，全流程测试通过后再进行下一个；最后统一处理所有 `_comments.txt` 中的 `UNHANDLED` 项。

---

## 1. 转换流程概览（单区域）

```
源区域 (d/<zone>/) 
   │
   ├─▶ lpc_converter.py  ──▶  <zone>.ucl  +  <zone>.comments.txt
   │       (Python 脚本，解析 LPC .c → UCL)
   │
   ├─▶ assign_room_coords.py  ──▶  给 <zone>.ucl 里每个 room 打 (x,y,z)
   │       从“中心 room”开始 BFS，步长 1，避开重叠
   │
   ├─▶ git add / commit <zone>.ucl <zone>.comments.txt
   │
   ├─▶ 热更加载到游戏  (mix run 或 remote shell)
   │
   ├─▶ 自动化回归测试  (路径连通、NPC/物品加载、指令无报错)
   │
   ├─▶ 人工巫师/玩家测试  (进区域走一圈、任务、战斗、技能、传送)
   │
   └─▶ 测试通过 → 标记该区域 ✅，进入下一区域
```

**关键约束**：
- 一次只转一个区域，**必须完全测试通过**才能进下一个
- `_comments.txt` 里的 `UNHANDLED` 先记录，**不阻塞**主流程，最后统一清理
- 坐标系：全局统一笛卡尔，zone 间预留缝隙（±500 以内），避免不同区域房间坐标碰撞

---

## 2. 区域处理顺序（直接复用 BFS 列表）

| 批次 | 层级 | 区域数 | 区域列表（按字母序） |
|------|------|--------|---------------------|
| 0 | Layer 0 | 1 | `city` |
| 1 | Layer 1 | 20 | `baituo` `death` `gaibang` `guiyun` `gumu` `huanghe` `jingzhou` `luoyang` `minimal_world` `minimal_world_v2` `quanzhen` `register` `shaolin` `taishan` `wizard` `wudang` `wudu` `xuedao` `xueshan` `zhongzhou` |
| 2 | Layer 2 | 23 | `beijing` `changan` `chengdu` `dali` `emei` `foshan` `fuzhou` `hangzhou` `heimuya` `hengyang` `kaifeng` `kunming` `lanzhou` `lingxiao` `room` `songshan` `suzhou` `village` `xiangyang` `xiaoyao` `xiyu` `quanzhou` |
| 3 | Layer 3 | 21 | `guanwai` `hengshan` `huashan` `item` `jinshe` `jueqing` `lingjiu` `meizhuang` `mingjiao` `motianya` `pk` `qingcheng` `shenfeng` `tianlongsi` `tiezhang` `tulong` `wanjiegu` `wuguan` `xiakedao` `yanziwu` |
| 4 | Layer 4 | 3 | `gaochang` `jinshe`(已列) `kunlun` |
| 5 | Unreachable | 8 | `huanggong` `lingzhou` `shenlong` `sky` `special` `tangmen` `taohua` `xuanminggu` |

> **说明**：`clone/shop`、`b/yitian`、`b/tulong`、`u/mudren` 为系统/外部关联区，**不纳入主序列**；转换时若主区引用它们，按“外部引用”标注在 `_comments.txt`，不单独生成 `.ucl`。

---

## 3. 单区域详细步骤（Checklist）

### 3.1 准备
- [ ] 确认源目录 `C:\files\git\mud\d\<zone>\` 存在 `.c` 文件
- [ ] 读取 `docs/mud-d-zone-center-connections.zh-CN.md` 中该区域的 **中心 room** 与 **跨区连接表**

### 3.2 运行 lpc_converter.py
```powershell
# 三个 Python 脚本都在【宿主机】运行 —— 容器 wuxia_mud_dev-app-1 内没有 Python
# （python3: not found）。LPC 语料也在宿主机：C:\files\git\mud\d\<zone>
cd C:\files\git\wuxia_mud_ex
python scripts\lpc_converter.py C:\files\git\mud\d\<zone> --zone <zone> --output data\world
```
> `PATH` 传目录即**自动递归**该目录下所有 `.c` 文件。
> 容器 `/app` 是仓库 `C:\files\git\wuxia_mud_ex` 的 bind mount，所以 `data\world` 与容器 `/app/data/world` 共享同一份文件，**不需要 `docker cp`**。

产出：
- `data\world\<zone>.ucl` —— 房间/物品/NPC/区域元数据
- `data\world\<zone>.comments.txt` —— 转换日志，**含 `UNHANDLED:` 行**（语法不支持、动态 exits、call_other 等）

### 3.3 运行 assign_room_coords.py
```powershell
# 只接受 2 个位置参数：ucl_path, start_room_id（没有第 3 个 zone_name 参数）
python scripts\assign_room_coords.py data\world\<zone>.ucl <center_room>
```
算法：
1. 读取 `.ucl` 所有 room 节点及 exits
2. 以 `center_room` 为 (0,0,0) 起点 BFS
3. 每条 exit 按方向增减坐标（`east:+x`, `west:-x`, `north:+y`, `south:-y`, `up:+z`, `down:-z`，斜向 ±1±1）
4. 遇到已赋坐标冲突 → 自动微调（+2 步长）并记录 WARNING 到 `_comments.txt`
5. 写回 `.ucl`（给每个 room 写入 `x` / `y` / `z` **三个独立字段**，不是 `coord: {x,y,z}`）

> 省略 `--output` 时**就地覆盖**输入 `.ucl`；想保留原文件请显式加
> `--output data\world\<zone>.coords.ucl`。
> 完整用法与测试流程见 `ASSIGN_ROOM_COORDS_TEST.md`。

### 3.4 提交版本控制
```bash
git add data/world/<zone>.ucl data/world/<zone>.comments.txt
git commit -m "add <zone>.ucl + coords (center: <center_room>)"
```

### 3.5 热更加载到运行中游戏
```bash
# 方式 A：Remote shell
docker exec -it <app_container> iex --remsh app@<host>
# 在 shell 里
World.load_zone("<zone>")   # 自定义加载函数，读取 .ucl 注入世界

# 方式 B：HTTP 管理端点（如已有）
curl -X POST http://localhost:4000/admin/zones/load -d '{"zone":"<zone>"}'
```

### 3.6 自动化回归测试（CI / 本地脚本）
```bash
mix test test/zone_<zone>_test.exs
```
测试点：
- [ ] 所有 room 能 `load` 无报错
- [ ] 所有 exits 指向的目标 room 存在（区内 + 跨区已加载的）
- [ ] NPC/物品模板能 `clone` 无报错
- [ ] 坐标无重复、无 NaN
- [ ] `goto <zone>/<center_room>` 可达

### 3.7 人工巫师/玩家测试（必须项）
| 角色 | 测试内容 | 通过标准 |
|------|----------|----------|
| **巫师** | `goto <zone>/<center>` → `walk` 全图、`call` 关键 NPC、`force` 任务触发、`check` 坐标连续性 | 无报错、描述正常、任务可完成 |
| **玩家** | 从 city 走官道/密道进区域 → 探索主线支线 → 战斗/技能/采集 → 传送/回城 | 主流程通顺、无卡死、掉线、属性异常 |

记录：测试日志存 `test_logs/<zone>_<date>.md`，含 发现问题/修复 commit。

### 3.8 标记完成
在计划表（下文）把该区域标 `✅`，注明测试日期、测试人、关键修复 commit。

---

## 4. 全局进度表（实时更新）

| 区域 | 批次 | 中心 | 转换 ✅ | 坐标 ✅ | 加载 ✅ | 自测 ✅ | 巫师测 ✅ | 玩家测 ✅ | 备注 |
|------|------|------|--------|--------|--------|--------|----------|----------|------|
| city | 0 | guangchang | | | | | | | 世界中枢，最先 |
| baituo | 1 | guangchang | | | | | | | |
| death | 1 | yanluodian | | | | | | | 地府，含轮回 |
| gaibang | 1 | undertre | | | | | | | goto 枢纽 |
| ... | ... | ... | | | | | | | |

> **维护方式**：每完成一个区域，在本表打勾并 `git commit --amend` 更新本计划文档（或单独 `progress.md`）。

---

## 5. 统一清理 UNHANDLED（全区域转完后）

收集所有 `<zone>_comments.txt` 里的 `UNHANDLED:` 行 → 汇总到 `UNHANDLED_master.md`，分类：

| 类型 | 示例 | 处理策略 |
|------|------|----------|
| 动态 exits（`call_other` 计算） | `exits: (: call_other(this_object(),"query_dynamic_exits") :)` | 写专用 Elixir 插件 / 手工补全坐标 |
| 复杂 `set("item_desc", mapping)` 含函数指针 | | 拆为静态描述 + 运行时 hook |
| 自定义 `init()`/`reset()` 逻辑 | NPC 巡逻、定时刷新 | 迁移到行为树/定时器系统 |
| 非标准 inherit（`VENDOR`、`BANK` 等） | | 映射到现有模块或新增模块 |
| 其它语法（`mixed*`、`class`、匿名函数） | | 人工改写为数据驱动 |

**清理流程**：
1. 按类型分派给对应开发/策划
2. 每类开一分支，改完 `.ucl` + 补测试
3. 合并回主分支，回归全区域

---

## 6. 游戏环境与测试指南

### 6.1 运行环境
| 组件 | 版本/地址 | 备注 |
|------|-----------|------|
| Elixir/Erlang | Elixir 1.11 / OTP 23+ | 宿主或容器 |
| 应用节点 | `app@<hostname>` | `docker-compose up -d` 启动 |
| 数据库 | PostgreSQL 13（Docker） | `pg_data` volume 持久化 |
| 代码仓库 | `C:\files\git\wuxia_mud_ex` (宿主) / `/app` (容器) | 宿主改代码 → `docker cp` 进容器 → `mix compile` |
| 世界数据 | `data/ucl/*.ucl` | 运行时热加载 |

### 6.2 进入游戏测试的三种方式
1. **巫师 Remote Shell（最强，可直接调用内部函数）**
   ```bash
   docker exec -it <container> iex --remsh app@<host>
   # 进去后
   World.goto("city/guangchang")
   Zone.list_rooms("city")
   ```
2. **Telnet/SSH 玩家客户端（真实玩家视角）**
   - 端口：`4000`（tcp）或 `443`（websocket）
   - 账号：提前 `Account.register("tester", "pwd")` 或用现有巫师号 `wizard/wiz123`
3. **自动化测试客户端（脚本化）**
   - `test/bot_client.exs` 用 `:gen_tcp` 连接、发指令、断言输出
   - CI 跑 `mix test` 时自动启动临时节点、跑完关闭

### 6.3 常用巫师测试指令速查
| 指令 | 作用 |
|------|------|
| `goto <zone>/<room>` | 瞬移 |
| `walk <dir>` | 步行测试 exits |
| `look` / `l` | 看房间描述/坐标 |
| `coord` | 显示当前坐标 |
| `call <npc> <fun> <args>` | 直接调用 NPC 模块函数 |
| `clone <template_id>` | 克隆物品/NPC |
| `dest <obj>` | 销毁物品 |
| `reload <zone>` | 热更重载该区域 `.ucl` |
| `zone_check <zone>` | 完整性自检（出口、坐标、模板） |

### 6.4 玩家测试清单（人工）
- [ ] 从 `city/guangchang` 出发，按文档跨区连接表走一遍**主干道**，确认每条跨区出口能到达目标区域的目标房间
- [ ] 在区域内完成 1 条主线任务 / 打 1 场战斗 / 用 1 个技能 / 拾取 1 件物品
- [ ] 测试 `fly`/`ride`/`teleport` 等移动技能不把人传到墙里
- [ ] 断线重连、存档读档、跨区存档读档
- [ ] 反馈记录：`test_logs/<zone>_player_<date>.md`

### 6.5 回滚/热修复
- 发现阻塞性 bug → `git revert <commit>` 或 直接改 `.ucl` → `reload <zone>` → 继续测试
- 坐标冲突 → 改 `assign_room_coords.py` 参数重跑 → 覆盖 `.ucl` → `reload`

---

## 7. 交付物清单（每区域）
1. `data/ucl/<zone>.ucl`（含 `coord`）
2. `data/ucl/<zone>_comments.txt`
3. `test_logs/<zone>_auto_<date>.md`（自动化测试报告）
4. `test_logs/<zone>_wizard_<date>.md`（巫师测试记录）
5. `test_logs/<zone>_player_<date>.md`（玩家测试记录）
6. 本计划文档的进度表更新 commit

---

## 8. 里程碑时间线（建议）

| 周 | 目标 |
|----|------|
| 1 | 完成 `city` + Layer 1 前 5 区（核心枢纽） |
| 2 | 完成 Layer 1 剩余 + Layer 2 前 10 区 |
| 3 | 完成 Layer 2 余 + Layer 3 前 10 区 |
| 4 | 完成 Layer 3 余 + Layer 4 + 不可达区 |
| 5 | 全区域回归 + UNHANDLED 统一清理 |
| 6 | 压力测试 / 玩家公测准备 |

---

## 9. 风险与对策
| 风险 | 对策 |
|------|------|
| 跨区出口目标区域尚未转换 | 先转换目标区域、或在 `_comments.txt` 标注 `PENDING_TARGET_ZONE`，后补 |
| 坐标碰撞（不同区域房间落在同坐标） | `assign_room_coords.py` 预留 zone 包围盒（每区 ±500），冲突自动偏移 |
| 动态 exits 导致运行时连通性与静态不符 | UNHANDLED 清理阶段专门处理，必要时引入运行时钩子 |
| 测试人力不足 | 自动化覆盖 80% 以上；玩家测试仅核心主线 |

---

## 10. 启动命令速查单

```bash
# 0. 启动游戏集群
cd C:\files\git\wuxia_mud_ex
docker-compose up -d

# 1. 进容器编译
docker exec -it <app> bash -c "cd /app && mix deps.get && mix compile"

# 2. 单区域转换示例（city）—— 下面三条都在【宿主机 PowerShell】跑，容器里没有 Python
#    （PowerShell 不支持 &&，所以分行顺序执行）
python scripts\lpc_converter.py C:\files\git\mud\d\city --zone city --output data\world
python scripts\assign_room_coords.py data\world\city.ucl guangchang
python scripts\validate_ucl.py data\world\city.ucl

# 3. 热更加载
docker exec -it <app> iex --remsh app@<host>
# 在 shell:
World.load_zone("city")


# 4. 跑自动化测试
docker exec -it <app> bash -c "cd /app && mix test test/zone_city_test.exs"

# 5. 人工测试 → 记录 → 标记 ✅ → 下一区
```

---

> **文档维护**：本计划为活文档，每完成一个区域即更新进度表与备注列，随代码一同 commit。全流程结束后归档为 `docs/archive/zone-conversion-plan-<date>.md`。