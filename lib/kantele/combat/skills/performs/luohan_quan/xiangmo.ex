defmodule Kantele.Combat.Skills.Performs.LuohanQuan.Xiangmo do
  @moduledoc """
  降魔「xiangmo」（对照 `kungfu/skill/luohan-quan/xiangmo.c`）

  罗汉拳单体攻击：消耗 30~50 内力，对战斗中对手出招（空手/拳脚）。

  差异（TODO(migrate)）：
  - LPC 仅 `level:luohan-quan>=20`；本版加 `mapped` 与 `neili` 门槛；
  - 命中判定：`ap/2 + rand(ap) > dp`（dp=parry），忙乱 2/3 轮；
  - 空手攻击不检查武器类型（cuff 为空手）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "luohan-quan/xiangmo"
  @move_name "「罗汉降魔」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, ap} <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, ap)
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

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "luohan-quan")

    if level < 20 do
      {:error, "你的罗汉拳法不够娴熟，现在还无法使用#{@move_name}。\n"}
    else
      {:ok, Stats.skill(stats, "cuff")}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 50 do
      {:error, "你现在真气不够，无法运用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "cuff") == "luohan-quan" do
      :ok
    else
      {:error, "你没有激发罗汉拳，无法使用罗汉降魔！\n"}
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

  defp apply_perform(conn, character, target, ap) do
    # LPC: msg = HIY "$N" HIY "嗨的一声，一拳平平朝$n"
    #           HIY "打出，姿势有板有眼，颇具风范。\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N嗨的一声，一拳平平朝$n打出，姿势有板有眼，颇具风范。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{attacker: ref(character), perform_id: @perform_id, ap: ap, rng: &:rand.uniform/1}
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    ap = max(Map.get(data, :ap, 0), 1)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = 60 + ap / 5 + random(ap / 5);
      #      msg += HIR "只见$n" HIR "一个招架失误，登时"
      #             "被这拳打了个正着，闷哼一声，退了一步。\n" NOR;
      damage = 60 + div(ap, 5) + Engine.rand(rng, max(div(ap, 5), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 20, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn = Broadcast.publish(conn, "只见$n一个招架失误，登时被这拳打了个正着，闷哼一声，退了一步。\n", bindings)

      # LPC: me->add("neili", -30); me->start_busy(2);
      Performs.feedback(attacker, 30, 2)

      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$p" CYN "轻轻一格，架住了$P"
      #            CYN "的来拳。\n" NOR; me->add("neili", -10); me->start_busy(3);
      conn = Broadcast.publish(conn, "可是$p轻轻一格，架住了$P的来拳。\n", bindings)

      Performs.feedback(attacker, 10, 3)

      put_character(conn, character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
