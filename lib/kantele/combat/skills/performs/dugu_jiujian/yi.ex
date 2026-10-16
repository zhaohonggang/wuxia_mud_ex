defmodule Kantele.Combat.Skills.Performs.DuguJiujian.Yi do
  @moduledoc """
  弘意式「yi」（对照 `kungfu/skill/dugu-jiujian/yi.c`，inherit F_SSERVER）

  独孤九剑（剑 sword）攻击绝招：要求 duigu-jiujian >= 90、剑已激发映射；
  起始文案按 `switch(random(3))` 三选一；命中判定 `ap/2 + random(ap) > dp`，
  其中 `ap = sword + martial-cognize`，`dp = parry + martial-cognize +
  dugu-jiujian`（均为目标侧）；命中伤害 `damage = ap + random(ap)`（外伤 50%）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "dugu-jiujian/yi"
  @move_name "「弘意式」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_can_learn(character),
         :ok <- check_skill_level(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (me->query("can_learn/dugu-jiujian/nothing"))
  #          return notify_fail("你所使用的外功中没有这种功能。\n");
  defp check_can_learn(character) do
    if Map.get(character_marks(character), :"can_learn/dugu-jiujian/nothing") do
      {:error, "你所使用的外功中没有这种功能。\n"}
    else
      :ok
    end
  end

  # LPC: if (skill < 90) return notify_fail("你所使用的外功中没有这种功能。\n");
  # NOTE: LPC 两处返回同一文案，需保留两次该字面量。
  defp check_skill_level(stats) do
    if Stats.skill(stats, "dugu-jiujian") < 90 do
      {:error, "你所使用的外功中没有这种功能。\n"}
    else
      :ok
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "dugu-jiujian" do
      :ok
    else
      {:error, "你没有激发独孤九剑，难以施展#{@move_name}。\n"}
    end
  end

  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    # LPC: switch (random(3)) { case 0: ...; case 1: ...; default: ... }
    start_msg = start_message(Engine.rand(&:rand.uniform/1, 3))
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: ap = me->query_skill("sword") + me->query_skill("martial-cognize",1);
    #      dp = target->query_skill("parry") + target->query_skill("martial-cognize",1)
    #         + target->query_skill("dugu-jiujian");
    ap = Stats.skill(stats, "sword") + Stats.skill(stats, "martial-cognize")

    dp =
      Stats.skill(target.meta.stats, "parry") +
        Stats.skill(target.meta.stats, "martial-cognize") +
        Stats.skill(target.meta.stats, "dugu-jiujian")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: switch (random(3)) —— 三条起始文案，均为单一相邻拼接字面量。
  defp start_message(0) do
    "$N随手一剑指向$n，落点正是$n破绽所在，神剑之威，当真人所难测。\n"
  end

  defp start_message(1) do
    "$N剑招大开大阖，看似杂乱无章，但招招皆击$n攻势中破绽，有如神助。\n"
  end

  defp start_message(_) do
    "$N反手横剑刺向$n，这似有招似无招的一剑竟然威力奇大，令人匪夷所思。\n"
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap + random(ap);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
      #        HIR "$n" HIR "全然无法领会$N" HIR "剑"
      #        "招中的奥妙，一个疏神，登遭重创！\n" NOR);
      #      me->start_busy(2);
      damage = ap + Engine.rand(rng, max(ap, 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 50, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_msg = "$n全然无法领会$N剑招中的奥妙，一个疏神，登遭重创！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 0, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "可$n" CYN "淡然处之，并没将$N"
      #            CYN "此招放在心上，随手架开，不漏半点破绽。\n" NOR;
      #      me->start_busy(3);
      miss_msg = "可$n淡然处之，并没将$N此招放在心上，随手架开，不漏半点破绽。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 0, 3)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  # LPC: me->query("can_learn/dugu-jiujian/nothing") —— 临时标记，未实现时为空。
  defp character_marks(character), do: Map.get(character.meta, :marks, %{})
end
