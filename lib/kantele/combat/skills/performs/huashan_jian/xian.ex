defmodule Kantele.Combat.Skills.Performs.HuashanJian.Xian do
  @moduledoc """
  夺命连环三仙剑「xian」（对照 `kungfu/skill/huashan-jian/xian.c`）

  华山剑宗绝技：需持剑、华山剑法>=160、dodge>=160、真气>=300、
  激发 sword 为华山剑法。攻击方扣 280 内力并下发 `combat/perform-incoming`，
  由目标侧 `resolve_incoming` 连出三剑（分别对 dodge/force/parry 判定）。

  各剑伤害 `ap + random(ap/3)`（第三剑 `ap + random(ap/2)`），
  外伤比例 `40+random(10)` / `50+random(10)` / `60+random(10)`；忙乱 3。

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

  @perform_id "huashan-jian/xian"
  @move_name "「夺命连环三仙剑」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_dodge(stats),
         :ok <- check_neili(character),
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

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对！\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "huashan-jian")

    if level < 160 do
      {:error, "你华山剑法不够娴熟，无法施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_dodge(stats) do
    if Stats.skill(stats, "dodge") < 160 do
      {:error, "你轻功修为不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "huashan-jian" do
      :ok
    else
      {:error, "你没有激发华山剑法，无法使用#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, _level, weapon) do
    stats = character.meta.stats
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 280}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    weapon_name = Map.get(weapon, :name, "")

    conn =
      Broadcast.publish(
        conn,
        "$N长啸一声，手中" <>
          weapon_name <>
          "随即不停转动，汹涌而出，正是华山剑宗绝技「夺命连环三仙剑」，但是" <>
          weapon_name <> "剑锋突变，一剑顿时化为三剑，袭向$n……\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: Stats.skill(stats, "sword"),
        weapon_name: weapon_name
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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

    dodge = Stats.skill(stats, "dodge")
    force = Stats.skill(stats, "force")
    parry = Stats.skill(stats, "parry")

    # 第一剑：当头直劈（dp = dodge，外伤 40+random(10)）
    conn = Broadcast.publish(conn, "$N将内力全都运到了剑上，呼的一剑，当头直劈。\n", bindings)

    {qi, wound, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) < dodge do
        conn = Broadcast.publish(conn, Messages.interpolate("$n斜身闪开。\n", bindings))
        {0, 0, conn}
      else
        damage = ap + Engine.rand(rng, max(div(ap, 3), 1))

        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$n急忙后退，竟然躲避不及，被$N这一剑震得口吐鲜血，接连后退。\n",
              bindings
            )
          )

        {damage, div(damage * (40 + Engine.rand(rng, 10)), 100), conn}
      end

    # 第二剑：拦腰横削（dp = force，外伤 50+random(10)）
    conn =
      Broadcast.publish(
        conn,
        "$N圈转" <> weapon_name <> "，拦腰横削，剑势恢弘，剑气纵横，令人匪夷所思。\n",
        bindings
      )

    {qi, wound, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) < force do
        conn = Broadcast.publish(conn, Messages.interpolate("$n纵身从剑上越过。\n", bindings))
        {qi, wound, conn}
      else
        damage = ap + Engine.rand(rng, max(div(ap, 3), 1))

        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "此招来势当真快极，$n哪里来得及闪避招架？只见$N剑光闪过，$n腰间霎时鲜血淋漓！\n",
              bindings
            )
          )

        {qi + damage, wound + div(damage * (50 + Engine.rand(rng, 10)), 100), conn}
      end

    # 第三剑：疾刺后心（dp = parry，外伤 60+random(10)）
    conn =
      Broadcast.publish(
        conn,
        "$N长剑反撩，疾刺$p后心，剑法之快，部位之准，当真闻所未闻。\n",
        bindings
      )

    {qi, wound, conn} =
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) < parry do
        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$n身在空中，不及变招，只能挥出一招，正击中$N剑上，略一借力，飘然避去。\n",
              bindings
            )
          )

        {qi, wound, conn}
      else
        damage = ap + Engine.rand(rng, max(div(ap, 2), 1))

        conn =
          Broadcast.publish(
            conn,
            Messages.interpolate(
              "$n身在空中，哪里来得及变招？只见$N此剑掠过，$n大声惨呼，鲜血四下飞溅！\n",
              bindings
            )
          )

        {qi + damage, wound + div(damage * (60 + Engine.rand(rng, 10)), 100), conn}
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
      id: "huashan-jian/xian",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
