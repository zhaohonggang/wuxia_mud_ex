defmodule Kantele.Combat.Skills.Performs.ChuncanZhang.Jian do
  @moduledoc """
  perform「作茧自缚」（source chuncan-zhang/jian.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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

  @perform_id "chuncan-zhang/jian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "chuncan-zhang")
    skill = Stats.skill(stats, "chuncan-zhang")

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
      Stats.skill(stats, "chuncan-zhang") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "chuncan-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 800 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 150}
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
    Performs.feedback(attacker, 150, 2)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "apply_adds": ["attack", "dodge"], "assign_refs": [{"skill", "chuncan-zhang"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(2);"], "level_gates": [{"chuncan-zhang", "80"}, {"force", "120"}], "map_gates": [{"strike", "chuncan-zhang"}], "prepared_gates": [{"strike", "chuncan-zhang"}], "remote_damage": false, "resource_gates": [{"max_neili", "800"}, {"neili", "200"}], "temp_set": ["ccz_jian"]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define JIAN "「" HIW "作茧自缚" NOR "」"
  # 
  # inherit F_CLEAN_UP;
  # inherit F_SSERVER;
  # 
  # void remove_effect(object me, int a_amount, int d_amount);
  # 
  # int perform(object me)
  # {
  # //      object weapon;
  #         int skill;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/chuncan-zhang/jian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if ((int)me->query_temp("ccz_jian"))
  #                 return notify_fail("你已经运起" JIAN "了。\n");
  # 
  #         if ((int)me->query_skill("chuncan-zhang", 1) < 80)
  #                 return notify_fail("你的春蚕掌法不够娴熟，难以施展" JIAN "。\n");
  # 
  #         if ((int)me->query_skill("force", 1) < 120)
  #                 return notify_fail("你的内功火候不够，难以施展" JIAN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 800)
  #                 return notify_fail("你的内力修为不够，难以施展" JIAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "chuncan-zhang")
  #                 return notify_fail("你没有激发春蚕掌法，难以施展" JIAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "chuncan-zhang")
  #                 return notify_fail("你没有准备春蚕掌法，难以施展" JIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 200 )
  #                 return notify_fail("你的真气不够，难以施展" JIAN "。\n");
  # 
  #         msg = HIW "$N" HIW "凝聚内力，掌劲吞吐，顿时双掌掀起一层气劲，护住周身经脉。\n\n" NOR;
  #         message_combatd(msg, me);
  # 
  #         skill = me->query_skill("chuncan-zhang", 1);
  # 
  #         me->add_temp("apply/attack", -skill / 4);
  #         me->add_temp("apply/dodge", skill / 3);
  #         me->set_temp("ccz_jian", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 4, skill / 3 :), skill / 2);
  # 
  #         me->add("neili", -150);
  #         if (me->is_fighting()) me->start_busy(2);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int a_amount, int d_amount)
  # {
  #         if (me->query_temp("ccz_jian"))
  #         {
  #                 me->add_temp("apply/attack", a_amount);
  #                 me->add_temp("apply/dodge", -d_amount);
  #                 me->delete_temp("ccz_jian");
  #                 tell_object(me, "你的" JIAN "运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
