defmodule Kantele.Combat.Skills.Performs.JinsheJian.Wan do
  @moduledoc """
  蛇影万道「wan」（对照 `kungfu/skill/jinshe-jian/wan.c`，inherit F_SSERVER）

  金蛇剑法（剑 sword）多段攻击绝招：要求持剑、jinshe-jian >= 180、
  真气 >= 260、sword 已激发映射、目标存活。
  命中判定 `ap / 2 + random(ap * 2) > target->query_skill("dodge")`（ap=剑法），
  命中则 `attack_time = 4 + random(ap / 35)`（上限 9）并追加大批攻击，
  否则不追加；两分支攻击方均扣 `attack_time * 30` 真气并忙乱
  `1 + random(attack_time / 2)`。
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

  @perform_id "jinshe-jian/wan"
  @move_name "「蛇影万道」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character),
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

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  #          return notify_fail(QIAN "只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "sword")
  #          return notify_fail("你使用的武器不对，难以施展" QIAN "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("jinshe-jian", 1) < 180)
  #          return notify_fail("你的金蛇剑法不够娴熟，难以施展" QIAN "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "jinshe-jian") < 180 do
      {:error, "你的金蛇剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 260)
  #          return notify_fail("你的真气不够，难以施展" QIAN "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 260 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "jinshe-jian")
  #          return notify_fail("你没有激发金蛇剑法，难以施展" QIAN "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "jinshe-jian" do
      :ok
    else
      {:error, "你没有激发金蛇剑法，难以施展#{@move_name}。\n"}
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

    # LPC: msg = HIW "\n$N" HIW "一声长吟，手中" + weapon->name() + HIW
    #           "顿时化做无数条灵蛇，" "从四面八方同时向$n" HIW "袭去。\n" NOR;
    # NOTE: weapon->name() 把起始文案拆成两段独立字面量。
    start_msg =
      "\n$N一声长吟，手中" <>
        (weapon_name || "") <> "顿时化做无数条灵蛇，从四面八方同时向$n袭去。\n"

    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "sword")
    attack_time = min(4 + Engine.rand(&:rand.uniform/1, max(div(ap, 35), 1)), 9)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        attack_time: attack_time,
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
    ap = max(Map.get(data, :ap, 0), 1)
    attack_time = max(Map.get(data, :attack_time, 1), 1)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC: if (ap / 2 + random(ap * 2) > dp)
    # TODO: 多段攻击循环（COMBAT_D->do_attack）跨进程补全；此处仅结算文案与消耗。
    conn =
      if div(ap, 2) + Engine.rand(rng, ap * 2) > dodge do
        # LPC: msg = HIR "结果$n" HIR "被$N" HIR "攻了个措手不及，$n"
        #            HIR "慌忙招架，心中叫苦。\n" NOR;
        hit_msg = "结果$n被$N攻了个措手不及，$n慌忙招架，心中叫苦。\n"
        Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)
      else
        # LPC: msg = HIC "$n" HIC "见$N" HIC "这几剑招式凌厉，诡异"
        #            "无比，只得苦苦招架。\n" NOR;
        miss_msg = "$n见$N这几剑招式凌厉，诡异无比，只得苦苦招架。\n"
        Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)
      end

    # LPC: me->add("neili", -attack_time * 30); me->start_busy(1 + random(attack_time / 2));
    Performs.feedback(
      attacker,
      attack_time * 30,
      1 + Engine.rand(rng, max(div(attack_time, 2), 1))
    )

    put_character(conn, character)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "jinshe-jian/wan",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
