defmodule Kantele.Combat.Skills.Performs.ZigaiJian.Hui do
  @moduledoc """
  perform「紫盖回翔」（source zigai-jian/hui.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "zigai-jian/hui"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "zigai-jian")
    ap = Stats.skill(stats, "zigai-jian")
    damage = (ap + Engine.rand(rng, div(ap, 2)))

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
      Stats.skill(stats, "dodge") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "zigai-jian") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "zigai-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 150 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 50}
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

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 50, 3)
    result = Messages.interpolate("$n心中一惊，虽知中计，但突如其来迅捷无比，已然闪避不及。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-50"}], "assign_refs": [{"ap", "zigai-jian"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"dodge", "120"}, {"force", "150"}, {"zigai-jian", "120"}], "map_gates": [{"sword", "zigai-jian"}], "remote_damage": true, "resource_gates": [{"neili", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HUI "「" HIC "紫盖回翔" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg, wn;
  #         object weapon;
  #         int ap, dp;
  # 
  #         me = this_player();
  # 
  #         if (userp(me) && ! me->query("can_perform/zigai-jian/hui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUI "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query_skill("zigai-jian", 1) < 120)
  #                 return notify_fail("你紫盖剑法不够娴熟，难以施展" HUI "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "zigai-jian")
  #                 return notify_fail("你没有激发紫盖剑法，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150 )
  #                 return notify_fail("你的内功火候不够，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query_skill("dodge") < 120)
  #                 return notify_fail("你的轻功火候不够，难以施展" HUI "。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在的真气不够，难以施展" HUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIY "\n$N" HIY "撤剑转身向后一纵，似欲逃走，$n" HIY "乘机挺"
  #               "剑上前，" HIY "眼见$n" HIY "即\n将得手，不料$N" HIY "凌空"
  #               "回身反刺，" + wn + HIY "直指$n" HIY "。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         ap = me->query_skill("zigai-jian", 1);
  #         dp = target->query_skill("dodge", 1);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #              damage = ap + random(ap / 2);
  # 
  #              msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 45,
  #                                           HIR "$n" HIR "心中一惊，虽知中计，但"
  #                                           + wn + HIR "突如其来迅捷无比，已然闪"
  #                                           "避不及。\n" NOR);
  # 
  #              me->start_busy(2);
  #              me->add("neili", -100);
  #         } else
  #         {
  #              msg = CYN "然而$n" CYN "眼见" + wn + CYN "已至，但$n"
  #                       CYN "身法迅速无比，提气向后一纵，$N" CYN "扑了"
  #                       "个空。\n" NOR;
  # 
  #              me->start_busy(3);
  #              me->add("neili", -50);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
