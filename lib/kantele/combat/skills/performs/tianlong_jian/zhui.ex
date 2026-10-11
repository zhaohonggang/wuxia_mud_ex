defmodule Kantele.Combat.Skills.Performs.TianlongJian.Zhui do
  @moduledoc """
  perform「毒龙双锥」（source tianlong-jian/zhui.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "tianlong-jian/zhui"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "tianlong-jian")
    ap = Stats.skill(stats, "sword")
    damage = (div(ap, 3) + Engine.rand(rng, div(ap, 2)))

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
      Stats.skill(stats, "force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tianlong-jian") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "tianlong-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 350}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 350, 1)
    result = Messages.interpolate("$n招架不住，哧地一声，$N手中的顿时破体钻入，鲜血四溅！
$n急忙抽身后退，可只见$N剑芒一漾，胸口便喷出一股血柱！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-350"}], "assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(3));"], "level_gates": [{"force", "150"}, {"tianlong-jian", "120"}], "map_gates": [{"sword", "tianlong-jian"}], "remote_damage": true, "resource_gates": [{"max_neili", "1500"}, {"neili", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHUI "「" HIM "毒龙双锥" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp, damage;
  #         // object ob;
  # 
  #         if (userp(me) && ! me->query("can_perform/tianlong-jian/zhui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" ZHUI "。\n");
  # 
  #         if ((int)me->query_skill("tianlong-jian", 1) < 120)
  #                 return notify_fail("你的天龙剑法火候太浅，难以施展" ZHUI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功修为太浅，难以施展" ZHUI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1500)
  #                 return notify_fail("你的内力修为太浅，难以施展" ZHUI "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "tianlong-jian")
  #                 return notify_fail("你没有激发天龙剑法，难以施展" ZHUI "。\n");
  # 
  #         if ((int)me->query("neili", 1) < 500)
  #                 return notify_fail("你现在的真气不足，，难以施展" ZHUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #     damage = ap / 3 + random(ap / 2);
  # 
  #         msg = HIM "$N" HIM "一声清啸，手中" + weapon->name() + HIM "急速旋转，剑尖"
  #               "作锥，剑身顿时腾起一股旋风，向$n" HIM "钻去。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30,
  #                                            HIR "$n" HIR "招架不住，哧地一声，$N"
  #                                            HIR "手中的" + weapon->name() + HIR
  #                                            "顿时破体钻入，鲜血四溅！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "奋力格挡，终于架开了$N"
  #                        CYN "的这一剑。\n" NOR;
  #         }
  # 
  #         msg += HIM "\n$N" HIM "随即抽剑回转，撩下劈上，手中" + weapon->name() + HIM
  #                "剑尖一颤，又激荡出一股旋涡劲钻向$n" HIM "。\n" NOR;
  #         if (ap * 2 / 5 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
  #                                            HIR "$n" HIR "急忙抽身后退，可只见$N"
  #                                            HIR + weapon->name() + HIR "剑芒一漾"
  #                                            "，胸口便喷出一股血柱！\n" NOR);
  #         } else
  #         {
  #             msg += CYN "可是$n" CYN "凝神聚气，飞身一跃而起，避开了$N"
  #                        CYN "的杀着。\n" NOR;
  #     }
  #         me->start_busy(2 + random(3));
  #         me->add("neili", -350);
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
