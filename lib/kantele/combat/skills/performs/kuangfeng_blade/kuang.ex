defmodule Kantele.Combat.Skills.Performs.KuangfengBlade.Kuang do
  @moduledoc """
  perform「狂风二十一式」（source kuangfeng-blade/kuang.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 狂风刀法>=70 → 内力>=200 →
  目标存活。.c 无 can_perform/武器/激发/准备门槛（框架统一的 check_perform_known
  仍保留；无武器门槛故不查兵器）。
  命中判定：random(攻击方战斗经验) > 目标战斗经验/2。
  施法即扣 60 内力、忙乱 2（命中与否都扣）；命中：目标忙乱 3，
  伤害 = 刀法/2 + random(刀法/2)、40% 外伤；未命中仅文案。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.Vitals

  @perform_id "kuangfeng-blade/kuang"
  @move_name "「狂风二十一式」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kuangfeng-blade")
    blade = Stats.skill(stats, "blade")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          # LPC: damage = me->query_skill("blade")；blade 供目标侧折算伤害
          blade: blade,
          # LPC: random(me->query("combat_exp")) > target->query("combat_exp") / 2
          combat_exp: stats.combat_exp,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你只能对战斗中的对手使用#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("kuangfeng-blade", 1) < 70)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "kuangfeng-blade") < 70 do
      {:error, "你目前功力还使不出#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIC "$N" HIC "淡然一笑，……$n" HIC "只觉得心跳都停止了！\n" NOR;
  # （C 侧各段字面量仅由颜色宏/空白分隔，合并为同一条文案）
  # LPC: me->add("neili", -60); me->start_busy(2);（命中与否都扣）
  defp apply_effect(conn, character, target) do
    msg =
      "$N淡然一笑，本就快捷绝伦的刀法骤然变得更加凌厉！就在这一瞬之间，$N已劈出二十一刀！\n刀夹杂着风，风里含着刀影！$n只觉得心跳都停止了！\n"

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 60}
    combat = Combat.start_busy(character.meta.combat, 2)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    atk_exp = max(Map.get(data, :combat_exp, 0), 1)
    blade = Map.get(data, :blade, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
    def_exp = character.meta.stats.combat_exp

    if Engine.rand(rng, atk_exp) > div(def_exp, 2) do
      # LPC: target->start_busy(3);
      #      damage = me->query_skill("blade"); damage = damage / 2 + random(damage / 2);
      #      do_damage(me, target, WEAPON_ATTACK, damage, 40, …);
      damage = div(blade, 2) + Engine.rand(rng, div(blade, 2))
      character = apply_damage(character, damage, 40)
      combat = Combat.start_busy(character.meta.combat, 3)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "只见$n已被$N切得体无完肤，血如箭般由全身喷射而出！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p急忙抽身躲开，使$P这招没有得逞。\n", bindings)
      )
      |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, percent, msg)
  # wound = damage * percent / 100（armor 未建模，按 percent 直算）
  defp apply_damage(character, damage, percent) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * percent, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // kuang.c -「狂风二十一式」
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("你只能对战斗中的对手使用「狂风二十一式」。\n");
  # 
  #         if ((int)me->query_skill("kuangfeng-blade", 1) < 70)
  #                 return notify_fail("你目前功力还使不出「狂风二十一式」。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -60);
  #         msg = HIC "$N" HIC "淡然一笑，本就快捷绝伦的刀法骤然变"
  #               "得更加凌厉！就在这一瞬之间，$N" HIC "已劈出二十"
  #               "一刀！\n刀夹杂着风，风里含着刀影！$n"
  #               HIC "只觉得心跳都停止了！\n" NOR;
  #         me->start_busy(2);
  # 
  #         if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
  #         {
  #                 target->start_busy(3);
  #                 damage = (int)me->query_skill("blade");
  #                 damage = damage / 2 + random(damage / 2);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40, 
  #                                            HIR "只见$n" HIR "已被$N" HIR
  #                                            "切得体无完肤，血如箭般由全身喷射而出！\n" NOR);
  #         } else
  #         {
  #                 msg += HIC "可是$p" HIC "急忙抽身躲开，使$P"
  #                        HIC "这招没有得逞。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
