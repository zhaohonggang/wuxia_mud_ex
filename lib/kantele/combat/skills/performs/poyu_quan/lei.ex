defmodule Kantele.Combat.Skills.Performs.PoyuQuan.Lei do
  @moduledoc """
  perform「雷动九天」（source poyu-quan/lei.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

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

  @perform_id "poyu-quan/lei"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "poyu-quan")
    skill = Stats.skill(stats, "cuff")
    count = div(skill, 6)

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
  defp check_gates(character), do: check_resources(character)

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 400}
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
    Performs.feedback(attacker, 400, 2)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-400"}], "assign_refs": [{"skill", "cuff"}, {"skill", "poyu-quan"}], "busy_lines": ["me->start_busy(2);"], "remote_damage": false, "resource_gates": [{"neili", "500"}], "temp_set": ["lei"], "var_gates": [{"skill", "120"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // leidong 雷动九天
  # // by winder 98.12
  # // modify by rcwiz 2003
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # #define LEI "「" HIM "雷动九天" NOR "」"
  # 
  # void remove_effect(object me, int amount);
  # 
  # int perform(object me)
  # {
  #     int skill, count/*, count1*/;
  # 
  # 
  #         if (userp(me) && ! me->query("can_perform/poyu-quan/lei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if ((int)me->query_temp("lei"))
  #         return notify_fail("你已经在运功中了。\n");
  # 
  #     if ((int)me->query("neili") < 500)
  #         return notify_fail("你现在的真气不够。\n");
  # 
  #     //skill = me->query_skill("cuff");
  #     skill = (int)me->query_skill("poyu-quan",1);
  # 
  #     if (skill < 120)
  #         return notify_fail("你的劈石破玉拳修为不够，无法施展" LEI "\n");
  # 
  #     me->add("neili", -400);
  #     message_combatd(HIM "$N" HIM "深深吸了一口气，脸上顿时"
  #                         "紫气大盛，出手越来越重！\n" NOR, me);
  # 
  #     //count = skill / 10;
  #     count = skill / 6;
  # 
  #         if (me->is_fighting())
  #                 me->start_busy(2);
  # 
  #     me->add_temp("str", count);
  #     me->add_temp("dex", count);
  #     me->set_temp("lei", 1);
  #     me->start_call_out((: call_other,  __FILE__, "remove_effect", me, count :), skill / 3);
  # 
  #     return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #     if ((int)me->query_temp("lei"))
  #     {
  #         me->add_temp("str", -amount);
  #         me->add_temp("dex", -amount);
  #         me->delete_temp("lei");
  #         tell_object(me, CYN "你的雷动九天运行完毕，将内力收回丹田。\n" NOR);
  #     }
  # }
end
