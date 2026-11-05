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
| **A3. f1 Diff-stop** | reload 终止「旧有而新无」的 zone/房间/NPC，已实现（`cleanup_stale_processes/1` + 角色→房间→zone 终止顺序 + zixu 豁免 + `DynamicSupervisor.terminate_child/2` 正常摘除 + `:global` 注册名清理） | 无 | `lib/kantele/world/kickoff.ex`；测试 `test/kantele/world/kickoff_test.exs` 14/0 |
| **A4. g 终测 / h 大规模分区搬运** | 全流程端到端验收 + 分区级世界搬迁 | 依赖 A1/A2/A3 | 同上 `:277-286` |

### A3 详情（f1 Diff-stop）—— ✅ 已完成

**实现内容**（`lib/kantele/world/kickoff.ex`）：

1. `apply_world/3` 先调用 `ensure_world_infrastructure/0`（兜底启动 `Kalevala.World` DynamicSupervisor 与 `ZoneCache`），再在 `safely/1` 内调用 `cleanup_stale_processes/1`。必须按此顺序：`Kalevala.Cache.keys/1`、`get/1` 直读 ETS 表，表不存在会抛 `ArgumentError`，且清理逻辑若在 `safely/1` 之外会直接击杀加载进程。
2. 角色清理：`DynamicSupervisor.which_children` 遍历各 zone `CharacterSupervisor` 子进程，`char_id != "zixu_daoren"` 且不在新世界集合中的角色发 `:terminate`（Foreman 以 `:normal` 退出，不会被重启）。
3. 房间清理：`stop_room/1` 通过房间状态里的 `supervisor_name` 找到 `RoomSupervisor`，用 `DynamicSupervisor.terminate_child/2` 正常摘除，再 `wait_for_exit/2` + `:global.unregister_name`。
4. Zone 清理：`purge_zone_tree/1` 用 `DynamicSupervisor.terminate_child(Kantele.World, pid)` 正常摘除 ZoneSupervisor，其子进程随之退出；残留 `:global` 名字逐个 kill + 注销；最后 `ZoneCache.delete`。
5. **关键约束**：ZoneSupervisor / Room 都是 `:permanent` 子进程，直接 `Process.exit(pid, :kill)` 会被监督树重启并重新注册 `:global` 名字，甚至触发 DynamicSupervisor 重启强度上限导致整个 supervisor `:shutdown`。必须走 `terminate_child/2`。
6. `start_zone/2` 只在 Zone / RoomSupervisor / ZoneSupervisor 三者都存活时才「原地 update」；任一缺失即 `purge_zone_tree/1` 后重建，避免半死树造成 `already_started` / `:noproc`。
7. 所有 `ZoneCache` 访问经 `safe_zone_keys/get/delete` 包装（ETS 表缺失 / GenServer 退出降级为无旧数据），`safe_get_state/1` 统一返回 `{:ok, state}`。

**测试**：`test/kantele/world/kickoff_test.exs` A3 f1 Diff-stop 三例全部通过（zone 被移除 / 房间被移除 / ZoneCache 条目清理），共 14/0；seed 137275 / 130361 / 1 / 999999 / 42 均 0 失败；与 hand/push/secularize 三个命令套件合跑 56/0（多 seed）。`test/kantele/world` 目录 1957/3，3 个失败（`npc_actions_yitian_test` 的 `:max_neili` KeyError、`mirror_zixu_test` 的 `:rand.uniform(0)`）单独跑同样复现，属既有失败。

---

## B. 占位命令（stub，未实现真实逻辑）

### B1. 23 个"XX系统暂未开放"文案 stub

> 均为 `run/2` 渲染占位文案，无事件/逻辑。文件统一位于 `lib/kantele/character/commands/`，占位在第 15 行（个别在 17–23）。

| 命令 | 文件 | 备注 |
|------|------|------|
| answer | `answer_command.ex:15` | |
| ansuan | `ansuan_command.ex` | 已真化：LPC `ansuan.c` 跨方向暗算门控 + 突袭/暴露/收尾（`ansuan_command_test` 绿） |
| beg | `beg_command.ex` | 已真化：丐帮门禁 + 房间 `no_beg`/`no_fight` 闸门 + `beg/attempt` 跨房间裁定落币（`beg_command` 绿） |
| come | `come_command.ex:15` | |
| hand | `hand_command.ex` | 已真化：LPC `hand.c` 手持门控（背包 present / 重量 20000 / 双手皆占 / 已装备）+ `:handing` 槽位（与 wield/remove 共用），`hand nothing` 收回（`hand_command_test` 绿） |
| liuxi | `liuxi_command.ex` | 已真化：走当前房间 `liuxi` 出口到柳溪镇广场，反向由 `yangzhou` 出口接回 |
| pkd | `pkd_command.ex:15` | |
| push | `push_command.ex` | 已真化：LPC `push.c` 跨方向推人门控 + qi/neili/force 消耗 + 目标 force>=150 推不动 + 目标 `character/teleport` 瞬移 + busy 收尾（`push_command_test` 绿） |
| release | `release_command.ex:15` | |
| remove | `remove_command.ex:15` | 真实现散在 `wield_command.ex` |
| secularize | `secularize_command.ex:15` | |
| stab | `stab_command.ex:15` | |
| special | `special_command.ex:15,21` | |
| stop | `stop_command.ex:15` | |
| stay | `stay_command.ex:15` | |
| talk | `talk_command.ex` | 已真化：LPC `talk.c` 解析 + 房间 NPC 查找 + `meta.inquiries` 应答（`talk_command_test` 绿） |
| train | `train_command.ex:15` | |
| top | `top_command.ex` + `top_ranking.ex` | 已真化：经验/等级/气血/精力/年龄榜（`top_command_test` 绿）；kill/die 因无计数器返回「未记录」 |
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

1. ✅ **A3 (f1 Diff-stop)** — 已完成：热更终止不再存在的 zone/房间/角色，防止僵尸进程堆积。测试 `test/kantele/world/kickoff_test.exs` 14/0。
2. **B1 `suicide`** — 删除角色对玩家体验重要
3. **C brothers 跨角色同步** — 小改动，社会系统完整性
4. **B1/B2 其余 stub** — 视玩法重心按需逐个真化
5. **A1/A2/A4** — 大工程，需立项排期（T1 转换器投入最大）

> 按仓库约定：本清单仅记录与查阅，开工任意项前先更新"当前状态"，每批验收以 `MIX_ENV=test mix test --seed 731933/788424` 全绿为准。