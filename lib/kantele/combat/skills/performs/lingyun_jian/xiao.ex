defmodule Kantele.Combat.Skills.Performs.LingyunJian.Xiao do
  @moduledoc """
  perform「剑气冲霄」（source lingyun-jian/xiao.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "lingyun-jian/xiao"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lingyun-jian")
    ap = Stats.skill(stats, "sword")
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
      Stats.skill(stats, "force") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "lingyun-jian") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "lingyun-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 180}
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
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
    Performs.feedback(attacker, 200, 2)
    result = Messages.interpolate("$n只见一道金光闪过，心中惊骇不已，但鲜血已从$n胸口喷出。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-180"}, {"neili", "-200"}], "assign_refs": [{"ap", "sword"}, {"dp", "parry"}], "busy_lines": ["me->start_busy(2 + random(4));", "me->start_busy(2);"], "level_gates": [{"force", "120"}, {"lingyun-jian", "120"}], "map_gates": [{"sword", "lingyun-jian"}], "remote_damage": true, "resource_gates": [{"neili", "300"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XIAO "「" HIW "剑气冲霄" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/lingyun-jian/xiao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XIAO "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" XIAO "。\n");
  # 
  #         if ((int)me->query_skill("lingyun-jian", 1) < 120)
  #                 return notify_fail("你凌云剑法不够娴熟，难以施展" XIAO "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "lingyun-jian")
  #                 return notify_fail("你没有激发凌云剑法，难以施展" XIAO "。\n");
  # 
  #         if ((int)me->query_skill("force") < 120)
  #                 return notify_fail("你的内功火候不够，难以施展" XIAO "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不够，难以施展" XIAO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIW "\n$N" HIW "长叹一声，语调宛然，忽然右手斜指长"
  #               "空，手中" + wn + HIW "寒光闪闪，猛然间使出绝"
  #               "招「" HIY "剑气冲霄" HIW "」，刹时间剑风凌厉"
  #               "，" + wn + HIW "以直冲云霄之势，斩向$n\n" HIW "。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #              msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
  #                                           HIR "$n" HIR "只见一道金光闪过，心中"
  #                                           "惊骇不已，但鲜血已从$n胸口喷出。\n"
  #                                           NOR);
  #              me->start_busy(2 + random(4));
  #              me->add("neili", -200);
  #         } else
  #         {
  #              msg = CYN "然而$n" CYN "眼明手快，侧身一跳"
  #                       "躲过$N" CYN "这一剑。\n" NOR;
  # 
  #              me->start_busy(2);
  #              me->add("neili", -180);
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end
