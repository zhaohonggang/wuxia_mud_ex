defmodule Kantele.Combat.Skills.Performs.BaguaDao.Mang do
  @moduledoc """
  劈天神芒「mang」（对照 `kungfu/skill/bagua-dao/mang.c`）

  八卦刀法绝招：须持 blade 类武器，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加伤害。

  门槛（攻击方，逐条对齐 LPC）：目标在战斗中、手持 blade 类武器、
  `force>=200`、`wai-bagua>=140`、`bagua-dao>=140`、
  `mapped("blade")=="bagua-dao"`、`neili>=200`。

  攻击方广播起手式（`$N脚踏八卦四方之位…团团裹住！`）、发 `perform-incoming`；
  目标侧按 `ap/2 + rand(ap) > dp`（ap=blade，dp=parry）判定命中：
  - 命中：`只听$n一声惨叫，一蓬血雨自亮白的刀芒中飞溅而出！`，攻击方扣 150 内力、忙乱 2；
  - 未中：`可是$p眼明手快…将$P的招式全部挡开！`，攻击方扣 60 内力、忙乱 3。

  差异（TODO(migrate)）：
  - LPC 命中伤害 `do_damage(qi, ap/2+rand(ap), 75)`，本版以 `qi` 气血 + 75% 外伤近似。
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

  @perform_id "bagua-dao/mang"
  @move_name "「劈天神芒」"

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
         :ok <- check_wai_bagua(stats),
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
  #         return notify_fail("你使用的武器不对，难以施展" MANG "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      {:ok, Map.get(weapon, :name) || ""}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # if (me->query_skill("force") < 200)
  #         return notify_fail("你的内功的修为不够，难以施展" MANG "。\n");
  defp check_force_level(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill("wai-bagua", 1) < 140)
  #         return notify_fail("你的外八卦神功修为不够，难以施展" MANG "。\n");
  defp check_wai_bagua(stats) do
    if Stats.skill(stats, "wai-bagua") < 140 do
      {:error, "你的外八卦神功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill("bagua-dao", 1) < 140)
  #         return notify_fail("你的八卦刀法修为不够，难以施展" MANG "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "bagua-dao") < 140 do
      {:error, "你的八卦刀法修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill_mapped("blade") != "bagua-dao")
  #         return notify_fail("你没有激发八卦刀法，难以施展" MANG "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "bagua-dao" do
      :ok
    else
      {:error, "你没有激发八卦刀法，难以施展#{@move_name}。\n"}
    end
  end

  # if (me->query("neili") < 200)
  #         return notify_fail("你的真气不够，难以施展" MANG "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon_name) do
    ap = Stats.skill(character.meta.stats, "blade")

    # LPC: msg = HIW "$N" HIW "脚踏八卦四方之位，陡然一振手中" + weapon->name() +
    #      HIW "，刀身顿时卷起阵阵雪亮刀芒，将$n" + HIW "团团裹住！\n" NOR;
    opening =
      Enum.join(
        [
          "$N脚踏八卦四方之位，陡然一振手中",
          weapon_name,
          "，刀身顿时卷起阵阵雪亮刀芒，将$n",
          "团团裹住！\n"
        ],
        ""
      )

    conn =
      Broadcast.publish(conn, opening, n1: character.name, n2: target.name)

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

    # LPC: ap = me->query_skill("blade"); dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap / 2 + random(ap); me->add("neili", -150); me->start_busy(2)
      damage = div(ap, 2) + Engine.rand(rng, max(ap, 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 75, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 150, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "只听$n一声惨叫，一蓬血雨自亮白的刀芒中飞溅而出！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -60); me->start_busy(3)
      Performs.feedback(attacker, 60, 3)

      Broadcast.publish(
        conn,
        Messages.interpolate(
          "可是$p眼明手快，只听叮叮当当响起了一串刀鸣，$p将$P的招式全部挡开！\n",
          bindings
        )
      )
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
