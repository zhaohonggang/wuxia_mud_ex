defmodule Kantele.Combat.Skills.Performs.LuoyingShenjian.Sui do
  @moduledoc """
  随波逐流「sui」（对照 `kungfu/skill/luoying-shenjian/sui.c`）

  落英神剑单体攻击：消耗 80/180 内力，对战斗中对手出招。

  差异（TODO(migrate)）：
  - LPC 仅 `level:luoying-shenjian>=80,force>=100`；本版逐条对齐各门槛；
  - 命中判定：`ap/2 + rand(ap) > dp`（dp=parry），命中令目标忙乱 `level/22+1`。
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

  @perform_id "luoying-shenjian/sui"
  @move_name "「随波逐流」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_target_busy(target),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, level)
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

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
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

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "luoying-shenjian")

    if level < 80 do
      {:error, "你落英神剑不够娴熟，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "luoying-shenjian" do
      :ok
    else
      {:error, "你没有激发落英神剑，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的内功火候不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
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

  defp apply_perform(conn, character, target, level) do
    weapon = Combat.weapon(character.meta.combat)
    weapon_name = weapon && Map.get(weapon, :name)
    ap = Stats.skill(character.meta.stats, "sword")

    # LPC: msg = HIG "$N" HIG "手中" + weapon->name() + HIG "疾转，剑幕缭绕，引得周"
    #           "围气流波动不已，笼罩$n" HIG "四方。\n" NOR;
    # NOTE: weapon->name() 把起始文案拆成两段字面量。
    a1 = "$N手中"
    a2 = "疾转，剑幕缭绕，引得周围气流波动不已，笼罩$n四方。\n"
    start_msg = a1 <> (weapon_name || "") <> a2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: me->add("neili", -80);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 80}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        ap: ap,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    ap = max(Map.get(data, :ap, 0), 1)
    level = max(Map.get(data, :level, 0), 1)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: msg += HIR "$n" HIR "勘不透$N" HIR "招中奥妙，不敢擅自出招，顿时"
      #            "便失了先机。\n" NOR;
      #      target->start_busy(me->query_skill("luoying-shenjian", 1) / 22 + 1);
      combat = Combat.start_busy(character.meta.combat, div(level, 22) + 1)
      character = %{character | meta: %{character.meta | combat: combat}}
      conn = Broadcast.publish(conn, "$n勘不透$N招中奥妙，不敢擅自出招，顿时便失了先机。\n", bindings)

      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$p" CYN "不慌不忙，看破了此招"
      #            "虚实，并没有受到半点影响。\n" NOR;
      #      me->add("neili", -100); me->start_busy(1);
      conn = Broadcast.publish(conn, "可是$p不慌不忙，看破了此招虚实，并没有受到半点影响。\n", bindings)

      Performs.feedback(attacker, 100, 1)

      put_character(conn, character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "luoying-shenjian/sui",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
