defmodule Kantele.Combat.Skills.Performs.RanmuDaofa.Huo do
  @moduledoc """
  perform「huo」（source ranmu-daofa/huo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "ranmu-daofa/huo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "ranmu-daofa")
    ap = (Stats.skill(stats, "ranmu-daofa") + Stats.skill(stats, "force"))
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "ranmu-daofa") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "ranmu-daofa" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "hunyuan-yiqi" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "luohan-fumogong" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      Stats.mapped(stats, "force") != "yijinjing" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 600 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 400}
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
    Performs.feedback(attacker, 400, 1)
    result = Messages.interpolate("只见$N手中一抖，刀身登时腾起滔天烈焰，如浴火麒麟一般席卷$n全身！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-400"}], "assign_refs": [{"ap", "ranmu-daofa"}, {"dp", "force"}], "busy_lines": ["me->start_busy(2 + random(2));", "target->start_busy(2);"], "level_gates": [{"force", "250"}, {"ranmu-daofa", "180"}], "map_gates": [{"blade", "ranmu-daofa"}, {"force", "hunyuan-yiqi"}, {"force", "luohan-fumogong"}, {"force", "yijinjing"}], "remote_damage": true, "resource_gates": [{"max_neili", "3000"}, {"neili", "600"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     int damage;
  #     int ap, dp;
  #     string msg;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「火麒蚀月」只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "blade")
  #         return notify_fail("你使用的武器不对。\n");
  # 
  #     if ((me->query_skill_mapped("force") != "hunyuan-yiqi") && (me->query_skill_mapped("force") != "yijinjing") && (me->query_skill_mapped("force") != "luohan-fumogong"))
  #         return notify_fail("你现在没有激发少林内功为内功，难以施展「火麒蚀月」。\n");
  # 
  #     if ((int)me->query_skill("ranmu-daofa", 1) < 180)
  #         return notify_fail("你的燃木刀法不够娴熟，不能使用火麒蚀月。\n");
  # 
  #     if ((int)me->query_skill("force") < 250)
  #         return notify_fail("你的内功火候不够，不能使用火麒蚀月。\n");
  # 
  #     if ((int)me->query("max_neili") < 3000 )
  #         return notify_fail("你的内力修为太弱，不能使用火麒蚀月。\n");
  # 
  #     if ((int)me->query("neili") < 600 )
  #         return notify_fail("你现在内力太弱，不能使用火麒蚀月。\n");
  # 
  #     if (me->query_skill_mapped("blade") != "ranmu-daofa")
  #         return notify_fail("你没有激发燃木刀法，不能施展火麒蚀月。\n");
  # 
  #     if (! living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "只见$N" HIR "手中" + weapon->name() + HIR "一抖，刀身登时腾起"
  #                     "滔天烈焰，如浴火麒麟一般席卷$n" HIR "全身！\n"NOR;
  # 
  #     me->start_busy(2 + random(2));
  #     ap = me->query_skill("ranmu-daofa", 1) + me->query_skill("force");
  #     dp = target->query_skill("force");
  # 
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         target->start_busy(2);
  #         damage = ap + random(ap);
  #         me->add("neili", -400);
  #         msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 130,
  #                                     RED "只闻一股焦臭从$n" RED "处传来，$n" RED "已被"
  #                                     "$P" RED "这精深奥妙的一"
  #                                     "刀击中，鲜血飞溅而出！\n" NOR);
  #     } else
  #     {
  #         msg += CYN "$p" CYN "见$P" CYN "来势汹汹，不敢抵挡，急忙斜跃避开。\n"NOR;
  #         me->add("neili", -200);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
