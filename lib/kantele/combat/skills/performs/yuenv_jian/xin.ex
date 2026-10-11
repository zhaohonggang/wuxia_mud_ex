defmodule Kantele.Combat.Skills.Performs.YuenvJian.Xin do
  @moduledoc """
  perform「西子捧心」（source yuenv-jian/xin.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yuenv-jian/xin"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yuenv-jian")
    delta = 0
    improve = 0
    n = 0
    m = 0

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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "dodge") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "sword") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yuenv-jian") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 180}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 180, 1)
    result = Messages.interpolate("$n大吃一惊，慌忙躲避，然而剑气来的好快，哪里躲得开？
只听$p一声惨叫，胸口已经被剑气所伤！
$n重创之下不禁破绽迭出，$P见状随手刺出，又是一剑！
就听$p又是一声惨叫，痛苦不堪。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-180"}], "assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(1);"], "level_gates": [{"dodge", "150"}, {"sword", "200"}, {"yuenv-jian", "150"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // pengxin.c 西子捧心
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XIN "「" HIM "西子捧心" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #         int ap, dp;
  #         int damage;
  #         int delta;
  # 
  #         float improve;
  #         int lvl, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "sword";
  # 
  #         if (userp(me) && ! me->query("can_perform/yuenv-jian/xin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #             return notify_fail(XIN "只能在战斗中对对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "sword")
  #             return notify_fail("你使用的武器不对。\n");
  # 
  #     if (me->query_skill("sword", 1) < 200)
  #         return notify_fail("你的剑术修为不够，不能施展" XIN "！\n");
  # 
  #     if (me->query_skill("yuenv-jian", 1) < 150)
  #         return notify_fail("你的越女剑术的修为不够，不能施展" XIN "！\n");
  # 
  #     if (me->query_skill("dodge",1) < 150)
  #         return notify_fail("你的轻功修为不够，不能施展" XIN "！\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你的真气不够！\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (me->query("gender") == "女性" &&
  #             target->query("gender") == "女性")
  #                 delta = target->query("per") - me->query("per");
  #         else
  #                 delta = 0;
  # 
  #     msg = HIG "\n$N" HIG "幽幽一声长叹，手中的" + weapon->name() +
  #               HIG "就如闪电般刺向$n" HIG "的胸口。\n但见剑招轻盈灵动，优美华丽，就"
  #               "连杀人间也不带一丝尘俗之气。\n" NOR;
  # 
  #         if (delta > 0)
  #                 msg += HIY "$n" HIY "只觉得$N" HIY "眼神中隐然透出"
  #                        "一股冰冷的寒意，心中不禁一颤。\n" NOR;
  #         else
  #                 delta = 0;
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
  #         improve = improve * 5 / 100 / lvl;
  # 
  #         me->add("neili", -180);
  #         ap = (me->query_skill("sword") + me->query_skill("dodge")) / 2;
  #         dp = target->query_skill("dodge");
  #         ap += ap * improve;
  #         me->start_busy(1);
  #         if (ap * 7 / 10  + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap / 2) + delta * 20;
  # 
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            HIR "$n" HIR "大吃一惊，慌忙躲避，然而剑"
  #                                            "气来的好快，哪里躲得开？\n只听$p" HIR
  #                                            "一声惨叫，胸口已经被剑气所伤！\n" NOR);
  #                 if (ap / 2 + random(ap) > dp)
  #                 {
  #                         //damage /= 3;
  #                         damage = ap + random(ap / 2) + delta * 20;
  # 
  #                         msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
  #                                                    HIC "$n重创之下不禁破绽迭出，$P"
  #                                                    HIC "见状随手刺出" + weapon->name() +
  #                                                    HIC "，又是一剑！\n" HIR "就听$p"
  #                                                    HIR "又是一声惨叫，痛苦不堪。\n" NOR);
  #                 }
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "见状身形急退，避开了$N"
  #                        HIC "的无形剑气的凌厉一击！\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
