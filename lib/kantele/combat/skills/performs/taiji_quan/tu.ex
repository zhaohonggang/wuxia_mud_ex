defmodule Kantele.Combat.Skills.Performs.TaijiQuan.Tu do
  @moduledoc """
  perform「太极图」（source taiji-quan/tu.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "taiji-quan/tu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taiji-quan")
    improve = 0
    n = 0
    m = 0
    flag = 1

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
      Stats.skill(stats, "taiji-quan") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "taiji-shengong") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "taoism") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "taiji-shengong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "unarmed") != "taiji-quan" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.jingli < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 0 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | jingli: vitals.jingli - 1000}
    vitals = %{vitals | neili: vitals.neili - 1000}
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 500}
    vitals = %{vitals | neili: 0}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 4)
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
    Performs.feedback(attacker, 500, 4)
    result = Messages.interpolate("只见手舞足蹈，忘乎所以，忽然大叫一声，吐血不止！
却见容貌哀戚，似乎想起了什么伤心之事，身子一晃，呕出数口鲜血！
呆立当场，一动不动，有如中邪，七窍都迸出鲜血来。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"jingli", "-1000"}, {"neili", "-1000"}, {"neili", "-200"}, {"neili", "-500"}], "assign_refs": [{"ap", "taoism"}, {"dp", "force"}], "busy_lines": ["me->start_busy(4);", "obs[i]->start_busy(3);"], "level_gates": [{"taiji-quan", "250"}, {"taiji-shengong", "300"}, {"taoism", "300"}], "map_gates": [{"force", "taiji-shengong"}, {"unarmed", "taiji-quan"}], "prepared_gates": [{"unarmed", "taiji-quan"}], "remote_damage": false, "resource_gates": [{"jingli", "1000"}, {"neili", "0"}, {"neili", "1000"}], "set_flags": [{"neili", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # inherit F_SSERVER;
  # 
  # #define TU "「" HIW "太极图" NOR "」"
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
  #         float improve;
  #         int lvl, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "unarmed";
  # 
  #         if (userp(me) && me->query("can_perform/taiji-quan/tu") < 10)
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         me->clean_up_enemy();
  #         if (! me->is_fighting())
  #                 return notify_fail(TU "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(TU "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("taiji-quan", 1) < 250)
  #                 return notify_fail("你的太极拳不够娴熟，难以施展" TU "。\n");
  # 
  #         if ((int)me->query_skill("taiji-shengong", 1) < 300)
  #                 return notify_fail("你的太极神功修为还不够高，难以施展" TU "。\n");
  # 
  #         if ((int)me->query_skill("taoism", 1) < 300)
  #                 return notify_fail("你的道学心法修为还不够高，难以施展" TU "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "taiji-quan")
  #                 return notify_fail("你现在没有激发太极拳，难以施展" TU "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "taiji-shengong")
  #                 return notify_fail("你现在没有激发太极神功，难以施展" TU "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "taiji-quan")
  #                 return notify_fail("你没有准备使用太极拳，难以施展" TU "。\n");
  # 
  #         if ((int)me->query("jingli") < 1000)
  #                 return notify_fail("你现在精力不够，难以施展" TU "。\n");
  # 
  #         if ((int)me->query("neili", 1) < 1000)
  #                 return notify_fail("你现在真气不够，难以施展" TU "。\n");
  # 
  #         msg = HIM "$N" HIM "淡然一笑，双手轻轻划了数个圈子，顿时四周的气"
  #               "流波动，源源不断的被牵引进来。\n\n" NOR;
  #         message_combatd(msg, me);
  # 
  #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvl = lvl * 4 / 5;
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
  #         improve = improve * 4 / 100 / lvl;
  # 
  #         me->add("neili", -1000);
  #         me->add("jingli", -1000);
  #         me->start_busy(4);
  #         ap = me->query_skill("taoism", 1) +
  #              me->query_skill("taiji-quan", 1) +
  #              me->query_skill("taiji-shengong", 1);
  #         ap += ap * improve;
  #         obs = me->query_enemy();
  #         for (flag = 0, i = 0; i < sizeof(obs); i++)
  #         {
  #                 dp = obs[i]->query_skill("force") * 2 +
  #                      obs[i]->query_skill("taoism", 1);
  #                 if (ap / 2 + random(ap) > dp)
  #                 {
  #                         switch (random(3))
  #                         {
  #                         case 0:
  #                                 tell_object(obs[i], HIY "恍惚之间你似乎回到了过去的世界，竟"
  #                                                     "然再无法控制自我，忽然眼前的一切\n"
  #                                                     "又全然不见，你心头一乱，浑身一阵剧"
  #                                                     "痛，内力紊乱难以控制！\n" NOR);
  #                                 break;
  #                         case 1:
  #                                 tell_object(obs[i], HIW "你眼前一切渐渐的模糊起来，好像是到"
  #                                                     "了仙境，然而你却觉得内息越来越乱，\n"
  #                                                     "四肢一阵酸痛，几乎要站立不住。\n" NOR);
  #                                 break;
  #                         default:
  #                                 tell_object(obs[i], HIR "你耳边忽然响起一个霹雳，眼见雷神挥"
  #                                                     "舞电锤向你打来，你不禁大吃一惊，\n"
  #                                                     "浑身上下都不听使唤，只有高声呼救。\n" NOR);
  #                                 break;
  #                         }
  #                         damage = ap / 3 + random(ap / 3);
  # 
  #                         obs[i]->receive_damage("qi", damage, me);
  #                         obs[i]->receive_wound("qi", damage / 2, me);
  # 
  #                         obs[i]->receive_damage("jing", damage / 3, me);
  #                         obs[i]->receive_wound("jing", damage / 6, me);
  # 
  #                         p = (int)obs[i]->query("qi") * 100 / (int)obs[i]->query("max_qi");
  # 
  #                         switch (random(3))
  #                         {
  #                         case 0:
  #                                 msg = HIR "只见" + obs[i]->name() +
  #                                       HIR "手舞足蹈，忘乎所以，忽"
  #                                       "然大叫一声，吐血不止！\n" NOR;
  #                                 msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  #                         case 1:
  #                                 msg = HIR "却见" + obs[i]->name() +
  #                                       HIR "容貌哀戚，似乎想起了什"
  #                                       "么伤心之事，身子一晃，呕出数口鲜血！\n" NOR;
  #                                 msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  #                         default:
  #                                 msg = HIR + obs[i]->name() +
  #                                       HIR "呆立当场，一动不动，有如中"
  #                                       "邪，七窍都迸出鲜血来。\n" NOR;
  #                                 msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  #                         }
  #                         obs[i]->start_busy(3);
  #                         message("vision", msg, environment(me), ({ obs[i] }));
  #                         obs[i]->add("neili", -500);
  #                         flag = 1;
  #                 } else
  #                 {
  #                         tell_object(obs[i], HIC "你发现眼前的景物似幻似真，连忙"
  #                                             "默运内功，不受困扰。\n" NOR);
  #                         obs[i]->add("neili", -200);
  #                 }
  #                 if (obs[i]->query("neili") < 0)
  #                         obs[i]->set("neili", 0);
  #         }
  # 
  #         if (! flag)
  #                 message_vision(HIM "然而没有任何人受了$N"
  #                    HIM "的影响。\n\n" NOR, me, 0, obs);
  # 
  #         return 1;
  # }
end
