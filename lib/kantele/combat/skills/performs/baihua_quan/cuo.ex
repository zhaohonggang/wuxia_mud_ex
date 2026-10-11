defmodule Kantele.Combat.Skills.Performs.BaihuaQuan.Cuo do
  @moduledoc """
  perform「cuo」（source baihua-quan/cuo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "baihua-quan/cuo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "baihua-quan")
    i = 10
    count = 0

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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "baihua-quan") < 160 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
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
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("$n只感到头晕目眩，只见$N或掌、或爪、或拳、或指铺天盖地的向自己各个部位袭来！
只一瞬间，全身竟已多了数十出伤痕，鲜血狂泻不止！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "apply_adds": ["attack"], "assign_refs": [{"count", "baihua-quan"}, {"lvl", "baihua-quan"}], "busy_lines": ["if (i > 5 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(6));"], "level_gates": [{"baihua-quan", "160"}], "prepared_gates": [{"claw", "baihua-quan"}, {"cuff", "baihua-quan"}, {"hand", "baihua-quan"}, {"strike", "baihua-quan"}, {"unarmed", "baihua-quan"}], "remote_damage": false, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("百花错乱只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "baihua-quan" &&
  #             me->query_skill_prepared("cuff") != "baihua-quan" &&
  #             me->query_skill_prepared("strike") != "baihua-quan" &&
  #             me->query_skill_prepared("claw") != "baihua-quan" &&
  #             me->query_skill_prepared("hand") != "baihua-quan")
  #                 return notify_fail("你现在没有准备使用百花错拳，无法施展百花错乱！\n");
  #  
  #         if (me->query_temp("weapon"))
  #                 return notify_fail("百花错乱须是空手才能施展。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，无法施展百花错乱。\n");
  # 
  #         if ((lvl = me->query_skill("baihua-quan", 1)) < 160)
  #                 return notify_fail("你的百花错拳还不够纯熟！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "只见$N使出百花错拳的精妙百花错乱，擒拿手中夹着鹰爪功，左手查拳，右手绵掌。攻\n"
  #                   "出去是八卦掌，收回时已是太极拳，诸家杂陈，毫无规律，只令$n眼花缭乱。\n\n" NOR;
  #         i = 10;
  #         if (lvl * 2 / 3 - random(lvl) > (int)target->query_skill("parry") / 2)
  #         {
  #                 msg += HIW "$n只感到头晕目眩，只见$N或掌、或爪、或拳、或指铺天盖地的向自己各个部位袭来！\n"
  #                            "只一瞬间，全身竟已多了数十出伤痕，"NOR+HIR"鲜血"NOR+HIW"狂泻不止！\n"NOR;
  #                 count = me->query_skill("baihua-quan", 1) / 6;
  #                 me->add_temp("apply/attack", count);
  #                 i += random(5);
  #         } else
  #         {
  #                 msg += HIY "$n只见$N运拳如奔，快拳缤纷递出，连忙振作精神勉强抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add("neili", -300);
  # 
  #         while (i--)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (i > 5 && ! target->is_busy())
  #                         target->start_busy(1);
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->start_busy(1 + random(6));
  #         return 1;
  # }
end
