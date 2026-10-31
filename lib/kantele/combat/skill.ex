defmodule Kantele.Combat.Skill do
  @moduledoc """
  武学 behaviour（对应 LPC `inherit/skill/skill.c` 的契约点）

  招式表存数据（实现模块的 `@actions` module attribute），公式存代码。

  # 实现

      defmodule MySkill do
        use Kantele.Combat.Skill

        @actions [
          %{"action" => "...", "force" => 80, "attack" => 25, "dodge" => 10,
            "parry" => 15, "damage" => 8, "lvl" => 0,
            "damage_type" => "刺伤", "skill_name" => "杨柳依依"}
        ]

        def id, do: "my-skill"
        def valid_enable("sword"), do: true
        def valid_enable(_), do: false
      end

  招式表字段与 LPC 完全一致（八字段）：action/force/attack/dodge/parry/
  damage/lvl/damage_type/skill_name。
  """

  alias Kantele.Character.Stats

  @type rng :: (pos_integer() -> pos_integer())

  @callback id() :: String.t()

  @doc "是否可 enable 到某用法（valid_enable/1）"
  @callback valid_enable(String.t()) :: boolean()

  @doc """
  带角色上下文的 `valid_enable`（对应 LPC 里读 `this_player()` 的实现）

  极少数技能的 LPC `valid_enable` 依赖角色状态（如 `jiuyin-shengong` 的
  `me->query("reborn")`：未转世只能 enable 到 `force`）。`valid_enable/1`
  拿不到角色，故这类技能额外实现本回调；`EnableCommand` 优先调它，其余技能
  由宏默认实现回落到 `valid_enable/1`。
  """
  @callback valid_enable(String.t(), term()) :: boolean()

  @doc "学习门槛校验（valid_learn/1）"
  @callback valid_learn(Stats.t()) :: :ok | {:error, String.t()}

  @doc """
  带角色上下文的学习门槛校验（可选 valid_learn/2）

  LPC `valid_learn(object me)` 会读 `me` 的 `max_neili`（在 Vitals，不在 Stats）
  以及临时装备状态（空手检查）。引擎的 `valid_learn/1` 只拿到 `Stats`，
  故需要 `max_neili` / 装备判断的技能额外实现本回调；默认回落到 `valid_learn/1`
  （忽略角色上下文，与既有迁移一致）。`character` 为 `%{meta: %{vitals: vitals}}`
  形状的任意结构（学习事件传学徒的 vitals，练习命令传自身 character）。
  """
  @callback valid_learn(Stats.t(), term()) :: :ok | {:error, String.t()}

  @doc """
  内功共存校验（valid_force/1，b5/P10）

  入参为另一门内功的 skill id；返回自身是否接受与其共存。
  `"*"` 为通配查询（learn.c:230 的短路语义）。默认无条件共存。
  """
  @callback valid_force(String.t()) :: boolean()

  @doc "练习一次的消耗（practice_skill 的 qi/neili 消耗）"
  @callback practice_cost() :: %{qi: non_neg_integer(), neili: non_neg_integer()}

  @doc """
  按等级加权随机选一招（query_action + NewRandom）

  LPC 的 `query_action(object me, object weapon)` 有两个参数，其中 `weapon`
  决定用哪张招式表（如绝学内功的 `actionw` / `actionf`）。引擎的
  `query_action/1`、`query_action/2` 拿不到角色上下文，所以**武器相关**的技能
  额外实现可选的 `query_action/3(level, rng, attacker)`；`attacker` 是
  `Kantele.Combat.Fighter` 快照（含 `:weapon_name`、`:skills`）。
  未实现者由宏默认实现回落到 `query_action/2`。
  """
  @callback query_action(non_neg_integer()) :: map()
  @callback query_action(non_neg_integer(), rng()) :: map()
  @callback query_action(non_neg_integer(), rng(), term()) :: map()

  @doc "绝招列表：短名 -> 实现 module（perform_action_file 映射）"
  @callback perform_list() :: %{String.t() => module()}

  @doc "运功列表：功能名 -> 实现 module（exert_function_file 映射）"
  @callback exert_list() :: %{String.t() => module()}

  @doc """
  伤害再判定钩子（对应 LPC valid_damage/4，如 taiji-quan 的借力打力）

  命中伤害算定后调用；返回 `{new_damage, message | nil}` 或
  `{new_damage, message, counter}`，其中 `counter` 为
  `{counter_damage :: integer(), counter_msg :: String.t()} | nil`，
  表示对攻击者造成的回弹/反击（由引擎累加进 `Round.counter_damage`）。
  `new_damage` 可为负表示完全化解并使伤害回弹；`message` 追加到战报文案。
  `rng` 为注入的随机函数（0 基，对齐 LPC `random(n)`）。

  引擎分两侧调用：攻击方映射技能（攻击特技）与防守方映射的招架/闪避技能
  （LPC 的 `me`=防守方），两侧返回的伤害修改与反击被顺序折叠。
  """
  @callback valid_damage(
              map(),
              map(),
              non_neg_integer(),
              map(),
              (non_neg_integer() -> non_neg_integer())
            ) ::
              {non_neg_integer(), String.t() | nil}
              | {non_neg_integer(), String.t() | nil, {integer(), String.t()} | nil}

  @doc """
  命中回调（对应 LPC hit_ob/4，如 taiji-quan 蓄力连击）

  命中成功时调用；返回修改后的 attacker 快照 map（如追加临时加成）。
  """
  @callback hit_ob(map(), map(), map()) :: map()

  @doc "练习前置校验（对应 practice_skill 的 qi/neili 门槛），返回 :ok 或出错文案"
  @callback practice_check(map()) :: :ok | {:error, String.t()}

  @doc "学习难度系数（对应 difficult_level/1，越小越容易升级）"
  @callback difficult_level(Stats.t()) :: non_neg_integer()

  @doc "被动招架加成（对应 query_effect_parry/1，按等级阶梯）"
  @callback query_effect_parry(Stats.t()) :: non_neg_integer()

  @doc "被动闪避加成（对应 query_effect_dodge/1）"
  @callback query_effect_dodge(Stats.t()) :: non_neg_integer()

  @doc "技能升级回调（对应 skill_improved/1），可在升级时改属性/解锁，返回新 stats"
  @callback skill_improved(Stats.t()) :: Stats.t()

  @doc "绝招文件路由（对应 perform_action_file/2）：招式名 -> 实现 module"
  @callback perform_action_file(String.t()) :: module() | nil

  @doc """
  曲目技能效果钩子（对应 LPC `SKILL_D(arg)->do_effect(me)`，歌谱技能专用）

  仅歌谱类技能（碧海潮生曲等）实现；入参 `conn` 供房间级广播 / 状态改写，
  `character` 为演奏者（actor）。绝大多数武学不实现此回调 —— 由
  `ItemActions.Play` 经 `Skills.get(arg)` + `function_exported?(:do_effect, 2)`
  守卫调用：未登记或未导出时**不调用**，演奏只播分级文案 + `start_busy`，
  与 LPC 在技能缺省时的行为一致。P9 把歌谱技能迁移为真实实现后自动接通，
  无需改 `Play`。
  """
  @callback do_effect(Kalevala.Character.Conn.t(), Kalevala.Character.t()) ::
              Kalevala.Character.Conn.t()

  @optional_callbacks [
    perform_list: 0,
    exert_list: 0,
    valid_damage: 5,
    hit_ob: 3,
    practice_check: 1,
    difficult_level: 1,
    query_effect_parry: 1,
    query_effect_dodge: 1,
    skill_improved: 1,
    perform_action_file: 1,
    do_effect: 2,
    query_action: 3,
    valid_enable: 2
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour Kantele.Combat.Skill

      import Kantele.Combat.Skill, only: [new_random: 1, new_random: 2]

      @doc false
      def valid_learn(_stats), do: :ok

      # 带角色上下文的学习门槛：默认忽略角色，回落到 valid_learn/1。
      # 需要 max_neili / 装备判断的技能（LPC valid_learn 读 me->query("max_neili")、
      # me->query_temp("weapon")）才覆盖本回调。
      @doc false
      def valid_learn(stats, _character), do: valid_learn(stats)

      # 带角色上下文的 valid_enable：默认忽略角色，回落到 valid_enable/1。
      # 只有 LPC 里读 `this_player()` 的技能（如 jiuyin-shengong 的 reborn 门控）才覆盖。
      @doc false
      def valid_enable(usage, _character), do: valid_enable(usage)

      # 武器感知选招：默认忽略角色快照，回落到 query_action/2。
      # 只有 LPC `query_action(me, weapon)` 分两张表的技能（绝学内功）才覆盖。
      @doc false
      def query_action(level, rng, _attacker), do: query_action(level, rng)

      @doc false
      def valid_force(_other), do: true

      @doc false
      def practice_cost(), do: %{qi: 50, neili: 30}

      @doc false
      def perform_list(), do: %{}

      @doc false
      def exert_list(), do: %{}

      @doc false
      def valid_damage(_attacker, _victim, damage, _action, _rng), do: {damage, nil}

      @doc false
      def hit_ob(_attacker, _victim, _action), do: :unchanged

      @doc false
      def practice_check(_vitals), do: :ok

      @doc false
      def difficult_level(_stats), do: 100

      @doc false
      def query_effect_parry(_stats), do: 0

      @doc false
      def query_effect_dodge(_stats), do: 0

      @doc false
      def skill_improved(stats), do: stats

      @doc false
      def perform_action_file(name), do: Map.get(perform_list(), name)

      defoverridable valid_learn: 1,
                     valid_learn: 2,
                     valid_enable: 2,
                     valid_force: 1,
                     query_action: 3,
                     practice_cost: 0,
                     perform_list: 0,
                     exert_list: 0,
                     valid_damage: 5,
                     hit_ob: 3,
                     practice_check: 1,
                     difficult_level: 1,
                     query_effect_parry: 1,
                     query_effect_dodge: 1,
                     skill_improved: 1,
                     perform_action_file: 1
    end
  end

  @doc """
  武器感知选招：LPC `query_action(me, weapon)` 的 `weapon ? actionw[...] : actionf[...]`

  全库只有 6 个「绝学内功」这么写（`actionf` 是空手表、`actionw` 是持械表），
  其余技能的 `query_action` 只有一张表，用 `pick_action/3` 即可。

  `attacker` 是 `Kantele.Combat.Fighter` 快照；`weapon_name` 非空即视为持械
  （对应 LPC `objectp(weapon)`）。`weapon_actions` 为空时也回落到空手表 ——
  避免某个技能只迁了一半表时出招为空。
  """
  @spec pick_action_for([map()], [map()], non_neg_integer(), term(), rng()) :: map()
  def pick_action_for(actions, weapon_actions, level, attacker, rng \\ &:rand.uniform/1) do
    if weapon?(attacker) and weapon_actions != [] do
      pick_action(weapon_actions, level, rng)
    else
      pick_action(actions, level, rng)
    end
  end

  @doc "攻击者是否持械（对应 LPC `objectp(weapon)`）"
  def weapon?(%{weapon_name: name}), do: is_binary(name) and name != ""
  def weapon?(_), do: false

  @doc """
  攻击者所持武器的原始 `skill_type`（对应 LPC `weapon->query("skill_type")`）

  少数技能的 `query_action` 不只看「有没有武器」，而是**按武器类型分表**
  （`never-defeated`：`whip` 走 `action_whip`，其余走 `action_default`）。
  空手时为 `nil`（LPC 里 `weapon` 为 0，switch 走 `"default"` 分支）。
  """
  @spec weapon_skill_type(term()) :: String.t() | nil
  def weapon_skill_type(%{weapon_skill_type: type}) when is_binary(type), do: type
  def weapon_skill_type(_), do: nil

  @doc """
  角色是否已转世（对应 LPC `me->query("reborn")`）

  本引擎把转世建模成 `stats.reborn` 的**属性加成表**（`%{str: n, int: n, ...}`），
  没有独立布尔标记，也没有 `reborn/count`（`leiting_fu/sanda.ex` 亦记作未建模）。
  这里以「有任一非零加成」判定已转世；未转世者全 0（`Stats.new/0` 默认值）→ false。

  只有少数 `valid_enable` 读 `this_player()` 的技能（九阳/九阴/太玄）需要它。
  """
  @spec reborn?(term()) :: boolean()
  def reborn?(%{meta: %{stats: %{reborn: reborn}}}), do: reborn_flag?(reborn)
  def reborn?(_), do: false

  defp reborn_flag?(reborn) when is_map(reborn),
    do: Enum.any?(Map.values(reborn), &(&1 not in [nil, 0]))

  defp reborn_flag?(reborn) when is_integer(reborn), do: reborn > 0
  defp reborn_flag?(_), do: false

  @doc """
  读 `meta.marks` 里的任务标记（对应 LPC `me->query("can_learn/xxx/enable_weapon")`）

  LPC 的 `can_learn/...` / `can_learned/...` 权限位在本引擎统一落在 `meta.marks`
  （与 `mark/guofu_job`、`mark/还了` 同一仓库），值非 `nil/0/false` 即视为已获得。
  """
  @spec mark?(term(), String.t()) :: boolean()
  def mark?(%{marks: marks}, key) when is_map(marks),
    do: Map.get(marks, key) not in [nil, 0, false]

  def mark?(%{meta: %{marks: marks}}, key) when is_map(marks),
    do: Map.get(marks, key) not in [nil, 0, false]

  def mark?(_character, _key), do: false

  @doc """
  从招式表中按等级选出可用招式并加权抽取一式

  对照 LPC：

      for (i = sizeof(action); i > 0; i--)
          if (level > action[i-1]["lvl"])
              return action[NewRandom(i, 20, level/5)];
  """
  @spec pick_action([map()], non_neg_integer(), rng()) :: map()
  def pick_action(actions, level, rng \\ &:rand.uniform/1) do
    count =
      Enum.count(actions, fn action ->
        level > Map.get(action, "lvl", 0)
      end)

    case count do
      0 -> List.first(actions) || %{}
      count -> Enum.at(actions, new_random(count, rng))
    end
  end

  @doc """
  取攻击方某技能等级（对应 LPC `me->query_skill(name, 1)`）

  `attacker` 是 `Kantele.Combat.Fighter` 快照（`skills` 为「技能 id → 等级」）。
  非 Fighter / 无该技能时返回 0 —— 与 LPC `query_skill` 未学时返回 0 一致。
  """
  @spec skill_of(term(), String.t()) :: non_neg_integer()
  def skill_of(%{skills: skills}, name) when is_map(skills) do
    case Map.get(skills, name, 0) do
      n when is_integer(n) and n > 0 -> n
      _ -> 0
    end
  end

  # 角色形状（`valid_enable/2` 收到的是角色而非 Fighter）
  def skill_of(%{meta: %{stats: stats}}, name), do: Kantele.Character.Stats.skill(stats, name)
  def skill_of(_attacker, _name), do: 0

  @doc """
  LPC `random(n)`：返回 `0..n-1`（`n <= 0` 时为 0）

  `rng` 遵循本模块约定 —— 返回 `1..n`（`&:rand.uniform/1`），故内部减一。
  """
  @spec lpc_random(rng(), integer()) :: non_neg_integer()
  def lpc_random(_rng, n) when n < 1, do: 0
  def lpc_random(rng, n), do: rng.(n) - 1

  @doc """
  表尾追加一条**运行时生成**的高阶招式后选招（LPC「极意」式）

  少数技能（华山剑法 / 太极拳 / 抽髓掌）的 `action` 表最后一式，其
  `force/attack/dodge/parry/damage` 不是字面量，而是
  `this_player()->query_skill(...) / k + random(...)`。LPC 把这串表达式写在
  **全局 `mapping *action` 初始化器**里 —— 那是 LPC 反模式（对象首次加载时求值一次，
  取的是当时的 `this_player()`）。本引擎按**出招时**计算（与作者意图一致）。

  仅当 `level > 该式 lvl` 时才生成，避免不可选中时白耗 `rng`。

  - `ultimate`：静态部分（`"action"`/`"lvl"`/`"skill_name"`/`"damage_type"`）
  - `values_fun`：`(attacker, rng) -> %{"force" => n, ...}`
  """
  @spec pick_action_with_ultimate(
          [map()],
          non_neg_integer(),
          term(),
          map(),
          (term(), rng() -> map()),
          rng()
        ) :: map()
  def pick_action_with_ultimate(actions, level, attacker, ultimate, values_fun, rng) do
    if level > Map.get(ultimate, "lvl", 0) do
      entry = Map.merge(ultimate, values_fun.(attacker, rng))
      pick_action(actions ++ [entry], level, rng)
    else
      pick_action(actions, level, rng)
    end
  end

  @doc """
  LPC NewRandom 加权随机：越靠后的招式权重越大

  精确移植 `inherit/skill/skill.c#NewRandom/3`（base/d 参数未参与计算，省略）
  """
  @spec new_random(non_neg_integer(), rng()) :: non_neg_integer()
  def new_random(n, rng \\ &:rand.uniform/1) when n >= 0 do
    k = min(6, n)

    case k do
      0 ->
        n

      _ ->
        sum = div(k * (k - 1), 2)
        walk(n, k, lpc_random(rng, sum), 0)
    end
  end

  defp walk(n, k, remaining, i) when i < k do
    if remaining - i <= 0 do
      max(n - k + i, 0)
    else
      walk(n, k, remaining - i, i + 1)
    end
  end

  defp walk(n, _k, _remaining, _i), do: n
end
