# 剩余工作清单（Remaining Work Checklist）

> 记录：2026-09-11 ｜ 分支 `kalevala`
> 来源：全量代码核查 + `docs/kantele-remaining-work.zh-CN.md` + `lpc_example/ex/MIGRATION_PLAN.md` 复核
> 基线：2334 tests / 0 failures（seed 731933/788424）
> 约定：所有规划批次（P0–P5 / M1–K3 / Q1–Q6）已完成；下表为**续做候选**，按优先级分档。

---

## A. 项目级工程缺口（最大 backlog）

| 项 | 说明 | 阻塞 | 参考 |
|----|------|------|------|
| **A1. T1 LPC→UCL 转换器** | 批量把 LPC 世界文件转成 UCL，仓库中不存在任何转换器代码 | 阻塞 A2/A4 | `docs/kantele-remaining-work.zh-CN.md:256` |
| **A2. T2 柳溪镇 34 文件全量对拍** | 将现有柳溪镇数据与 LPC 34 文件逐项比对补齐 | 依赖 A1 | 同上 `:260` |
| **A3. f1 Diff-stop** | reload 需终止「旧有而新无」的 zone/房间/NPC；当前只增更新不删 | 无 | `lib/kantele/world/kickoff.ex:100-113, 135-167`；记录于 `:270` |
| **A4. g 终测 / h 大规模分区搬运** | 全流程端到端验收 + 分区级世界搬迁 | 依赖 A1/A2/A3 | 同上 `:277-286` |

### A3 详情（f1 Diff-stop）

**现状问题**：`kickoff.ex` 的 `apply_world/3` 只做三件事，全为添加/更新：

- `start_zone`（`kickoff.ex:306`）：zone 进程存在时 `reset_characters` + `Zone.update`，**不终止**
- `start_room`（`kickoff.ex:322`）：room 存在时 `update_items` + `Room.update`，**不终止**
- `start_character`（`kickoff.ex:341`）：无条件新起 NPC 进程，被删 NPC **永不退**

**要补的能力**（`apply_world` 开头新增对比清理）：

1. 旧 zone 清单（`ZoneCache.keys()`）− 新世界 zone 集合 → 终止 zone 及其监督树子树
2. 旧房间进程（`:global` 注册名）− 新世界 rooms → `Process.exit(pid, :shutdown)`
3. 旧 NPC/角色进程（`DynamicSupervisor.which_children`）− 新世界 characters → `send(pid, :terminate)`（复用 `reset_characters` 模式）

**难点/注意**：

- 目前没有"全部房间"缓存，需扫 `:global` 或从各 zone 钻取
- 子虚道人（`zixu`）是代码模板启动、不在 UCL，diff 需**豁免**防止误杀
- 终止顺序：先角色 → 再房间 → 再 zone

---

## B. 占位命令（stub，未实现真实逻辑）

### B1. 23 个"XX系统暂未开放"文案 stub

> 均为 `run/2` 渲染占位文案，无事件/逻辑。文件统一位于 `lib/kantele/character/commands/`，占位在第 15 行（个别在 17–23）。

| 命令 | 文件 | 备注 |
|------|------|------|
| answer | `answer_command.ex:15` | |
| ansuan | `ansuan_command.ex:15,21` | |
| beg | `beg_command.ex:15` | |
| come | `come_command.ex:15` | |
| hand | `hand_command.ex:15` | |
| liuxi | `liuxi_command.ex:15` | |
| pkd | `pkd_command.ex:15` | |
| push | `push_command.ex:15` | |
| release | `release_command.ex:15` | |
| remove | `remove_command.ex:15` | 真实现散在 `wield_command.ex` |
| secularize | `secularize_command.ex:15` | |
| stab | `stab_command.ex:15` | |
| special | `special_command.ex:15,21` | |
| stop | `stop_command.ex:15` | |
| stay | `stay_command.ex:15` | |
| talk | `talk_command.ex:15` | |
| train | `train_command.ex:15` | |
| top | `top_command.ex:17-22` | 排行 |
| top2 | `top2_command.ex:15` | |
| topp | `topp_command.ex:15` | |
| to | `to_command.ex:15` | |
| touch | `touch_command.ex:15` | |
| vote | `vote_command.ex:15` | |

### B2. 14 个 W3 arch 静默 no-op

> 已注册（`commands.ex:1550-1605`，注释 "14个stubs - 需对象系统"），`run` 直接返回 conn。

| build | call | changeuser | grant | possess |
|-------|------|------------|-------|---------|
| purge | reboot | register | restore | setsk |
| shutdown | smash | throw | var | |

### B3. 小占位 / partial

| 命令/系统 | 文件 | 缺口 |
|-----------|------|------|
| clone 生物克隆 | `clone_command.ex:22` | item 可 clone，NPC 不可 |
| suicide | `suicide_command.ex:5,23` | 不删除角色记录（对话框注意） |
| prepare valid_combine | `prepare_command.ex:108-109` | 组合逻辑未实装 |
| closed | `closed_command.ex:9,50` | CLOSE_D 离线修炼缺失 |
| scheme 自动执行 | `scheme_command.ex:38` | show/edit/clear 已真，start 未开 |
| zixu 心魔幻境 | `world/mirror_daemon/zixu.ex:6,152-156` | 「尚在祭炼之中」占位 |
| uptime | `uptime_command.ex:24` | 手搓占位（无害） |

---

## C. 社区 / 杂项 TODO

| 项 | 文件 | 说明 |
|----|------|------|
| brothers 解除只改本地 | `brothers_command.ex:98` | `# TODO: 通知对方并同步移除对方名单（需跨角色更新，后续批处理）` |
| 饥饿系统不完整 | `feature_damage.ex:430-500` | heartbeat 扣减有，`eat` 仅展示（`eat_command.ex:8`） |

---

## D. 已记录的技术债（有意推迟 / v2）

| 项 | 来源 | 说明 |
|----|------|------|
| Q2 v2：疾病/光线/雪原封路 | `MIGRATION_PLAN.md:754` | event_noon 疾病、room light、季节封路 = stretch |
| Q1-T3：真·clone 动态目标 | `MIGRATION_PLAN.md:733-737` | 运行时 clone 需 Chei/Pawning |
| Q1-T3：search/explore 入位校验 | 同上 | 依赖房间人员查询 + 入位判断 |
| Q1-T3：count>1 逐件交付 | 同上 | |
| P-Adm 未开始（历史行） | `MIGRATION_PLAN.md:445` | §13 已全 ✅，属陈旧标注 |
| §3.2 P0 四个 `[ ]` | `MIGRATION_PLAN.md:172-179` | 与 §10 `P0 [x]` 冲突，stale |

---

## 建议优先级

1. **A3 (f1 Diff-stop)** — 修复热更不删残留，防止僵尸进程堆积（玩家可感、工程价值高）
2. **B1 `suicide`** — 删除角色对玩家体验重要
3. **C brothers 跨角色同步** — 小改动，社会系统完整性
4. **B1/B2 其余 stub** — 视玩法重心按需逐个真化
5. **A1/A2/A4** — 大工程，需立项排期（T1 转换器投入最大）

> 按仓库约定：本清单仅记录与查阅，开工任意项前先更新"当前状态"，每批验收以 `MIX_ENV=test mix test --seed 731933/788424` 全绿为准。