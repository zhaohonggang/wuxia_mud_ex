defmodule Kantele.Combat.Skills.LongxiangGong do
  @moduledoc """
  龙象般若功（对照 `kungfu/skill/longxiang-gong.c`）

  内功载体：`valid_enable("force")`，高层解锁 `parry`/`unarmed`；仅可学不可练。
  `valid_force` 接受 密宗内功/小无相/血刀大法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的复杂分层门槛（str/con/性别/lamaism/max_neili/unarmed 等）未完全实现，
    仅保留基本内力/等级检查；性别/层数/lamaism 检查标记 TODO。
  - `hit_ob` 被动（十龙十象/分层伤害）未接入。
  - powerup 中 `add_temp("str", layer*6)` 非 apply 键，本引擎未建模（保留状态与到期回收）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "longxiang-gong"

  @impl true
  def valid_enable(usage), do: usage in ["force", "parry", "unarmed"]

  @impl true
  def valid_force(force), do: force in ["mizong-neigong", "xiaowuxiang", "xuedao-dafa"]

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
end
