defmodule Kantele.Combat.Skills.Performs.FiveAvoid.Break do
  @moduledoc """
  perform「五遁绝杀」（source five-avoid/break.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → 气>=70 → 内功>=200 → 真气>=max_neili/2 →
  目标存活。起手广播后按 `five-avoid/30 + 2`（上限 5）循环：
  每轮若目标已脱离（不在敌列表/不同房间）或自身气/真气 < 20，则播「收身停住了
  脚步」并中断；否则播「身影在$n身旁时隐时现 ...」，随后扣气 10、真气 10。
  循环结束后忙乱 1 回合。

  差异（TODO(migrate)）：
  - `if (! COMBAT_D->fight(me, target))` —— `COMBAT_D->fight()` 在
    `adm/daemons/combatd.c` 中声明为 `void`，FluffOS 下以 void 调用作表达式取值
    恒为 0，故 `!0` 恒真，该分支**必然执行**（已核对全库 `kungfu/` 仅此一处
    `if (!..._D->...)`）。本文件照此还原为无条件广播；
  - 本招无目标侧伤害/状态（全部为攻击方自身消耗与房间文案），故不实现
    `resolve_incoming/4`；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `living(target)` 门槛在攻击方侧无 meta 可查，用 `dead?/1` 保守回退
    （敌列表仅存引用快照时恒判存活）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast

  @perform_id "five-avoid/break"
  @move_name "「五遁绝杀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_gates(character, target) do
      apply_effect(conn, character, target)
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
      [] -> {:error, "#{@move_name}只能在战斗中使用。\n"}
    end
  end

  defp check_gates(character, target) do
    with :ok <- check_qi(character),
         :ok <- check_force(character),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      :ok
    end
  end

  # LPC: if ((int)me->query("qi") < 70)
  defp check_qi(character) do
    if character.meta.vitals.qi < 70 do
      {:error, "你的气不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("force") < 200)
  defp check_force(character) do
    if Stats.skill(character.meta.stats, "force") < 200 do
      {:error, "你的内功火候不够，难以施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < (int)me->query("max_neili") / 2)
  defp check_neili(character) do
    vitals = character.meta.vitals

    if vitals.neili < div(vitals.max_neili, 2) do
      {:error, "你的真气不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活。
  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIC "$N使出五行遁中的「五遁绝杀」，身法" "陡然间变得变幻莫测！\n" NOR;
    #      message_combatd(msg, me);
    conn =
      Broadcast.publish(conn, "$N使出五行遁中的「五遁绝杀」，身法陡然间变得变幻莫测！\n",
        n1: character.name
      )

    # LPC: count = (int)me->query_skill("five-avoid") / 30 + 2; if (count > 5) count = 5;
    count = min(div(Stats.skill(character.meta.stats, "five-avoid"), 30) + 2, 5)

    {conn, character} =
      Enum.reduce_while(1..count, {conn, character}, fn _, {conn_acc, char_acc} ->
        combat = char_acc.meta.combat
        vitals = char_acc.meta.vitals

        # LPC: if (! target || (environment(target) != environment(me)) ||
        #         ! me->is_fighting(target) || me->query("qi") < 20 || me->query("neili") < 20)
        if target_gone?(combat, char_acc) or vitals.qi < 20 or vitals.neili < 20 do
          # LPC: message_combatd(WHT "$N的身形倏地一转，收身停住了脚步。\n" NOR, me); break;
          conn_acc =
            Broadcast.publish(conn_acc, "$N的身形倏地一转，收身停住了脚步。\n", n1: char_acc.name)

          {:halt, {conn_acc, char_acc}}
        else
          # LPC: message_combatd(WHT "$N的身影在$n身旁时隐时现 ...\n" NOR, me, target);
          conn_acc =
            Broadcast.publish(conn_acc, "$N的身影在$n身旁时隐时现 ...\n",
              n1: char_acc.name,
              n2: target.name
            )

          # LPC: if (! COMBAT_D->fight(me, target))
          #        message_combatd(WHT "但是$N始终没有找到机会出手！\n" NOR, me);
          # `COMBAT_D->fight()` 为 void，作表达式取值恒 0 → 该分支必然执行。
          conn_acc =
            Broadcast.publish(conn_acc, "但是$N始终没有找到机会出手！\n", n1: char_acc.name)

          # LPC: me->receive_damage("qi", 10); me->add("neili", -10);
          vitals =
            vitals
            |> Vitals.damage(:qi, 10)
            |> Map.update!(:neili, &max(&1 - 10, 0))

          char_acc = %{char_acc | meta: %{char_acc.meta | vitals: vitals}}
          {:cont, {conn_acc, char_acc}}
        end
      end)

    # LPC: me->start_busy(1);
    combat = Combat.start_busy(character.meta.combat, 1)
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: ! target || (environment(target) != environment(me)) || ! me->is_fighting(target)
  defp target_gone?(combat, character) do
    case combat.enemies do
      [enemy | _] -> Map.get(enemy, :room_id) != character.room_id
      [] -> true
    end
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-10"}], "assign_refs": [{"count", "five-avoid"}], "busy_lines": ["me->start_busy(1);"], "level_gates": [{"force", "200"}], "remote_damage": false, "resource_gates": [{"neili", "20"}, {"qi", "20"}, {"qi", "70"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // break.c 五遁绝杀
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「五遁绝杀」只能在战斗中使用。\n");
  # 
  #         if ((int)me->query("qi") < 70)
  #                 return notify_fail("你的气不够，无法施展「五遁绝杀」！\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功火候不够，难以施展「五遁绝杀」！\n");
  # 
  #         if ((int)me->query("neili") < (int)me->query("max_neili") / 2)
  #                 return notify_fail("你的真气不够，无法施展「五遁绝杀」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "使出五行遁中的「五遁绝杀」，身法"
  #               "陡然间变得变幻莫测！\n" NOR;
  # 
  #         message_combatd(msg, me);
  #         count = (int)me->query_skill("five-avoid") / 30 + 2;
  #         if (count > 5 ) count = 5;
  # 
  #         while (count--)
  #         {
  #                 if (! target || (environment(target) != environment(me)) ||
  #                     ! me->is_fighting(target) ||
  #                     me->query("qi") < 20 ||
  #                     me->query("neili") < 20)
  #                 {
  #                         message_combatd(WHT "$N" WHT "的身形倏地一"
  #                                         "转，收身停住了脚步。\n" NOR, me);
  #                         break;
  #                 } else
  # 
  #                 message_combatd(WHT "$N" WHT "的身影在$n"
  #                                 WHT "身旁时隐时现 ...\n" NOR, me, target);
  #                 if (! COMBAT_D->fight(me, target))
  #                         message_combatd(WHT "但是$N" WHT "始终没有找到机会出手！\n" NOR, me);
  #                 me->receive_damage("qi", 10);
  #                 me->add("neili", -10);
  #         }
  # 
  #         me->start_busy(1);
  #         return 1;
  # }
end
