defmodule Kantele.Combat.Skills.Performs.XianglongZhang.Hui do
  @moduledoc """
  perform「亢龙有悔」（source xianglong-zhang/hui.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xianglong-zhang/hui"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xianglong-zhang")
    improve = 0

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
      Stats.skill(stats, "force") < 380 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xianglong-zhang") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "xianglong-zhang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 6000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
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
    result = Messages.interpolate("$P身形一闪，竟已晃至$p跟前，$p躲闪不及，顿被击个正中。
$p一声惨嚎，被$P这一掌击中胸前，喀嚓喀嚓断了几根肋骨。
结果$p躲闪不及，$P掌劲顿时穿胸而过，顿时口中鲜血狂喷。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "strike"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(3 + random(4));"], "level_gates": [{"force", "380"}, {"xianglong-zhang", "250"}], "map_gates": [{"strike", "xianglong-zhang"}], "prepared_gates": [{"strike", "xianglong-zhang"}], "remote_damage": true, "resource_gates": [{"max_neili", "6000"}, {"neili", "1000"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HUI "「" HIR "亢龙有悔" NOR "」"
  # #define HUIP "「" HIR "亢龙有悔" HIW "」"
  # #define HUIZ "「" HIY "真·亢龙有悔" HIY "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  #         float improve;
  #         improve = 0;
  # 
  #         if (userp(me) && ! me->query("can_perform/xianglong-zhang/hui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HUI "只能空手使用。\n");
  # 
  #         if ((int)me->query_skill("force") < 380)
  #                 return notify_fail("你内功修为不够，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 6000)
  #                 return notify_fail("你内力修为不够，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query_skill("xianglong-zhang", 1) < 250)
  #                 return notify_fail("你降龙十八掌火候不够，难以施展" HUI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "xianglong-zhang")
  #                 return notify_fail("你没有激发降龙十八掌，难以施展" HUI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "xianglong-zhang")
  #                 return notify_fail("你没有准备降龙十八掌，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query("neili") < 1000)
  #                 return notify_fail("你现在真气不够，难以施展" HUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (me->query("family/family_name") == "丐帮")
  #         {
  #             message_sort( HIY "\n$N" HIY "施展出丐帮绝学 " HUIZ "\n" NOR, me, target);
  #             improve += 10 / 100;
  #         }
  # 
  #         // 第一掌
  #         //ap = me->query_skill("strike") + me->query("str") * 5;
  #         //dp = target->query_skill("dodge") + target->query("dex") * 5;
  #          ap = me->query_skill("strike") + me->query("str") * 10;
  #          dp = target->query_skill("dodge") + target->query("dex") * 10;
  #          ap += ap * improve;
  # 
  #         message_sort(HIW "\n忽然$N" HIW "身形激进，左手一划，右手呼的一掌"
  #                      "拍向$n" HIW "，正是降龙十八掌" HUIP "。力自掌生之际"
  #                      "说到便到，以排山倒海之势向$n" HIW "狂涌而去，当真石"
  #                      "破天惊，威力无比。\n" NOR, me, target);
  # 
  #         if (ap * 2 / 3 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60 + random(10),
  #                                           HIR "$P身形一闪，竟已晃至$p跟前，$p躲"
  #                                           "闪不及，顿被击个正中。\n" NOR);
  #         } else
  #         {
  #                 msg = HIC "却见$p气贯双臂，凝神应对，$P掌"
  #                       "力如泥牛入海，尽数卸去。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         // 第二掌
  #         ap = me->query_skill("strike") + me->query("str") * 10;
  #         dp = target->query_skill("parry") + target->query("int") * 10;
  #         ap += ap * improve;
  # 
  #         message_sort(HIW "\n$N" HIW "一掌既出，身子已然抢到离$n" HIW "三"
  #                      "四丈之外，后掌推前掌两股掌力道合并，又是一招" HUIP
  #                      "攻出，掌力犹如怒潮狂涌，势不可当。霎时$p便觉气息窒"
  #                      "滞，立足不稳。\n" NOR, me, target);
  # 
  #         if (ap * 3 / 5 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 70 + random(10),
  #                                           HIR "$p一声惨嚎，被$P这一掌击中胸前，"
  #                                           "喀嚓喀嚓断了几根肋骨。\n" NOR);
  #         } else
  #         {
  #                 msg = HIC "可是$p全力抵挡招架，竟似游刃有"
  #                       "余，将$P的掌力卸于无形。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         // 第三掌
  #         ap = me->query_skill("strike") + me->query("str") * 10;
  #         dp = target->query_skill("force") + target->query("con") * 10;
  #         ap += ap * improve;
  # 
  #         message_sort(HIW "\n紧跟着$N" HIW "右掌斜挥，前招掌力未消，此招掌"
  #                      "力又到，竟然又攻出一招" HUIP "，掌夹风势，势如破竹，"
  #                      "便如一堵无形气墙，向前疾冲而去。$n" HIW "只觉气血翻"
  #                      "涌，气息沉浊。\n" NOR, me, target);
  # 
  #         if (ap *11 / 20 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap);
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80 + random(10),
  #                                           HIR "结果$p躲闪不及，$P掌劲顿时穿胸而"
  #                                           "过，顿时口中鲜血狂喷。\n" NOR);
  #         } else
  #         {
  #                 msg = HIC "$p眼见来势凶猛，身形疾退，瞬间"
  #                       "飘出三丈，脱出掌力之外。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  #         me->start_busy(3 + random(4));
  #         //me->add("neili", -400 - random(600));
  #         me->add("neili", -400 - random(400));
  #         return 1;
  # }
end
