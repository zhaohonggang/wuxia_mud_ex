defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Hun do
  @moduledoc """
  perform「混天一气」（source taixuan-gong/hun.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "taixuan-gong/hun"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taixuan-gong")

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
      Stats.skill(stats, "taixuan-gong") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "taixuan-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "unarmed") != "taixuan-gong" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 600 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
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

  # TODO(migrate) 目标侧结算：命中/闪避/伤害公式与文案需按原始源码（见文末）补齐。
  #   target->receive_damage("jing", damage / 2)  # UNSUPPORTED: unknown ident damage
  #   target->receive_wound("jing", damage / 3)  # UNSUPPORTED: unknown ident damage

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 3)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "assign_refs": [{"ap", "taixuan-gong"}, {"dp", "force"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"taixuan-gong", "200"}], "map_gates": [{"force", "taixuan-gong"}, {"unarmed", "taixuan-gong"}], "prepared_gates": [{"unarmed", "taixuan-gong"}], "remote_damage": true, "resource_gates": [{"neili", "600"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define HUN "「" HIW "混天一气" NOR "」"
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/taixuan-gong/hun"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)target = me->select_opponent();
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HUN "只能空手施展。\n");
  # 
  #         if (me->query_skill("taixuan-gong", 1) < 200)
  #                 return notify_fail("你的太玄功还不够娴熟，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "taixuan-gong")
  #                 return notify_fail("你现在没有激发太玄功为拳脚，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "taixuan-gong")
  #                 return notify_fail("你现在没有激发太玄功为内功，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "taixuan-gong")
  #                 return notify_fail("你现在没有准备使用太玄功，难以施展" HUN "。\n");
  # 
  #         if (me->query("neili") < 600)
  #                 return notify_fail("你的内力不够，难以施展" HUN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "\n$N" HIG "双手合十，双目微闭，太玄奥义自心底涌出，猛然间，$N"
  #               HIG "双手向前推出，一股强劲的气流袭向$n " HIG "。\n" NOR;
  # 
  #         ap = me->query_skill("taixuan-gong", 1) * 2 + me->query("con") * 10 +
  #              me->query_skill("martial-cognize", 1);
  # 
  #         dp = target->query_skill("force") + target->query("con") * 10 +
  #              target->query_skill("martial-cognize", 1);
  # 
  #         me->add("neili", -300);
  # 
  #         if (ap / 2 + random(ap) < dp)
  #         {
  #                 msg += HIY "然而$n" HIY "全力抵挡，终于将$N" HIY
  #                        "发出的气流挡住。\n" NOR;
  #             me->start_busy(2);
  #         } else
  #         {
  #                 me->add("neili", -300);
  #             me->start_busy(3);
  #                 damage = ap + random(ap);
  #                 target->add("neili", -(me->query_skill("taixuan-gong", 1) +
  #                             random(me->query_skill("taixuan-gong", 1))), me);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 80 + random(5),
  #                                            (: final, me, target, damage :));
  # 
  #         }
  #         message_sort(msg, me, target);
  #         return 1;
  # }
  # 
  # 
  # string final(object me, object target, int damage)
  # {
  #         target->receive_damage("jing", damage / 2, me);
  #         target->receive_wound("jing", damage / 3, me);
  #         target->busy(1);
  #         return  HIR "$n" HIR "急忙飞身后退，可是气流射"
  #                 "得更快，只听$p" HIR "一声惨叫，一股气"
  #                 "流已经透体而过，鲜血飞溅！$n" HIR "顿"
  #                 "觉精力涣散，无法集中。\n" NOR;
  # }
end
