defmodule Kantele.Combat.Skills.Performs.LingsheZhangfa.Wuji do
  @moduledoc """
  perform「wuji」（source lingshe-zhangfa/wuji.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "lingshe-zhangfa/wuji"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lingshe-zhangfa")
    ap = Stats.skill(stats, "staff")
    damage = (ap + Engine.rand(rng, ap))

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
         :ok <- check_resources(character),
         :ok <- check_weapon(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 -> {:error, "你的内功火候不够，难以运用使用「横行无忌」！\n"}
      Stats.skill(stats, "lingshe-zhangfa") < 150 -> {:error, "你的灵蛇杖法还不到家，无法使用「横行无忌」！\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "staff") != "lingshe-zhangfa" -> {:error, "你没有激发灵蛇杖法，无法使用「横行无忌」！\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "你现在的真气不够，无法使用「横行无忌」！\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    # TODO(migrate) 武器检查需人工核对（自动提取的文案仅供参考）：
    #   {:error, "运用「横行无忌」必须手中持杖！\n"}
    :ok

  end

  defp check_other(character) do
    # TODO(migrate) 其它门槛（战斗/临时状态/道具等）需人工核对：
    #   {:error, "「横行无忌」只能对战斗中的对手使用。\n"}
    #   {:error, "你还不会使用「横行无忌」。\n"}
    :ok

  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 80}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
    combat = Combat.start_busy(combat, 4)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}
    conn = Broadcast.publish(conn, "$N一声冷笑，手中的某物忽然变得如同活物一般，时上时下，忽左忽右，不知攻向$n何处！", n1: character.name)

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
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
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
    result = if hit, do: Messages.interpolate("$n实在无法捕捉到$P的实招，接连挡空，连中数招，登时吐了一口鲜血！", n1: attacker.name, n2: character.name), else: Messages.interpolate("$n奋力招架，总算抵挡住了$P的攻击！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-80"}], "assign_refs": [{"ap", "staff"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(3);", "target->start_busy(1);", "me->start_busy(4);", "target->start_busy(1);"], "level_gates": [{"force", "200"}, {"lingshe-zhangfa", "150"}], "map_gates": [{"staff", "lingshe-zhangfa"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // wuji.c 横行无忌
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #           object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/lingshe-zhangfa/wuji"))
  #               return notify_fail("你还不会使用「横行无忌」。\n");
  # 
  #           if (! target || ! me->is_fighting(target))
  #                   return notify_fail("「横行无忌」只能对战斗中的对手使用。\n");
  # 
  #           if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "staff")
  #                   return notify_fail("运用「横行无忌」必须手中持杖！\n");
  # 
  #           if ((int)me->query_skill("force") < 200)
  #                   return notify_fail("你的内功火候不够，难以运用使用「横行无忌」！\n");
  # 
  #           if ((int)me->query("neili") < 300)
  #                   return notify_fail("你现在的真气不够，无法使用「横行无忌」！\n");
  # 
  #           if ((int)me->query_skill("lingshe-zhangfa", 1) < 150)
  #                   return notify_fail("你的灵蛇杖法还不到家，无法使用「横行无忌」！\n");
  # 
  #           if (me->query_skill_mapped("staff") != "lingshe-zhangfa")
  #                   return notify_fail("你没有激发灵蛇杖法，无法使用「横行无忌」！\n");
  # 
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "一声冷笑，手中的" + weapon->name() + HIY "忽然变得"
  #               "如同活物一般，时上时下，忽左忽右，不知攻向$n" HIY "何处！\n" NOR;
  #         ap = me->query_skill("staff");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = ap + random(ap);
  #                 me->add("neili", -200);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 55,
  #                                    HIR "$n" HIR "实在无法捕捉到$P"
  #                                            HIR "的实招，接连挡空，连中数招，"
  #                                            "登时吐了一口鲜血！\n" NOR);
  #         me->start_busy(3);
  #                 target->start_busy(1);
  #     } else
  #     {
  #         msg += CYN "$n" CYN "奋力招架，总算抵挡住了$P"
  #                        CYN "的攻击！\n" NOR;
  #                 me->add("neili", -80);
  #         me->start_busy(4);
  #                 target->start_busy(1);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
