defmodule Kantele.Combat.Skills.Performs.SongshanQuan.Chui do
  @moduledoc """
  perform「千斤锤」（source songshan-quan/chui.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "songshan-quan/chui"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "songshan-quan")
    ap = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
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
      Stats.skill(stats, "force") < 40 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "songshan-quan") < 30 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 120 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 30}
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 30, 1)
    result = Messages.interpolate("$N出手既快，方位又奇，$n闪避不及，闷哼一声，已然中拳。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-30"}], "assign_refs": [{"ap", "cuff"}, {"damage", "songshan-quan"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(2 + random(3));"], "level_gates": [{"force", "40"}, {"songshan-quan", "30"}], "prepared_gates": [{"cuff", "songshan-quan"}], "remote_damage": true, "resource_gates": [{"neili", "120"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define CHUI "「" HIG "千斤锤" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/songshan-quan/chui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CHUI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(CHUI "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("songshan-quan", 1) < 30)
  #                 return notify_fail("你嵩山拳法不够娴熟，难以施展" CHUI "。\n");;
  # 
  #         if (me->query_skill_prepared("cuff") != "songshan-quan")
  #                 return notify_fail("你没有准备嵩山拳法，难以施展" CHUI "。\n");
  # 
  #         if (me->query_skill("force") < 40)
  #                 return notify_fail("你的内功修为不够，难以施展" CHUI "。\n");
  # 
  #         if ((int)me->query("neili") < 120)
  #                 return notify_fail("你现在的真气不够，难以施展" CHUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "\n$N" HIC "双拳挥出，施一招「" HIG "千斤锤"
  #               HIC "」，拳速极快，部位极准，" HIC "分袭$n" HIC "面"
  #               "门和胸口。\n" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = (int)me->query_skill("songshan-quan", 1);
  #                 damage += random(damage / 2);
  # 
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 35,
  #                                           HIR "$N" HIR "出手既快，方位又奇，$n"
  #                                           HIR "闪避不及，闷哼一声，已然中拳。\n" NOR);
  # 
  #                 me->add("neili", -100);
  #             me->start_busy(2 + random(2));
  #         } else
  #         {
  #                 msg = CYN "$n" CYN "不慌不忙，以快打快，将$N"
  #                       CYN "这招化去。\n" NOR;
  # 
  #                 me->add("neili", -30);
  #             me->start_busy(2 + random(3));
  #         }
  #         message_vision(msg, me, target);
  #         return 1;
  # }
end
