defmodule Kantele.Combat.Skills.Performs.LingxiaoQuan.San do
  @moduledoc """
  perform「神倒鬼跌三连环」（source lingxiao-quan/san.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "lingxiao-quan/san"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lingxiao-quan")
    ap = Stats.skill(stats, "cuff")

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
      Stats.skill(stats, "force") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "lingxiao-quan") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "cuff") != "lingxiao-quan" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
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
    Performs.feedback(attacker, 200, 1)
    result = Messages.interpolate("$N微微一笑，施出「神倒鬼跌三连环」，右手探出，直揪$n后颈。
$P出手既快，方位又奇，$p如何避得，当即被$N揪住，重重的摔在地上！

紧接着$N“噫”的一声，左手猛然探出，如闪电般抓向$n的前胸。
$p只觉胸口一麻，已被$P抓住胸口，用力顺势一甩，顿时平平飞了出去！

又见$N身子一矮，将力道聚于腿部，右脚猛扫$n下盘，左脚随着绊去。
结果$p稍不留神，顿时给$P绊倒在地，呕出一大口鲜血！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "assign_refs": [{"ap", "cuff"}, {"damage", "lingxiao-quan"}, {"dp", "dodge"}, {"dp", "force"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(3));"], "level_gates": [{"force", "250"}, {"lingxiao-quan", "180"}], "map_gates": [{"cuff", "lingxiao-quan"}], "prepared_gates": [{"cuff", "lingxiao-quan"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SAN "「" HIR "神倒鬼跌三连环" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  # //      string wname;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/lingxiao-quan/san"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SAN "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(weapon = me->query_temp("weapon")))
  #                 return notify_fail("只有空手才能施展" SAN "。\n");
  # 
  #         if (me->query_skill("force") < 250)
  #                 return notify_fail("你的内功修为不够，难以施展" SAN "。\n");
  # 
  #         if ((int)me->query_skill("lingxiao-quan", 1) < 180)
  #                 return notify_fail("你的凌霄拳法不够娴熟，难以施展" SAN "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在真气不够，难以施展" SAN "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "lingxiao-quan")
  #                 return notify_fail("你没有激发凌霄拳法，难以施展" SAN "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "lingxiao-quan")
  #                 return notify_fail("你现在没有准备使用凌霄拳法，难以施展" SAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         damage = (int)me->query_skill("lingxiao-quan", 1) / 2;
  #         damage += random(damage);
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("parry");
  #         msg = HIR "$N" HIR "微微一笑，施出「神倒鬼跌三连环」，右手探出，直揪$n"
  #               HIR "后颈。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 20,
  #                                            HIR "$P" HIR "出手既快，方位又奇，$p"
  #                                            HIR "如何避得，当即被$N" HIR "揪住，"
  #                                            "重重的摔在地上！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "$p" CYN "见势不妙，急忙凝力稳住，右臂挥出，格开$P"
  #                        CYN "手臂。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("dodge");
  #         msg += "\n" HIR "紧接着$N" HIR "“噫”的一声，左手猛然探出，如闪电般抓向$n"
  #                HIR "的前胸。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 25,
  #                                            HIR "$p" HIR "只觉胸口一麻，已被$P"
  #                                            HIR "抓住胸口，用力顺势一甩，顿时平"
  #                                            "平飞了出去！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "丝毫不为$P"
  #                        CYN "所动，奋力格挡，稳稳将这一招架开。\n" NOR;
  #         }
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("force");
  #         msg += "\n" HIR "又见$N" HIR "身子一矮，将力道聚于腿部，右脚猛扫$n"
  #                HIR "下盘，左脚随着绊去。\n" NOR;
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "结果$p" HIR "稍不留神，顿时给$P"
  #                                            HIR "绊倒在地，呕出一大口鲜血！\n" NOR);
  #         } else
  #         {
  #                 msg += CYN "然而$p" CYN "沉身聚气，稳住下盘，身子一幌，没给$P"
  #                        CYN "绊倒。\n" NOR;
  #         }
  #         me->start_busy(2 + random(3));
  #         me->add("neili", -200);
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
