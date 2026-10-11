defmodule Kantele.Combat.Skills.Performs.TanzhiShentong.Po do
  @moduledoc """
  perform「破九域」（source tanzhi-shentong/po.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tanzhi-shentong/po"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tanzhi-shentong")
    ap = (Stats.skill(stats, "finger") + Stats.skill(stats, "throwing"))
    damage = (div(ap, 2) + Engine.rand(rng, div(ap, 2)))

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
      Stats.skill(stats, "tanzhi-shentong") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "throwing") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
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
      vitals.max_neili < 2400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
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
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.wound(vitals, :qi, damage)
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 3)
    result = if hit, do: Messages.interpolate("只见那base_unit来势迅猛之极，$n根本无暇闪避，被这招击个正中！", n1: attacker.name, n2: character.name), else: Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "assign_refs": [{"ap", "finger"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"tanzhi-shentong", "180"}, {"throwing", "180"}], "map_gates": [{"finger", "tanzhi-shentong"}], "prepared_gates": [{"finger", "tanzhi-shentong"}], "remote_damage": false, "resource_gates": [{"max_neili", "2400"}, {"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # #define PO "「" HIW "破九域" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int ap, dp, damage, p;
  #         string pmsg;
  #         string msg;
  #         object weapon, weapon2;
  # 
  #         if (userp(me) && ! me->query("can_perform/tanzhi-shentong/po"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PO "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("handing"))
  #            || (string)weapon->query("skill_type") != "throwing")
  #                 return notify_fail("你手中没有拿着暗器，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("tanzhi-shentong", 1) < 180)
  #                 return notify_fail("你弹指神通修为不够，难以施展" PO "。\n");
  # 
  #         if ((int)me->query_skill("throwing", 1) < 180)
  #                 return notify_fail("你基本暗器修为不够，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_mapped("finger") != "tanzhi-shentong")
  #                 return notify_fail("你没有激发弹指神通，难以施展" PO "。\n");
  # 
  #         if (me->query_skill_prepared("finger") != "tanzhi-shentong")
  #                 return notify_fail("你没有准备弹指神通，难以施展" PO "。\n");
  # 
  #         if (me->query("max_neili") < 2400)
  #                 return notify_fail("你的内力修为不足，难以施展" PO "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不够，难以施展" PO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -300);
  #         weapon->add_amount(-1);
  # 
  #         msg = HIW "陡见$N" HIW "双目精光四射，顿听破空声大作，一" +
  #               weapon->query("base_unit") + weapon->name() + HIW "由"
  #               "指尖弹出，疾速射向$n" HIW "。\n" NOR;
  # 
  #         ap = me->query_skill("finger") + me->query_skill("throwing");
  #         dp = target->query_skill("dodge") + target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #             me->start_busy(2);
  #                    //damage = ap / 2 + random(ap / 3);
  #                    damage = ap / 2 + random(ap / 2);
  # 
  #                 msg += HIR "只见那" + weapon->query("base_unit") +
  #                        weapon->name() + HIR "来势迅猛之极，$n" HIR
  #                        "根本无暇闪避，被这招击个正中！\n" NOR;
  # 
  #                 target->receive_wound("qi", damage, me);
  #                    COMBAT_D->clear_ahinfo();
  #                    weapon->hit_ob(me, target, me->query("jiali") + 300);
  # 
  #                 if ((weapon2 = target->query_temp("weapon"))
  #                    && ap / 3 + random(ap) > dp)
  #                 {
  #                         msg += HIW "$n" HIW "手腕一麻，手中" + weapon2->name() +
  #                                HIW "不由脱手而出！\n" NOR;
  #                         weapon2->move(environment(me));
  #                 }
  # 
  #                 p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  #                 if (stringp(pmsg = COMBAT_D->query_ahinfo()))
  #                            msg += pmsg;
  #                            msg += "( $n" + eff_status_msg(p) + " )\n";
  #                    message_combatd(msg, me, target);
  #         } else
  #         {
  #             me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "早料得$P" CYN "有此一着，急"
  #                        "忙飞身跃起，躲闪开来。\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  #         me->reset_action();
  #         return 1;
  # }
end
