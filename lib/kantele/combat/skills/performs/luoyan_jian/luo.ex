defmodule Kantele.Combat.Skills.Performs.LuoyanJian.Luo do
  @moduledoc """
  perform「一剑落九雁」（source luoyan-jian/luo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "luoyan-jian/luo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "luoyan-jian")
    ap = Stats.skill(stats, "sword")
    count = 0
    i = 0

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
      Stats.skill(stats, "luoyan-jian") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "luoyan-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
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
    Performs.feedback(attacker, 200, 1)
    result = Messages.interpolate("$N蓦的一声清啸，施出衡山派绝学「一剑落九雁」，手中青光荡漾。霎时间回风落雁剑剑招连绵涌出，有如神助，剑气笼罩$n四方。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "apply_adds": ["attack"], "assign_refs": [{"ap", "sword"}, {"count", "luoyan-jian"}, {"dp", "dodge"}], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(9));"], "level_gates": [{"luoyan-jian", "150"}], "map_gates": [{"sword", "luoyan-jian"}], "remote_damage": false, "resource_gates": [{"neili", "400"}], "var_gates": [{"i", "9"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LUO "「" HIR "一剑落九雁" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int ap, dp;
  #         int i, count;
  # 
  #         if (userp(me) && ! me->query("can_perform/luoyan-jian/luo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(LUO "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" LUO "。\n");
  # 
  #     if ((int)me->query_skill("luoyan-jian", 1) < 150)
  #         return notify_fail("你的回风落雁剑不够娴熟，难以施展" LUO "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "luoyan-jian")
  #                 return notify_fail("你没有激发回风落雁剑法，难以施展" LUO "。\n");
  # 
  #     if (me->query("neili") < 400)
  #         return notify_fail("你目前的真气不够，难以施展" LUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "\n$N" HIW "蓦的一声清啸，施出衡山派绝学「" HIR "一剑落九雁"
  #               HIW "」，手中" + weapon->name() + HIW "青光荡漾。霎时间回风"
  #               "落雁剑剑招连绵涌出，有如神助，剑气笼罩$n" HIW "四方。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #     ap = me->query_skill("sword");
  #     dp = target->query_skill("dodge");
  # 
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         msg = HIY "$n" HIY "见$P" HIY "剑势汹涌，寒意顿生，竟"
  #                       "被逼得连连后退，狼狈不已。\n" NOR;
  #                 count = me->query_skill("luoyan-jian") / 40;
  #         } else
  #         {
  #                 msg = HIC "$n" HIC "见$N" HIC "这几剑来势迅猛无比，毫"
  #                       "无破绽，只得小心应付。\n" NOR;
  #                 count = 0;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -200);
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 9; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->start_busy(1 + random(9));
  #         return 1;
  # }
end
