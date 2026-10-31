defmodule Kantele.Combat.Skills.YunvXinfa do
  @moduledoc """
  武学实装「yunv-xinfa」（源 yunv-xinfa.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：difficult_level, exert_function_file, hit_ob, practice_skill, valid_force, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/yunv_xinfa/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "yunv-xinfa"

  @impl true
  def valid_enable(usage), do: usage in ["force"]

  @impl true
  def valid_force(force), do: force in ["suxin-jue", "quanzhen-xinfa"]

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    force = Stats.skill(stats, "force")
    max_neili = max_neili_of(character)

    cond do
      gender_of(character) == "无性" ->
        {:error, "你无根无性，阴阳难调，不能修习玉女心经。\n"}

      force < 150 ->
        {:error, "你的基本内功火候还不够，不能修习玉女心经。\n"}

      Stats.int(stats) < 32 ->
        {:error, "你的先天悟性不足，无法领悟玉女心经。\n"}

      not is_nil(max_neili) and max_neili < 2000 ->
        {:error, "你的内力修为不足，难以领会玉女心经。\n"}

      true ->
        :ok
    end
  end

  # LPC hit_ob（combatd.c:707 force 路径）：门控 lvl<150、neili<300、无武器、
  # random(force/6)<对手con、random(3)>1、未学成 wall → 不触发；sword 分支须
  # mapped sword==suxin-jian；whip 分支须 mapped whip==yinsuo-jinling。各自给对手追加
  # receive_damage(qi,db_local)+receive_wound(qi,db_local*2/3)，db_local = lvl/5(+random) 或 lvl/4(+random)。
  # 注：LPC 源以 query_skill("yunv-xinjing") 取自身等级（疑似源内别名），此处按本技能 id 取。
  # 未建模：攻击方 neili 自耗 -50、can_learn/yunv-xinjing/wall 门控。
  @impl true
  def hit_ob(attacker, victim, _db, _factor, rng) do
    lvl = Map.get(attacker.skills, id(), 0)
    force = Map.get(attacker.skills, "force", 0)

    if lvl < 150 or attacker.neili < 300 or is_nil(attacker.weapon_name) or
         Kantele.Combat.Engine.rand(rng, max(div(force, 6), 1)) < victim.con or
         Kantele.Combat.Engine.rand(rng, 3) > 1 or
         Map.get(attacker.mapped, "force") != id() do
      {0, nil}
    else
      wst = attacker.weapon_skill_type

      case {wst, Map.get(attacker.mapped, "sword"), Map.get(attacker.mapped, "whip")} do
        {"sword", "suxin-jian", _} ->
          yunv_wound(attacker, lvl, div(lvl, 5), rng,
            "$N手中" <> attacker.weapon_name <>
              "忽的一振，将玉女心经功力运于剑端，漫出无边寒意。\n")

        {"whip", _, "yinsuo-jinling"} ->
          yunv_wound(attacker, lvl, div(lvl, 4), rng,
            "$N一声娇喝，将玉女心经功力运至" <> attacker.weapon_name <>
              "之上，姿势妙曼，令人肃然起敬。\n")

        _ ->
          {0, nil}
      end
    end
  end

  defp yunv_wound(_attacker, _lvl, base, rng, msg) do
    db_local = base + Kantele.Combat.Engine.rand(rng, max(base, 1))
    extra = db_local + div(db_local * 2, 3)
    {max(extra, 0), msg, []}
  end

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  defp max_neili_of(%{meta: %{vitals: %{max_neili: max_neili}}}) when is_integer(max_neili),
    do: max_neili
  defp max_neili_of(_), do: nil

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions
end
