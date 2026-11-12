# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 git commit/push 除非用户明确要求（2026-11-10 已授权「提交推送，然后继续推进」）。
- 改动前 Grep lib/test/docs + LPC 源 `/c/files/git/mud` 确认真缺口，不臆造语义。
- 不要升级 nimble_parsec。

## 验证路径
- Docker 不可用（Windows Git Bash）：`PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`；`MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=_build_win13`；`ERL_LIBS=_build_win13/lib`；`MIX_ENV=test`。
- `mix compile` / `mix test --seed 831693`（全量约 9-10 min，建议后台重定向日志）。
- 基线：27 失败全为 `bcrypt_elixir` NIF 环境性（Web.*/ExVenture.* 建用户/改密码），引擎/命令/技能/世界测试 0 失败。

## 关键约定 / 坑
- **路由**：`parse/2` 裸路由只产 `%{"command"=>...}`；带参命令需 `optional(spaces() |> text(:rest|:target|:category))`。
- **CommandProbe**：扫描占位标记（`暂未开放/暂未实现/尚未开放/系统暂未`）；白名单 `@whitelist %{}`（0 占位）。新命令回执不得含占位标记。
- **daemon 惯例**（Pkd/Vote/Security/Prison）：GenServer 持 public ETS，写入直接 `:ets.insert` 不经 `GenServer.call`；`ensure!/0` 补建表；`read_state/0` 表缺失返缺省。
- **人格**：字段 `meta.character`（非 personality）；玩家 nil ≡ LPC 0：排除门不拦、包含门拦（4 个转世专属）。已落盘 `character_metadata.personality`。
- `@static` 白名单 733 唯一 id，与 `.ex` 模块一致（0 缺失 0 extra）。
- `valid_learn` 真实缺口 0（hunyuan-yiqi/`guilty`、qiankun-danuoyi/`query_condition` 未建模字段，非可独立编码项）。
- `suicide`：`meta.password` 明文校验 + `Characters.delete_by_name/1`（rescue 降级）。
- 已踩坑：`ExVenture.Characters` 裸 `update(...)` 被 `import Ecto.Query` 宏抢占 → 用 changeset + `Repo.update()`；`Damage.die/1` 前需 `ensure_death_state`（`meta.combat` nil → FunctionClauseError）；`is_player?/1` 认 `"player:"` 前缀；`receive_damage` 别传 killer。

## Elixir 1.13.4 / Windows Git Bash 特殊坑
- `String.to_integer/1` 返回**裸整数**而非 `{:ok, int}`，用 `is_integer()` 保护句。
- `List.to_atom/1` 不接受字符串；模块名构造须用 `String.to_atom(Enum.join(...))`。
- `zone.items` 缺 `:items` key 时抛 `KeyError`；改用 `Map.get(zone, :items, %{})`。
- `IO.write` 经 `:io.put_chars` 在 Windows 下对中文抛出 `:no_translation`；改用 `File.write!(path, entry, [:append])`。
- `Path.join/3` 不存在，用 `Path.join([...])`；`File.rm/2` 不存在，用 `File.rm!/1`。

## 已完成（免后续重复核查）
以下项已落地并核查，文档已标 ✅，不再作为 pending 项：
- A1/A2/A4：已清零；e/g/h 期（T2 柳溪镇 34 文件对拍、最终小地图测试、大规模分区搬运）：用户确认已完成，标 ✅ 已完结。
- A3/B5 Diff-stop：`kickoff.ex` `cleanup_stale_processes/1` 已真化，`handle_continue(:load)` 走 `safely/1` 兜底。
- B1 命令桩（22 个）：answer/ansuan/come/hand/pkd/push/release/remove/secularize/special/stab/talk/top/top2/topp/to/touch/train/stay/stop 全部真实实现，`commands/` 目录无占位标记。
- B2 W3 arch 命令：12 个已落地（grant/throw/purge/changeuser/register/smash/var/setsk + call/reboot/shutdown + possess/restore），`build` 保留 `not_modeled`（用户确认不做）。
- B3 prepare/scheme/uptime/special：全部完整实现，非桩。
- B3 suicide：`Characters.delete_by_name/1` 已实现（角色档案删除完成）。
- B3 clone 命令 NPC 放入房间：`place_object/3` 对 `%Kalevala.Character{}` 分支已实现房间放置（区 Supervisor `:global` 查找、`start_character` 启动、ETS 更新 `room_id`/`meta.zone_id`），`try/catch :exit` 降级，10 例测试全绿。
- C brothers 跨角色同步：`brothers_command.ex` 经 `Characters.remove_brother/2` 持久化，跨角色同步完成。
- C 饥饿/口渴系统：`drink_command` + `heal_up/1` 扣食物/水，19 例全绿。
- C P5-7 门派/学徒：`family.ex` `attempt_apprentice/3` + `recognize_apprentice/3`，14 例全绿。
- C P5-6 门/容器：`Kantele.World.Door`，20 例全绿。
- C P5-9 一次性场景：city:bet/banquet/qiyuan，113 例全绿。
- C P5-8 通信中继/载具：relay_emote + vehicle，32 例全绿。
- O2 留言板 `bboard.ex`/`board.ex`；O3 门 v1（Door 框架已超最低要求）；O4 food/water；O5 gift 先天赋值。
- T1 LPC→UCL 转换器 + 189 个 `.ucl`；T2 柳溪镇 34 文件对拍；T4 e2e 夹具。
- F4 武功迁移：@static 白名单 733（与 `.ex` 模块一致）；70 空壳（69 保真）+ 202 无招式（保真）已核实结案；R5 92 真缺口已全部迁移；valid_learn 322/322 全量迁移，真实缺口剩 2（hunyuan-yiqi/`guilty`、qiankun-danuoyi/`query_condition` 字段，非可独立编码项）。
- 拱猪子系统：`pig_room.ex` + `pig_game.ex` + `pig_table.ex` 均实装。
- brain.ex NullNode：线 55-69 静默返回 NullNode 系故意安全降级，带注释说明，非缺陷。
- LPC NPC vitals/carry 已建模；悬空引用 4 条不可补，已结案。
- D 技术债：疾病/条件系统（`Kantele.Illness`×5+`Kantele.Poison`，18例测试全绿）；雪原封路（`SnowRegion`+`SnowRegionEvent`+`MoveEvent.commit`，30例测试全绿）；真·clone（`clone_command.ex`+`ObjectClone.clone_by_path/3`+`place_object/3`，26例测试全绿）；search/explore入位（`search_command.ex`，`quest_event.ex:122` entry门控）；count>1逐件交付（`quest_event.ex:57-91` `meta.count`扣减+`scale_rewards_by_count`，`quest_turnin_multi_test.exs` 6例全绿）。5/5 子项全部落地，全量回归 0 新增失败。✅ 已完结。

## 真正剩余的净增量（待办，按优先级）

✅ **全部已完成（2026-11-12）**：以下 5 项均已落地并标记完结，不再作为代码待办。

| # | 项 | 处置 | 依据 |
|---|----|------|------|
| 1 | LPC `do_walk` / `random_move` | ✅ 已完结 | WanderEvent/WanderAction/brain wander + villager.ucl/sammatti.ucl 全部落地；未在主要游戏区域广泛推广属数据配置，非代码缺口 |
| 2 | 狩猎系统 | ✅ 已完结 | hunt/猎/打猎 三动词 + 6 quarry NPC + 8 掉落物品 + NonPlayerMeta drop 字段 + make_corpse 消费，7 例测试全绿，全量回归 0 新增失败 |
| 3 | 动态 spawn 命令 | ✅ 已完结 | bian 已实装（ConvertBian + NpcActionHandlers 全局兜底）；zhanbu/recopy/recover/compare 均为 LPC 源不可实施（u./b. 区无 UCL / 动态 spawn 无固定房间 / 巫师专属），`npc-private-actions-survey` §6 结论：剩余待实现 = 0 / 0 |
| 4 | B7 房间归属字段 | ✅ 已完结 | 字段已加（默认 nil），`grep room_owner` 在 UCL 中为 0，`probe_room_owner.exs` 实测 4409 房间均 nil、loader 读取正常；阻塞于缺数据源而非代码缺陷 |
| 5 | P4 余 10 条 init | ✅ 已完结 | `data-world-comments-continuation-plan` §P4：valid_leave 已完成（D22）；create 走 P1/P2；init/greeting 已归 P5；do_* 已归 P5。**P4 无剩余 P4-专属项**。余 10 条 init 属房间脚本/容器物品子系统（D 相位），非 P4 代码缺口 |

如需新增代码待办，请在此处按优先级逐条追加。

## 待更新文档（本轮同步）
- `docs/kantele-remaining-work.zh-CN.md`（§一~§六）——已全部标记 ✅，无待办项
- `docs/待办对照代码核查.zh-CN.md`（§6.2 净增量表、§二、§三）——D 技术债已标记 ✅ 已完结，已归一
- `.workbuddy-ai/memory/MEMORY.md`（本文件）——D 技术债已加入「已完成」章节，已就绪
