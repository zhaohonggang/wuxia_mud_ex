defmodule Kantele.Combat.Fighter do
  @moduledoc """
  参战一方的战斗数据快照（纯数据，供 Engine 公式使用）

  对应 LPC do_attack/3 中通过 query_entire_dbase/query_temp 拿到的双方数据
  """

  defstruct [
    :id,
    :name,
    :pid,
    :room_id,
    :str,
    :dex,
    :con,
    :int,
    :combat_exp,
    :skills,
    :mapped,
    :applies,
    :busy,
    :jiali,
    :neili,
    :no_kill,
    :attack_skill,
    :weapon_name
  ]

  def new() do
    %__MODULE__{
      id: nil,
      name: "",
      pid: nil,
      room_id: nil,
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      combat_exp: 0,
      skills: %{},
      mapped: %{},
      applies: %{},
      busy: 0,
      jiali: 0,
      neili: 0,
      no_kill: false,
      attack_skill: "unarmed",
      weapon_name: nil
    }
  end

  @doc """
  从角色结构构建战斗快照（只依赖 meta：房间侧裁剪副本同样可用）

  武器决定攻击技能类型（LPC reset_action：weapon->skill_type，否则 unarmed）
  """
  def from_character(character) do
    stats = character.meta.stats
    combat = character.meta.combat

    applies = Kantele.Character.Combat.effective_applies(combat)
    weapon = Kantele.Character.Combat.weapon(combat)

    attack_skill =
      case weapon && Map.get(weapon, :skill_type) do
        nil -> "unarmed"
        "pin" -> "sword"
        type -> type
      end

    %__MODULE__{
      id: character.id,
      name: character.name,
      pid: character.pid,
      room_id: character.room_id,
      str: stats.str,
      dex: stats.dex,
      con: stats.con,
      int: stats.int,
      combat_exp: stats.combat_exp,
      skills: stats.skills,
      mapped: stats.mapped,
      applies: applies,
      busy: combat.busy,
      jiali: combat.jiali,
      neili: character.meta.vitals.neili,
      no_kill: no_kill?(character),
      attack_skill: attack_skill,
      weapon_name: weapon && Map.get(weapon, :name)
    }
  end

  defp no_kill?(%{meta: %{combat_config: %{no_kill: no_kill}}}) when not is_nil(no_kill),
    do: no_kill

  defp no_kill?(_), do: false
end

defmodule Kantele.Combat.Round do
  @moduledoc """
  一轮攻击的结算结果（伤害尚未结算进气血）

  `segments` 为带 `$N/$n/$l/$w` 占位符的文案片段，按序拼接后由
  `Kantele.Combat.Messages.interpolate/2` 替换为真实名字
  """

  defstruct [
    :outcome,
    :action,
    :limb,
    :damage,
    :wounded,
    :jiali_spent,
    segments: []
  ]
end

defmodule Kantele.Combat.Engine do
  @moduledoc """
  战斗命中管线（严格对照 `adm/daemons/combatd.c` 的 do_attack/4）

  流程：

  1. 选择招式（映射特技的招式表按等级加权，对应 NewRandom）
  2. `skill_power/3` 计算攻防当量，AP/(AP+DP) 判定闪避
  3. 招架 PP 判定（持械差 ±10 delta；busy 时 dp/pp 除三）
  4. 命中：`(apply/damage + random)/2` 起底，加招式 damage%、加力 jiali、
     force 百分比与力量 bonus；护甲 `random(apply/armor)` 折算创伤
  5. 伤害/创伤封顶折算（>200、>400 两档）

  所有随机数经 `rng/1` 注入（默认 `:rand.uniform/1`），便于单元测试。
  """

  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Round
  alias Kantele.Combat.Skills

  @type rng :: (pos_integer() -> pos_integer())

  @doc "LPC random(n)：返回 0..n-1"
  @spec rand(rng(), non_neg_integer()) :: non_neg_integer()
  def rand(_rng, n) when n < 1, do: 0
  def rand(rng, n), do: rng.(n) - 1

  @doc """
  经验边际递减（valid_power/1）：超过阈值的部分大幅缩水
  """
  def valid_power(exp) when exp < 2_000_000, do: exp
  def valid_power(exp) when exp < 3_000_000, do: 2_000_000 + div(exp - 2_000_000, 10)
  def valid_power(exp), do: 2_000_000 + 100_000 + div(exp - 3_000_000, 20)

  @doc """
  技能当量（skill_power/3）：level³ 经验边际递减，再按属性 /30 放大

  - 等级 < 1 时退化为 exp/2 * 属性 / 30
  - apply 表的 attack/defense 直接加到等级上
  """
  def skill_power(%Fighter{} = fighter, skill, usage) do
    level = Map.get(fighter.skills, skill, 0) + Map.get(fighter.applies, usage, 0)

    attr =
      case usage do
        :attack -> fighter.str
        _ -> fighter.dex
      end

    cond do
      level < 1 ->
        div(div(valid_power(fighter.combat_exp), 2), 30) * attr

      level > 500 ->
        power = div(level, 10) * level * level
        div(power + valid_power(fighter.combat_exp), 30) * attr

      true ->
        power = div(level * level * level, 10)
        div(power + valid_power(fighter.combat_exp), 30) * attr
    end
  end

  @doc """
  攻击一轮（do_attack 的纯函数化），返回 `%Round{}`
  """
  def attack_round(%Fighter{} = attacker, %Fighter{} = victim, opts \\ []) do
    rng = Keyword.get(opts, :rng, &:rand.uniform/1)

    action = select_action(attacker)

    round = %Round{
      outcome: :hit,
      action: action,
      limb: Messages.random_limb(rng),
      damage: 0,
      wounded: 0,
      jiali_spent: 0,
      segments: ["\n" <> Map.get(action, "action") <> "！\n"]
    }

    ap = max(skill_power(attacker, attacker.attack_skill, :attack), 1)
    dp = defense_power(victim, "dodge", 0, rng)

    if rand(rng, ap + dp) < dp do
      # (3) AP/(AP+DP)：闪避成功
      %{round | outcome: :dodge, segments: round.segments ++ [Messages.dodge_msg()]}
    else
      parry_check(attacker, victim, round, ap, rng)
    end
  end

  defp parry_check(attacker, victim, round, ap, rng) do
    pp = defense_power(victim, "parry", weapon_delta(attacker, victim), rng)

    if rand(rng, ap + pp) < pp do
      # (4) AP/(AP+PP)：招架成功
      %{round | outcome: :parry, segments: round.segments ++ [Messages.parry_msg()]}
    else
      damage_calc(attacker, victim, round, rng)
    end
  end

  # 防守当量：busy 时除三（heart_beat 的 dp/3），下限 1
  defp defense_power(victim, skill, delta, _rng) do
    power =
      victim
      |> skill_power(skill, :defense)
      |> Kernel.+(delta)
    power =
      case victim.busy > 0 do
        true -> div(power, 3)
        false -> power
      end

    max(power, 1)
  end

  # 空手对持械吃亏、持械对空手占优（combatd.c delta ±10）
  defp weapon_delta(attacker, victim) do
    case {attacker.weapon_name != nil, victim.weapon_name != nil} do
      {false, true} -> 10
      {true, false} -> -10
      _ -> 0
    end
  end

  # ---- (5) 命中后的伤害计算 ----

  defp damage_calc(attacker, victim, round, rng) do
    base = Map.get(attacker.applies, damage_key(attacker.attack_skill), 0)
    damage = div(base + rand(rng, base), 2)
    damage = damage + div(Map.get(round.action, "damage", 0) * damage, 100)

    # LPC：damage_bonus 以基础膂力起底，再加力(jiali)/招式 force%
    {jiali, jiali_spent} = jiali_bonus(attacker)
    damage_bonus = force_bonus(round, attacker.str + jiali)

    damage =
      if damage_bonus > 0 do
        damage + div(damage_bonus + rand(rng, damage_bonus), 3)
      else
        damage
      end

    # 创伤 = 伤害减去 random(apply/armor)，约 1/2 概率生效（LPC random(3)==1 等），
    # 随后各自封顶
    armor = max(Map.get(victim.applies, :armor, 0), 0)

    {wounded, damage} =
      wound_split(damage - rand(rng, armor), damage, rng)

    # 攻击者根骨影响创伤（con 效果）
    wounded = wounded |> Kernel.-(div(wounded * (attacker.con - 10), 100)) |> max(0)

    # 高身法偶发卸掉整击伤害（dex 效果）
    damage =
      if rand(rng, 100) < div(attacker.dex - 10, 4) + 2 do
        0
      else
        damage
      end

    segments =
      case damage > 0 do
        true ->
          round.segments ++
            [Messages.damage_msg(damage, Map.get(round.action, "damage_type"))]

        false ->
          round.segments ++ [Messages.no_damage_msg()]
      end

    %Round{
      round
      | damage: damage,
        wounded: wounded,
        jiali_spent: jiali_spent,
        segments: segments
    }
  end

  # 创伤概率门（LPC random(3)==1 或主动杀意下同样判定 ≈ 1/2）：掷中才结算创伤
  defp wound_split(raw_wound, damage, _rng) when raw_wound < 1, do: {0, cap(damage)}

  defp wound_split(raw_wound, damage, rng) do
    case rand(rng, 2) do
      0 -> {cap(raw_wound), cap(damage)}
      _ -> {0, cap(damage)}
    end
  end

  defp damage_key("unarmed"), do: :unarmed_damage
  defp damage_key(_skill), do: :damage

  # 加力：内力富余时以 jiali 点内力换取等量伤害加成
  defp jiali_bonus(attacker) do
    if attacker.jiali > 0 and attacker.neili > attacker.jiali do
      {attacker.jiali, attacker.jiali}
    else
      {0, 0}
    end
  end

  # 招式 force 字段按百分比放大 bonus（action["force"] 效果）
  defp force_bonus(round, damage_bonus) do
    case Map.get(round.action, "force", 0) do
      force when is_integer(force) and force > 0 ->
        damage_bonus + div(force * damage_bonus, 100)

      _ ->
        damage_bonus
    end
  end

  # 伤害封顶折算（>400 与 >200 两档）
  defp cap(value) when value > 400, do: div(value - 400, 4) + 300
  defp cap(value) when value > 200, do: div(value - 200, 2) + 200
  defp cap(value), do: value

  # ---- 招式选择 ----

  @doc """
  选定本轮招式：优先用映射特技的招式表（query_action），否则用通用拳脚
  """
  def select_action(%Fighter{} = attacker) do
    mapped = Map.get(attacker.mapped, attacker.attack_skill)

    case mapped && Skills.get(mapped) do
      nil ->
        level = Map.get(attacker.skills, attacker.attack_skill, 0)
        Skills.DefaultActions.query_action(attacker.attack_skill, level)

      skill_module ->
        level = Map.get(attacker.skills, mapped, 0)
        skill_module.query_action(level)
    end
  end
end
