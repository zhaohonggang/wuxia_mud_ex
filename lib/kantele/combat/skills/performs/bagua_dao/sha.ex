defmodule Kantele.Combat.Skills.Performs.BaguaDao.Sha do
  @moduledoc """
  杀龙无悔「sha」（对照 `kungfu/skill/bagua-dao/sha.c`）

  八卦刀法绝招：须持 blade 类武器，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加伤害。

  门槛（攻击方，逐条对齐 LPC）：目标在战斗中、手持 blade 类武器、
  `force>=250`、`bagua-dao>=180`、`mapped("blade")=="bagua-dao"`、`neili>=300`。

  攻击方广播起手式（`$N仰天清啸…直贯$n而去！`）、发 `perform-incoming`；
  目标侧按 `ap/2 + rand(ap) > dp`（ap=blade+str*10，dp=force+con*10）判定命中：
  - 命中：`只听$n一声惨叫，$N<刀>刀锋一闪，竟已嵌入$p体内尺许…`，攻击方扣 200 内力、忙乱 3；
  - 未中：`$n见$P来势汹涌…躲闪开来。`，攻击方扣 100 内力、忙乱 4。

  差异（TODO(migrate)）：
  - LPC 命中伤害 `do_damage(qi, ap/2+rand(ap), 85)`，本版以 `qi` 气血 + 85% 外伤近似。
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

  @perform_id "bagua-dao/sha"
  @move_name "「杀龙无悔」"

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
  #     (string)weapon->query("skill_type") != "blade")
  #         return notify_fail("你使用的武器不对，难以施展" SHA "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      {:ok, Map.get(weapon, :name) || ""}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # if (me->query_skill("force") < 250)
  #         return notify_fail("你的内功修为不够，难以施展" SHA "。\n");
  defp check_force_level(stats) do
    if Stats.skill(stats, "force") < 250 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill("bagua-dao", 1) < 180)
  #         return notify_fail("你的八卦刀法修为不够，难以施展" SHA "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "bagua-dao") < 180 do
      {:error, "你的八卦刀法修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill_mapped("blade") != "bagua-dao")
  #         return notify_fail("你没有激发八卦刀法，难以施展" SHA "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "bagua-dao" do
      :ok
    else
      {:error, "你没有激发八卦刀法，难以施展#{@move_name}。\n"}
    end
  end

  # if (me->query("neili") < 300)
  #         return notify_fail("你的真气不够，难以施展" SHA "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon_name) do
    stats = character.meta.stats
    # LPC: ap = me->query_skill("blade") + me->query_str() * 10
    ap = Stats.skill(stats, "blade") + Stats.query_str(stats) * 10

    # LPC: msg = HIR "$N" HIR "仰天清啸，手中" + weapon->name() +
    #      HIR "斜划出一道半弧，整个刀身顿时腾起凛冽无比的"
    #      "杀气，直贯$n" HIR "而去！\n" NOR;
    opening =
      "$N仰天清啸，手中" <>
        weapon_name <> "斜划出一道半弧，整个刀身顿时腾起凛冽无比的杀气，直贯$n而去！\n"

    conn = Broadcast.publish(conn, opening, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        weapon_name: weapon_name
      }
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
    weapon_name = Map.get(data, :weapon_name, "")
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats

    # LPC: dp = target->query_skill("force") + target->query_con() * 10
    dp = Stats.skill(stats, "force") + Stats.query_con(stats) * 10

    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap / 2 + random(ap); me->add("neili", -200); me->start_busy(3)
      damage = div(ap, 2) + Engine.rand(rng, max(ap, 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 85, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 200, 3)

      head = Messages.interpolate("只听$n一声惨叫，$N", bindings)

      tail = Messages.interpolate("刀锋一闪，竟已嵌入$p体内尺许，带出一蓬血雨。\n", bindings)

      conn
      |> Broadcast.publish(head <> weapon_name <> tail)
      |> put_character(character)
    else
      # LPC: me->add("neili", -100); me->start_busy(4)
      Performs.feedback(attacker, 100, 4)

      Broadcast.publish(
        conn,
        Messages.interpolate(
          "$n见$P来势汹涌，不敢轻易抵挡，连忙飞身腾挪，躲闪开来。\n",
          bindings
        )
      )
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
