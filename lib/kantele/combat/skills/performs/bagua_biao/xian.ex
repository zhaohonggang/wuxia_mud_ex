defmodule Kantele.Combat.Skills.Performs.BaguaBiao.Xian do
  @moduledoc """
  perform「镖中现掌」（source bagua-biao/xian.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "bagua-biao/xian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bagua-biao")

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
      Stats.skill(stats, "bagua-biao") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "bagua-zhang") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "bagua-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "throwing") != "bagua-biao" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 150 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

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
    Performs.feedback(attacker, 100, 3)
    result = Messages.interpolate("可只见$n哈哈一笑，身子一矮，躲了过去。
哪知方才的暗器竟是虚招，等$p反应时$N已至跟前，双掌齐施，重重的印在$n胸前。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(3);"], "level_gates": [{"bagua-biao", "120"}, {"bagua-zhang", "120"}, {"force", "150"}], "map_gates": [{"strike", "bagua-zhang"}, {"throwing", "bagua-biao"}], "prepared_gates": [{"strike", "bagua-zhang"}], "remote_damage": true, "resource_gates": [{"neili", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XIAN "「" HIY "镖中现掌" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object anqi;
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/bagua-biao/xian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XIAN "只能在战斗中对对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(XIAN "只能空手施展。\n");
  # 
  #         if (! objectp(anqi = me->query_temp("handing"))
  #            || (string)anqi->query("skill_type") != "throwing")
  #                 return notify_fail("你现在手中并没有拿着暗器。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "bagua-zhang") 
  #                 return notify_fail("你没有激发八卦掌，难以施展" XIAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "bagua-zhang") 
  #                 return notify_fail("你没有准备八卦掌，难以施展" XIAN "。\n");
  # 
  #         if (me->query_skill_mapped("throwing") != "bagua-biao") 
  #                 return notify_fail("你没有激发八卦镖诀，难以施展" XIAN "。\n");
  # 
  #         if ((int)me->query_skill("bagua-zhang", 1) < 120)
  #                 return notify_fail("你的八卦掌不够娴熟，难以施展" XIAN "。\n");
  # 
  #         if ((int)me->query_skill("bagua-biao", 1) < 120)
  #                 return notify_fail("你的八卦镖诀不够娴熟，难以施展" XIAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" XIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在真气不足，难以施展" XIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "突然只听$N" HIY "喝道：“$n" HIY "看招！”"
  #               "说完单手一扬，袖底顿时窜出一道金光，直射$n" HIY
  #               "而去！\n" NOR;
  # 
  #         ap = me->query_skill("strike", 1) +
  #              me->query_skill("throwing");
  # 
  #         dp = target->query_skill("dodge", 1) +
  #              target->query_skill("parry", 1);
  # 
  #         me->start_busy(3);
  #         if (anqi->query_amount() > 0)anqi->add_amount(-1);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         { 
  #                 damage = ap / 3 + random(ap / 2);
  #                 me->add("neili", -100);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIY "可只见$n" HIY "哈哈一笑，身子一矮"
  #                                            "，躲了过去。\n" NOR + HIR "哪知方才的"
  #                                            "暗器竟是虚招，等$p" HIR "反应时$N" HIR
  #                                            "已至跟前，双掌齐施，重重的印在$n" HIR
  #                                            "胸前。\n" NOR);
  #         } else
  #         {
  #                 msg += HIY "可是$p" HIY "看破了$P" HIY "的企图，没"
  #                        "有受到迷惑，招手将暗器全部揽了下来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
