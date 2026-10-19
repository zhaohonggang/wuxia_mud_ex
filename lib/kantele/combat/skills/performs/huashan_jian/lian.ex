defmodule Kantele.Combat.Skills.Performs.HuashanJian.Lian do
  @moduledoc """
  剑掌五连环「lian」（对照 `kungfu/skill/huashan-jian/lian.c`）

  门槛：持剑、neili>=160、force>=100、华山剑法>=50、激发 sword 为华山剑法、
  目标存活且战斗中。
  攻击方发 `perform-incoming`；连出 5 击，每击 `random(3)==1` 且目标未忙乱时
  令目标忙乱 1 回合；攻击方扣 120 内力并忙乱 `1+random(3)`。

  差异（TODO(migrate)）：
  - LPC 的 5 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线，无自定义文案）
    折算为每击 `level/10 + random(level/10)` 基础伤害 + 命中判定
    （`level/2 + random(level)` vs dodge），创伤 1/3；命中/失手文案由引擎生成，
    本模块不补文案。
  - 每击伤害的 `level/10` 是对 `do_attack` 的**近似**，不是 LPC 数值。
    同类「循环 do_attack」的招式各写各的近似，例如 `kuangfeng_jian/sao` 用 `level/3`
    （相差 3.3 倍）。两者**故意不统一**：在没有依据的情况下改动会直接影响平衡。
    将来若在战斗层抽出共享的 do_attack 近似实现，应把两者一起切过去。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform "huashan-jian/lian"
  @name "「剑掌五连环」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- weapon(combat),
         :ok <- neili(character),
         :ok <- force(stats),
         {:ok, level} <- level(stats),
         :ok <- mapped(stats, weapon),
         :ok <- target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform, level: level}
      })

      conn
      |> Broadcast.publish(
        "$N使出华山派绝技「剑掌五连环」，身法陡然加快！\n",
        n1: character.name,
        n2: target.name
      )
      |> assign(:prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp known(stats) do
    if Stats.perform_known?(stats, @perform),
      do: :ok,
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@name}只能对战斗中的对手使用。\n"}
    end
  end

  defp weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: type} = weapon when type == "sword" -> {:ok, weapon}
      _ -> {:error, "你使用的武器不对！\n"}
    end
  end

  defp neili(character) do
    if character.meta.vitals.neili < 160,
      do: {:error, "你的真气不够，无法施展#{@name}！\n"},
      else: :ok
  end

  defp force(stats) do
    if Stats.skill(stats, "force") < 100,
      do: {:error, "你的内功火候不够，难以施展#{@name}！\n"},
      else: :ok
  end

  defp level(stats) do
    level = Stats.skill(stats, "huashan-jian")

    if level < 50,
      do: {:error, "你的华山剑法还不到家，无法施展#{@name}！\n"},
      else: {:ok, level}
  end

  defp mapped(stats, weapon) do
    if Stats.mapped(stats, weapon.skill_type) == "huashan-jian",
      do: :ok,
      else: {:error, "你没有激发华山剑法，无法施展#{@name}。\n"}
  end

  # LPC: if (! living(target)) —— 敌人列表只存引用快照时无 meta 可查，
  # 此时恒判存活，由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # `.c` 的 living(target) 门槛已在攻击方 target_alive/1 保留文案，
    # 目标侧死亡时静默（同 biyan_dao/luo.ex 惯例）。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    dodge = Stats.skill(character.meta.stats, "dodge")
    per_hit = max(div(level, 10), 1)

    # LPC: for (i = 0; i < 5; i++) { if (!target->is_busy() && random(3) == 1)
    #          target->start_busy(1); COMBAT_D->do_attack(me, target, weapon, 0); }
    {combat, damage} =
      Enum.reduce(1..5, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
        combat_acc =
          if combat_acc.busy == 0 and Engine.rand(rng, 3) == 1 do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(level, 2) + Engine.rand(rng, level) > dodge do
          {combat_acc, damage_acc + per_hit + Engine.rand(rng, per_hit)}
        else
          {combat_acc, damage_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: me->add("neili", -120); me->start_busy(1 + random(3));
    Performs.feedback(attacker, 120, 1 + Engine.rand(rng, 3))

    put_character(conn, character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end
