defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Jing do
  @moduledoc """
  perform「惊字诀」（source taixuan-gong/jing.c，由 translate_perform.py 生成，inherit F_SSERVER）

  四回合连击，每回合不同DP计算、不同效果、不同回调：
  - 第1回合：DP=目标str*2+unarmed+parry，命中扣neili+busy1，callback final1
  - 第2回合：DP=目标int*2+dodge+parry，命中jing伤/创，callback final2
  - 第3回合：DP=目标con*2+force+parry，命中jing伤/创
  - 第4回合：DP=目标dex*2+dodge+parry，命中busy+消息含武器名，callback final3
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.Combat

  @perform_id "taixuan-gong/jing"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taixuan-gong")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do

      # 确定武器类型
      weapon_type = get_weapon_type(character)
      has_weapon = weapon_type != :unarmed

      # 计算 AP
      ap = if weapon_type == :sword do
        lvl + Stats.skill(stats, "sword")
      else
        lvl + Stats.skill(stats, "blade")
      end

      # 初始消息
      conn = Broadcast.publish(conn, "只见$N身形陡起，内劲如虹，${weapon_msg}直指$n要害！", n1: character.name, weapon_msg: get_weapon_msg(has_weapon))

      # 扣除内力
      neili_cost = 400 + Engine.rand(rng, 400)
      vitals = character.meta.vitals
      vitals = %{vitals | neili: max(vitals.neili - neili_cost, 0)}
      attacker = %{character | meta: Map.put(character.meta, :vitals, vitals)}

      # 攻击方 busy
      combat = Combat.start_busy(combat, 2 + Engine.rand(rng, 3))
      attacker = %{attacker | meta: Map.put(attacker.meta, :combat, combat)}

      # 第1回合
      {conn, attacker, target} = round1(conn, attacker, target, lvl, ap, rng)

      # 第2回合
      {conn, attacker, target} = round2(conn, attacker, target, lvl, ap, rng)

      # 第3回合
      {conn, attacker, target} = round3(conn, attacker, target, lvl, ap, rng)

      # 第4回合
      {conn, attacker, target} = round4(conn, attacker, target, lvl, ap, rng)

      # 结束
      conn
      |> put_character(attacker)
      |> Map.put(:target, target)
      |> assign(:prompt, false)

    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "blade") < 340 -> {:error, "你的刀法不够娴熟，难以施展惊字诀。\n"}
      Stats.skill(stats, "force") < 340 -> {:error, "你的内功火候不够，难以施展惊字诀。\n"}
      Stats.skill(stats, "martial-cognize") < 260 -> {:error, "你的武学修养不够，难以施展惊字诀。\n"}
      Stats.skill(stats, "sword") < 340 -> {:error, "你的剑法不够娴熟，难以施展惊字诀。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "taixuan-gong" and Stats.mapped(stats, "sword") != "taixuan-gong" ->
        {:error, "你没有激发太玄功刀剑，难以施展惊字诀。\n"}

      Stats.mapped(stats, "sword") != "taixuan-gong" and Stats.mapped(stats, "blade") != "taixuan-gong" and Stats.mapped(stats, "unarmed") != "taixuan-gong" ->
        {:error, "你没有激发/准备太玄功拳脚，难以施展惊字诀。\n"}

      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 10000 -> {:error, "你的内力修为不足，难以施展惊字诀。\n"}
      vitals.neili < 850 -> {:error, "你的内力不足，难以施展惊字诀。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    # 复杂武器检查简化：必须激发太玄功刀/剑或拳脚
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "taixuan-gong" and Stats.mapped(stats, "blade") != "taixuan-gong" and Stats.mapped(stats, "unarmed") != "taixuan-gong" ->
        {:error, "你必须激发太玄功才能施展惊字诀。\n"}
      true -> :ok
    end
  end

  defp check_other(character) do
    stats = character.meta.stats

    cond do
      false -> {:error, "你所使用的外功中没有这种功能。\n"}
      true -> :ok
    end
  end

  defp get_weapon_type(character) do
    stats = character.meta.stats
    cond do
      Stats.mapped(stats, "sword") == "taixuan-gong" -> :sword
      Stats.mapped(stats, "blade") == "taixuan-gong" -> :blade
      true -> :unarmed
    end
  end

  defp get_weapon_msg(:sword), do: "剑气纵横"
  defp get_weapon_msg(:blade), do: "刀光如练"
  defp get_weapon_msg(_), do: "内劲暗吐"

  defp apply_effect(conn, character) do
    # 无条件效果已在 run 中处理
    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # ===== 第1回合：DP = str*2 + unarmed + parry =====
  defp round1(conn, attacker, target, lvl, ap, rng) do
    target_stats = target.meta.stats

    # DP = str*2 + unarmed + parry
    dp = target.meta.stats.str * 2 + Stats.skill(target.meta.stats, "unarmed") + Stats.skill(target.meta.stats, "parry")
    hit = div(ap * 4, 5) + Engine.rand(rng, ap) >= dp

    {conn, attacker, target} =
      if true do
        # 命中
        damage = ap + Engine.rand(rng, ap)

        # 目标 neili 伤害
        neili_damage = lvl + Engine.rand(rng, lvl)
        target_vitals = target.meta.vitals
        target_vitals = Vitals.damage(target_vitals, :neili, neili_damage)

        # busy 1
        target_combat = target.meta.combat
        target_combat = Combat.start_busy(target_combat, 1)
        target = %{target | meta: Map.put(target.meta, :combat, target_combat)}

        # final1 消息：目标 neili 受损 + busy 1
        result = "可只见$n惨叫一声，内息大乱，竟被$N震得心神俱颤！"
        conn = Broadcast.publish(conn, Messages.interpolate(result, n1: attacker.name, n2: target.name))

        # 攻击方 busy
        attacker_combat = attacker.meta.combat
        attacker_combat = Combat.start_busy(attacker_combat, 1)
        attacker = %{attacker | meta: Map.put(attacker.meta, :combat, attacker_combat)}

        {conn, attacker, target}
      else
        # 闪避
        result = "$n身形微晃，竟将$N这招惊字诀卸了个干干净净！"
        conn = Broadcast.publish(conn, Messages.interpolate(result, n1: attacker.name, n2: target.name))
        {conn, attacker, target}
      end

    {conn, attacker, target}
  end

  # ===== 第2回合：DP = int*2 + dodge + parry =====
  defp round2(conn, attacker, target, lvl, ap, rng) do
    target_stats = target.meta.stats

    # DP = int*2 + dodge + parry
    dp = target.meta.stats.int * 2 + Stats.skill(target.meta.stats, "dodge") + Stats.skill(target.meta.stats, "parry")
    hit = div(ap * 4, 5) + Engine.rand(rng, ap) >= dp

    {conn, attacker, target} =
      if hit do
        # 命中
        damage = ap + Engine.rand(rng, ap)

        # jing 伤害/创伤
        target_vitals = target.meta.vitals
        target_vitals = Vitals.damage(target_vitals, :jing, div(damage, 2))
        target_vitals = Vitals.wound(target_vitals, :jing, div(damage, 4))
        target = %{target | meta: Map.put(target.meta, :vitals, target_vitals)}

        # final2 消息：jing 伤害/创
        conn = Broadcast.publish(conn, Messages.interpolate("只见$n惨叫一声，精气大损，${weapon}竟已刺入数寸！", n1: attacker.name, n2: target.name, weapon: get_weapon_name(:sword)))

        {conn, attacker, target}
      else
        # 闪避
        result = "$n身形飘忽，竟在$N剑气中穿梭自如，竟未沾边！"
        conn = Broadcast.publish(conn, Messages.interpolate(result, n1: attacker.name, n2: target.name))
        {conn, attacker, target}
      end

    {conn, attacker, target}
  end

  # ===== 第3回合：DP = con*2 + force + parry =====
  defp round3(conn, attacker, target, lvl, ap, rng) do
    target_stats = target.meta.stats

    # DP = con*2 + force + parry
    dp = target.meta.stats.con * 2 + Stats.skill(target.meta.stats, "force") + Stats.skill(target.meta.stats, "parry")
    hit = div(ap * 4, 5) + Engine.rand(rng, ap) >= dp

    {conn, attacker, target} =
      if hit do
        # 命中
        damage = ap + Engine.rand(rng, ap)

        # jing 伤害/创伤
        target_vitals = target.meta.vitals
        target_vitals = Vitals.damage(target_vitals, :jing, div(damage, 2))
        target_vitals = Vitals.wound(target_vitals, :jing, div(damage, 4))
        target = %{target | meta: Map.put(target.meta, :vitals, target_vitals)}

        # final2 消息
        conn = Broadcast.publish(conn, Messages.interpolate("$n精气大损，${weapon}竟已刺入数寸！", n1: attacker.name, n2: target.name, weapon: get_weapon_name(:sword)))

        {conn, attacker, target}
      else
        # 闪避
        result = "$n身形飘忽，竟在$N剑气中穿梭自如，竟未沾边！"
        conn = Broadcast.publish(conn, Messages.interpolate(result, n1: attacker.name, n2: target.name))
        {conn, attacker, target}
      end

    {conn, attacker, target}
  end

  # ===== 第4回合：DP = dex*2 + dodge + parry =====
  defp round4(conn, attacker, target, lvl, ap, rng) do
    target_stats = target.meta.stats

    # DP = dex*2 + dodge + parry
    dp = target.meta.stats.dex * 2 + Stats.skill(target.meta.stats, "dodge") + Stats.skill(target.meta.stats, "parry")
    hit = div(ap * 4, 5) + Engine.rand(rng, ap) >= dp

    {conn, attacker, target} =
      if hit do
        # 命中
        damage = ap + Engine.rand(rng, ap)

        # 目标 busy 4 + random(lvl/40)
        busy_rounds = 4 + Engine.rand(rng, div(lvl, 40))
        target_combat = target.meta.combat
        target_combat = Combat.start_busy(target_combat, busy_rounds)
        target = %{target | meta: Map.put(target.meta, :combat, target_combat)}

        # final3 消息：busy + 武器名
        conn = Broadcast.publish(conn, Messages.interpolate("$N剑气势如破竹，$n被剑气裹挟，重重摔出数丈之外！", n1: attacker.name, n2: target.name))

        {conn, attacker, target}
      else
        # 闪避
        result = "$n身形飘忽，竟在$N最后一击中穿梭自如，竟未沾边！"
        conn = Broadcast.publish(conn, Messages.interpolate(result, n1: attacker.name, n2: target.name))
        {conn, attacker, target}
      end

    {conn, attacker, target}
  end

  defp get_weapon_name(:sword), do: "剑"
  defp get_weapon_name(:blade), do: "刀"
  defp get_weapon_name(_), do: "内劲"

  defp apply_effect(conn, character) do
    # 无条件效果已在 run 中处理
    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # 多回合攻击已在 run 中处理，这里只需返回
    conn
    |> put_character(character)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end
end