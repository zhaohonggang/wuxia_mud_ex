defmodule Kantele.Combat.Skills.Performs.QianzhuWandushou.Zhugu do
  @moduledoc """
  perform「zhugu」（source qianzhu-wandushou/zhugu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "qianzhu-wandushou/zhugu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    improve = 0
    n = 0
    m = 0
    lvl = Stats.skill(stats, "hand")
    damage = (lvl + Engine.rand(rng, div(lvl, 2)))

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
         :ok <- check_resources(character),
         :ok <- check_weapon(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 -> {:error, "你的内功火候不足以施展蛛蛊决。\n"}
      Stats.skill(stats, "qianzhu-wandushou") < 130 -> {:error, "你的千蛛万毒手修为不够，现在还无法施展蛛蛊决。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "hand") != "qianzhu-wandushou" -> {:error, "你没有激发千蛛万毒手，无法施展蛛蛊决。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 400 -> {:error, "你的真气不够，现在无法施展蛛蛊决。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    # TODO(migrate) 武器检查需人工核对（自动提取的文案仅供参考）：
    :ok

  end

  defp check_other(character) do
    # TODO(migrate) 其它门槛（战斗/临时状态/道具等）需人工核对：
    #   {:error, "你要对谁施展蛛蛊决？\n"}
    #   {:error, "看清楚，那不是活人。\n"}
    #   {:error, "这里不能攻击别人！\n"}
    :ok

  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 80}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    combat = Combat.start_busy(combat, 4)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}
    conn = Broadcast.publish(conn, "$N施出蛛蛊决，只见一缕黑气从指尖透出，只一闪就没入了$n的眉心！", n1: character.name)

    conn
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
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 80, 4)
    msg = if hit, do: "$p只觉得一股如山的劲力顺指尖猛攻过来，只觉得全身毒气狂窜，“哇”的一声吐出一口黑血！", else: "可是$p运足内力，以深厚的内功化解了这一指的毒劲。"
    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-80"}], "affect_by": ["qianzhu_wandushou"], "assign_refs": [{"lvl", "hand"}, {"poison", "poison"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(4);"], "level_gates": [{"force", "200"}, {"qianzhu-wandushou", "130"}], "map_gates": [{"hand", "qianzhu-wandushou"}], "remote_damage": true, "resource_gates": [{"neili", "400"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int lvl, poison;
  #         int damage;
  # 
  #         float improve;
  #         int lvls, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "hand";
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/qianzhu-wandushou/zhugu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (environment(me)->query("no_fight"))
  #         return notify_fail("这里不能攻击别人！\n");
  # 
  #     if (! target || ! target->is_character())
  #         return notify_fail("你要对谁施展蛛蛊决？\n");
  # 
  #     if (target->query("not_living"))
  #         return notify_fail("看清楚，那不是活人。\n");
  # 
  #         if ((int)me->query_skill("force") < 200)
  #                 return notify_fail("你的内功火候不足以施展蛛蛊决。\n");
  # 
  #         if ((int)me->query_skill("qianzhu-wandushou", 1) < 130)
  #                 return notify_fail("你的千蛛万毒手修为不够，现在还无法施展蛛蛊决。\n");
  # 
  #         if (me->query_skill_mapped("hand") != "qianzhu-wandushou")
  #                 return notify_fail("你没有激发千蛛万毒手，无法施展蛛蛊决。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，现在无法施展蛛蛊决。\n");
  # 
  #         msg = HIB "$N" HIB "施出蛛蛊决，只见一缕黑气从"
  #               "指尖透出，只一闪就没入了$n" HIB "的眉心！\n" NOR;
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
  #         if (me->query("family/family_name") == "五毒教")
  #             improve += 0.1;
  # 
  #         lvl = me->query_skill("hand");
  #         poison = me->query_skill("poison");
  # 
  #         poison = (int)poison / 15;
  #         lvl += lvl * improve;
  # 
  #         if (lvl / 2 + random(lvl) > target->query_skill("force"))
  #         {
  #                 damage = lvl + random(lvl / 2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 50 + poison,
  #                                            HIR "$p" HIR "只觉得一股如山的劲力顺指尖猛"
  #                                            "攻过来，只觉得全身毒气狂窜，“哇”的一声"
  #                                            "吐出一口黑血！\n" NOR);
  #                 target->affect_by("qianzhu_wandushou",
  #                                   ([ "level" : lvl * 2 / 3 + random(poison),
  #                                      "id"    : me->query("id"),
  #                                      "duration" : lvl / 40 + random(lvl / 18) ]));
  #                 me->add("neili", -200);
  #                 me->start_busy(2);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "运足内力，以深厚的内功"
  #                        "化解了这一指的毒劲。\n" NOR;
  #                 me->start_busy(4);
  #                 me->add("neili", -80);
  #         }
  #         message_combatd(msg, me, target);
  #         me->want_kill(target);
  #         if (! target->is_killing(me)) target->kill_ob(me);
  # 
  #         return 1;
  # }
end
