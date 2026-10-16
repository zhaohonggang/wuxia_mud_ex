defmodule Kantele.Combat.Skills.Performs.JingyueBifa.Ci do
  @moduledoc """
  残月刺「ci」（对照 `kungfu/skill/jingyue-bifa/ci.c`，inherit F_SSERVER）

  惊月笔法（匕首 dagger）单体攻击绝招：要求持匕首、jingyue-bifa >= 30、
  dagger 已激发映射、真气 >= 100、目标未忙乱且存活。
  攻击方无条件扣 80 真气；命中判定
  `level + random(level) > target->query_skill("dodge")`，
  命中后目标忙乱 `2 + random(level / 24)`、攻击方忙乱 `random(2)`；
  落空则攻击方忙乱 2。
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

  @perform_id "jingyue-bifa/ci"
  @move_name "「残月刺」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_target_busy(target),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
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

  # LPC: if (! target || ! me->is_fighting(target))
  #          return notify_fail(CI "只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "dagger")
  #          return notify_fail("你使用的武器不对，难以施展" CI "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "dagger" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
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

  # LPC: if ((int)me->query_skill("jingyue-bifa", 1) < 30)
  #          return notify_fail("你惊月笔法不够娴熟，难以施展" CI "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "jingyue-bifa") < 30 do
      {:error, "你惊月笔法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("dagger") != "jingyue-bifa")
  #          return notify_fail("你没有激发惊月笔法，难以施展" CI "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "dagger") == "jingyue-bifa" do
      :ok
    else
      {:error, "你没有激发惊月笔法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  #          return notify_fail("你现在的真气不够，难以施展" CI "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)

    # LPC: msg = HIC "\n$N" HIC "怒啸一声，施展出绝招「" HIW "残月刺" HIC "」"
    #           "手中" + wn + HIC "划出一道弧形，将$n" HIC "笼罩。"NOR;
    # NOTE: wn = weapon->name() 把起始文案拆成两段独立字面量。
    start_msg =
      "\n$N怒啸一声，施展出绝招「残月刺」手中" <>
        (weapon_name || "") <> "划出一道弧形，将$n笼罩。"

    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: me->add("neili", -80);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 80}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    level = Stats.skill(stats, "jingyue-bifa")

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
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC: if (level + random(level) > target->query_skill("dodge"))
    if level + Engine.rand(rng, level) > dodge do
      # LPC: target->start_busy(2 + random(level / 24)); me->start_busy(random(2));
      combat =
        Combat.start_busy(character.meta.combat, 2 + Engine.rand(rng, max(div(level, 24), 1)))

      character = %{character | meta: %{character.meta | combat: combat}}

      # LPC: msg = HIY "$N" HIY "看不出$n" HIY "招式中的虚实，连忙"
      #                "护住自己全身，一时竟无以应对！\n" NOR;
      hit_msg = "$N看不出$n招式中的虚实，连忙护住自己全身，一时竟无以应对！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      # LPC: me->start_busy(random(2)); （内力已于起手扣 80）
      Performs.feedback(attacker, 0, Engine.rand(rng, 2))

      put_character(conn, character)
    else
      # LPC: msg = CYN "可是$N" CYN "镇定自若，小心拆招，没有被"
      #                "$n" NOR + CYN "招式所困。\n" NOR;
      # NOTE: `"$n" NOR + CYN` 处的 `+` 把文案拆成两段独立字面量。
      miss_msg = Enum.join(["可是$N镇定自若，小心拆招，没有被$n", "招式所困。\n"], "")
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      # LPC: me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      put_character(conn, character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "jingyue-bifa/ci",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
