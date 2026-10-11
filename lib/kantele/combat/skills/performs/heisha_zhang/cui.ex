defmodule Kantele.Combat.Skills.Performs.HeishaZhang.Cui do
  @moduledoc """
  perform「催魂掌」（source heisha-zhang/cui.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "heisha-zhang/cui"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "heisha-zhang")
    ap = Stats.skill(stats, "strike")
    damage = (div(ap, 2) + Engine.rand(rng, div(ap, 3)))

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
      Stats.skill(stats, "heisha-zhang") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "heisha-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 100}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
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

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 100, 3)
    result = Messages.interpolate("$n只觉$N掌劲穿胸而过，一时说不出的难受，呕出一大口黑血。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "affect_by": ["sha_poison"], "assign_refs": [{"ap", "strike"}, {"dp", "force"}, {"lvl", "heisha-zhang"}], "busy_lines": ["me->start_busy(3);"], "level_gates": [{"force", "150"}, {"heisha-zhang", "100"}], "map_gates": [{"strike", "heisha-zhang"}], "prepared_gates": [{"strike", "heisha-zhang"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define CUI "「" HIB "催魂掌" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  #         int lvl;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/heisha-zhang/cui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CUI "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" CUI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "heisha-zhang")
  #                 return notify_fail("你没有激发黑砂掌，难以施展" CUI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "heisha-zhang")
  #                 return notify_fail("你现在没有准备使用黑砂掌，难以施展" CUI "。\n");
  # 
  #         if ((int)me->query_skill("heisha-zhang", 1) < 100)
  #                 return notify_fail("你的黑砂掌不够熟练，难以施展" CUI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内力修为不足，难以施展" CUI "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，难以施展" CUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIB "$N" HIB "冷笑数声，单掌陡然一振，催魂般悄然拍至$n"
  #               HIB "前胸，不着半点力道。\n" NOR;  
  # 
  #         lvl = me->query_skill("heisha-zhang", 1);
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("force");
  # 
  #         me->start_busy(3);
  #         if (ap / 2 + random(ap) > dp)
  #         { 
  #                 damage = ap / 2 + random(ap / 3);
  #                 me->add("neili", -100);
  #                 target->affect_by("sha_poison",
  #                                ([ "level" : me->query("jiali") + random(me->query("jiali")),
  #                                   "id"    : me->query("id"),
  #                                   "duration" : lvl / 50 + random(lvl / 20) ]));
  #                                   msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK,
  #                                          damage, 20, HIR "$n" HIR "只觉$N" HIR "掌劲穿"
  #                                          "胸而过，一时说不出的难受，呕出一大口黑血。\n"
  #                                          NOR);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见$N"
  #                        CYN "来势汹涌，奋力格挡，终于化解开来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
