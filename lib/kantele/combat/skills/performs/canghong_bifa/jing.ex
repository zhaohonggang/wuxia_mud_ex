defmodule Kantele.Combat.Skills.Performs.CanghongBifa.Jing do
  @moduledoc """
  惊虹一笔「jing」（对照 `kungfu/skill/canghong-bifa/jing.c`）

  苍虹笔法绝招：须持 dagger 类武器，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加伤害。

  门槛（攻击方，逐条对齐 LPC）：已学此招 → 目标在战斗中 → 手持 dagger 类武器 →
  `force>=150` → `neili>=500` → `canghong-bifa>=100` →
  `mapped("dagger")=="canghong-bifa"` → 目标存活。

  攻击方广播起手式（`$N手中<笔>大开大合…射向$n！`）、发 `perform-incoming`；
  目标侧按 `ap/2 + rand(ap) > dp`（ap=dagger，dp=parry）判定命中：
  - 命中：扣 200 内力、忙乱 1，伤害 `100 + ap/3 + rand(ap/2)`（50% 外伤），
    文案 `顿时只听得“噗嗤”一声，$n胸口被$N一笔刺中，溅出一柱鲜血。`；
    若 `ap/3 + rand(ap) > dp 且目标未忙乱` → 目标忙乱 `ap/25+1`；
  - 落空：扣 50 内力、忙乱 3，文案 `可是$p的看破了$P的招式…`。
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

  @perform_id "canghong-bifa/jing"
  @move_name "「惊虹一笔」"

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
         :ok <- check_neili(character),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats) do
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # if (! objectp(weapon = me->query_temp("weapon")) ||
  #     (string)weapon->query("skill_type") != "dagger")
  #         return notify_fail("你所使用的武器不对，难以施展" JING "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "dagger" do
      {:ok, Map.get(weapon, :name) || ""}
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # if (me->query_skill("force") < 150)
  #         return notify_fail("你的内功修为不够，难以施展" JING "。\n");
  defp check_force_level(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query("neili") < 500)
  #         return notify_fail("你现在的真气不足，难以施展" JING "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (skill < 100)
  #         return notify_fail("你苍虹笔法修为有限，难以施展" JING "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "canghong-bifa") < 100 do
      {:error, "你苍虹笔法修为有限，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill_mapped("dagger") != "canghong-bifa")
  #         return notify_fail("你没有激发苍虹笔法，难以施展" JING "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "dagger") == "canghong-bifa" do
      :ok
    else
      {:error, "你没有激发苍虹笔法，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon_name) do
    ap = Stats.skill(character.meta.stats, "dagger")

    # LPC: msg = HIM "$N" HIM "手中" + weapon->name() + HIM "大开大合，宛若天马行"
    #      "空，难测阴阳，化作一道道疾光射向$n" HIM "！\n" NOR;
    opening = "$N手中" <> weapon_name <> "大开大合，宛若天马行空，难测阴阳，化作一道道疾光射向$n！\n"

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

    # LPC: ap = me->query_skill("dagger"); dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: me->add("neili", -200); damage = 100 + ap / 3 + random(ap / 2);
      #      me->start_busy(1)
      damage = 100 + div(ap, 3) + Engine.rand(rng, max(div(ap, 2), 1))
      Performs.feedback(attacker, 200, 1)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 50, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: if (ap / 3 + random(ap) > dp && ! target->is_busy())
      #              target->start_busy(ap / 25 + 1);
      character =
        if div(ap, 3) + Engine.rand(rng, max(ap, 1)) > dp and
             character.meta.combat.busy == 0 do
          combat = Combat.start_busy(character.meta.combat, div(ap, 25) + 1)
          %{character | meta: %{character.meta | combat: combat}}
        else
          character
        end

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "顿时只听得“噗嗤”一声，$n胸口被$N一笔刺中，溅出一柱鲜血。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -50); me->start_busy(3)
      Performs.feedback(attacker, 50, 3)

      Broadcast.publish(
        conn,
        Messages.interpolate(
          "可是$p的看破了$P的招式，巧妙的一一拆解，没露半点破绽！\n",
          bindings
        )
      )
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
