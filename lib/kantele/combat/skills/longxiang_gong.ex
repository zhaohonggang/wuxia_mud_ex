defmodule Kantele.Combat.Skills.LongxiangGong do
  @moduledoc """
  龙象般若功（对照 `kungfu/skill/longxiang-gong.c`）

  内功载体：`valid_enable("force")`，高层解锁 `parry`/`unarmed`；仅可学不可练。
  `valid_force` 接受 密宗内功/小无相/血刀大法 共存。

  差异（TODO(migrate)）：
  - `hit_ob` 被动（十龙十象/分层伤害）未接入。
  - powerup 中 `add_temp("str", layer*6)` 非 apply 键，本引擎未建模（保留状态与到期回收）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "longxiang-gong"

  # LPC hit_ob（combatd.c:707 force 路径）：damage_bonus>=130、layer(=lvl/30,封顶13)>=6、
  # neili>=500、空手、force 与 unarmed 都映射到本技能、damage_bonus/6 >= 对手 con、
  # 且 random(10)>=5 时触发。layer>=10 且 random(2)==1 走「十龙十象」档
  # (damage_bonus-50)/3，否则 (damage_bonus-100)/3。
  # 未建模：me->add("neili",-80/-50) 自耗；secondary_weapon / prepared 门控。
  @impl true
  def hit_ob(attacker, victim, db, _factor, rng) do
    lvl = Map.get(attacker.skills, id(), 0)
    layer = min(div(lvl, 30), 13)

    if db < 130 or layer < 6 or attacker.neili < 500 or not is_nil(attacker.weapon_name) or
         Map.get(attacker.mapped, "force") != id() or Map.get(attacker.mapped, "unarmed") != id() or
         div(db, 6) < victim.con or Kantele.Combat.Engine.rand(rng, 10) < 5 do
      {0, nil}
    else
      {extra, msg} =
        if layer >= 10 and Kantele.Combat.Engine.rand(rng, 2) == 1 do
          {max(div(db - 50, 3), 0),
           "$N拳锋之上竟蕴藏着『十龙十象』之力，罡劲破体，摧毁了$n的真元！\n"}
        else
          {max(div(db - 100, 3), 0),
           "$N双拳暗含龙象般若功第#{layer}层功力，$n心脉受震，喷出一口鲜血！\n"}
        end

      {extra, msg, []}
    end
  end

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def valid_force(force), do: force in ["mizong-neigong", "xiaowuxiang", "xuedao-dafa"]

  @impl true
  def valid_learn(stats, character) do
    level = Stats.skill(stats, id())
    layer = div(level, 30)

    cond do
      # LPC `int valid_learn`（longxiang-gong.c:76-84）：str/con 两门在前，
      # 与 `gender == 无性 && layer >= 1` 一起构成 arity-2 才有的门槛。
      # 之前 E4 误把这三者削成 `con < 20`，导致 partial_batch1 回归。
      Stats.str(stats) < 36 ->
        {:error, "你的先天膂力孱弱，无法修炼龙象般若功。\n"}

      Stats.con(stats) < 30 ->
        {:error, "你的先天根骨孱弱，无法修炼龙象般若功。\n"}

      gender_of(character) == "无性" and layer >= 1 ->
        {:error, "你无根无性，阴阳不调，无法修炼龙象般若功。\n"}

      true ->
        valid_learn(stats)
    end
  end

  @impl true
  def valid_learn(stats) do
    force = Stats.skill(stats, "force")
    level = Stats.skill(stats, id())
    layer = div(level, 30)

    cond do
      force < 100 ->
        {:error, "你的基本内功火候不足，难以领会龙象般若功。\n"}

      force < level ->
        {:error, "你的基本内功水平不够，难以修炼更深厚的龙象般若功。\n"}

      layer >= 3 and Stats.skill(stats, "lamaism") < 100 ->
        {:error, "你对密宗心法理解不够，难以领会龙象般若功。\n"}

      true ->
        :ok
    end
  end

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: nil

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.LongxiangGong.Powerup,
      "shield" => Kantele.Combat.Skills.LongxiangGong.Shield
    }
  end
end

defmodule Kantele.Combat.Skills.LongxiangGong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/longxiang-gong/exert/powerup.c`）

  需 3 层（skill>=90）、500 内力，耗 100；
  attack=skill/3+layer*15, parry=skill/3, dodge=skill/3（LPC 另加 str=layer*6 未建模）；
  持续 skill 秒；战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "longxiang-gong/powerup",
      gates: [
        {:custom,
         fn ctx ->
           layer = div(Kantele.Character.Stats.skill(ctx.stats, "longxiang-gong"), 30)
           layer >= 3
         end, "你龙象般若功修为不够，难以运功。\n"},
        {:neili_min, 500, "你目前的真气不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack:
             {:add, {:div, {:skill, "longxiang-gong"}, 3},
              {:mul, {:div, {:skill, "longxiang-gong"}, 30}, 15}},
           parry: {:div, {:skill, "longxiang-gong"}, 3},
           dodge: {:div, {:skill, "longxiang-gong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "longxiang-gong"},
      expire_message: "你的龙象般若功运行完毕，将内力收回丹田。\n",
      message: fn ctx ->
        layer = div(Kantele.Character.Stats.skill(ctx.stats, "longxiang-gong"), 30)
        "$N运足龙象般若功第#{layer}层功力，全身骨骼节节暴响，罡气向四周扩散开来！\n"
      end
    }
end

defmodule Kantele.Combat.Skills.LongxiangGong.Shield do
  @moduledoc """
  护体「shield」（对照 `kungfu/skill/longxiang-gong/exert/shield.c`）

  需 3 层（skill>=90）、500 内力，耗 100；armor=skill/2，持续 skill 秒；
  战斗中 busy 2 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "longxiang-gong/shield",
      gates: [
        {:custom,
         fn ctx ->
           layer = div(Kantele.Character.Stats.skill(ctx.stats, "longxiang-gong"), 30)
           layer >= 3
         end, "你龙象般若功修为不够，难以运功。\n"},
        {:neili_min, 500, "你目前的真气不够。\n"},
        {:no_buff, "shield", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "shield",
         %{
           armor: {:div, {:skill, "longxiang-gong"}, 2}
         }}
      ],
      busy: {:if_fighting, 2},
      duration: {:skill, "longxiang-gong"},
      expire_message: "你的龙象般若功运行完毕，将内力收回丹田。\n",
      message: fn ctx ->
        layer = div(Kantele.Character.Stats.skill(ctx.stats, "longxiang-gong"), 30)
        "$N暗聚龙象般若功第#{layer}层功力，顿时一股白雾蒸腾而起，瞬间笼罩$N全身！\n"
      end
    }

  @impl true
  def perform_list() do
    %{
      "die" => Kantele.Combat.Skills.Performs.LongxiangGong.Die,
      "ji" => Kantele.Combat.Skills.Performs.LongxiangGong.Ji,
      "tun" => Kantele.Combat.Skills.Performs.LongxiangGong.Tun,
      "zhen" => Kantele.Combat.Skills.Performs.LongxiangGong.Zhen
    }
  end
end
