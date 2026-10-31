defmodule Kantele.Combat.Skills.DouzhuanXingyi do
  @moduledoc """
  武学实装「douzhuan-xingyi」（源 douzhuan-xingyi.c，由 translate_skill.exs 生成）

  已自动化：静态招式 0 式、valid_enable、practice_cost。
  TODO(migrate): 人工迁移中...：
  - 动态招式 0 式（值含 this_player/query_skill/random，
    需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
  - 源码钩子/条件：perform_action_file, practice_skill, valid_damage, valid_learn
  - perform/exert 路由骨架见 tmp/perf_out/douzhuan_xingyi/
  """

  use Kantele.Combat.Skill

  @actions []

  @impl true
  def id(), do: "douzhuan-xingyi"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    lvl = Map.get(victim.skills, "douzhuan-xingyi", 0)
    zihui = Map.get(victim.skills, "zihui-xinfa", 0)

    if lvl < 100 or zihui < 100 do
      {damage, nil}
    else
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "force", 0) + mp
      dp = Map.get(victim.skills, "parry", 0)
      ran = douzhuan_ran(lvl)

      if lvl > 200 and zihui > 200 and victim.busy == 0 and victim.neili > attacker.neili and
           victim.neili > 500 and mp < 100 and rng.(ran) - 1 == 0 do
        ap2 = Map.get(victim.skills, "parry", 0)
        dp2 = Map.get(attacker.skills, "force", 0)

        msg =
          if div(dp2, 2) + rng.(max(dp2, 1)) - 1 < ap2 do
            "$N默运紫徽心法，施展起绝学「斗转星移」，一股真气在体内迅速惯行，巧妙地牵引着$n的招式。\n" <>
              "$n大吃一惊，不料$N竟将先前的招式尽数折回反攻向自己。\n猛然间$n一声惨呼，已然闪避不及。\n"
          else
            "$n眼见$N来势汹涌，不敢大意，施出浑身解数化解开来。\n"
          end

        {0, msg}
      else
        if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
          {0, douzhuan_msg(rng)}
        else
          if mp >= 100 do
            {damage, douzhuan_fail_msg(rng)}
          else
            {damage, nil}
          end
        end
      end
    end
  end

  defp douzhuan_ran(lvl) do
    cond do
      lvl > 500 -> 4
      lvl > 450 -> 6
      lvl > 400 -> 8
      lvl > 360 -> 10
      lvl > 320 -> 15
      lvl > 280 -> 20
      lvl > 240 -> 25
      true -> 30
    end
  end

  defp douzhuan_msg(rng) do
    case rng.(3) - 1 do
      0 -> "$n身形忽然转个不停，$N这一招竟然无从下手。\n"
      1 -> "$n单掌一托，$N登时拿捏不准力道，不禁泛起一阵有心无力的感觉。\n"
      _ -> "$N一招眼看击中了$n，然而$n轻轻一卸，将$N的攻击化解于无形。\n"
    end
  end

  defp douzhuan_fail_msg(rng) do
    case rng.(3) - 1 do
      0 -> "$n身形忽然转个不停，然而$N早已看穿其中奥妙，丝毫不受影响，挥招直入。\n"
      1 -> "$n单掌一托，$N忽感拿捏不准力道，蓦然警醒，登时变化招式。\n"
      _ -> "$n轻轻一卸力，但是$N已然看出其中四两拨千金的变化，左右腾挪，让$n如意算盘就此落空。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["parry"]

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @impl true
  def perform_list() do
    %{
      "yi" => Kantele.Combat.Skills.Performs.DouzhuanXingyi.Yi
    }
  end
end
