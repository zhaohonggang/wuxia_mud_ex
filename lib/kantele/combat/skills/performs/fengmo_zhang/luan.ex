defmodule Kantele.Combat.Skills.Performs.FengmoZhang.Luan do
  @moduledoc """
  perform「群魔乱舞」（source fengmo-zhang/luan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → 持杖 → 疯魔杖法>=120 → 激发 `staff` 为
  疯魔杖法 → 内功>=150 → 真气>=200 → 目标存活。
  起手广播后连出 5 击，每击 50% 概率令未忙乱的目标忙乱 1 回合；
  攻击方扣 100 真气并忙乱 `1 + random(5)`（由目标侧 `combat/perform-feedback` 回执）。

  差异（TODO(migrate)）：
  - LPC 的 5 次 `COMBAT_D->do_attack(me, target, weapon, 0)`（完整 AP/DP/招架/伤害管线）
    折算为每击 `level/15` 基础伤害 + 命中判定 `level/2 + random(level)` vs 目标 dodge
    （同 duanjia-sword/jue、dongyang-dao/luan）；
  - `.c` 的起手文案 `"…手中" + weapon->name() + "接二连三朝$n挥去。"` 按原样拆为三段；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "fengmo-zhang/luan"
  @move_name "「群魔乱舞」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "fengmo-zhang")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- check_weapon(character),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          skill: level,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # 框架层「是否已学此招」门槛（.c 未列 `can_perform`，见 moduledoc 差异说明）。
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #         || (string)weapon->query("skill_type") != "staff")
  defp check_weapon(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: "staff"} = weapon -> {:ok, weapon}
      _ -> {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("fengmo-zhang", 1) < 120)
  defp check_level(stats) do
    if Stats.skill(stats, "fengmo-zhang") < 120 do
      {:error, "你疯魔杖法火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("staff") != "fengmo-zhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "staff") != "fengmo-zhang" do
      {:error, "你没有激发疯魔杖法，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 150)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活。
  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target, weapon) do
    # LPC: msg = HIY "$N" HIY "眼中杀气大盛，施出疯魔杖「" HIR "群魔乱舞"
    #            HIY "」绝技，手中" + weapon->name() + HIY "接二连三朝$n"
    #            HIY "挥去。\n" NOR;
    #      message_combatd(msg, me, target);
    # 按 LPC 字符串拼接结构拆分：`"…绝技，手中" + weapon->name() + "接二连三朝$n挥去。"`。
    conn
    |> Broadcast.publish(
      "$N眼中杀气大盛，施出疯魔杖「群魔乱舞」绝技，手中" <>
        Map.get(weapon, :name) <> "接二连三朝$n挥去。\n",
      n1: character.name,
      n2: target.name
    )
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
    level = max(Map.get(data, :level, 0), 1)
    bindings = [n1: attacker.name, n2: character.name]
    dodge = Stats.skill(character.meta.stats, "dodge")
    per_hit = max(div(level, 15), 1)

    # LPC: for (i = 0; i < 5; i++) { if (! me->is_fighting(target)) break;
    #        if (random(2) && ! target->is_busy()) target->start_busy(1);
    #        COMBAT_D->do_attack(me, target, weapon, 0); }
    # 折算：每击 level/15 基础伤害 + 命中判定（level/2 + random(level) vs 目标 dodge）。
    {combat, damage, hits} =
      Enum.reduce(1..5, {character.meta.combat, 0, 0}, fn _, {combat_acc, damage_acc, hit_acc} ->
        # if (random(2) && ! target->is_busy()) target->start_busy(1);
        combat_acc =
          if Engine.rand(rng, 2) == 1 and combat_acc.busy == 0 do
            Combat.start_busy(combat_acc, 1)
          else
            combat_acc
          end

        if div(level, 2) + Engine.rand(rng, level) > dodge do
          {combat_acc, damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1}
        else
          {combat_acc, damage_acc, hit_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: me->add("neili", -100); me->start_busy(1 + random(5));
    Performs.feedback(attacker, 100, 1 + Engine.rand(rng, 5))

    result =
      if hits > 0 do
        Messages.interpolate("$n被$N击中！", bindings)
      else
        Messages.interpolate("可是$n左闪右避，堪堪避开了$N的群魔乱舞。", bindings)
      end

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LUAN "「" HIR "群魔乱舞" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int i;
  #  
  #         if (userp(me) && ! me->query("can_perform/fengmo-zhang/luan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "staff")
  #                 return notify_fail("你所使用的武器不对，难以施展" LUAN "。\n");
  # 
  #         if ((int)me->query_skill("fengmo-zhang", 1) < 120)
  #                 return notify_fail("你疯魔杖法火候不够，难以施展" LUAN "。\n");
  # 
  #         if (me->query_skill_mapped("staff") != "fengmo-zhang")
  #                 return notify_fail("你没有激发疯魔杖法，难以施展" LUAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" LUAN "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不足，难以施展" LUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "眼中杀气大盛，施出疯魔杖「" HIR "群魔乱舞"
  #               HIY "」绝技，手中" + weapon->name() + HIY "接二连三朝$n"
  #               HIY "挥去。\n" NOR;
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -100);
  # 
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(2) && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  #         me->start_busy(1 + random(5));
  #         return 1;
  # }
end
