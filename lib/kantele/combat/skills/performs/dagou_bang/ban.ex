defmodule Kantele.Combat.Skills.Performs.DagouBang.Ban do
  @moduledoc """
  绊字诀「ban」（对照 `kungfu/skill/dagou-bang/ban.c`，inherit F_SSERVER）

  打狗棒法（棍 staff）攻击绝招：要求内力 >= 300、内功 force >= 240、
  dagou-bang >= 180、棍已激发映射；按 staff+直觉/2+int*10 与
  dodge+直觉/2+dex*10 判定命中（外伤 70%），另有 max_neili 碾压秒杀分支。
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

  @perform_id "dagou-bang/ban"
  @move_name "「绊字诀」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "staff" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "dagou-bang") < 180 do
      {:error, "你打狗棒法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "staff") == "dagou-bang" do
      :ok
    else
      {:error, "你没有激发打狗棒法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 240 do
      {:error, "你的内功火候不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  #          return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)

    # LPC: msg = HIG "$N" HIG "使出打狗棒法「" NOR + WHT "绊"
    #           HIG "」字诀，手中" + weapon->query("name") +
    #           HIG "左封右逼，缓缓朝$n" HIG "挑去。\n" NOR;
    # NOTE: C 侧 "$N""使出打狗棒法「" 相邻 → 合并；但 "使出打狗棒法「" + "绊"
    #       以 + 拼接 → 拆成两段；"绊""」字诀，手中" 相邻 → 合并。weapon 名
    #       位于「绊」段之后，故必须 p1 <> p2 <> weapon <> p3 三段独立字面量。
    p1 = "$N使出打狗棒法「"
    p2 = "绊」字诀，手中"
    p3 = "左封右逼，缓缓朝$n挑去。\n"
    start_msg = p1 <> p2 <> (weapon_name || "") <> p3
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: if (me->query("max_neili") > target->query("max_neili") * 2) { ... }
    kill? = character.meta.vitals.max_neili > target.meta.vitals.max_neili * 2

    ap =
      Stats.skill(stats, "staff") +
        div(Stats.skill(stats, "martial-cognize"), 2) +
        stats.int * 10

    dp =
      Stats.skill(target.meta.stats, "dodge") +
        div(Stats.skill(target.meta.stats, "martial-cognize"), 2) +
        target.meta.stats.dex * 10

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        kill?: kill?,
        weapon_name: weapon_name,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    kill? = Map.get(data, :kill?, false)
    weapon_name = Map.get(data, :weapon_name)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    cond do
      kill? ->
        # LPC: msg += HIR "$n" HIR "全身一颤，立足不稳，被$N"
        #            HIR "这招击得飞起，重重的跌落在地上。\n" NOR;
        #      me->add("neili", -50); me->start_busy(1);
        #      target->set("eff_qi", 1); target->set("eff_jing", 1);
        #      target->unconcious(me);
        kill_msg = "$n全身一颤，立足不稳，被$N这招击得飞起，重重的跌落在地上。\n"
        conn = Broadcast.publish(conn, kill_msg, n1: attacker.name, n2: character.name)

        # TODO: 跨进程击晕（unconcious）补全
        Performs.feedback(attacker, 50, 1)

        conn
        |> put_character(character)

      div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp ->
        # LPC: damage = ap/2 + random(ap);
        #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 70,
        #        HIR "只听$n" HIR "小腿处「嗤嗤」两声脆"
        #        "响，竟被$N" HIR "的" + weapon->name() +
        #        HIR "贯出两个血洞。\n" NOR);
        #      me->start_busy(1 + random(3)); me->add("neili", -200);
        damage = div(ap, 2) + Engine.rand(rng, max(ap, 1))
        vitals = Vitals.damage(character.meta.vitals, :qi, damage)
        vitals = Vitals.wound(vitals, :qi, div(damage * 70, 100))
        character = %{character | meta: %{character.meta | vitals: vitals}}

        hit_part1 = "只听$n小腿处「嗤嗤」两声脆响，竟被$N的"
        hit_part2 = "贯出两个血洞。\n"
        hit_msg = hit_part1 <> (weapon_name || "") <> hit_part2
        conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

        Performs.feedback(attacker, 200, 1 + Engine.rand(rng, 3))

        conn
        |> put_character(character)

      true ->
        # LPC: msg += CYN "可$n" CYN "全神防御，不露半点破绽，使得$N"
        #            CYN "这招无功而返。\n" NOR;
        #      me->start_busy(3); me->add("neili", -100);
        miss_msg = "可$n全神防御，不露半点破绽，使得$N这招无功而返。\n"
        conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

        Performs.feedback(attacker, 100, 3)

        conn
        |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
