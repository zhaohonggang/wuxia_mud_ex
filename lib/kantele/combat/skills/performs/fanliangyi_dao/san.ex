defmodule Kantele.Combat.Skills.Performs.FanliangyiDao.San do
  @moduledoc """
  华岳三神峰「san」（对照 `kungfu/skill/fanliangyi-dao/san.c`）

  反两仪刀法刀法绝招：需装备 `blade` 类武器，连出三刀
  （反转 / 回转 / 飞身跃起），三式均以目标 `parry` 为防御值判定命中。

  攻击方算 `ap`（blade 技能）并下发 `combat/perform-incoming`，
  由目标侧 `resolve_incoming` 逐式判定并广播，最后回执忙乱。

  差异（TODO(migrate)）：
  - LPC 首句用 `message_sort`，本引擎统一走 `Broadcast.publish`（同
    `chilian_shenzhang/lian.ex` 惯例）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "fanliangyi-dao/san"
  @move_name "「华岳三神峰」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, level, weapon)
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (!objectp(weapon) || weapon->query("skill_type") != "blade")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "blade" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1800 do
      {:error, "你的内力修为不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 320 do
      {:error, "你的真气不够！\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "fanliangyi-dao")

    if level < 100 do
      {:error, "你反两仪刀法火候不足，无法施展#{@move_name}\n"}
    else
      {:ok, level}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 140 do
      {:error, "你的内功修为不足，无法施展#{@move_name}\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "fanliangyi-dao" do
      :ok
    else
      {:error, "你还没有激发反两仪刀法，无法施展#{@move_name}！\n"}
    end
  end

  defp apply_perform(conn, character, target, level, weapon) do
    stats = character.meta.stats

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        ap: Stats.skill(stats, "blade"),
        weapon_name: Map.get(weapon, :name, "")
      }
    })

    assign(conn, :prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    weapon_name = Map.get(data, :weapon_name, "")
    ap = Map.get(data, :ap, 0)
    parry = Stats.skill(stats, "parry")

    # LPC: message_sort(首句) —— 起手式
    conn =
      Broadcast.publish(
        conn,
        "$N使出华山派绝技「华岳三神峰」，身法突然变得异常灵动飘忽！手中" <>
          weapon_name <> "连连卷向$n。\n",
        bindings
      )

    # 第一刀：反转
    conn = Broadcast.publish(conn, "$N反转" <> weapon_name <> "，忽然一刀劈出，威力无穷。\n", bindings)

    {qi, wound, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) < parry do
        conn = Broadcast.publish(conn, Messages.interpolate("$n向外一跳闪过了这招。\n", bindings))
        {0, 0, conn}
      else
        damage = div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1))

        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate("$n躲避不及，被$N这刀砍中肩膀，鲜血直流。\n", bindings)
          )

        {damage, div(damage * 50, 100), conn}
      end

    # 第二刀：回转
    conn = Broadcast.publish(conn, "$N回转" <> weapon_name <> "，猛地大步向前，直袭$n下盘。\n", bindings)

    {qi, wound, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) < parry do
        conn = Broadcast.publish(conn, Messages.interpolate("$n纵身而起，躲过这一招。\n", bindings))
        {qi, wound, conn}
      else
        damage = div(ap, 2) + Engine.rand(rng, max(div(ap, 2), 1))

        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate("$n闪避不及，大腿已被$N砍得血肉模糊！\n", bindings)
          )

        {qi + damage, wound + div(damage * 60, 100), conn}
      end

    # 第三刀：飞身跃起
    conn =
      Broadcast.publish(
        conn,
        "$N飞身跃起，手中" <> weapon_name <> "自天而下，劈向$n。\n",
        bindings
      )

    {qi, wound, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) < parry do
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate("$n一快打快，向后飞身一跳，竟躲过这招。\n", bindings)
          )

        {qi, wound, conn}
      else
        damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate("$n正犹豫剑，刀光划过，鲜血已染满刀身。！\n", bindings)
          )

        {qi + damage, wound + div(damage * 70, 100), conn}
      end

    # LPC: me->start_busy(3);
    Performs.feedback(attacker, 0, 3)

    conn
    |> put_character(apply_wound(character, qi, wound))
  end

  defp apply_wound(character, qi, wound) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, qi)
      |> Vitals.wound(:qi, wound)

    %{character | meta: %{character.meta | vitals: vitals}}
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "fanliangyi-dao/san",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
