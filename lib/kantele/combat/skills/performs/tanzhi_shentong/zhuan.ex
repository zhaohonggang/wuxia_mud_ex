defmodule Kantele.Combat.Skills.Performs.TanzhiShentong.Zhuan do
  @moduledoc """
  perform「转乾坤」（source tanzhi-shentong/zhuan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tanzhi-shentong/zhuan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tanzhi-shentong")
    improve = 0
    n = 0
    m = 0
    count = Stats.skill(stats, "mathematics")
    damage = (-1)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          damage: damage,
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
      Stats.skill(stats, "qimen-wuxing") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tanzhi-shentong") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "finger") != "tanzhi-shentong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
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
    Performs.feedback(attacker, 200, 3)
    result = Messages.interpolate("$N将全身功力聚于一指，指劲按照二十八宿方位云贯而出，正是桃花岛「转乾坤」绝技。
霎那间$n只见寒芒一闪，$N食指已钻入$p印堂半尺，指劲顿时破脑而入。
你听到“噗”的一声，身上竟然溅到几滴脑浆！
( $n受伤过重，已经有如风中残烛，随时都可能断气。)
霎那间$n只见寒芒一闪，$N食指已钻入$p胸堂半尺，指劲顿时破体而入。
你听到“嗤”的一声，身上竟然溅到几滴鲜血！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "assign_refs": [{"ap", "finger"}, {"count", "mathematics"}, {"dp", "force"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);", "me->start_busy(2);"], "level_gates": [{"qimen-wuxing", "200"}, {"tanzhi-shentong", "220"}], "map_gates": [{"finger", "tanzhi-shentong"}], "prepared_gates": [{"finger", "tanzhi-shentong"}], "remote_damage": true, "resource_gates": [{"max_neili", "3500"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHUAN "「" HIR "转乾坤" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      object weapon;
  #         int ap, dp, damage, count;
  #         string msg;
  # 
  #         float improve;
  #         int lvls, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "finger";
  # 
  #         if (userp(me) && ! me->query("can_perform/tanzhi-shentong/zhuan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(ZHUAN "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("tanzhi-shentong", 1) < 220)
  #                 return notify_fail("你的弹指神通不够娴熟，难以施展" ZHUAN "。\n");
  # 
  #         if ((int)me->query_skill("qimen-wuxing", 1) < 200)
  #                 return notify_fail("你的奇门五行修为不够，难以施展" ZHUAN "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "tanzhi-shentong")
  #                 return notify_fail("你没有激发弹指神通，难以施展" ZHUAN "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "tanzhi-shentong")
  #                 return notify_fail("你没有准备弹指神通，难以施展" ZHUAN "。\n");
  # 
  #         if (me->query("max_neili") < 3500)
  #                 return notify_fail("你的内力修为不足，难以施展" ZHUAN "。\n");
  # 
  #         if (me->query("neili") < 800)
  #                 return notify_fail("你现在的真气不够，难以施展" ZHUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "将全身功力聚于一指，指劲按照二十八宿方位云贯而出，正"
  #               "是桃花岛「" HIR "转乾坤" HIC "」绝技。\n" NOR;
  # 
  #         lvls = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvls = lvls * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (m = 0; m < sizeof(ks); m++)
  #         {
  #             if (SKILL_D(ks[m])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[m], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 5 / 100 / lvls;
  # 
  #         ap = me->query_skill("finger") +
  #              me->query_skill("qimen-wuxing", 1) +
  #              me->query_skill("tanzhi-shentong", 1);
  # 
  #         dp = target->query_skill("force") +
  #              target->query_skill("parry", 1) +
  #              target->query_skill("qimen-wuxing", 1);
  #         count = me->query_skill("mathematics", 1);
  #         ap += ap * improve;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = 0;
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                     me->start_busy(2);
  #                         msg += HIR "霎那间$n" HIR "只见寒芒一闪，$N" HIR "食指"
  #                                "已钻入$p" HIR "印堂半尺，指劲顿时破脑而入。\n"
  #                                HIW "你听到“噗”的一声，身上竟然溅到几滴脑浆！"
  #                                "\n" NOR "( $n" RED "受伤过重，已经有如风中残烛"
  #                                "，随时都可能断气。" NOR ")\n";
  #                         damage = -1;
  #                 } else
  #         {
  #                     me->start_busy(3);
  #                     damage = ap + random(ap);
  #                     me->add("neili", -(200 + random(count)));
  #                     msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, (100 + random(count/10)),
  #                                                HIR "霎那间$n" HIR "只见寒芒一闪，$N"
  #                                                    HIR "食指已钻入$p" HIR "胸堂半尺，指劲"
  #                                                    "顿时破体而入。\n你听到“嗤”的一声，"
  #                                                    "身上竟然溅到几滴鲜血！\n" NOR);
  #         }
  #         } else
  #         {
  #                 me->start_busy(2);
  #                 me->add("neili", -200);
  #                 msg += CYN "$p" CYN "见$P" CYN "招式奇特，不感大"
  #                        "意，顿时向后跃数丈，躲闪开来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (damage < 0)
  #                 target->die(me);
  # 
  #         return 1;
  # }
end
