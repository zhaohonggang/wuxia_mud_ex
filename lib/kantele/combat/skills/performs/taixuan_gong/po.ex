defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Po do
  @moduledoc """
  perform「破字诀」（source taixuan-gong/po.c，由 translate_perform.py 生成，inherit F_SSERVER）

  AOE 群攻 perform：对周围所有敌人进行判定，命中则造成 qi/jing 伤害/创伤 + busy + neili 扣减
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

  @perform_id "taixuan-gong/po"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat_state = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taixuan-gong")
    ap = Stats.skill(stats, "force") + Stats.skill(stats, "unarmed") + Stats.skill(stats, "martial-cognize") + lvl + character.meta.stats.con * 10

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character) do
      # AOE: 对所有敌人发送事件
      enemies = character.meta.combat.enemies
      if enemies == [] do
        conn
        |> Broadcast.publish("这里没有可供攻击的对手。\n", n1: character.name)
        |> assign(:prompt, false)
      else
        # 无条件效果：扣内力、busy、前置广播
        conn = apply_effect(conn, character)

        # 向每个敌人发送事件
        Enum.each(enemies, fn enemy ->
          send(enemy.pid, %Event{
            from_pid: self(),
            topic: "combat/perform-incoming",
            data: %{
              attacker: ref(character),
              perform_id: @perform_id,
              level: lvl,
              skill: lvl,
              ap: ap,
              rng: rng
            }
          })
        end)

        conn
        |> assign(:prompt, false)
      end
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

  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_prepared(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "taixuan-gong") < 260 -> {:error, "你的太玄功不够娴熟，难以施展破字诀。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "taixuan-gong" -> {:error, "你的内功没有激发太玄功，难以施展破字诀。\n"}
      true -> :ok
    end
  end

  defp check_prepared(character) do
    stats = character.meta.stats

    cond do
      Stats.prepared(stats, "unarmed") != "taixuan-gong" -> {:error, "你没有准备太玄功拳脚，难以施展破字诀。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals
    stats = character.meta.stats
    enemies = character.meta.combat.enemies
    enemy_count = length(enemies)

    cond do
      vitals.max_neili < 8500 -> {:error, "你的内力修为不足，难以施展破字诀。\n"}
      Stats.skill(stats, "taixuan-gong") < 260 -> {:error, "你的太玄功不够娴熟，难以施展破字诀。\n"}
      vitals.neili < enemy_count * 220 -> {:error, "你的内力不足以支撑破字诀的消耗。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件效果：busy 5，扣内力 (敌人数量 * 220)，前置广播
    vitals = character.meta.vitals
    enemies = character.meta.combat.enemies
    neili_cost = length(character.meta.combat.enemies) * 220

    vitals = %{vitals | neili: max(vitals.neili - neili_cost, 0)}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    combat_state = character.meta.combat
    combat_state = Combat.start_busy(combat_state, 5)
    character = %{character | meta: Map.put(character.meta, :combat, combat_state)}

    conn = Broadcast.publish(conn, "霎时只见$N气贯长虹，双袖猛振，破字诀气劲如排山倒海般向四周敌人卷去！", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(_combat) do
    # AOE perform 不使用单目标 target/1，在 run 中直接处理多目标
    {:error, "AOE perform 使用多目标模式\n"}
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    combat_state = character.meta.combat
    lvl = Map.get(data, :level, 0)
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    stats = character.meta.stats
    dp = Stats.skill(stats, "force") * 2 + Stats.skill(stats, "martial-cognize") + character.meta.stats.con * 10

    # 命中判定：ap * 2 / 3 + random(ap) > dp
    hit = div(ap * 2, 3) + Engine.rand(rng, ap) >= dp

    vitals = character.meta.vitals
    attacker_vitals = attacker.meta.vitals
    attacker_combat_state = attacker.meta.combat

hit_result =
      if hit do
        # 命中：qi/jing 伤害/创伤 + busy 1 + neili -500
        damage = div(ap, 3) + Engine.rand(rng, div(ap, 2))

        vitals = Vitals.damage(vitals, :qi, damage)
        vitals = Vitals.wound(vitals, :qi, div(damage * 2, 3))
        vitals = Vitals.damage(vitals, :jing, div(damage, 4))
        vitals = Vitals.wound(vitals, :jing, div(damage, 6))

        # busy 1
        combat_state = character.meta.combat
        combat_state = Combat.start_busy(combat_state, 1)
        character = %{character | meta: Map.put(character.meta, :combat, combat_state)}

        # 目标 neili -500
        vitals = %{vitals | neili: max(vitals.neili - 500, 0)}

        # 状态消息（简化）
        p = div(vitals.qi * 100, vitals.max_qi)

        # 攻击方反馈
        Performs.feedback(attacker, 500, 1)

        # 命中消息（随机）
        case Engine.rand(rng, 5) do
          0 -> "霎那间#{character.name}受创倒地，鲜血染红了衣襟！"
          1 -> "#{character.name}闷哼一声，连退数步，气息大乱！"
          2 -> "#{character.name}被震得连连后退，骨骼碎裂声不绝于耳！"
          3 -> "#{character.name}剧痛难当，身形踉跄，几欲跌倒！"
          _ -> "#{character.name}痛苦地呻吟，竟被这破字诀打得七荤八素！"
        end
      else
        # 闪避
        Performs.feedback(attacker, 0, 1)

        # 闪避时也需要定义 combat_state 变量
        combat_state = character.meta.combat

        "可是#{character.name}身法诡异，竟在气劲中穿梭自如，竟未沾边！"
      end

    character = Map.put(character, :meta, Map.put(character.meta, :vitals, vitals))
    character = Map.put(character, :meta, Map.put(character.meta, :combat, combat_state))
    attacker = Map.put(attacker, :meta, Map.put(attacker.meta, :vitals, attacker_vitals))
    attacker = Map.put(attacker, :meta, Map.put(attacker.meta, :combat, attacker_combat_state))

    result = Messages.interpolate(hit_result, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
    |> Map.put(:attacker, attacker)
  end

  defp target(_combat) do
    {:error, "AOE perform 使用多目标模式\n"}
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{
  #     "add_costs": [{"neili", "-500"}],
  #     "assign_refs": [{"ap", "force"}, {"dp", "force"}],
  #     "busy_lines": ["me->start_busy(5);", "obs[i]->start_busy(1);"],
  #     "level_gates": [{"taixuan-gong", "260"}],
  #     "map_gates": [{"force", "taixuan-gong"}],
  #     "prepared_gates": [{"unarmed", "taixuan-gong"}],
  #     "remote_damage": false,
  #     "resource_gates": [{"max_neili", "8500"}, {"neili", "0"}],
  #     "set_flags": [{"neili", "0"}]
  #   }

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # inherit F_SSERVER;
  # 
  # #define PO "「" HIC "破字诀" NOR "」"
  # 
  # int perform(object me)
  # {
  #         object *obs;
  #         string msg;
  #         int damage;
  #         int ap, dp;
  #         int flag;
  #         int i;
  #         int p;
  # 
  #         if (userp(me) && ! me->query("can_perform/taixuan-gong/po"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         me->clean_up_enemy();
  # 
  #         if (! me->is_fighting())
  #                 return notify_fail(PO "只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(PO "只能空手施展。\n");
  # 
  #         if (me->query("max_neili") < 8500)
  #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
  # 
  #         if (me->query_skill("taixuan-gong", 1) < 260)
  #                 return notify_fail("你的太玄功不够娴熟，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "taixuan-gong")
  #                 return notify_fail("你的内功没有激发太玄功，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "taixuan-gong")
  #                 return notify_fail("你没有准备太玄功拳脚，难以施展" PO "。\n");
  # 
  #         obs = me->query_enemy();
  # 
  #         if ((int)me->query("neili") < sizeof(obs) * 220)
  #                 return notify_fail("你的内力不足以支撑" PO "的消耗。\n");
  # 
  #         msg = HIW "霎时只见$N" HIW"气贯长虹，双袖猛振，破字诀气劲如排山倒海般向四周敌人卷去！" NOR;
  # 
  #         message_sort(msg, me);
  # 
  #         me->start_busy(5);
  # 
  #         ap = me->query_skill("force", 1) +
  #              me->query_skill("unarmed", 1) +
  #              me->query_skill("martial-cognize", 1) +
  #              me->query_skill("taixuan-gong", 1) +
  #              me->query("con") * 10;
  # 
  #         me->add("neili", -(sizeof(obs) * 220));
  # 
  #         for (flag = 0, i = 0; i < sizeof(obs); i++)
  #         {
  #                 dp = obs[i]->query_skill("force") * 2 +
  #                      obs[i]->query_skill("martial-cognize", 1) +
  #                      obs[i]->query("con") * 10;
  # 
  #                 if (ap * 2 / 3 + random(ap) > dp)
  #                 {
  #                         switch (random(2))
  #                         {
  #                         case 0:
  #                                 tell_object(obs[i], HIR "可怜" + obs[i]->name() + HIR "竟未躲过这一招，身子一软，瘫软在地！" NOR);
  #                                 break;
  # 
  #                         default:
  #                                 tell_object(obs[i], HIR "可怜" + obs[i]->name() + HIR "躲避不及，被破字诀气劲重重击中！" NOR);
  #                                 break;
  #                         }
  # 
  #                         damage = ap / 3 + random(ap / 2);
  # 
  #                         obs[i]->receive_damage("qi", damage, me);
  #                         obs[i]->receive_wound("qi", damage * 2 / 3 , me);
  # 
  #                         obs[i]->receive_damage("jing", damage / 4, me);
  #                         obs[i]->receive_wound("jing", damage / 6, me);
  # 
  #                     p = (int)obs[i]->query("qi") * 100 / (int)obs[i]->query("max_qi");
  # 
  #                         switch (random(5))
  #                         {
  #                         case 0:
  #                                 msg = HIR "可怜" + obs[i]->name() + HIR "一口气没接上来，瘫软在地！" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         case 1:
  #                                 msg = HIR "可怜" + obs[i]->name() + HIR "受了重击，口吐鲜血，摇摇欲坠！" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         case 2:
  #                                 msg = HIR "可怜" + obs[i]->name() + HIR "被打得七荤八素，骨骼碎裂声不绝于耳！" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         case 3:
  #                                 msg = HIR "可怜" + obs[i]->name() + HIR "剧痛难当，身形踉跄，几欲跌倒！" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         default:
  #                                 msg = HIR "可怜" + obs[i]->name() + HIR "痛苦地呻吟，竟被这破字诀打得七荤八素！" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  #                         }
  #                         obs[i]->start_busy(1);
  #                         message("vision", msg, environment(me), ({ obs[i] }));
  #                         obs[i]->add("neili", -500);
  #                         ;
  #                 } else
  #                 {
  #                         tell_object(obs[i], HIY "可是" + obs[i]->name() + HIY "身法诡异，竟在气劲中穿梭自如，竟未沾边！" NOR);
  #                 }
  #                 if (obs[i]->query("neili") < 0)
  #                         obs[i]->set("neili", 0);
  #         }
  # 
  #         if (! flag)
  #                 message_vision(HIY "并没有任何敌人受到波及，尽数避开！\n\n" NOR, me, 0, obs);
  # 
  #         return 1;
  # }
end