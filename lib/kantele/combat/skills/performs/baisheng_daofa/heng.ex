defmodule Kantele.Combat.Skills.Performs.BaishengDaofa.Heng do
  @moduledoc """
  横扫千军「heng」（对照 `kungfu/skill/baisheng-daofa/heng.c`）

  百胜刀法必杀绝招：须持 blade 类武器，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加伤害。

  门槛（攻击方，逐条对齐 LPC）：目标在战斗中、手持 blade 类武器、
  `baisheng-daofa>=150`、`mapped("blade")=="baisheng-daofa"`、`force>=200`、
  `neili>=500`。

  攻击方按 `query("character")` 选起手文案（`光明磊落` 额外 `ap += ap/4`）、
  发 `perform-incoming`；目标侧按 `ap/2 + rand(ap) > dp`
  （ap=blade+str*5，dp=force+str*5）判定：
  - 命中：伤害 `ap + rand(ap/3)`（50% 外伤）、扣 350 内力、忙乱 3；
    追加 `final` 文案：`ap/3>dp` → `就此毙命！`（目标即死）；
    `ap/2>dp` 且目标持械 → `<目标兵器>再也拿捏不住，应声而出。`；
  - 未中：`$n奋力招架，硬生生的挡住了这令天地失色之必杀一击！`，扣 150 内力、忙乱 4。

  差异（TODO(migrate)）：
  - LPC `final` 分支的 `weapon->move(environment(me))`（缴械落地）本版仅保留文案，
    未实现实际移出（沿用 shenmen_jian/ci 先例）。
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

  @perform_id "baisheng-daofa/heng"
  @move_name "「横扫千军」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon_name} <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force_level(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, weapon_name)
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

  # if (! objectp(weapon = me->query_temp("weapon")) ||
  #     (string)weapon->query("skill_type") != "blade")
  #         return notify_fail("你所使用的武器不对，难以施展" HENG "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      {:ok, Map.get(weapon, :name) || ""}
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # if ((int)me->query_skill("baisheng-daofa", 1) < 150)
  #         return notify_fail("你百胜刀法还不到家，难以施展" HENG "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "baisheng-daofa") < 150 do
      {:error, "你百胜刀法还不到家，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (me->query_skill_mapped("blade") != "baisheng-daofa")
  #         return notify_fail("你没有激发百胜刀法，难以施展" HENG "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "baisheng-daofa" do
      :ok
    else
      {:error, "你没有激发百胜刀法，难以施展#{@move_name}。\n"}
    end
  end

  # if ((int)me->query_skill("force") < 200)
  #         return notify_fail("你的内功火候不够，难以施展" HENG "。\n");
  defp check_force_level(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if ((int)me->query("neili") < 500)
  #         return notify_fail("你现在的真气不够，难以施展" HENG "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon_name) do
    stats = character.meta.stats
    # LPC: ap = me->query_skill("blade") + me->query_str() * 5;
    ap = Stats.skill(stats, "blade") + Stats.query_str(stats) * 5

    # LPC: if (me->query("character") == "光明磊落") { …msg…; ap += ap * 1 / 4; }
    #      else …msg…
    {ap, opening} =
      if Map.get(character.meta, :character) == "光明磊落" do
        msg =
          "$N嗔目大喝，杀气凛然而起，手持" <>
            weapon_name <> "义无反顾的猛然横扫$n，全然不顾生死，浩气怅然！\n"

        {ap + div(ap, 4), msg}
      else
        msg =
          "$N狂提内劲，将全身力道灌注于" <>
            weapon_name <> "之上疾斩劈出，“唰”的一声扫向$n而去！\n"

        {ap, msg}
      end

    conn = Broadcast.publish(conn, opening, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{attacker: ref(character), perform_id: @perform_id, ap: ap}
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats

    # LPC: dp = target->query_skill("force") + target->query_str() * 5;
    dp = Stats.skill(stats, "force") + Stats.query_str(stats) * 5

    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap + random(ap / 3); me->add("neili", -350); me->start_busy(3)
      damage = ap + Engine.rand(rng, max(div(ap, 3), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 50, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 350, 3)

      # LPC final(): 基础文案 + 依 ap/dp 追加分支
      base =
        Messages.interpolate(
          "$n连忙抵挡，却那里招架得住，整个人被这一击打得飞身而起，远落平沙。",
          bindings
        )

      target_weapon = Combat.weapon(character.meta.combat)

      cond do
        div(ap, 3) > dp ->
          # LPC: msg += "就此毙命！\n"; char_killed(target, me) → 目标即死
          vitals = %{character.meta.vitals | qi: 0}
          combat = %{character.meta.combat | dead: true}
          character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

          conn
          |> Broadcast.publish(base <> "就此毙命！\n")
          |> put_character(character)

        div(ap, 2) > dp and target_weapon != nil ->
          # LPC: msg += "手中的" + weapon->name() + "再也拿捏不住，应声而出。\n";
          #      weapon->move(environment(me))（本版仅保留文案）
          weapon_name = Map.get(target_weapon, :name) || ""

          conn
          |> Broadcast.publish(base <> "手中的" <> weapon_name <> "再也拿捏不住，应声而出。\n")
          |> put_character(character)

        true ->
          Broadcast.publish(conn, base <> "\n")
      end
    else
      # LPC: me->add("neili", -150); me->start_busy(4)
      Performs.feedback(attacker, 150, 4)

      Broadcast.publish(
        conn,
        Messages.interpolate(
          "$n奋力招架，硬生生的挡住了这令天地失色之必杀一击！\n",
          bindings
        )
      )
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
