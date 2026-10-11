defmodule Kantele.Combat.Skills.Performs.RiyueLun.Lian do
  @moduledoc """
  perform「五轮连转」（source riyue-lun/lian.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
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

  @perform_id "riyue-lun/lian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "riyue-lun")
    count = div(Stats.skill(stats, "longxiang-gong"), 4)
    i = 0

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          rng: rng
        }
      })

      apply_effect(conn, character)
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

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "longxiang-gong") < 90 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "riyue-lun") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "hammer") != "riyue-lun" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 250}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
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
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 250, 1)
    result = Messages.interpolate("突然间铁轮从日月金轮中分离开来，化作一道红芒朝$n砸去。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-250"}], "apply_adds": ["attack", "damage"], "assign_refs": [{"count", "force"}, {"count", "longxiang-gong"}], "busy_lines": ["me->start_busy(1 + random(5));"], "level_gates": [{"force", "250"}, {"longxiang-gong", "90"}, {"riyue-lun", "150"}], "map_gates": [{"hammer", "riyue-lun"}], "remote_damage": false, "resource_gates": [{"max_neili", "3000"}, {"neili", "500"}], "var_gates": [{"i", "5"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LIAN "「" HIW "五轮连转" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string wp, msg;
  #         int i, count;
  # 
  #         if (userp(me) && ! me->query("can_perform/riyue-lun/lian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "hammer")
  #                 return notify_fail("你所使用的武器不对，难以施展" LIAN "。\n");
  # 
  #         if (me->query_skill_mapped("hammer") != "riyue-lun")
  #                 return notify_fail("你没有激发日月轮法，难以施展" LIAN "。\n");
  # 
  #         if ((int)me->query_skill("riyue-lun", 1) < 150)
  #                 return notify_fail("你日月轮法火候不足，难以施展" LIAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 250)
  #                 return notify_fail("你的内功火候不足，难以施展" LIAN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不足，难以施展" LIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" LIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wp = weapon->name();
  # 
  #         msg = HIY "$N" HIY "嗔目大喝，施展出日月轮法「" HIW "五轮连转"
  #               HIY "」神技，蓦地将手中" + wp + HIY "飞掷\n而出，幻作数"
  #               "道光芒，相互盘旋着压向$n" HIY "，招术煞为精奇！\n" NOR;
  #         message_combatd(msg, me, target);
  # 
  #         if ((int)me->query_skill("longxiang-gong", 1) < 90)
  #                 count = me->query_skill("force", 1) / 8;
  #         else
  #                 count = me->query_skill("longxiang-gong", 1) / 4;
  # 
  #         me->add_temp("apply/attack", count);
  #         me->add_temp("apply/damage", count * 2 / 3);
  # 
  #         for (i = 0; i < 5; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (! weapon->is_item_make()
  #                    && weapon->query("id") == "riyue jinlun")
  #                 {
  #                         switch (i)
  #                         {
  #                         case 0:
  #                                 msg = WHT "突然间锡轮从日月金轮中分离"
  #                                       "开来，化作一道灰芒朝$n" WHT "砸"
  #                                       "去。\n" NOR;
  #                                 break;
  #                         case 1:
  #                                 msg = HIR "突然间铁轮从日月金轮中分离"
  #                                       "开来，化作一道红芒朝$n" HIR "砸"
  #                                       "去。\n" NOR;
  #                                 break;
  #                         case 2:
  #                                 msg = YEL "突然间铜轮从日月金轮中分离"
  #                                       "开来，化作一道黄芒朝$n" YEL "砸"
  #                                       "去。\n" NOR;
  #                                 break;
  #                         case 3:
  #                                 msg = HIW "突然间银轮从日月金轮中分离"
  #                                       "开来，化作一道银芒朝$n" HIW "砸"
  #                                       "去。\n" NOR;
  #                                 break;
  #                         default:
  #                                 msg = HIY "突然间金轮从日月金轮中分离"
  #                                       "开来，化作一道金芒朝$n" HIY "砸"
  #                                       "去。\n" NOR;
  #                                 break;
  #                         }
  #                         message_combatd(msg, me, target);
  #                         COMBAT_D->do_attack(me, target, weapon, 30);
  #                 } else
  #                         COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  #     me->add("neili", -250);
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/damage", -count * 2 / 3);
  #     me->start_busy(1 + random(5));
  #     return 1;
  # }
end
