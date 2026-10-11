defmodule Kantele.Combat.Skills.Performs.ZhemeiShou.Hua do
  @moduledoc """
  perform「化妖功」（source zhemei-shou/hua.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "zhemei-shou/hua"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "zhemei-shou")
    improve = 0
    n = 0
    i = 0
    ap = (Stats.skill(stats, "dodge") + Stats.skill(stats, "hand"))
    damage = ap
    lv = Stats.skill(stats, "zhemei-shou")
    cost_neili = (-200)

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
      Stats.skill(stats, "beiming-shengong") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xiaowuxiang") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "zhemei-shou") < 220 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "beiming-shengong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "xiaowuxiang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "hand") != "zhemei-shou" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
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
    combat = Combat.start_busy(combat, 1)
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
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.damage(vitals, :qi, damage)
          vitals = Vitals.wound(vitals, :qi, div(damage, 2))
          vitals = Vitals.damage(vitals, :jing, div(damage, 4))
          vitals = Vitals.wound(vitals, :jing, div(damage, 8))
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 200, 3)
    result = if hit, do: Messages.interpolate("", n1: attacker.name, n2: character.name), else: Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "assign_refs": [{"ap", "dodge"}, {"dp", "dodge"}, {"lv", "zhemei-shou"}], "busy_lines": ["me->start_busy(1);", "me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"beiming-shengong", "220"}, {"xiaowuxiang", "220"}, {"zhemei-shou", "220"}], "map_gates": [{"force", "beiming-shengong"}, {"force", "xiaowuxiang"}, {"hand", "zhemei-shou"}], "prepared_gates": [{"hand", "zhemei-shou"}], "remote_damage": false, "resource_gates": [{"max_neili", "4000"}, {"neili", "800"}], "var_gates": [{"damage", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # #define HUA "「" HIR "化妖功" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  #         int ap, dp, p;
  #         int lv, cost_neili;
  # 
  #         float improve;
  #         int lvl, i, n;
  #         string martial;
  #         string *ks;
  #         martial = "hand";
  # 
  #         if (userp(me) && ! me->query("can_perform/zhemei-shou/hua"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUA "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HUA "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("beiming-shengong", 1) < 220
  #             && (int)me->query_skill("xiaowuxiang", 1) < 220)
  #                 return notify_fail("你的逍遥内功火候不够，难以施展" HUA "。\n");
  # 
  #         if (lv = (int)me->query_skill("zhemei-shou", 1) < 220)
  #                 return notify_fail("你逍遥折梅手等级不够，难以施展" HUA "。\n");
  # 
  #         if (me->query("max_neili") < 4000)
  #                 return notify_fail("你的内力修为不足，难以施展" HUA "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "beiming-shengong"
  #             && me->query_skill_mapped("force") != "xiaowuxiang")
  #                 return notify_fail("你没有激发逍遥内功，难以施展" HUA "。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "zhemei-shou")
  #                 return notify_fail("你没有激发逍遥折梅手，难以施展" HUA "。\n");
  # 
  #         if (me->query_skill_prepared("hand") != "zhemei-shou")
  #                 return notify_fail("你没有准备逍遥折梅手，难以施展" HUA "。\n");
  # 
  #         if (me->query("neili") < 800)
  #                 return notify_fail("你现在真气不足，难以施展" HUA "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIM "$N" HIM "深深吸进一口气，单手挥出，掌缘顿时霞光万道，漾出"
  #               "七色虹彩向$n" HIM "席卷而至。\n" NOR;
  # 
  #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvl = lvl * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (i = 0; i < sizeof(ks); i++)
  #         {
  #             if (SKILL_D(ks[i])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[i], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 4 / 100 / lvl;
  # 
  #         ap = me->query_skill("dodge") + me->query_skill("hand");
  #         dp = target->query_skill("dodge") + target->query_skill("parry");
  # 
  #         ap += ap * improve;
  # 
  #         if (target->is_bad() || ! userp(target))
  #                 ap += ap / 10;
  # 
  #         if (ap * 2 / 3 + random(ap) + random(20) > dp)
  #         {
  #                 damage = 0;
  #                 lv = me->query_skill("zhemei-shou", 1);
  #                 if (lv >= 220)cost_neili = -500;
  #                 if (lv >= 240)cost_neili = -470;
  #                 if (lv >= 260)cost_neili = -440;
  #                 if (lv >= 280)cost_neili = -400;
  #                 if (lv >= 300)cost_neili = -360;
  #                 if (lv >= 320)cost_neili = -320;
  #                 if (lv >= 340)cost_neili = -300;
  #                 if (lv >= 360)cost_neili = -270;
  #                 if (lv >= 400)cost_neili = -200;
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                         msg += HIM "只听$n" HIM "一声尖啸，$N" HIM "的七色掌"
  #                                "劲已尽数注入$p" HIM "体内，顿时将$p" HIM "化"
  #                                "为一滩血水。\n" NOR "( $n" RED "受伤过重，已"
  #                                "经有如风中残烛，随时都可能断气。" NOR ")\n";
  #                         damage = -1;
  #                         me->add("neili", cost_neili);
  #                         me->start_busy(1);
  #                 } else
  #                 {
  #                         damage = ap;
  #                         damage += me->query_temp("apply/unarmed_damage");
  #                         damage += random(damage);
  # 
  #                         target->receive_damage("qi", damage, me);
  #                         target->receive_wound("qi", damage / 2, me);
  #                         target->receive_damage("jing", damage / 4, me);
  #                         target->receive_wound("jing", damage / 8, me);
  #                         p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  # 
  #                         msg += HIM "$n" HIM "只是微微一愣，$N" HIM "的七色掌劲已破体而"
  #                                "入，$p" HIM "便犹如身置洪炉一般，连呕数口鲜血。\n" NOR;
  #                         msg += "( $n" + eff_status_msg(p) + " )\n";
  # 
  #                         me->add("neili", cost_neili);
  #                         me->start_busy(2);
  #                 }
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "见状大惊失色，完全勘破不透$P"
  #                        CYN "招中奥秘，当即飞身跃起丈许，躲闪开来。\n" NOR;
  #                 me->add("neili", -200);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (damage < 0)
  #                 target->die(me);
  # 
  #         return 1;
  # }
end
