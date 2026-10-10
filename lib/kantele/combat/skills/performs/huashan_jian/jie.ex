defmodule Kantele.Combat.Skills.Performs.HuashanJian.Jie do
  @moduledoc """
  绝招「截手式」（对照 kungfu/skill/huashan-jian/jie.c）

  消耗 50 内力，对战斗中的对手出剑：命中则目标忙乱 `level/22 + 2` 轮，
  失手则文本落空（目标仅见招架/拨打文案）。

  攻击者只出招：本模块在攻击者进程内校验门槛、扣内力、放出主文案，
  再把 `combat/perform-incoming` 事件发给目标；由目标以自身完整状态
  （parry 等级、兵器）在本进程结算命中的随机判定与忙乱——与战斗心跳
  `combat/incoming` 同构，规避跨进程读取目标状态。

  TODO(migrate): LPC 在 `target->is_busy()` 时直接 notify_fail、且仅失手时
  `me->start_busy(1)`；本版目标忙乱不阻发招、攻击者也不进入忙乱（缺回执通道）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "huashan-jian/jie"
  @jie "「截手式」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_weapon(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
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
      [] -> {:error, @jie <> "只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "huashan-jian")

    if level < 30 do
      {:error, "你的华山剑法不够娴熟，无法施展#{@jie} 。\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "huashan-jian" do
      :ok
    else
      {:error, "你没有激发华山剑法，无法施展#{@jie}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 60 do
      {:error, "你现在真气不够，无法使用#{@jie}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N长剑一勒，使出华山剑法绝技之「截手式」，转折之际天衣无缝，" <>
          "一剑既出，后着源源倾泻，如大浪跃滩，层层叠叠，迅然扑向$n！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{attacker: ref(character), perform_id: @perform_id, level: level}
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    level = Map.get(data, :level, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)
    parry = Stats.skill(character.meta.stats, "parry")

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || "兵器"]

    if Engine.rand(rng, level) > div(parry, 2) do
      combat = Combat.start_busy(combat, div(level, 22) + 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("结果$p瘁不及防，连连倒退几步，一时间无法回手！\n", bindings)
      )
      |> put_character(put_combat(character, combat))
    else
      text =
        if weapon_name do
          Messages.interpolate(
            "但是$p识破了$N的用意，自顾将手中的#{weapon_name}舞成一团光花，" <>
              "$N一怔之下再也攻不进去。\n",
            bindings
          )
        else
          Messages.interpolate("但是$p双手戳点刺拍，将$N的来招一一架开。\n", bindings)
        end

      Broadcast.publish(conn, text)
    end
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
