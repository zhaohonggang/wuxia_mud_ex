defmodule Kantele.Combat.Skills.Performs.YinyangRen.Heng do
  @moduledoc """
  perform「横空出世」（source yinyang-ren/heng.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yinyang-ren/heng"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yinyang-ren")
    ap = Stats.skill(stats, "blade")
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
      Stats.skill(stats, "dodge") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yinyang-ren") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "yinyang-ren" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      Stats.mapped(stats, "sword") != "yinyang-ren" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2700 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
    vitals = %{vitals | neili: vitals.neili - 240}
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
    Performs.feedback(attacker, 240, 1)
    result = Messages.interpolate("$n见此招来势凶猛， 阻挡不及， 顿时被所伤，苦不堪言。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}, {"neili", "-240"}], "assign_refs": [{"ap", "blade"}, {"ap", "sword"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(1 + random(2));"], "level_gates": [{"dodge", "200"}, {"force", "200"}, {"yinyang-ren", "180"}], "map_gates": [{"blade", "yinyang-ren"}, {"sword", "yinyang-ren"}], "remote_damage": true, "resource_gates": [{"max_neili", "2700"}, {"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HENG "「" HIC "横空出世" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/yinyang-ren/heng"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HENG "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || ((string)weapon->query("skill_type") != "sword"
  #            && (string)weapon->query("skill_type") != "blade"))
  #                 return notify_fail("你使用的武器不对，难以施展" HENG "。\n");
  # 
  #         if (me->query_skill("force") < 200)
  #                 return notify_fail("你的内功的修为不够，难以施展" HENG "。\n");
  # 
  #         if (me->query_skill("yinyang-ren", 1) < 180)
  #                 return notify_fail("你的阴阳刃法修为不够，难以施展" HENG "。\n");
  # 
  #         if ((int)me->query_skill("dodge") < 200)
  #                 return notify_fail("你的轻功火候不够，难以施展" HENG "。\n");  
  # 
  #         if ((int)me->query("max_neili") < 2700)
  #                 return notify_fail("你的内力修为不足，难以施展" HENG "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，难以施展" HENG "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "yinyang-ren"
  #             && me->query_skill_mapped("blade") != "yinyang-ren")
  #                 return notify_fail("你没有激发阴阳刃法，难以施展" HENG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "\n只见$N" HIY "手中" + weapon->name() + HIY "斜指"
  #               "苍天，猛然间招式突变，" + weapon->name() + HIY "“呼"
  #               "呼”作响，一式「" HIC "横空出世" HIY "」，力劈虚空，"
  #               "气压群山，犹如风卷残云般地袭向$n" HIY "。\n" NOR;
  #         message_sort(msg, me, target);
  # 
  #         // 根据所激发的是sword或blade来判断ap值。
  #         if (me->query_skill_mapped("sword") == "yinyang-ren")
  #                 ap = me->query_skill("sword");
  #         else 
  #                 ap = me->query_skill("blade");
  # 
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 me->add("neili", -240);
  #                 me->start_busy(2 + random(2));
  #                 msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
  #                                            HIR "$n" HIR "见此招来势凶猛， 阻挡不"
  #                                            "及， 顿时被" + weapon->name() + HIR 
  #                                            "所伤，苦不堪言。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -150);
  #                 me->start_busy(1 + random(2));
  #                 msg = CYN "可却见" CYN "$n" CYN "猛的拔地而起，避开了"
  #                        CYN "$N" CYN "来势凶猛的一招。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end
