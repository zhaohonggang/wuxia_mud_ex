defmodule Kantele.Combat.Skills.Performs.JinguanYusuo.Suo do
  @moduledoc """
  玄门金锁「suo」（对照 `kungfu/skill/jinguan-yusuo/suo.c`，inherit F_SSERVER）

  金关玉锁单体攻击绝招：要求 jinguan-yusuo >= 150、内功 force >= 200、
  真气 >= 500、目标未忙乱且存活；攻击方扣 100 真气 / 忙乱 1 于命中，
  扣 50 真气 / 忙乱 2 于落空。命中判定
  `random(level) > target->query_skill("parry") / 2`，命中后目标忙乱 `level / 16` 轮。
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

  @perform_id "jinguan-yusuo/suo"
  @move_name "「玄门金锁」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_busy(target),
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

  # LPC: if (! target || ! me->is_fighting(target))
  #          return notify_fail(SUO "只有在战斗中才能使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只有在战斗中才能使用。\n"}
    end
  end

  # LPC: if ((level = me->query_skill("jinguan-yusuo", 1)) < 150)
  #          return notify_fail("你的金关玉锁不够熟练，难以施展" SUO "。\n" NOR);
  defp check_skill_level(stats) do
    if Stats.skill(stats, "jinguan-yusuo") < 150 do
      {:error, "你的金关玉锁不够熟练，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 200)
  #          return notify_fail("你的内功火候不足，难以施展" SUO "。\n");
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功火候不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 500)
  #          return notify_fail("你现在的真气不足，难以施展" SUO "。\n" NOR);
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_busy())
  #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  defp check_target_busy(target) do
    if Combat.busy?(target.meta.combat) do
      {:error, target.name <> "目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    # LPC: msg = HIY "突然间$N" HIY "双手蓦的回圈，使出「" HIR "玄门金锁"
    #           HIY "」绝技，企图锁死$n" HIY "的招数。\n" NOR;
    start_msg = "突然间$N双手蓦的回圈，使出「玄门金锁」绝技，企图锁死$n的招数。\n"
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    level = Stats.skill(stats, "jinguan-yusuo")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
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
    level = max(Map.get(data, :level, 0), 1)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    parry = Stats.skill(character.meta.stats, "parry")

    # LPC: if (random(level) > (int)target->query_skill("parry", 1) / 2)
    if Engine.rand(rng, level) > div(parry, 2) do
      # LPC: target->start_busy(level / 16);
      combat = Combat.start_busy(character.meta.combat, div(level, 16))
      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC: msg += HIR "霎时$n" HIR "只觉招数一紧，双臂瘫软，全身"
      #            "力道竟似被$N" HIR "牢牢锁住！\n" NOR;
      hit_msg = "霎时$n只觉招数一紧，双臂瘫软，全身力道竟似被$N牢牢锁住！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      # LPC: me->add("neili", -100); me->start_busy(1);
      Performs.feedback(attacker, 100, 1)

      put_character(conn, character)
    else
      # LPC: msg += HIC "可是$n" HIC "防守严密，丝毫不为$N"
      #            HIC "的招数所乱。\n" NOR;
      miss_msg = "可是$n防守严密，丝毫不为$N的招数所乱。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      # LPC: me->add("neili", -50); me->start_busy(2);
      Performs.feedback(attacker, 50, 2)

      put_character(conn, character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "jinguan-yusuo/suo",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
