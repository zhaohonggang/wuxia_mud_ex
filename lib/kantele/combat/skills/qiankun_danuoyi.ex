defmodule Kantele.Combat.Skills.QiankunDanuoyi do
  @moduledoc """
  武学实装「qiankun-danuoyi」（源 qiankun-danuoyi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, query_effect_parry, skill_improved, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/qiankun_danuoyi/
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Conditions
  alias Kantele.Character.Stats

  @actions []

  @impl true
  def id(), do: "qiankun-danuoyi"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    qiankun = Map.get(victim.skills, "qiankun-danuoyi", 0)

    if qiankun < 100 do
      {damage, nil}
    else
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "force", 0) + mp
      dp = Map.get(victim.skills, "parry", 0)
      skill_ok = div(ap, 2) + rng.(max(ap, 1)) - 1 < dp

      big = skill_ok and
            victim.busy == 0 and
            qiankun > 350 and
            victim.max_neili * 2 / 3 > attacker.max_neili and
            rng.(30) - 1 == 1 and
            mp < 100

      if big do
        na = Map.get(attacker.mapped, attacker.attack_skill, attacker.attack_skill)
        {0,
         "$N一招攻出，却见$n迎身而上，冷笑道：「区区#{na}，能奈我何？」\n" <>
           "$n当即运起乾坤大挪移第七层心法，企图挪移$N的攻势。\n\n"}
      else
        if skill_ok do
          {0, qiankun_parry_msg(rng)}
        else
          if mp >= 100 do
            {damage, qiankun_fail_msg(rng)}
          else
            {damage, nil}
          end
        end
      end
    end
  end

  defp qiankun_parry_msg(rng) do
    case rng.(8) - 1 do
      0 -> "$N一招击在$n身上，却被$n暗运乾坤大挪移，将内力尽数移入地下。\n"
      1 -> "$n轻轻一带，$N发现自己招数回击过来，吓得往后倒退几步。\n"
      2 -> "$n手臂回转，在$N手肘下轻轻一推，$N招数落空。\n"
      3 -> "$n右手伸出，在$N手腕上轻轻一拉，$N收势不住，直往前扑去。\n"
      4 -> "$n身形不动，$N一招击下，有如石沉大海，不觉呆住了。\n"
      5 -> "$n左牵右引，$N如身处漩流，连续转了好几个圈子。\n"
      6 -> "$n双手回圈，$N只觉得前面好象有一堵墙，再也攻不进去。\n"
      _ -> "$n轻轻一转，$N一招击在地上，只打得尘土飞扬。\n"
    end
  end

  defp qiankun_fail_msg(rng) do
    case rng.(6) - 1 do
      0 -> "$n暗运乾坤大挪移，试图将内力尽数移入地下，然而$N早已勘破其中奥妙，内力变化莫测。\n"
      1 -> "$n轻轻一带，$N发现自己招数回击过来，急忙变招，身转如意，反让$n防不胜防。\n"
      2 -> "$n手臂回转，在$N手肘下轻轻一推，然而$N招数忽的一变，并未落空。\n"
      3 -> "$n右手伸出，在$N手腕上轻轻一拉，$N收势不住，顺势变招扑前直击。\n"
      4 -> "$n左牵右引，$N如身处漩流，顺势变招，圆转如意，随心所欲。\n"
      _ -> "$n双手回圈，$N只觉得前面好象有一堵墙，猛然警醒，聚力于一点，力攻对方。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["parry"]

  # LPC `valid_learn(object me)`（源 qiankun-danuoyi.c）
  # `query_condition("qiankun-except")` 已接入：E1 在 learn_command / skills_event 调用
  # valid_learn 前，把 session 态 conditions（`get_session(conn,"conditions")`）以
  # `:conditions` 键并入 character 快照，此处 guarded 读取即可。其余门槛
  # （性别/悟性/内力/内功/招架）已按 LPC 逐条保真迁移。
  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())
    gender = gender_of(character)
    family_name = family_name_of(character)
    max_neili = max_neili_of(character)
    conditions = Map.get(character, :conditions, %{})

    # LPC: layer = query_skill/50; if (layer > 7) layer = 7; if (family=="明教") layer = 1;
    layer = if family_name == "明教", do: 1, else: min(div(lvl, 50), 7)

    cond do
      gender == "无性" and lvl >= 50 ->
        {:error, "你试图按照心法修炼大挪移，却觉得心中一阵迷茫，难以继续。\n"}

      not is_nil(Conditions.query_condition(%{conditions: conditions}, "qiankun-except")) ->
        {:error, "你现在体内若冰、四肢皆寒、面赤如火，无法继续修炼神功。\n"}

      Stats.int(stats) < 29 + layer ->
        {:error, "你觉得乾坤大挪移实在是深奥无比，全然无法理解。\n"}

      Stats.int(stats) < 39 + layer - div(Stats.skill(stats, "force"), 50) and
          family_name != "明教" ->
        {:error, "你觉乾坤大挪移实在是深奥无比，全然无法理解。\n"}

      not is_nil(max_neili) and max_neili < 5000 ->
        {:error, "你的内力修为太差，无法修炼乾坤大挪移。\n"}

      Stats.skill(stats, "force") < 450 ->
        {:error, "你的内功火候不够，无法修炼乾坤大挪移。\n"}

      Stats.skill(stats, "parry") < lvl ->
        {:error, "你的基本招架火候有限，无法体会更高深的乾坤大挪移。\n"}

      Stats.skill(stats, "force") < lvl ->
        {:error, "你的基本内功火候有限，无法体会更高深的乾坤大挪移。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "nuoyi" => Kantele.Combat.Skills.Performs.QiankunDanuoyi.Nuoyi
    }
  end

  # LPC `me->query("gender")`
  defp gender_of(%{meta: %{env: %{gender: gender}}}), do: gender
  defp gender_of(_character), do: "男性"

  # LPC `me->query("family/family_name")`：无门派时 LPC 返回 0，
  # `0 != "少林派"` 为真 → 拦；nil 行为一致，无需额外守卫。
  defp family_name_of(%{meta: %{family: family}}) when is_map(family),
    do: Map.get(family, :name) || Map.get(family, "name")
  defp family_name_of(_character), do: nil

  # LPC `me->query("max_neili")`：vitals 里的上限值（不在 Stats 里）
  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: nil
end
