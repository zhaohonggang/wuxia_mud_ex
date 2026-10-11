defmodule Kantele.Combat.Skills.Performs.XuantieJian.Juan do
  @moduledoc """
  perform「卷字诀」（source xuantie-jian/juan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "xuantie-jian/juan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "xuantie-jian")
    ap = Stats.skill(stats, "sword")

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
      Stats.skill(stats, "force") < 400 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "xuantie-jian") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "xuantie-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
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
    vitals = %{vitals | neili: vitals.neili - 25}
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
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
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
  #   %{"add_costs": [{"neili", "-25"}, {"neili", "-50"}], "assign_refs": [{"ap", "sword"}, {"dp", "dodge"}], "busy_lines": ["if (target->is_busy())", "target->start_busy(ap / 20 + 2);", "me->start_busy(2);"], "level_gates": [{"force", "400"}, {"xuantie-jian", "100"}], "map_gates": [{"sword", "xuantie-jian"}], "remote_damage": false, "resource_gates": [{"neili", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // juan.c 卷字诀
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define JUAN "「" HIW "卷字诀" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         // int damage;
  #         int ap, dp;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/xuantie-jian/juan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JUAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对。\n");
  # 
  #         if ((int)me->query_skill("xuantie-jian", 1) < 100)
  #                 return notify_fail("你的玄铁剑法不够娴熟，不能使用" JUAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 400)
  #                 return notify_fail("你的内功火候不够，不能使用" JUAN "。\n");
  # 
  #         if ((int)me->query("neili") < 100 )
  #                 return notify_fail("你现在内力太弱，不能使用" JUAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "xuantie-jian")
  #                 return notify_fail("你没有激发玄铁剑法，不能施展" JUAN "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N一抖手中的" + weapon->name() + HIY "，自下而上的朝$n"
  #               HIY "卷了过去，曲曲折折，变化无常！\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("dodge");
  #         if (random(ap) > dp / 2)
  #         {
  #                 target->start_busy(ap / 20 + 2);
  #                 me->add("neili", -50);
  #                 msg += YEL "$p" YEL "连忙竭力招架，一时无暇反击。\n" NOR;
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "看破了$P" CYN "的企图，斜跃避开了$P"
  #                        CYN "的攻击。\n"NOR;
  #         me->add("neili", -25);
  #             me->start_busy(2);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
