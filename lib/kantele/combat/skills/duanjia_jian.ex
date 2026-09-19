defmodule Kantele.Combat.Skills.DuanjiaJian do
  @moduledoc """
  段家剑法（对照 `kungfu/skill/duanjia-jian.c`）

  剑/杖法载体：`valid_enable("sword")`、`valid_enable("staff")`；
  `valid_force` 接受 基本剑法/基本杖法/段家剑法 共存。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的性别/性格限制未实现。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "duanjia-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "staff"]

  @impl true
  def valid_force(force), do: force in ["basic-sword", "basic-staff", "duanjia-jian"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的基本内功火候还不够。\n"}

      Stats.skill(stats, "duanjia-jian") > 0 && Stats.skill(stats, "force") < Stats.skill(stats, "duanjia-jian") ->
        {:error, "你的基本内功水平不够，难以修炼更深厚的段家剑法。\n"}

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
  def perform_list() do
    %{
      "lian" => Kantele.Combat.Skills.DuanjiaJian.Lian,
      "jing" => Kantele.Combat.Skills.DuanjiaJian.Jing
    }
  end
end

defmodule Kantele.Combat.Skills.DuanjiaJian.Lian do
  @moduledoc """
  五绝连环「lian」（对照 `kungfu/skill/duanjia-jian/lian.c`）

  门槛：杖/剑、段家剑法>=120、force>=150、neili>=300、目标存活且战斗中。
  连续 5 次攻击，每次可能使目标 busy 1。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "duanjia-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword", "staff"]

  @impl true
  def valid_force(force), do: force in ["basic-sword", "basic-staff", "duanjia-jian"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功修为不够，难以施展「五绝连环」。\n"}

      Stats.skill(stats, "duanjia-jian") > 0 && Stats.skill(stats, "force") < Stats.skill(stats, "duanjia-jian") ->
        {:error, "你的基本内功水平不够，难以修炼更深厚的段家剑法。\n"}

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
  def perform_list() do
    %{"lian" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "duanjia-jian/lian",
      kind: :perform,
      gates: [
        {:custom, &gate_weapon/1, "你使用的武器不对，难以施展「五绝连环」。\n"},
        {:custom, &gate_fighting/1, "「五绝连环」只能对战斗中的对手使用。\n"},
        {:skill_min, "duanjia-jian", 120, "你的段家剑法不够娴熟，难以施展「五绝连环」。\n"},
        {:custom, &gate_force/1, "你的内功修为不够，难以修炼更深厚的段家剑法。\n"},
        {:neili_min, 300, "你现在的真气不够，难以施展「五绝连环」。\n"},
        {:custom, &gate_target_alive/1, "对方那些那些费力吧？\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:custom, &effect_lian/1}
      ],
      busy: {:if_fighting, 1 + :rand.uniform(5)},
      message: "$N深吸一口气，脚下步步进击，稳重之极，手中的兵器使得犹如飞龙一般，缠绕向$n！\n"
    }
  end

  defp gate_weapon(ctx) do
    weapon = ctx.character.meta.equipped.weapon

    if weapon && weapon.meta.skill_type in ["staff", "sword"] do
      :ok
    else
      {:error, "你使用的武器不对，难以施展「五绝连环」。\n"}
    end
  end

  defp gate_fighting(ctx),
    do:
      if(ctx.character.meta.combat.busy > 0 || not Enum.empty?(ctx.character.meta.combat.enemies),
        do: :ok,
        else: {:error, "只能对战斗中的对手使用。\n"}
      )

  defp gate_force(ctx) do
    if Stats.skill(ctx.stats, "force") >= 150 do
      :ok
    else
      {:error, "你的内功修为不够，难以修炼更深厚的段家剑法。\n"}
    end
  end

  defp gate_target_alive(ctx),
    do:
      if(ctx.target && ctx.target.meta.vitals.alive?,
        do: :ok,
        else: {:error, "对方那些那些费力吧？\n"}
      )

  defp effect_lian(state) do
    # 5 次攻击
    {_final_state, _} =
      Enum.reduce_while(1..5, state, fn _, acc_state ->
        if acc_state.character.meta.combat.busy > 0 ||
             not Enum.empty?(acc_state.character.meta.combat.enemies) do
          {:halt, acc_state}
        else
          if :rand.uniform(5) == 0 && not acc_state.target.meta.combat.busy > 0 do
            new_target = %{acc_state.target | meta: %{acc_state.target.meta | combat: Map.put(acc_state.target.meta.combat, :busy, 1)}}
            acc_state = Map.put(acc_state, :target, new_target)
          end

          # 模拟攻击
          acc_state = Map.update(acc_state, :character, fn char ->
            %{
              char
              | meta: %{
                  char.meta
                  | vitals: %{acc_state.character.meta.vitals | neili: acc_state.character.meta.vitals.neili - 100}
              }
            }
          end)

          {:cont, acc_state}
        end
      end)

    # 最后设置 busy
    final_state = Map.update(state, :character, fn char ->
      %{char | meta: %{char.meta | combat: Map.put(char.meta.combat, :busy, 1 + :rand.uniform(5))}}
    end)

    {:halt, final_state}
  end
end

defmodule Kantele.Combat.Skills.DuanjiaJian.Jing do
  @moduledoc """
  惊天一剑「jing」（对照 `kungfu/skill/duanjia-jian/jing.c`）

  门槛：剑、段家剑法>=80、force>=120、neili>=300、目标存活且战斗中。
  内力对抗，成功造成 force+sword/5 + random 伤害、自身 busy 2、扣 neili damage。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "duanjia-jian"

  @impl true
  def valid_enable(usage), do: usage in ["sword"]

  @impl true
  def valid_force(force), do: force in ["basic-sword", "duanjia-jian"]

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功修为不够，难以施展「惊天一剑」。\n"}

      Stats.skill(stats, "duanjia-jian") < 80 ->
        {:error, "你的段家剑法不够娴熟，难以施展「惊天一剑」。\n"}

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
  def perform_list() do
    %{"jing" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "duanjia-jian/jing",
      kind: :perform,
      gates: [
        {:custom, &gate_sword/1, "你使用的武器不对，难以施展「惊天一剑」。\n"},
        {:custom, &gate_fighting/1, "「惊天一剑」只能对战斗中的对手使用。\n"},
        {:skill_min, "duanjia-jian", 80, "你的段家剑法不够娴熟，难以施展「惊天一剑」。\n"},
        {:skill_min, "force", 120, "你的内功修为不够，难以施展「惊天一剑」。\n"},
        {:neili_min, 300, "你现在的真气不够，难以施展「惊天一剑」。\n"},
        {:custom, &gate_target_alive/1, "对方那些那些费力吧？\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:custom, &effect_jing/1}
      ],
      busy: 0,
      message: "$N一跃而起，手腕一抖，挽出一个美丽的剑花，飞向$n而去。\n"
    }
  end

  defp gate_sword(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展「惊天一剑」。\n"}
    end
  end

  defp gate_fighting(ctx), do: if(ctx.character.meta.combat.busy > 0 || not Enum.empty?(ctx.character.meta.combat.enemies), do: :ok, else: {:error, "只能对战斗中的对手使用。\n"})
  defp gate_target_alive(ctx), do: if(ctx.target && ctx.target.meta.vitals.alive?, do: :ok, else: {:error, "对方那些那些费力吧？\n"})

  defp effect_jing(state) do
    char = state.character
    target = state.target

    ap = Stats.skill(char.meta.stats, "force")
    dp = Stats.skill(target.meta.stats, "force")

    success = :rand.uniform(ap) > div(dp, 2)

    if success do
      skill_force = Stats.skill(char.meta.stats, "force")
      skill_sword = Stats.skill(char.meta.stats, "sword")
      damage = div(skill_force + skill_sword, 5) + :rand.uniform(div(skill_force + skill_sword, 5))

      new_t_q = max(target.meta.vitals.qi - damage, 0)
      new_t_eff_q = max(target.meta.vitals.eff_qi - damage, 0)

      new_target = %{target | meta: %{target.meta | vitals: %{
          target.meta.vitals
          | qi: new_t_q,
            eff_qi: new_t_eff_q
        }}}

      new_char = %{
        char
        | meta: %{
            char.meta
            | vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - damage},
              combat: put_busy(char.meta.combat, 2)
          }
      }

      new_target = %{target | meta: %{target.meta | vitals: %{
          target.meta.vitals
          | qi: max(target.meta.vitals.qi - damage, 0),
            eff_qi: max(target.meta.vitals.eff_qi - damage, 0)
        }}}

      message = "只见#{"#{char.name}"}人剑合一，穿向#{"#{target.name}"}，#{"#{target.name}"}只觉一股热流穿心而过，喉头一甜，鲜血狂喷而出！\n"

      state
      |> Map.put(:character, new_char)
      |> Map.put(:target, new_target)
      |> Map.put(:message, message)
    else
      new_target = target
      new_char = %{char | meta: %{char.meta | vitals: %{char.meta.vitals | neili: char.meta.vitals.neili - 100}, combat: put_busy(char.meta.combat, 3)}}
      message = "可是#{"#{target.name}"}猛地向边上一跃，跳出了#{"#{char.name}"}的攻击范围。\n"

      state
      |> Map.put(:character, new_char)
      |> Map.put(:target, new_target)
      |> Map.put(:message, message)
    end
  end

  defp put_busy(combat, n), do: %{combat | busy: n}
end