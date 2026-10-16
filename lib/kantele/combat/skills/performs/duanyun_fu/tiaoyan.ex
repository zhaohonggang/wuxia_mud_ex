defmodule Kantele.Combat.Skills.Performs.DuanyunFu.Tiaoyan do
  @moduledoc """
  挑眼式「tiaoyan」（对照 `kungfu/skill/duanyun-fu/tiaoyan.c`，inherit F_SSERVER）

  夺命三斧单体攻击：要求 duanyun-fu >= 60、真气 >= 100；命中判定为
  `random(combat_exp) > target_combat_exp/2`，命中伤害取技能等级（外伤 45%），
  无武器/内激发门槛。
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

  @perform_id "duanyun-fu/tiaoyan"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- target(combat),
         :ok <- check_skill_level(stats),
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「挑眼式」只能在战斗中对对手使用。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "duanyun-fu") < 60 do
      {:error, "你的夺命三斧还不到家，不会施展「挑眼式」。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的真气不够，无法施展「挑眼式」。\n"}
    else
      :ok
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
    # LPC: msg = HIG "$N" HIG "使出夺命三斧之「挑眼式」，斧尖疾挑$n" HIG "双眼。\n" NOR;
    start_msg = "$N使出夺命三斧之「挑眼式」，斧尖疾挑$n双眼。\n"
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2
    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: stats.combat_exp,
        dp: target.meta.stats.combat_exp,
        lvl: Stats.skill(stats, "duanyun-fu"),
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
    lvl = Map.get(data, :lvl, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if Engine.rand(rng, max(ap, 1)) > div(dp, 2) do
      # LPC: do_damage(me, target, WEAPON_ATTACK, lvl, 45,
      #        HIR "结果$p" HIR "只觉得眼前一黑，双眼一"
      #        "阵剧痛，血流满面。\n" NOR);
      #      me->add("neili", -50);
      vitals = Vitals.damage(character.meta.vitals, :qi, lvl)
      vitals = Vitals.wound(vitals, :qi, div(lvl * 45, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_msg = "结果$p只觉得眼前一黑，双眼一阵剧痛，血流满面。\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 50, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += HIG "可是$p" HIG "看破了$P" HIG "的企图，急忙躲开了。\n" NOR;
      miss_msg = "可是$p看破了$P的企图，急忙躲开了。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
