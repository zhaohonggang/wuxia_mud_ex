defmodule Kantele.Combat.Skills.Performs.HanxingBada.Lastrisk do
  @moduledoc """
  孤注一掷（对照 `kungfu/skill/hanxing-bada/lastrisk.c`，inherit F_SSERVER）

  寒星八打暗器绝招：要求寒星八打 skill >= 60、手中持有暗器（throwing）；
  以 combat_exp 比较判定命中，命中后销毁暗器。
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

  @perform_id "hanxing-bada/lastrisk"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target)
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
      [] -> {:error, "孤注一掷只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "throwing" && Map.get(weapon, :amount, 1) >= 1 do
      :ok
    else
      {:error, "你手中必须先有暗器。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "hanxing-bada") < 60 do
      {:error, "你的寒星八打修为太浅，无法施展孤注一掷。\n"}
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

  defp apply_perform(conn, character, target) do
    my_exp = character.meta.stats.combat_exp || 0
    ob_exp = target.meta.stats.combat_exp || 0

    # LPC: msg = CYN "$N" CYN "孤注一掷，发出所有暗器攻向$n" CYN "！\n" NOR;
    start_msg = "$N孤注一掷，发出所有暗器攻向$n！\n"
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: my_exp,
        dp: ob_exp,
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
    rng = Map.get(data, :rng, &:rand.uniform/1)

    # LPC: random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2
    if Engine.rand(rng, max(ap, 1)) > div(dp, 2) do
      # LPC: msg += HIR "结果$p" HIR "被$P" HIR "攻了个措手不及，中了数枚暗器！\n" NOR;
      #      me->start_busy(2); me->add("neili", -100);
      hit_msg = "结果$p被$P攻了个措手不及，中了数枚暗器！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "从容不迫的躲过了$P" CYN "的最后一击。\n" NOR;
      #      me->start_busy(2); me->add("neili", -100);
      miss_msg = "可是$p从容不迫的躲过了$P的最后一击。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 2)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
