defmodule Kantele.Combat.Skills.Performs.YunvJian.Mei do
  @moduledoc """
  perform「千姿百媚」（source yunv-jian/mei.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yunv-jian/mei"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yunv-jian")
    level = Stats.skill(stats, "yunv-jian")

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
      Stats.skill(stats, "dodge") < 60 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "yunv-jian") < 40 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "yunv-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 60 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 50}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 50, 2)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}], "assign_refs": [{"level", "yunv-jian"}], "busy_lines": ["target->start_busy(2 + random(level / 24));", "me->start_busy(random(2));", "me->start_busy(2);"], "level_gates": [{"dodge", "60"}, {"yunv-jian", "40"}], "map_gates": [{"sword", "yunv-jian"}], "remote_damage": false, "resource_gates": [{"neili", "60"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define MEI "「" HIM "千姿百媚" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg, wn;
  #         object weapon;
  #         int level;
  # 
  #         me = this_player();
  # 
  #         if (userp(me) && ! me->query("can_perform/yunv-jian/mei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(MEI "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" MEI "。\n");
  # 
  #         if ((int)me->query_skill("yunv-jian", 1) < 40)
  #                 return notify_fail("你玉女剑法不够娴熟，难以施展" MEI "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "yunv-jian")
  #                 return notify_fail("你没有激发玉女剑法，难以施展" MEI "。\n");
  # 
  #         if ((int)me->query_skill("dodge") < 60)
  #                 return notify_fail("你的轻功修为不够，难以施展" MEI "。\n");
  # 
  #         if ((int)me->query("neili") < 60)
  #                 return notify_fail("你现在的真气不够，难以施展" MEI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIC "\n$N" HIC "陡然间姿态万千，身法飘逸，犹如一个婀娜"
  #               "多姿的女子在随歌漫舞一样。但是$N手中" + wn + HIC "却"
  #               "跟随着身体轻盈地晃动，看似毫无章法，却又像是隐藏着厉"
  #               "害的招式。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         level = me->query_skill("yunv-jian", 1);
  #         me->add("neili", -50);
  #         if (level / 2 + random(level) > target->query_skill("dodge", 1))
  #         {
  #         msg = HIY "$N" HIY "看不出$n" HIY "招式中的虚实，连忙"
  #                       "护住自己全身，一时竟无以应对！\n" NOR;
  #                 target->start_busy(2 + random(level / 24));
  #                 me->start_busy(random(2));
  #     } else
  #         {
  #         msg = CYN "可是$N" CYN "看出了$n" CYN "这招乃虚招，顿"
  #                       "时一丝不乱，镇定自若。\n" NOR;
  # 
  #                 me->start_busy(2);
  #     }
  #     message_combatd(msg, target, me);
  # 
  #     return 1;
  # }
end
