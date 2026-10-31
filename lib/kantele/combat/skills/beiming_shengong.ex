defmodule Kantele.Combat.Skills.BeimingShengong do
  @moduledoc """
  北冥神功（对照 `kungfu/skill/beiming-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 逍遥心法/小无相/北冥神功 共存。

  差异（TODO(migrate)）：
  - `suck`（吸功）需空手、等级>=90、目标人类且战斗中、
    内功对抗成功扣目标 max_neili、增自身 max_neili，
    有冷却 temp "sucked"。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "beiming-shengong"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "beiming-shengong", 0) < 70 or
         Map.get(attacker.mapped, "force") == "taixuan-gong" or
         attacker.jiali < 1 do
      {damage, nil}
    else
      ap = Map.get(attacker.skills, "force", 0)
      dp = Map.get(victim.skills, "force", 0)

      if div(ap, 2) + rng.(max(ap, 1)) - 1 < dp do
        {0, beiming_msg(rng)}
      else
        {damage, nil}
      end
    end
  end

  defp beiming_msg(rng) do
    case rng.(4) - 1 do
      0 -> "$N只觉得内力源源而泻，不由得大吃一惊。\n"
      1 -> "$N只觉得发出的内力犹如石沉大海，不知所踪。\n"
      2 -> "$N只觉得发出的内力犹无影无踪，浑然不知着落。\n"
      _ -> "$N不住催动内力，但是只觉得$n竟似毫不费力。\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["xiaoyao-xinfa", "xiaowuxiang", "beiming-shengong"]

  @impl true
  def valid_learn(stats, character) do
    lvl = Stats.skill(stats, id())

    cond do
      gender_of(character) == "无性" and lvl > 49 ->
        {:error, "你无根无性，阴阳不调，难以领会高深的北冥神功。\n"}

      Stats.int(stats) < 32 ->
        {:error, "你觉得北冥神功艰深无比，难以领会。\n"}

      Stats.con(stats) < 24 ->
        {:error, "你试着运转了一下内力，眼前登时一黑！\n"}

      true ->
        :ok
    end
  end

  defp gender_of(%{meta: %{env: %{gender: gender}}}) when is_binary(gender), do: gender
  defp gender_of(_), do: "男性"

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.BeimingShengong.Powerup,
      "shield" => Kantele.Combat.Skills.Performs.BeimingShengong.Shield,
      "suck" => Kantele.Combat.Skills.BeimingShengong.Suck
    }
  end

  @impl true
  def perform_list() do
    %{
      "suck" => Kantele.Combat.Skills.BeimingShengong.Suck
    }
  end
end

defmodule Kantele.Combat.Skills.BeimingShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/beiming-shengong/powerup.c`）

  门槛（按 .c 顺序）：目标为自身 → neili>=500 → 未在运功。
  扣 100 真气；attack=defense=北冥/3，持续 北冥 秒；
  战斗中 busy `1+random(3)`；到期回收。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "beiming-shengong/powerup",
      gates: [
        # LPC: if (target != me) return notify_fail("你只能用北冥神功提升自己的战斗力。\n");
        # exert 恒以自身为目标，此门槛恒真，仅保留文案以对齐 .c。
        {:custom, fn _ -> true end, "你只能用北冥神功提升自己的战斗力。\n"},
        {:neili_min, 500, "你的内力不够!\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "beiming-shengong"}, 3},
           defense: {:div, {:skill, "beiming-shengong"}, 3}
         }}
      ],
      # LPC: if (me->is_fighting()) me->start_busy(1 + random(3));
      # {:random, min, max} 含端点，故 {:random, 1, 3} 即 1 + random(3)
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "beiming-shengong"},
      expire_message: "你的北冥神功运行完毕，将内力收回丹田。\n",
      message: "$N将内力运遍浑身诸大要穴，然后收气丹田，双目一睁，登时精光四射！\n"
    }
end

defmodule Kantele.Combat.Skills.BeimingShengong.Suck do
  @moduledoc """
  吸功「suck」（对照 `kungfu/skill/beiming-shengong/suck.c`）

  门槛：北冥>=90、空手、非 no_fight、目标人类存活、
  自身 max_neili < current_neili_limit、目标 max_neili>=100、
  目标 max_neili >= 自身/5、目标非太玄功。
  内力对抗成功：扣目标 max_neili、增自身 max_neili（按差距递减）、
  双方 busy、设 temp "sucked" 冷却。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "beiming-shengong/suck"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_empty_handed(character),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_can_absorb_more(character),
         :ok <- check_target_has_neili(target),
         :ok <- check_target_not_weak(character, target),
         :ok <- check_not_taixuan(target),
         :ok <- check_not_cooldown(character) do
      apply_perform(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] ->
        if not enemy.meta.combat.dead do
          {:ok, enemy}
        else
          {:error, "你要吸取谁的丹元？\n"}
        end

      [] ->
        {:error, "你要吸取谁的丹元？\n"}
    end
  end

  defp check_empty_handed(character) do
    if is_nil(Map.get(character.meta.combat.equipped || %{}, :weapon)) do
      :ok
    else
      {:error, "你必须空手才能施用北冥神功吸人丹元！\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "beiming-shengong") >= 90 do
      :ok
    else
      {:error, "你的北冥神功功力不够，不能吸取对方的丹元！\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili >= 20 do
      :ok
    else
      {:error, "你的内力不够，不能使用北冥神功。\n"}
    end
  end

  defp check_can_absorb_more(character) do
    my_max = character.meta.vitals.max_neili
    limit = Map.get(character.meta.stats, :max_neili_limit) || my_max * 2

    if my_max < limit do
      :ok
    else
      {:error, "你的内功水平有限，再吸取也是徒劳。\n"}
    end
  end

  defp check_target_has_neili(target) do
    if target.meta.vitals.max_neili >= 100 do
      :ok
    else
      # LPC: notify_fail(target->name() + "丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n");
      {:error, "#{target.name}丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n"}
    end
  end

  defp check_target_not_weak(character, target) do
    my_max = character.meta.vitals.max_neili
    tg_max = target.meta.vitals.max_neili

    if tg_max >= div(my_max, 5) do
      :ok
    else
      # LPC: notify_fail(target->name() + "的内功修为远不如你，你无法从他体内吸取丹元！\n");
      {:error, "#{target.name}的内功修为远不如你，你无法从他体内吸取丹元！\n"}
    end
  end

  defp check_not_taixuan(target) do
    if Map.get(target.meta.stats.mapped || %{}, "force") != "taixuan-gong" do
      :ok
    else
      {:error, "目标运行太玄真气将吸功反弹回去。\n"}
    end
  end

  defp check_not_cooldown(character) do
    if not (character.meta.combat.buffs |> Enum.any?(&(&1.key == "sucked"))) do
      :ok
    else
      {:error, "你刚刚吸取过丹元！\n"}
    end
  end

  defp apply_perform(conn, character, target) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 10}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N全身一振，伸出右手，轻轻握在$n的手臂上。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: Stats.skill(character.meta.stats, "beiming-shengong"),
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)

    sp = Stats.skill(attacker.meta.stats, "force")
    dp = Stats.skill(character.meta.stats, "force")

    success = sp + rng.(sp) > dp + rng.(dp)

    if success do
      beiming_lvl = Stats.skill(attacker.meta.stats, "beiming-shengong")
      sucked = 1 + div(beiming_lvl - 90, 10)
      sucked = max(sucked, 1)

      my_max = attacker.meta.vitals.max_neili
      tg_max = character.meta.vitals.max_neili

      sucked =
        cond do
          my_max > tg_max + 100 -> div(sucked, 2)
          my_max > tg_max + 200 -> div(sucked, 2)
          my_max > tg_max + 400 -> div(sucked, 2)
          my_max > tg_max + 800 -> div(sucked, 2)
          my_max > tg_max + 1600 -> div(sucked, 2)
          my_max > tg_max + 3200 -> div(sucked, 2)
          true -> sucked
        end

      if sucked < 1 do
        new_target = %{
          character
          | meta: %{
              character.meta
              | combat: Combat.start_busy(character.meta.combat, 2)
            }
        }

        message = "可是你发现对方内力似乎弱过你太多，一时难以吸收以为己用。\n"

        conn =
          conn
          |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
          |> put_character(new_target)

        Performs.feedback(attacker, %{
          neili_cost: 10,
          busy: 4
        })

        conn
      else
        new_tg_max = max(character.meta.vitals.max_neili - sucked, 0)

        new_target = %{
          character
          | meta: %{
              character.meta
              | vitals: %{character.meta.vitals | max_neili: new_tg_max},
                combat: Combat.start_busy(character.meta.combat, 2)
            }
        }

        message = "你觉得" <> character.name <> "的丹元自手掌源源不绝地流了进来。\n"

        conn =
          conn
          |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
          |> put_character(new_target)

        Performs.feedback(attacker, %{
          neili_cost: 10,
          busy: 4,
          gain_max_neili: sucked
        })

        conn
      end
    else
      new_target = %{
        character
        | meta: %{
            character.meta
            | combat: Combat.start_busy(character.meta.combat, 6)
          }
      }

      # LPC: message_combatd(HIY "可是$p" HIY "看破了$P" HIY
      #                       "的企图，机灵地溜了开去。\n" NOR, me, target);
      # （$p = target 本人，$P = 攻击方，故目标读到「可是你看破了<攻击方>的企图」）
      message = "可是你看破了" <> attacker.name <> "的企图，机灵地溜了开去。\n"

      conn =
        conn
        |> Broadcast.publish(message, n1: attacker.name, n2: character.name)
        |> put_character(new_target)

      Performs.feedback(attacker, %{
        neili_cost: 10,
        busy: 6
      })

      conn
    end
  end

  defp ref(character) do
    %{
      id: character.id,
      pid: character.pid,
      name: character.name,
      room_id: character.room_id,
      meta: character.meta
    }
  end
end
