defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Shou do
  @moduledoc """
  perform「九阴神手」（source jiuyin-shengong/shou.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jiuyin-shengong/shou"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = Stats.skill(stats, "jiuyin-shengong")
    ap1 = (Stats.skill(stats, "jiuyin-shengong") + Stats.skill(stats, "force"))
    damage = ((ap1 * 2) + Engine.rand(rng, ap1))

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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "jiuyin-shengong") < 260 -> {:error, "TODO(migrate) 门槛不足。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 140}
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 60}
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
    Performs.feedback(attacker, 60, 1)
    result = Messages.interpolate("$n只觉此招，阴柔无比，诡异莫测，心中一惊，却猛然间觉得一股阴风透骨而过。
这一招完全超出了$n的想象，被$N结结实实的打中了檀中大穴，浑身真气登时涣散！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-140"}, {"neili", "-200"}, {"neili", "-60"}], "assign_refs": [{"ap", "jiuyin-shengong"}, {"ap1", "jiuyin-shengong"}, {"dp1", "parry"}], "busy_lines": ["me->start_busy(1 + random(3));", "target->start_busy(1 + random(2));"], "level_gates": [{"jiuyin-shengong", "260"}], "prepared_gates": [{"hand", "jiuyin-shengong"}, {"unarmed", "jiuyin-shengong"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // shou.c 九阴神手
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define SHOU "「" HIG "九阴神手" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #     int ap, dp, ap1, dp1, damage;
  # 
  #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/shou"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #         target = offensive_target(me);
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(SHOU "只能在战斗中对对手使用。\n");
  # 
  #     if (me->query_temp("weapon"))
  #         return notify_fail("此招只能空手施展！\n");
  # 
  #     if (me->query_skill("jiuyin-shengong", 1) < 260)
  #         return notify_fail("你的九阴神功还不够娴熟，不能使用" SHOU "！\n");
  # 
  #     if (me->query("neili") < 300)
  #         return notify_fail("你的真气不够！\n");
  # 
  #     if (me->query_skill_prepared("hand") != "jiuyin-shengong" && me->query_skill_prepared("unarmed") != "jiuyin-shengong")
  #         return notify_fail("你没有准备使用九阴神功，无法施展" SHOU "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "“哈”的一声吐出了一口气，手势奇特，软绵绵的奔向$n" HIY "的要穴！\n";
  # 
  #     ap = me->query_skill("jiuyin-shengong");
  #     dp = target->query("combat_exp") / 10000;
  #     me->add("neili", -60);
  #     me->start_busy(1 + random(3));
  # 
  #     me->want_kill(target);
  # 
  #     if (dp >= 100) // 此招对百万经验以上的人无效
  #     {              // 但是仍然受到伤害
  # 
  #         ap1 = me->query_skill("jiuyin-shengong", 1) + me->query_skill("force", 1);
  #         dp1 = target->query_skill("parry", 1) + target->query_skill("dodge", 1);
  #         //damage = ap1 + random(ap1);
  #         damage = ap1 * 2 + random(ap1);
  #         if (ap1 / 2 + random(ap1) > dp1)
  #         {
  #             msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 90,
  #                                        HIR "$n" HIR "只觉此招，阴柔无比，诡异莫测，"
  #                                            "心中一惊，却猛然间觉得一股阴风透骨而过。\n" NOR);
  #             me->add("neili", -140);
  #         }
  # 
  #         else
  #             msg += HIC "$n" HIC "知道来招不善，小心应对，没出一点差错。\n" NOR;
  #         message_combatd(msg, me, target);
  #         target->start_busy(1 + random(2));
  #         return 1;
  #     }
  #     else if (random(ap) > dp)
  #     {
  #         msg += HIR "这一招完全超出了$n" HIR "的想象，被$N" HIR "结结实实的打中了檀中大穴，浑身真气登时涣散！\n" NOR;
  #         message_combatd(msg, me, target);
  #         me->add("neili", -200);
  #         target->die(me);
  #         return 1;
  #     }
  #     else
  #     {
  #         msg += HIM "$n" HIM "大吃一惊，连忙胡乱抵挡，居"
  #                    "然没有一点伤害，侥幸得脱！\n" NOR;
  #     }
  # 
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
