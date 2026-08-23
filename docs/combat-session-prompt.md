# 任务：为 ExVenture/Kantele 补充武侠风格实时战斗系统

> 使用方式：新开一个 AI 会话（工作目录设为 `C:\files\git\wuxia_mud_ex`），将本文件全文作为首条提示词粘贴给它。
> 本提示词由 mud 仓库迁移分析生成，参照物路径均为本机绝对路径。

## 角色与目标

你在 `C:\files\git\wuxia_mud_ex`（Elixir / ExVenture Kalevala 分支，游戏层模块名 Kantele）工作。
目标：移植一个 LPC MUD 的完整战斗系统，使玩家能与 NPC 实时过招、使用武功绝招、
获得击杀奖励、死亡重生。参考仓库 `C:\files\git\mud` **只读**，不要修改它。

## 第一步：读懂两侧现状（动手前必做）

### 目标引擎现状（C:\files\git\wuxia_mud_ex）
- 游戏层在 `lib/kantele/`：世界加载 `lib/kantele/world/loader.ex`（解析 data/world/*.ucl 播种进 PostgreSQL）、
  命令路由 `lib/kantele/character/commands.ex`（Router DSL，接受任意 UTF-8 动词），
  登录建角 `lib/kantele/character/controllers/login_controller.ex`
- 已有：房间/出口(仅六向 n/s/e/w/u/d)、NPC 行为树 brains(data/brains/*.ucl)、物品(name/description/verbs，
  Meta 是空 struct)、Web+Telnet 双通道、`dev_start.bat reset` 重播种数据库
- **Vitals 半成品**：`Kantele.Character.Vitals` 已存在（health_points/skill_points/endurance_points，
  登录时写死 25/17/30 且永不变化，prompt 显示 `{hp}25/25hp`）。P0 应在其上扩展 qi/jing/neili 或替换字段
- **没有**：战斗命令、伤害计算、角色属性持久化（DB 里只有名字）、装备概念、技能概念
- 目标解析规则：`Kalevala.Character.matches?/2` 是**全名精确匹配（忽略大小写）**，
  带空格的名字必须用引号 `tell "报讯人 Town Crier" hi`。战斗目标命名约定：NPC 一律用单词名（黑虎/野猪），
  这样 `kill 黑虎` 免引号直接可用
- 内容格式与生效机制见 `docs/game-content-guide.zh-CN.md`（注意 .ucl 必须 LF）

### 战斗引擎权威源码（C:\files\git\mud，逐行理解后翻译公式）
| 文件 | 内容 |
|---|---|
| `adm/daemons/combatd.c`（2006 行） | 核心：skill_power(lvl³ 经验边际递减)、AP/(AP+DP) 命中、招架 PP 判定、伤害=(apply/damage+random)/2+action 加成+加力 jiali、护甲 random(apply/armor) 减免、hit_with_poison、winner_reward/killer_reward 奖励、auto_fight 仇恨(attitude aggressive/hatred/vendetta)、no_fight 房间停手 |
| `feature/attack.c` | heart_beat(每秒)选对手发起 attack；busy 时 dp/3 |
| `feature/damage.c` | receive_damage/receive_wound/receive_curing(qi/jing/eff_*)、unconcious/die 流程 |
| `inherit/skill/skill.c` | 技能基类契约与 NewRandom 加权选招 |
| `kungfu/skill/banruo-zhang.c` | 特殊武技样板：action[] 招式表(force/attack/dodge/parry/damage/lvl/damage_type/skill_name 八字段)、valid_enable/valid_learn/practice_skill/query_action/perform_action_file |
| `minimal_world/skill/liuxi-neigong/powerup.c` | exert 运功契约：int exert(me,target)，temp buff apply/attack+defense，start_call_out 定时移除 |

### 验收夹具（用柳溪镇做端到端测试）
`C:\files\git\mud\minimal_world\`——10 房间/6 NPC/6 物品的微型区域，README 有覆盖矩阵：
- `npc/heihu.c`：aggressive 强敌（str/dex/max_qi/apply/attack 等）
- `skill/liuxin-jian.c` + `liuxin-jian/liu.c`：剑法招式表 + 绝招 buff（can_perform 权限校验）
- `skill/liuxi-neigong.c` + `powerup.c`：内功 exert
- `obj/changjian.c`(武器伤害 22)/`bupao.c`(甲值)/`laotou.c`(拜师学艺)

## 第二步：设计并实现（按阶段交付，每阶段可独立验收）

### P0 最小可打（核心闭环）
1. **Vitals**：角色内存态 qi/jing/neili 及上限（初值给默认），受伤/恢复/自然回复；
   死亡 → 尸体文案 → 在出生点重生（复用 starting_room）
2. **Combat 进程**：每个进入战斗的角色一个状态（enemies 集合/busy/temp apply 表）。
   心跳建议每角色 `Process.send_after` 1s 一轮（对应 heart_beat），或集中 tick 进程——二选一并说明理由
3. **命中管线**（严格按 combatd.c 公式）：skill_power → dodge/parry 判定 → 伤害计算 → 护甲减免 → vitals 结算 → 战斗文案（中文，含 $N/$n 替换为双方名字、招式名）
4. **命令**：`fight/kill <目标>`、`halt`、显示状态的 `score`；aggressive NPC 进入房间自动开战
   （实现挂点：复用现有 brain 节点 DSL——`conditions/room-enter` 已存在（town_crier 在用），
   新增 `actions/combat-engage` 类节点即可，勿另起炉灶）
5. **奖励**：击杀得 combat_exp（简化 winner_reward 公式即可）

### P1 武功协议
6. **Skill behaviour**（Elixir behaviour 对应 LPC 契约点）：
   `valid_enable/valid_learn/practice_cost/action_table(level)/perform_list/exert_list`
   招式表存数据（module attribute 即可），公式存代码
7. 把柳心剑法+柳浪闻莺(perform)+柳溪内功(powerup exert)做成首个实现：
   temp apply buff + 定时移除(Process.send_after)；`perform <skill>.<招>` / `exert powerup` 命令
8. NPC 配技能：黑虎会反击、王师父可陪练

### P2 成长与装备（视进度）
9. Character 属性持久化 schema（combat_exp/potential/skills 映射/neili 上限等）+ 登录恢复
10. Item.Meta 扩展(damage/armor/value) + `wield/wear` 影响命中管线
11. `learn/practice` 命令 + 等级门槛校验

## 工程约定
- Elixir 标准风格，遵循项目现有模块划分（Kantele.* 游戏层）；中文文案全 UTF-8
- 每个 P 阶段配 `mix test` 测试（公式单元测试为主：命中概率边界、伤害区间、buff 过期）
- ⚠️ `mix test` 别名会先执行 ecto.create+migrate（见 mix.exs aliases），**必须 db 容器在线**
  （先 `dev_start.bat` 或 `docker compose -f docker-compose.dev.yml up -d db`）
- 开发迭代技巧：游戏内 `reload` 命令可运行时重载世界数据，`recompile` 热编译 Elixir 代码，
  dev 模式下改代码刷新浏览器即生效，无需反复重启容器
- 尽量不新增 hex 依赖（NimbleParsec/ecto 等已在依赖树中；:timer、Process.send_after 够用）
- 不改 `.ucl` 世界结构也能跑通 P0/P1（战斗对象可用现有 sammatti 区 NPC 或临时注册的测试 NPC）
- 完成后在 `docs/` 写一份 `combat-system.zh-CN.md`：架构图、公式对照表(LPC→Elixir)、命令列表

## 最终验收清单
- [ ] fight 黑虎：命中/闪避/招架/伤害文案随回合滚动，一方死亡正确结算
- [ ] perform sword.liu 后 apply/dodge 提升、约十几秒后自动消退并有提示
- [ ] exert powerup 攻防提升、战斗中 start_busy
- [ ] aggressive NPC 见玩家主动攻击；no_fight 房间无法开战（若该房间标记已迁移）
- [ ] 击杀获 exp，死亡回出生点
- [ ] mix test 全绿，mix format 通过
