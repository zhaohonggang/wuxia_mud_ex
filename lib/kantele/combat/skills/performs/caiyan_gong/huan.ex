defmodule Kantele.Combat.Skills.Performs.CaiyanGong.Huan do
  @moduledoc """
  云霞幻生「huan」（对照 `kungfu/skill/caiyan-gong/huan.c`）

  采燕功棍法绝招：须持 club 类武器，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加伤害。

  门槛（攻击方，逐条对齐 LPC）：已学此招 → 目标在战斗中 → 手持 club 类武器 →
  `caiyan-gong>=120` → `dodge>=180` → `mapped("club")=="caiyan-gong"` →
  `neili>=200` → 目标存活。

  攻击方广播起手式（两次插入武器名，`$N蓦地施出「云霞幻生」绝技…`）、
  发 `perform-incoming`；目标侧按 `ap/2 + rand(ap*4/3) > dp`
  （ap=club，dp=parry）判定命中：
  - 命中：扣 80 内力、忙乱 2，伤害 `50 + ap/6 + rand(ap/6)`（45% 外伤），
    文案 `$p大惊失色之下接连被$P击中数棍，当即疼痛难当，` +
    （`rand(3)>=1 且目标未忙乱` → `无暇反击。` 且目标忙乱 `damage/15`；否则 `急声长呼。`）；
  - 落空：扣 50 内力、忙乱 3，文案 `$n大惊之下急忙跃开数步…`。
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

  @perform_id "caiyan-gong/huan"
  @move_name "「云霞幻生」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon_name} <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_dodge(stats),
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # if (! objectp(weapon = me->query_temp("weapon")) ||
  #     (string)weapon->query("skill_type") != "club")
  #         return notify_fail("你使用的武器不对，难以施展" HUAN "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "club" do
      {:ok, Map.get(weapon, :name) || ""}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # if ((skill = me->query_skill("caiyan-gong", 1)) < 120)
  #         return notify_fail("你采燕功等级不够，难以施展" HUAN "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "caiyan-gong") < 120 do
      {:error, "你采燕功等级不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill("dodge") < 180)
  #         return notify_fail("你的轻功火候不够，难以施展" HUAN "。\n");
  defp check_dodge(stats) do
    if Stats.skill(stats, "dodge") < 180 do
      {:error, "你的轻功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill_mapped("club") != "caiyan-gong")
  #         return notify_fail("你没有激发采燕功，难以施展" HUAN "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "club") == "caiyan-gong" do
      :ok
    else
      {:error, "你没有激发采燕功，难以施展#{@move_name}。\n"}
    end
  end

  # if (me->query("neili") < 200)
  #         return notify_fail("你现在的真气不够，难以施展" HUAN "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon_name) do
    ap = Stats.skill(character.meta.stats, "club")

    # LPC: message_sort(HIM "\n$N" HIM "蓦地施出「" HIW "云霞幻生" HIM "」绝技，手中"
    #      + wn + HIM "由一变二，" "由二变四，由四变八，由八变十六……竟幻出"
    #      "无数根" + wn + HIM "。棍影层层叠叠朝四周" "疾刺而出，企图封锁$n"
    #      HIM "的退路。\n" NOR, me, target);
    opening =
      "$N蓦地施出「云霞幻生」绝技，手中" <>
        weapon_name <>
        "由一变二，由二变四，由四变八，由八变十六……竟幻出无数根" <>
        weapon_name <> "。棍影层层叠叠朝四周疾刺而出，企图封锁$n的退路。\n"

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

    # LPC: ap = me->query_skill("club"); dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap * 4 / 3) > dp)
    if div(ap, 2) + Engine.rand(rng, max(div(ap * 4, 3), 1)) > dp do
      # LPC: me->add("neili", -80); damage = 50 + ap / 6 + random(ap / 6);
      #      me->start_busy(2)
      damage = 50 + div(ap, 6) + Engine.rand(rng, max(div(ap, 6), 1))
      Performs.feedback(attacker, 80, 2)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 45, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC final(): base + (random(3) >= 1 && ! target->is_busy() → "无暇反击。" +
      #              target->start_busy(damage / 15) ; else → "急声长呼。")
      base = Messages.interpolate("$p大惊失色之下接连被$P击中数棍，当即疼痛难当，", bindings)

      if Engine.rand(rng, 3) >= 1 and character.meta.combat.busy == 0 do
        combat = Combat.start_busy(character.meta.combat, max(div(damage, 15), 1))
        character = %{character | meta: %{character.meta | combat: combat}}

        conn
        |> Broadcast.publish(base <> "无暇反击。\n")
        |> put_character(character)
      else
        conn
        |> Broadcast.publish(base <> "急声长呼。\n")
        |> put_character(character)
      end
    else
      # LPC: me->add("neili", -50); me->start_busy(3)
      Performs.feedback(attacker, 50, 3)

      Broadcast.publish(
        conn,
        Messages.interpolate("$n大惊之下急忙跃开数步，方才摆脱$N棍影的范围。\n", bindings)
      )
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
