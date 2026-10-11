defmodule Kantele.Combat.Skills.Performs.MiaojiaJian.Gan do
  @moduledoc """
  perform「流星赶月」（source miaojia-jian/gan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "miaojia-jian/gan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "miaojia-jian")
    ap = Stats.skill(stats, "sword")
    damage = (div(ap, 2) + Engine.rand(rng, ap))

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
      Stats.skill(stats, "force") < 280 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "miaojia-jian") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "miaojia-jian") < 260 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "miaojia-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
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
    vitals = %{vitals | neili: vitals.neili - 500}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 3)
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 500, 4)
    result = Messages.interpolate("$n顿时大惊失色，只觉胸口处一凉，那柄竟然已经穿胸透过，带出一蓬血雨！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-500"}], "assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(3);", "me->start_busy(4);"], "level_gates": [{"force", "280"}, {"miaojia-jian", "200"}, {"miaojia-jian", "260"}], "map_gates": [{"sword", "miaojia-jian"}], "remote_damage": true, "resource_gates": [{"max_neili", "3000"}, {"neili", "600"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define GAN "「" HIY "流星赶月" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         object weapon;
  #         int ap, dp, wn;
  # 
  #         if (userp(me) && ! me->query("can_perform/miaojia-jian/gan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(GAN "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" GAN "。\n");
  # 
  #         if ((int)me->query_skill("miaojia-jian", 1) < 200)
  #                 return notify_fail("你苗家剑法不够娴熟，难以施展" GAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 280 )
  #                 return notify_fail("你的内功火候不够，难以施展" GAN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3000)
  #                 return notify_fail("你的内力修为不够，难以施展" GAN "。\n");
  # 
  #         if ((int)me->query("neili") < 600)
  #                 return notify_fail("你现在真气不够，难以施展" GAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "miaojia-jian")
  #                 return notify_fail("你没有激发苗家剑法，难以施展" GAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIY "$N" HIY "凝聚内力，手中" + wn + HIY "迸出万道光华，蓦然间破空"
  #               "声骤响，" + wn + HIY "竟离手射出，流星般向$n" HIY "奔去！\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("dodge");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->start_busy(3);
  #                 damage = ap / 2 + random(ap);
  #                 damage += random(damage);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
  #                                            HIR "$n" HIR "顿时大惊失色，只觉胸口处"
  #                                            "一凉，那柄" + wn + HIR "竟然已经穿胸透"
  #                                            "过，带出一蓬血雨！\n" NOR);
  #                 me->add("neili", -500);
  #         } else
  #         {
  #                 me->start_busy(4);
  #                 msg += HIC "$n" HIC "见" + wn + HIC "来势汹涌，心知绝"
  #                        "不可挡，当即向后横移数尺，终于躲闪开来。\n" NOR;
  #                 me->add("neili", -500);
  #         }
  # 
  #         if (userp(me) && (int)me->query_skill("miaojia-jian", 1) < 260)
  #         {
  #                 msg += HIY "只见" + wn + HIY "余势不尽，又向前飞出数"
  #                        "丈，方才没入土中。\n" NOR;
  #             weapon->move(environment(me));
  #     } else
  #                 msg += HIY "然而$N" HIY "身形一展，登时跃出数丈，掌"
  #                        "出如风，将射出的" + wn + HIY "又抄回手中。\n" NOR;
  # 
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
