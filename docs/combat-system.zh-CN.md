# 武侠实时战斗系统（Kantele）

> 移植自 LPC MUD（`C:\files\git\mud`，参考 `adm/daemons/combatd.c` 等），
> 在 ExVenture/Kalevala 之上的 Elixir 实现。本文对应提示词
> `docs/combat-session-prompt.md` 的交付说明。

## 总览

```
┌─────────────────────────── 游戏节点（app 容器） ───────────────────────────┐
│                                                                           │
│  玩家/ NPC 各一个 Foreman 进程（状态机，串行处理消息）                        │
│  ┌──────────────┐   combat/start   ┌──────────────┐                       │
│  │ Player       │ ◄──────────────► │ NPC(黑虎…)   │                        │
│  │  meta.combat │                  │  meta.combat │                         │
│  │  meta.stats  │                  │  meta.stats  │                          │
│  │  meta.vitals │                  │  meta.vitals │                           │
│  └──────┬───────┘                  └──────┬───────┘                         │
│         │ combat/tick (1s 自投递)          │                                  │
│         ▼                                 │                                  │
│  CombatEvent.tick ── combat/incoming ────►│ 防守方以自身完整状态结算            │
│  （出招方发快照）        ▲                 │ Engine.attack_round              │
│                          └── 房间频道广播 ──┘ Broadcast(type: "combat")      │
│                                                                           │
│  Room GenServer：combat/attack、combat/aggressive、skills/learn 解析        │
│    （按名字找目标 / 挑选在场玩家开战 / 找师父转发授艺）                        │
└───────────────────────────────────────────────────────────────────────────┘
```

### 关键设计决策

| 决策 | 选择 | 理由 |
|---|---|---|
| 心跳模型 | **每角色自投递**（`Process.send_after` 经 foreman） | 与 LPC 每个 living 对象独立 heart_beat 一一对应；无需集中式 tick 进程的簿记；foreman 串行处理天然免锁 |
| 结算位置 | **防守方结算**（攻击者只发快照） | LPC `receive_damage` 本就在受害者对象上执行；同时规避 Kalevala 房间上下文角色被 Trimmed（仅剩 vitals）的限制 |
| 延时事件 | `Process.send_after` 直投自身 | foreman 会把 `delay_event` 转发给房间路由，房间无对应处理器会静默丢弃；自投递绕开该限制 |
| 战况广播 | 房间频道消息 `type: "combat"` | 复用现有 Communication 订阅分发，含发起者在内全场可见 |

## 目录结构

```
lib/kantele/combat/
  engine.ex            # 纯公式引擎（skill_power/AP-DP-PP/伤害/创伤），rng 可注入
  messages.ex          # 中文文案库（damage_msg/status_msg/winner_msg + 占位符替换）
  skill.ex             # Skill behaviour + NewRandom 加权选招
  broadcast.ex         # 战斗频道广播
  skills/
    skills.ex          # 注册表 + 未映射时的通用招式
    liuxin_jian.ex     # 柳心剑法（招式表数据）+ 绝招「柳浪闻莺」
    liuxi_neigong.ex   # 柳溪内功 + 运功 powerup

lib/kantele/character/
  character.ex         # Vitals(qi/jing/neili) / Stats / NPCConfig 结构体
  combat.ex            # 运行时战斗状态（enemies/busy/jiali/temp/buffs/equipped）
  combat 相关事件 events/combat_event.ex、skills_event.ex
  commands/fight|halt|score|perform|exert|learn|enable|wield_command.ex
  records.ex           # 属性持久化（Ecto）

lib/kantele/world/room.ex   # 房间侧解析器（combat/attack 等）
priv/repo/migrations/*_create_character_metadata.exs
data/world/liuxi.ucl        # 柳溪镇：黑虎(aggressive)/野猪/王重九(拜师)/长剑布袍
data/brains/heihu.ucl       # aggressive 脑（room-enter → actions/combat-engage）
scripts/combat_e2e.exs      # 端到端验收脚本（Erlang 分布直连游戏 VM）
```

## 公式对照表（LPC → Elixir）

| LPC（combatd.c 等） | Elixir（Kantele.Combat.Engine） | 说明 |
|---|---|---|
| `valid_power(exp)` | `Engine.valid_power/1` | 200k/300k 两段边际递减，逐分支一致 |
| `skill_power(ob, skill, usage)` | `Engine.skill_power/3` | `level³/10 (+exp)` 后 `/30*属性`；等级<1 退化为 `exp/2/30*attr`；apply.attack/defense 加到等级 |
| `random(ap+dp) < dp` 闪避 | `rand(rng, ap+dp) < dp` | rng 注入（默认 `:rand.uniform/1`），测试可脚本化 |
| 招架 `pp = skill_power(...)+delta`，持械差 ±10 | `defense_power/4` 内 delta | busy 时 dp/pp 除三（heart_beat 的 dp/3） |
| `(apply/damage+random)/2` 起底 | `damage_calc/4` | 武器读 `applies.damage`，空手读 `unarmed_damage` |
| 招式 `action["damage"]%`、`action["force"]%` | 同名百分比加成 | 特技招式表八字段与 LPC 完全一致 |
| 加力 jiali（内力换伤害） | `jiali_bonus/1` + tick 先扣内力 | `neili > jiali` 时生效 |
| 护甲 `wounded -= random(apply/armor)` | 同左 | 创伤单独结算，攻击者 con 修正 |
| 伤害封顶 `(d-400)/4+300`、`(d-200)/2+200` | `cap/1` | 伤害与创伤各自封顶 |
| `NewRandom(n)`（skill.c） | `Skill.new_random/2` | 逐步移植，n=2 恒返回 0 等 corner case 一致 |
| `query_action`（等级门槛 + 加权） | `Skill.pick_action/3` | 只从 `lvl < level` 的招式中加权抽取 |
| `heart_beat → attack → fight/do_attack` | `tick → strike → incoming` | 出招/结算分离到两个进程，语义等价 |
| `receive_damage/receive_wound` | `Vitals.damage/wound` | wound 削减上限并夹住当前值 |
| `auto_fight/aggressive`（init 触发） | brain `room-enter → actions/combat-engage` | 复用既有行为树 DSL |
| `winner_reward`（简化） | `reward_for/1` | `exp = max(victim_exp/10, 5)`，potential = exp/2 |
| 死亡→尸体文案→回出生点 | `die/3` → Teleport（Movement 事件） | NPC 先去虚空停尸，60s 后 respawn 回出生点 |

**有意简化**（对照原版）：

- 昏迷（unconcious）阶段省略，气血归零直接进入死亡流程。
- 轻功/招架特技的 `valid_damage/hit_ob` 钩子未实现（柳溪世界无此需求）。
- 毒、狂怒值(jianu)、团队/仇杀系统未移植。

## Skill behaviour

```elixir
@callback id() :: String.t()
@callback valid_enable(String.t()) :: boolean()
@callback valid_learn(Stats.t()) :: :ok | {:error, String.t()}
@callback practice_cost() :: %{qi: n, neili: n} | nil   # nil = 不可练习
@callback query_action(level, rng) :: map()             # 招式表加权抽取
@callback perform_list() :: %{短名 => module}           # 绝招
@callback exert_list() :: %{功能名 => module}           # 运功
```

招式表存模块属性 `@actions`（纯数据），公式存 `Kantele.Combat.Skill`。
柳心剑法练到 60 层自动领悟绝招「柳浪闻莺」（简化原作 gongxian 门槛）。

## 命令列表

| 命令 | 说明 |
|---|---|
| `fight/kill <目标>` | 开战（房间按全名精确匹配，NPC 单词名免引号） |
| `halt` | 停手，向所有敌人发停手请求 |
| `score` | 气血/属性/经验/武学总览 |
| `perform liuxin-jian.liu` 或 `perform sword.liu` | 绝招（技能 id 或 map_skill 用法均可） |
| `exert powerup` | 运功（走 force 映射的内功） |
| `learn <技能> <师父>` | 拜师学习（消耗潜能 2 点/级，师父等级与 valid_learn 校验） |
| `practice <技能>` | 练习（消耗 qi/neili；柳溪内功只能 learn） |
| `enable <用法> <特技>` | 技能映射（如 `enable sword liuxin-jian`） |
| `wield/unwield/wear/remove <物品>` | 装备武器/护甲（影响命中管线） |

## 世界内容（柳溪镇）

- 山路：黑虎（aggressive，900 气，apply attack45/damage35/armor20）
- 镇广场：野猪（新手靶，80 气）
- 练武场：王重九（no_kill 点到即止型师父，可教 force/sword/liuxin-jian/liuxi-neigong）
- 张记铁铺：长剑（damage 22/sword）、布袍（armor 2）
- 出生点经萨玛蒂铁匠铺北门进入；黑虎死亡后进虚空停尸 60 秒重生

## 测试

```bash
# 单元 + 全链路（确定性，双方由测试进程扮演，事件流断言）
MIX_ENV=test mix test test/kantele

# 端到端（连接运行中的游戏 VM，真实 Foreman 驱动）
docker exec wuxia_mud_dev-app-1 sh -c \
  "cd /app && elixir --sname probe -S mix run --no-start scripts/combat_e2e.exs"
```

e2e 覆盖：登录 → score → 装备 → 拜师学艺 → enable/exert powerup（含二次拒绝）
→ perform 门槛 → 黑虎主动开战 → 多轮战况 → halt 逃跑 → 重伤战死 →
原地重生 → 击杀野猪获得经验。

注意：连续多次运行 e2e 时，上一次失败残留的场景进程可能仍在服务端执行
数分钟（其 foreman 已被预清理终止，不会影响本次判定，但可能出现在房间观
察文本中）；必要时重启 app 容器获得完全干净的环境。
