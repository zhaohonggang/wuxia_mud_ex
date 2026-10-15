defmodule Kantele.Combat.Skills.Performs.FengleiPanfa.Fenglei do
  @moduledoc """
  风雷四击「fenglei」（对照 `kungfu/skill/fenglei-panfa/fenglei.c`）

  风雷盘法锤法绝招：需装备 `hammer` 类武器，连出四式
  （风起云涌 / 狂风骤雨 / 雷霆万钧 / 电闪雷鸣），依次以目标
  dodge / dodge / force / parry 为防御值判定命中。

  攻击方算 `ap`（hammer 技能）与基础 `damage` 并下发 `combat/perform-incoming`，
  由目标侧 `resolve_incoming` 逐式判定并广播，最后回执消耗与忙乱。

  差异（TODO(migrate)）：
  - LPC 的 `me->query_temp("weapon")` 对应 `combat.equipped[:weapon]`。
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

  @perform_id "fenglei-panfa/fenglei"
  @move_name "「风雷四击」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_mapped(stats),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character) do
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (!objectp(weapon) || weapon->query("skill_type") != "hammer")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "hammer" do
      {:ok, weapon}
    else
      {:error, "你目前所装备的武器无法使用出#{@move_name}。\n"}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "hammer") == "fenglei-panfa" do
      :ok
    else
      {:error, "你没有激发风雷盘法，不能使用#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "fenglei-panfa")

    if level < 150 do
      {:error, "你的风雷盘法不够娴熟，还使不出#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level, weapon) do
    rng = &:rand.uniform/1
    stats = character.meta.stats

    damage = div(level, 2)
    damage = damage + Engine.rand(rng, div(damage, 2))

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        ap: Stats.skill(stats, "hammer"),
        damage: damage,
        neili: 400 + Engine.rand(rng, 100),
        busy: 2 + Engine.rand(rng, 5),
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
    damage = Map.get(data, :damage, 0)
    neili = Map.get(data, :neili, 400)
    busy = Map.get(data, :busy, 2)

    dodge = Stats.skill(stats, "dodge")
    force = Stats.skill(stats, "force")
    parry = Stats.skill(stats, "parry")

    # 风起云涌（dp = dodge，外伤 30）
    conn =
      Broadcast.publish(
        conn,
        "$N喝道：“风起云涌！”身形陡然加快，单手高举" <>
          weapon_name <> "，便如狂风一般袭向$n。\n",
        bindings
      )

    {qi, wound, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dodge do
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被这招击个正中。\n",
              bindings
            )
          )

        {damage, div(damage * 30, 100), conn}
      else
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p冷静非凡，丝毫不为这奇幻的招数所动，凝神抵挡，不漏半点破绽！\n",
              bindings
            )
          )

        {0, 0, conn}
      end

    # 狂风骤雨（dp = dodge，外伤 32）
    conn =
      Broadcast.publish(
        conn,
        "$N喝道：“狂风骤雨！”手中" <>
          weapon_name <> "一阵狂舞，气势如虹，铺天盖地连续向$n攻去。\n",
        bindings
      )

    {qi, wound, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dodge do
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被这招击个正中。\n",
              bindings
            )
          )

        {qi + damage, wound + div(damage * 32, 100), conn}
      else
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p冷静非凡，丝毫不为这奇幻的招数所动，凝神抵挡，不漏半点破绽！\n",
              bindings
            )
          )

        {qi, wound, conn}
      end

    # 雷霆万钧（dp = force，外伤 33）
    conn =
      Broadcast.publish(
        conn,
        "$N喝道：“雷霆万钧！”跃至半空，手中" <>
          weapon_name <> "一个盘旋，携着万钧之劲凌空贯向$n。\n",
        bindings
      )

    {qi, wound, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > force do
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被这招击个正中。\n",
              bindings
            )
          )

        {qi + damage, wound + div(damage * 33, 100), conn}
      else
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p冷静非凡，丝毫不为这奇幻的招数所动，凝神抵挡，不漏半点破绽！\n",
              bindings
            )
          )

        {qi, wound, conn}
      end

    # 电闪雷鸣（dp = parry，外伤 35）
    conn =
      Broadcast.publish(
        conn,
        "$N喝道：“电闪雷鸣！”猛地向前直冲数尺，手中" <>
          weapon_name <> "幻出一道黄芒，闪电一般射出。\n",
        bindings
      )

    {qi, wound, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > parry do
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p一楞，只见$P身形一闪，已晃至自己跟前，躲闪不及，被这招击个正中。\n",
              bindings
            )
          )

        {qi + damage, wound + div(damage * 35, 100), conn}
      else
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$p冷静非凡，丝毫不为这奇幻的招数所动，凝神抵挡，不漏半点破绽！\n",
              bindings
            )
          )

        {qi, wound, conn}
      end

    # LPC: me->start_busy(2 + random(5)); me->add("neili", -400 - random(100));
    Performs.feedback(attacker, neili, busy)

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
      id: "fenglei-panfa/fenglei",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
