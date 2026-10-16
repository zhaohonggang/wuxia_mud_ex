defmodule Kantele.Combat.Skills.Performs.Houquan.Zhen do
  @moduledoc """
  猴拳「zhen」（对照 `kungfu/skill/houquan/zhen.c`，inherit F_SSERVER）

  猴拳「震」字诀：要求空手、houquan >= 50、真气 >= 100、目标存活且在战斗中。
  攻击方广播起手式、扣 80 内力、忙乱 3，并发 `combat/perform-incoming`；
  目标侧按 `random(force) > target_force/2` 判定：
  - 命中：伤害 `force/3 + random(force/3)`（内伤），目标忙乱 `random(3)`；
  - 未中：广播“可是…并没有上当”。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "houquan/zhen"
  @move_name "「震」字诀"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_empty_hand(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats, level)
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
      [] -> {:error, "神功震敌只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  #          return notify_fail("你必须空手才能使用「震」字诀！\n");
  defp check_empty_hand(combat) do
    if Combat.weapon(combat) do
      {:error, "你必须空手才能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("houquan", 1) < 50)
  #          return notify_fail("你的猴拳不够娴熟，不会使用「震」字诀。\n");
  defp check_skill_level(stats) do
    level = Stats.skill(stats, "houquan")

    if level < 50 do
      {:error, "你的猴拳不够娴熟，不会使用#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  # LPC: if ((int)me->query("neili", 1) < 100)
  #          return notify_fail("你现在真气太弱，不能使用「震」字诀。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气太弱，不能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if not dead?(target),
      do: :ok,
      else: {:error, "对方都已经这样了，用不着这么费力吧？\n"}
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats, level) do
    # LPC: msg = CYN "$N" CYN "默运神功，使出猴拳「震」字诀，企图以内力震伤$n"
    #           CYN "。\n" NOR; me->add("neili", -80);
    conn =
      Broadcast.publish(conn, "$N默运神功，使出猴拳「震」字诀，企图以内力震伤$n。\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -80); me->start_busy(3)（两分支攻击方均忙乱 3）
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 80, 0)}
    combat = Combat.start_busy(character.meta.combat, 3)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    force = Stats.skill(stats, "force")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{attacker: ref(character), perform_id: @perform_id, force: force, level: level}
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
    force = Map.get(data, :force, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    target_force = Stats.skill(character.meta.stats, "force")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("force")) > target->query_skill("force") / 2)
    if Engine.rand(rng, max(force, 1)) > div(target_force, 2) do
      # LPC: target->start_busy(random(3));
      combat = Combat.start_busy(character.meta.combat, Engine.rand(rng, 3))

      # LPC: damage = me->query_skill("force", 1); damage = damage / 3 + random(damage / 3);
      #      msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30, "内伤:?");
      damage = div(force, 3) + Engine.rand(rng, max(div(force, 3), 1))
      _injury = "内伤:?"

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))

      character = %{
        character
        | meta: %{character.meta | vitals: vitals, combat: combat}
      }

      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，并没有上当。\n" NOR;
      Broadcast.publish(conn, "可是$p看破了$P的企图，并没有上当。\n", bindings)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
