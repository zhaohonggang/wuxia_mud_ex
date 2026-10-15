defmodule Kantele.Combat.Skills.Performs.BaxianJian.Dian do
  @moduledoc """
  魁星点元「dian」（对照 `kungfu/skill/baxian-jian/dian.c`）

  八仙剑法绝招：须持 sword 类武器，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加伤害（并泄去目标内力）。

  门槛（攻击方，逐条对齐 LPC）：目标在战斗中、手持 sword 类武器、
  `force>=150`、`baxian-jian>=100`、`mapped("sword")=="baxian-jian"`、
  `neili>=250`。

  攻击方广播起手式（`$N施出「魁星点元」绝技…射向$n。`）、发 `perform-incoming`；
  目标侧按 `ap/2 + rand(ap) > dp`（ap=sword，dp=parry）判定命中：
  - 命中：伤害 `ap/2 + rand(ap*2/3)`（30% 外伤），并 `target->add("neili", -damage)`；
    文案 `结果$n不慎被$N剑尖荡出的剑气点中劳宫穴…`，攻击方扣 150 内力、忙乱 2；
  - 未中：`可是$p并不慌乱…格挡开了$P的剑招。`，攻击方扣 60 内力、忙乱 3。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "baxian-jian/dian"
  @move_name "「魁星点元」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon_name} <- check_weapon(combat),
         :ok <- check_force_level(stats),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, weapon_name)
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
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # if (! objectp(weapon = me->query_temp("weapon")) ||
  #     (string)weapon->query("skill_type") != "sword")
  #         return notify_fail("你使用的武器不对，难以施展" DIAN "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, Map.get(weapon, :name) || ""}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # if (me->query_skill("force") < 150)
  #         return notify_fail("你的内功的修为不够，难以施展" DIAN "。\n");
  defp check_force_level(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill("baxian-jian", 1) < 100)
  #         return notify_fail("你的八仙剑法修为不够，难以施展" DIAN "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "baxian-jian") < 100 do
      {:error, "你的八仙剑法修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill_mapped("sword") != "baxian-jian")
  #         return notify_fail("你没有激发八仙剑法，难以施展" DIAN "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "baxian-jian" do
      :ok
    else
      {:error, "你没有激发八仙剑法，难以施展#{@move_name}。\n"}
    end
  end

  # if (me->query("neili") < 250)
  #         return notify_fail("你现在真气不够，难以施展" DIAN "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon_name) do
    ap = Stats.skill(character.meta.stats, "sword")

    # LPC: msg = HIC "$N" HIC "施出「" HIR "魁星点元" HIC "」绝技，手中" + wn +
    #      HIC "微作龙吟，剑尖迸出一道剑气射向$n" HIC "。\n" NOR;
    opening =
      "$N施出「魁星点元」绝技，手中" <>
        weapon_name <> "微作龙吟，剑尖迸出一道剑气射向$n。\n"

    conn = Broadcast.publish(conn, opening, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{attacker: ref(character), perform_id: @perform_id, ap: ap}
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(character.meta.stats, "parry")

    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("sword"); dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap / 2 + random(ap * 2 / 3); me->start_busy(2); me->add("neili", -150)
      damage = div(ap, 2) + Engine.rand(rng, max(div(ap * 2, 3), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))

      # LPC final(): target->add("neili", -damage)（不低于 0）
      vitals = %{vitals | neili: max(vitals.neili - damage, 0)}
      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 150, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "结果$n不慎被$N剑尖荡出的剑气点中劳宫穴，全身真气不禁狂泄而出！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(3); me->add("neili", -60)
      Performs.feedback(attacker, 60, 3)

      Broadcast.publish(
        conn,
        Messages.interpolate("可是$p并不慌乱，收敛心神，轻轻格挡开了$P的剑招。\n", bindings)
      )
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
