defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Ri do
  @moduledoc """
  perform「魔光日无极」（source jiuyang-shengong/ri.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jiuyang-shengong/ri"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyang-shengong")
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
      Stats.skill(stats, "jiuyang-shengong") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "jiuyang-shengong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "unarmed") != "jiuyang-shengong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 8000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 0 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 2000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 1000}
    vitals = %{vitals | neili: vitals.neili - 500}
    vitals = %{vitals | neili: 0}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 5)
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
    Performs.feedback(attacker, 500, 5)
    result = Messages.interpolate("只听一声惨嚎，接连退了数步，“哇”的呕出一大口鲜血。
只见向后飞出丈远，重重的跌落在地上，衣衫烧焦，再也没力气站起。
只见跌跌撞撞向后连退数步，伏倒在地。须眉、衣衫都发出一股焦臭。
光芒闪过，却是呆立当场，动也不动，七窍流血，神情扭曲，煞是恐怖。
急忙抽身后退，可只见眼前光芒暴涨，一闪而过。全身已多了数个伤口，鲜血飞溅。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-1000"}, {"neili", "-500"}], "assign_refs": [{"ap", "force"}, {"dp", "force"}], "busy_lines": ["me->start_busy(5);", "obs[i]->start_busy(1);"], "level_gates": [{"jiuyang-shengong", "250"}], "map_gates": [{"force", "jiuyang-shengong"}, {"unarmed", "jiuyang-shengong"}], "prepared_gates": [{"unarmed", "jiuyang-shengong"}], "remote_damage": false, "resource_gates": [{"max_neili", "8000"}, {"neili", "0"}, {"neili", "2000"}], "set_flags": [{"neili", "0"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # inherit F_SSERVER;
  # 
  # #define RI "「" HIW "魔光日无极" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/jiuyang-shengong/ri"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         me->clean_up_enemy();
  #         if (! me->is_fighting())
  #                 return notify_fail(RI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(RI "只能空手施展。\n");
  # 
  #         if (me->query("max_neili") < 8000)
  #                 return notify_fail("你的内力的修为不够，现在无法使用" RI "。\n");
  # 
  #         if (me->query_skill("jiuyang-shengong", 1) < 250)
  #                 return notify_fail("你的九阳神功还不够娴熟，难以施展" RI "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有激发九阳神功为拳脚，难以施展" RI "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有激发九阳神功为内功，难以施展" RI "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有准备使用九阳神功，难以施展" RI "。\n");
  # 
  #         if ((int)me->query("neili") < 2000)
  #                 return notify_fail("你的真气不够，无法运用" RI "。\n");
  # 
  #         msg = HIY "只见$N" HIY "双目微闭，单手托天。掌心顿时腾起一个无比刺眼的"
  #               "气团，正是奥\n义「" NOR + HIW "魔光日无极" NOR + HIY "」。霎时"
  #               "金光万道，尘沙四起，空气炽热，几欲沸腾。$N" HIY "\n随即收拢掌心"
  #               "，气团爆裂开来，向四周电射而出，光芒足以和日月争辉。\n\n" NOR;
  # 
  #         message_combatd(msg, me);
  # 
  #         me->add("neili", -1000);
  #         me->start_busy(5);
  # 
  #         ap = me->query_skill("force", 1) +
  #              me->query_skill("unarmed", 1) +
  #              me->query_skill("martial-cognize", 1) +
  #              me->query_skill("jiuyang-shengong", 1) +
  #              me->query("con") * 10;
  # 
  #         obs = me->query_enemy();
  #         for (flag = 0, i = 0; i < sizeof(obs); i++)
  #         {
  #                 dp = obs[i]->query_skill("force") * 2 +
  #                      obs[i]->query_skill("martial-cognize", 1) +
  #                      obs[i]->query("con") * 10;
  # 
  #                 if (ap / 2 + random(ap) > dp)
  #                 {
  #                         switch (random(2))
  #                         {
  #                         case 0:
  #                                 tell_object(obs[i], HIR "你只觉眼前金光万道，周围空气几欲沸"
  #                                                     "腾，光芒便如利箭一般透体而入。\n" NOR);
  #                                 break;
  # 
  #                         default:
  #                                 tell_object(obs[i], HIR "你只觉眼前金光万道，周围空气几欲沸"
  #                                                     "腾，光芒便如千万细针一齐扎入身体般。\n"
  #                                                     NOR);
  #                                 break;
  #                         }
  # 
  #                         damage = ap / 4 + random(ap / 3);
  # 
  #                         obs[i]->receive_damage("qi", damage, me);
  #                         obs[i]->receive_wound("qi", damage / 2, me);
  # 
  #                         obs[i]->receive_damage("jing", damage / 6, me);
  #                         obs[i]->receive_wound("jing", damage / 10, me);
  # 
  #                     p = (int)obs[i]->query("qi") * 100 / (int)obs[i]->query("max_qi");
  # 
  #                         switch (random(5))
  #                         {
  #                         case 0:
  #                                 msg = HIR "只听" + obs[i]->name() +
  #                                       HIR "一声惨嚎，接连退了数步，“"
  #                                       "哇”的呕出一大口鲜血。\n" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         case 1:
  #                                 msg = HIR "只见" + obs[i]->name() +
  #                                       HIR "向后飞出丈远，重重的跌落在"
  #                                       "地上，衣衫烧焦，再也没力气站起"
  #                                       "。\n" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         case 2:
  #                                 msg = HIR "只见" + obs[i]->name() +
  #                                       HIR "跌跌撞撞向后连退数步，伏倒"
  #                                       "在地。须眉、衣衫都发出一股焦臭"
  #                                       "。\n" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         case 3:
  #                                 msg = HIR "光芒闪过，" + obs[i]->name() +
  #                                       HIR "却是呆立当场，动也不动，七"
  #                                       "窍流血，神情扭曲，煞是恐怖。\n" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         default:
  #                                 msg = HIR + obs[i]->name() +
  #                                       HIR "急忙抽身后退，可只见眼前光"
  #                                       "芒暴涨，一闪而过。全身已多了数"
  #                                       "个伤口，鲜血飞溅。\n" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  #                         }
  #                         obs[i]->start_busy(1);
  #                         message("vision", msg, environment(me), ({ obs[i] }));
  #                         obs[i]->add("neili", -500);
  #                         flag = 1;
  #                 } else
  #                 {
  #                         tell_object(obs[i], HIY "你只觉眼前金光万道，周围空气几"
  #                                             "欲沸腾，大惊之下连忙急运内功，抵御"
  #                                             "开来。\n" NOR);
  #                 }
  #                 if (obs[i]->query("neili") < 0)
  #                         obs[i]->set("neili", 0);
  #         }
  # 
  #         if (! flag)
  #                 message_vision(HIY "只见光芒顿敛，却没有任何人被$N"
  #                    HIY "这招击中。\n\n" NOR, me, 0, obs);
  # 
  #         return 1;
  # }
end
