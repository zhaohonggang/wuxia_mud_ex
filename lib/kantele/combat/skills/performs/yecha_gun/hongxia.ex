defmodule Kantele.Combat.Skills.Performs.YechaGun.Hongxia do
  @moduledoc """
  perform「红霞贯日」（source yecha-gun/hongxia.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yecha-gun/hongxia"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yecha-gun")
    skill = Stats.skill(stats, "yecha-gun")
    ap = Stats.skill(stats, "club")
    damage = (div(ap, 6) + Engine.rand(rng, div(ap, 6)))

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
    with :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "club") != "yecha-gun" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 150}
    vitals = %{vitals | neili: vitals.neili - 50}
    vitals = %{vitals | neili: vitals.neili - 80}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 80, 3)
    result = Messages.interpolate("$N身形曼妙，手中铁棍虚虚实实，舞出无数的棍影宛若满天的红霞，将$n重重包围。
$n只觉$N棍影重重，无所不在，自己无处躲闪，顿时身上连中数棍，被攻了个措手不及。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}, {"neili", "-50"}, {"neili", "-80"}], "assign_refs": [{"ap", "club"}, {"dp", "parry"}, {"skill", "yecha-gun"}], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "if (ap / 2 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(3);"], "map_gates": [{"club", "yecha-gun"}], "remote_damage": true, "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "120"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h> 
  # #include <combat.h> 
  # 
  # #define HONG "「" HIR "红霞贯日" NOR "」" 
  # 
  # inherit F_SSERVER; 
  # 
  # int perform(object me, object target) 
  # {
  #         int skill, ap, dp, damage; 
  #         string msg; 
  # 
  #         //if (userp(me) && ! me->query("can_perform/yecha-gun/hongxia")) 
  #         //        return notify_fail("你所使用的外功中没有这种功能。\n"); 
  # 
  #         if (! target) 
  #         { 
  #                 me->clean_up_enemy(); 
  #                 target = me->select_opponent(); 
  #         }
  # 
  #         if (! target || ! me->is_fighting(target)) 
  #                 return notify_fail(HONG "只能对战斗中的对手使用。\n"); 
  # 
  #         skill = me->query_skill("yecha-gun", 1);
  #  
  #         if (skill < 120) 
  #                 return notify_fail("你的夜叉棍法等级不够，难以施展" HONG "。\n"); 
  # 
  #         if (me->query("neili") < 200) 
  #                 return notify_fail("你的真气不够，难以施展" HONG "。\n"); 
  # 
  #         if (me->query_skill_mapped("club") != "yecha-gun") 
  #                 return notify_fail("你没有激发夜叉棍法，难以施展" HONG "。\n"); 
  # 
  #         if (target->is_busy()) 
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n"); 
  # 
  #         if (! living(target)) 
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n"); 
  # 
  #         msg = HIR "$N" HIR "身形曼妙，手中铁棍" HIR "虚虚实实，舞出无数的棍影" 
  #               "宛若满天的红霞，将$n重重包围。\n" NOR; 
  #         
  #         me->add("neili", -50); 
  # 
  #         ap = me->query_skill("club"); 
  #         dp = target->query_skill("parry"); 
  # 
  #         if (ap / 2 + random(ap * 4 / 3) > dp) 
  #         {
  #                 me->add("neili", -150); 
  #                 damage = ap / 6 + random(ap / 6); 
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 30, 
  #                                            HIR "$n" HIR "只觉$N" HIR "棍影重重，" 
  #                                            "无所不在，自己无处躲闪，顿时身上" 
  #                                            "连中数棍，被攻了个措手不及。\n" NOR); 
  # 
  #                 me->start_busy(1); 
  #                 if (ap / 2 + random(ap) > dp && ! target->is_busy()) 
  #                         target->start_busy(ap / 30 + 2); 
  #         } else 
  #         {
  #                 msg += CYN "$n" CYN "只见$N" CYN "看破了棍法中的虚实，凝神" 
  #                        "化解开来。\n" NOR; 
  #                 me->add("neili", -80); 
  #                 me->start_busy(3); 
  #         } 
  #         message_combatd(msg, me, target);  
  # 
  #         return 1; 
  # }
end
