defmodule Kantele.Combat.Skills.Performs.TaixuanGong.Hun do
  @moduledoc """
  perform「混元一气」（source taixuan-gong/hun.c，由 translate_perform.py 生成，inherit F_SSERVER）

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
    ap = lvl * 2 + Stats.skill(stats, "con") * 10 + Stats.skill(stats, "martial-cognize")
    dp = 0  # computed target-side
    damage = ap + Engine.rand(rng, ap)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
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

  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "taixuan-gong") < 200 -> {:error, "你的太玄功不够娴熟，难以施展混元一气。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "force") != "taixuan-gong" -> {:error, "你的内功没有激发太玄功，难以施展混元一气。\n"}
      Stats.mapped(stats, "unarmed") != "taixuan-gong" -> {:error, "你没有准备太玄功拳脚，难以施展混元一气。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 600 -> {:error, "你的内力不足，难以施展混元一气。\n"}
      true -> :ok
    end
  end

  defp check_other(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "taixuan-gong" -> {:error, "你必须空手才能施展混元一气。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件效果：扣内力 300 + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn = Broadcast.publish(conn, "突然只见$N双掌一合，内劲暗吐，无形气劲直卷$n而去！", n1: character.name)

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
    lvl = Map.get(data, :level, 0)
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    stats = character.meta.stats
    dp = Stats.skill(stats, "force") + Stats.skill(stats, "con") * 10 + Stats.skill(stats, "martial-cognize")

    # 命中判定：ap / 2 + random(ap) < dp 为闪避
    hit = div(ap, 2) + Engine.rand(rng, ap) >= dp

    vitals = character.meta.vitals
    attacker_vitals = attacker.meta.vitals

    hit_result =
      if hit do
        # 命中：目标受到 jing 伤害/创伤 + busy 1
        # 伤害计算：damage = ap + random(ap) (已在 attacker 侧计算)
        # 目标 neili 伤害：-(taixuan-gong skill + random(taixuan-gong skill))
        neili_damage = lvl + Engine.rand(rng, lvl)
        vitals = Vitals.damage(vitals, :neili, neili_damage)

        # jing 伤害/创伤（来自 final 回调）
        vitals = Vitals.damage(vitals, :jing, div(damage, 2))
        vitals = Vitals.wound(vitals, :jing, div(damage, 3))

        # busy 1
        combat = character.meta.combat
        combat = Combat.start_busy(combat, 1)
        character = %{character | meta: Map.put(character.meta, :combat, combat)}

        # 攻击方额外消耗：neili -300, busy 3
        attacker_vitals = %{attacker_vitals | neili: attacker_vitals.neili - 300}
        attacker_combat = attacker.meta.combat
        attacker_combat = Combat.start_busy(attacker_combat, 3)
        attacker = attacker
        |> Map.put(:meta, Map.put(attacker.meta, :vitals, attacker_vitals))
        |> Map.put(:meta, Map.put(attacker.meta, :combat, attacker_combat))

        Performs.feedback(attacker, 300, 3)

        # 命中消息（来自 final 回调）
        "可只见$n惨叫一声，顿时被$N内劲震得心神俱颤，内息大乱！"
      else
        # 闪避：攻击方 busy 2
        attacker_combat = attacker.meta.combat
        attacker_combat = Combat.start_busy(attacker_combat, 2)
        attacker = %{attacker | meta: Map.put(attacker.meta, :combat, attacker_combat)}

        Performs.feedback(attacker, 0, 2)

        "却见$n身形微晃，竟将$N这招混元一气卸了个干干净净！"
      end

    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    attacker = %{attacker | meta: Map.put(attacker.meta, :vitals, attacker_vitals)}

    result = Messages.interpolate(hit_result, n1: attacker.name, n2: character.name)

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
    |> Map.put(:attacker, attacker)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{
  #     "add_costs": [{"neili", "-300"}],
  #     "assign_refs": [{"ap", "taixuan-gong"}, {"dp", "force"}],
  #     "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"],
  #     "level_gates": [{"taixuan-gong", "200"}],
  #     "map_gates": [{"force", "taixuan-gong"}, {"unarmed", "taixuan-gong"}],
  #     "prepared_gates": [{"unarmed", "taixuan-gong"}],
  #     "remote_damage": true,
  #     "resource_gates": [{"neili", "600"}],
  #     "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"]
  #   }

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define HUN "「" HIW "混元一气" NOR "」"
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
  #                 return notify_fail(HUN "只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(HUN "只能空手施展。\n");
  # 
  #         if (me->query_skill("taixuan-gong", 1) < 200)
  #                 return notify_fail("你的太玄功不够娴熟，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "taixuan-gong")
  #                 return notify_fail("你没有激发太玄功拳脚，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "taixuan-gong")
  #                 return notify_fail("你的内功没有激发太玄功，难以施展" HUN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "taixuan-gong")
  #                 return notify_fail("你没有准备太玄功拳脚，难以施展" HUN "。\n");
  # 
  #         if (me->query("neili") < 600)
  #                 return notify_fail("你的内力不足，难以施展" HUN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "\n$N" HIG "双掌一合，内劲暗吐，无形气劲直卷$n而去！\n" NOR;
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
  #                 msg += HIY "可是$n" HIY "身形微晃，竟将$N" HIY
  #                        "这招混元一气卸了个干干净净！\n" NOR;
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
  #         return  HIR "$n" HIR "惨叫一声，顿时被$N内劲震得心神俱颤，内息大乱！"
  #                 "已将$p" HIR "一招混元一气卸了个干干净净！\n" NOR;
  # }
end