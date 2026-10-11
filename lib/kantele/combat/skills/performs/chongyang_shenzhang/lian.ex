defmodule Kantele.Combat.Skills.Performs.ChongyangShenzhang.Lian do
  @moduledoc """
  perform「重阳连环掌」（source chongyang-shenzhang/lian.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "chongyang-shenzhang/lian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "chongyang-shenzhang")
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
      Stats.skill(stats, "chongyang-shenzhang") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "force") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "chongyang-shenzhang" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 100 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 80}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 80, 1)
    result = Messages.interpolate("$N大喝一声，施出「重阳连环掌」，顿时双掌纷飞，向$n猛攻而去。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-80"}], "busy_lines": ["me->start_busy(1 + random(4));"], "level_gates": [{"chongyang-shenzhang", "100"}, {"force", "120"}], "map_gates": [{"strike", "chongyang-shenzhang"}], "remote_damage": false, "resource_gates": [{"neili", "100"}], "temp_set": ["action_flag"], "var_gates": [{"i", "4"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define LIAN "「" HIR "重阳连环掌" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #         string msg;
  #         mapping p;
  #         int i, af;
  # 
  #         if (userp(me) && ! me->query("can_perform/chongyang-shenzhang/lian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(LIAN "只能对战斗中的对手使用。\n");
  # 
  #     if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(LIAN "只能空手施展。\n");
  # 
  #     if ((int)me->query_skill("chongyang-shenzhang", 1) < 100)
  #         return notify_fail("你重阳神掌不够娴熟，难以施展" LIAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "chongyang-shenzhang")
  #                 return notify_fail("你没有激发重阳神掌，难以施展" LIAN "。\n");
  # 
  #         if (! mapp(p = me->query_skill_prepare())
  #            || p["strike"] != "chongyang-shenzhang")
  #                 return notify_fail("你没有准备重阳神掌，难以施展" LIAN "。\n");
  # 
  #     if ((int)me->query_skill("force") < 120)
  #         return notify_fail("你的内功火候不够，难以施展" LIAN "。\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你目前的真气不足，难以施展" LIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "大喝一声，施出「" HIR "重阳连环掌" HIY "」，顿"
  #               "时双掌纷飞，向$n" HIY "猛攻而去。\n" NOR;
  #     message_combatd(msg, me, target);
  #     me->add("neili", -80);
  # 
  #         af = member_array("strike", keys(p));
  # 
  #         for (i = 0; i < 4; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 me->set_temp("action_flag", af);
  #             COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #     me->start_busy(1 + random(4));
  #     return 1;
  # }
end
