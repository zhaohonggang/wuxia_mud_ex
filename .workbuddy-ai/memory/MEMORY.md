# Workspace Memory — wuxia_mud_ex (Elixir/Phoenix LPC MUD port)

## Iron rules
- 无 git commit/push 除非用户明确要求（2026-11-10 已授权「提交推送，然后继续推进」）。
- 改动前 Grep lib/test/docs + LPC 源 `/c/files/git/mud` 确认真缺口，不臆造语义。
- 不要升级 nimble_parsec。

## 阅读约定
- `.workbuddy-ai/memory/YYYY-MM-DD.md` 是按日追加的流水账，其中的「下一步/待办/遗留」为当日中间状态，后续条目或本文件「已完成」章节可推翻。
- `docs/` 历史计划文档同理：59 份已加「📌 归档声明 · 全库待办清零」。
- **唯一状态入口 = 本文件「已完成 / 净增量归档」 + `docs/待办对照代码核查.zh-CN.md` §三 / §6.2**。除此之外任何「待办」字样都不是当前待办。

## 验证路径
- Docker 不可用（Windows Git Bash）：`PATH=/c/Users/honggang/tools/erl-25.3.2.6/bin:/c/Users/honggang/tools/elixir-1.13.4-otp25/bin:$PATH`；`MIX_HOME=/c/Users/honggang/tools/mix-1.13`；`MIX_BUILD_PATH=_build_win13`；`ERL_LIBS=_build_win13/lib`；`MIX_ENV=test`。
- `mix compile` / `mix test --seed 831693`（全量约 9-10 min，建议后台重定向日志）。
- 基线：**27 failures**（7757 tests / 27 failures / 575.6s，2026-11-13）。27 例全为 `bcrypt_elixir` NIF 环境性（`Bcrypt.Base.gensalt_nif/3 is undefined`，Web.*/ExVenture.* 建用户/改密码），引擎/命令/技能/世界测试 0 失败。

## 关键约定 / 坑
- **路由**：`parse/2` 裸路由只产 `%{"command"=>...}`；带参命令需 `optional(spaces() |> text(:rest|:target|:category))`。
- **CommandProbe**：扫描占位标记；白名单 `@whitelist %{}`（0 占位）。新命令回执不得含占位标记。
- **daemon 惯例**（Pkd/Vote/Security/Prison）：GenServer 持 public ETS，写入直接 `:ets.insert`；`ensure!/0` 补建表；`read_state/0` 表缺失返缺省。
- **人格**：字段 `meta.character`（非 personality）；玩家 nil ≡ LPC 0。
- `@static` 白名单 733 唯一 id，与 `.ex` 模块一致（0 缺失 0 extra）。
- `suicide`：`meta.password` 明文校验 + `Characters.delete_by_name/1`（rescue 降级）。
- **两条死亡管线**：正常战斗击杀走 `CombatEvent.die/3`；`smash`/房间 `break` 走 `Feature.Damage.die/2` → `process_death/2`。公共尸体逻辑在 `Kantele.World.Corpse.spawn/1`。
- **物品缓存 key 是 `<zone>:<key>`**；动态生成的 `Item.Instance` 要用完整 key。
- **UCL 不能有单独一行的 `#`**（空注释）；注释行必须带内容。
- `NameGenerator.random_name/2` 返回 `{姓名, [拼音id]}` 元组，用 `elem(..., 0)` 取名字串。
- `Map.get(character_data, :random_name_type, :none)` 从 UCL 读取的是**字符串**（如 `"cn"`），case 要匹配字符串，不是原子。
- `is_player?/1` 认 `"player:"` 前缀；`receive_damage` 别传 killer。
- `zone.items` 缺 `:items` key 时抛 KeyError；改用 `Map.get(zone, :items, %{})`。
- `IO.write` 在 Windows 下对中文抛 `:no_translation`；改用 `File.write!/2` 追加。
- `Path.join/3` 不存在，用 `Path.join([...])`；`File.rm/2` 不存在，用 `File.rm!/1`。
- `String.to_integer/1` 返回裸整数，用 `is_integer()` 保护；`List.to_atom/1` 不接受字符串。

## 已完成（免后续重复核查）
- A1/A2/A4：已清零；e/g/h 期：用户确认已完成，标 ✅。
- A3/B5 Diff-stop：`kickoff.ex` `cleanup_stale_processes/1` 已真化，`handle_continue(:load)` 走 `safely/1`。
- B1 命令桩（22 个）：全部真实实现，无占位标记。
- B2 W3 arch 命令：12 个已落地；`build` 保留 `not_modeled`（用户确认不做）。
- B3 prepare/scheme/uptime/special/suicide/clone：全部完整实现。
- C 跨角色同步/饥饿口渴/门派学徒/门容器/一次性场景/通信中继载具：全部落地。
- O2 留言板；O3 门 v1；O4 food/water；O5 gift 先天赋值。
- T1 LPC→UCL 转换器 + 189 `.ucl`；T2 柳溪镇 34 文件对拍；T4 e2e 夹具。
- F4 武功迁移：@static 白名单 733；70 空壳 + 202 无招式已核实；R5 92 真缺口已全部迁移；valid_learn 322/322 全量迁移。
- 拱猪子系统：pig_room/pig_game/pig_table 均实装。
- 死亡→地府→还阳 完整对齐 LPC（combat_event.die/3 + revive/2 + niutou AskHandler + death.ucl）。
- 尸体/NPC 掉落系统（corpse.ex + drop_a/b/c + power，19/19 quarry NPC 已移植，14 例测试全绿）。
- 猎人 NPC 教 hunting（hunter.ex AskHandler + hunting.ex valid_learn/2 + eat_command.ex raw_meat 门控，50 例全绿）。
- 三项遗留待办（2026-11-15）：Set Grant as wizard / 世界位置文档 / 位置加到 goto 命令 — 全部结案。
- LPC 式随机鬼魂名字（2026-11-16）：`random_ghost_name/1` + death.ucl 18 NPC `random_name_type = "ghost"`，全量回归 7830 tests / 27 failures，0 新增失败。
- ask 黎生 五丁开山 / 绝命一踢（sect_master_grant，2026-11-14）：inquiry_handler 注册 + UCL 配置，99 例测试 0 失败。
- 随机 NPC 名字生成（2026-11-16 已提交推送，commit 1c017236 + fa11948a）：
  - `NameGenerator` 新增 `random_ghost_name/1`、`random_biaoshi_name/1`、`random_biaotou_name/1`。
  - `loader.ex` `parse_character/4`：case 匹配字符串 `"ghost"`/`"cn"`/`"biaoshi"`/`"biaotou"`，`elem(NameGenerator.random_name(...), 0)` 取名字串。
  - `death.ucl` 18 HellZhen NPC `random_name_type = "ghost"`；`gaibang.ucl` 7 丐帮弟子 `random_name_type = "cn"`；`changan.ucl` 镖师 `biaoshi`、镖头 `biaotou`，总镖头 `万青山` 保留不变。

## 当前待办（2026-11-16）
- **Run tests + commit/push `AskCommand.find_ask_npc/2` prefix matching 修复**：
  - `lib/kantele/character/commands/shop_commands.ex` 已补 `Room.NameMatch.matches?/2` 兜底（跟 `TalkCommand` 一致），修复 `ask 张青崖 Zhang Qingya 拜师` 返回「这里没有这样的人」。
  - `mix compile` 已通过，测试未运行，未提交未推送。
  - 测试文件：`test/kantele/character/commands/ask_command_test.exs`、`test/kantele/character/ask_command_test.exs`。

## Elixir 1.13.4 / Windows Git Bash 特殊坑
（同上，见「关键约定 / 坑」末尾。）

## 净增量归档（全部已完结，无待办）
- `docs/` 下 78 份文档 + 根目录 md 已全量扫描，59 份含待办标记的历史文档已加「📌 归档声明 · 全库待办清零」。
- `docs/待办对照代码核查.zh-CN.md` §一/§二/§四/§五/§6.1 过时断言已实质修正；§6.2 净增量表、§二、§三已标记 ✅ 已完结。
- 5/5 子项全部落地，全量回归 0 新增失败。
