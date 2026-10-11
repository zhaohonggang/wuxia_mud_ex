defmodule Kantele.Combat.Skills.Performs.HujiaDaofa.Cang do
  @moduledoc """
  perform「八方藏刀势」（source hujia-daofa/cang.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "hujia-daofa/cang"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "hujia-daofa")
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
      Stats.skill(stats, "force") < 250 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "hujia-daofa") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "blade") != "hujia-daofa" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 220}
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
    Performs.feedback(attacker, 220, 1)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-220"}], "apply_adds": ["attack"], "assign_refs": [{"count", "hujia-daofa"}], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(8));"], "level_gates": [{"force", "250"}, {"hujia-daofa", "180"}], "map_gates": [{"blade", "hujia-daofa"}], "remote_damage": false, "resource_gates": [{"neili", "200"}], "var_gates": [{"i", "8"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define CANG "「" HIW "八方藏刀势" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #         string msg;
  #         int count;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/hujia-daofa/cang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(CANG "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，难以施展" CANG "。\n");
  # 
  #     if ((int)me->query_skill("force") < 250)
  #         return notify_fail("你的内功火候不够，难以施展" CANG "。\n");
  # 
  #     if ((int)me->query_skill("hujia-daofa", 1) < 180)
  #         return notify_fail("你的胡家刀法还不到家，难以施展" CANG "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "hujia-daofa")
  #                 return notify_fail("你没有激发胡家刀法，难以施展" CANG "。\n");
  # 
  #     if ((int)me->query("neili") < 200)
  #         return notify_fail("你的真气不够，难以施展" CANG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "轻舒猿臂，施出「战八方藏刀式」，手中的" + weapon->name() +
  #               HIW "吞吞吐吐，变化莫测，笼罩了$n" HIW "周身要害！\n" NOR;
  # 
  #         if (random(me->query_skill("blade")) > target->query_skill("parry") / 2)
  #         {
  #                 msg += HIY "$n" HIY "见来招实在是变幻莫测，不由得心"
  #                        "生惧意，招式登时出了破绽！\n" NOR;
  #                 count = me->query_skill("hujia-daofa", 1) / 4;
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "心底微微一惊，打起精神小心接招。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #     message_combatd(msg, me, target);
  #     me->add("neili", -220);
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 8; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #             COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #     me->start_busy(1 + random(8));
  #     return 1;
  # }
end
