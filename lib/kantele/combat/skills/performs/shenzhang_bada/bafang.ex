defmodule Kantele.Combat.Skills.Performs.ShenzhangBada.Bafang do
  @moduledoc """
  perform「bafang」（source shenzhang-bada/bafang.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "shenzhang-bada/bafang"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shenzhang-bada")
    ap = (Stats.skill(stats, "strike") + Stats.skill(stats, "shenzhang-bada"))
    damage = div(ap, 2)

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
      Stats.skill(stats, "force") < 300 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "shenzhang-bada") < 200 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "shenzhang-bada" ->
        {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 700 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 350}
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
    Performs.feedback(attacker, 350, 3)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-350"}], "assign_refs": [{"ap", "strike"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "300"}, {"shenzhang-bada", "200"}], "map_gates": [{"strike", "shenzhang-bada"}], "remote_damage": true, "resource_gates": [{"neili", "700"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // bafang.c 威镇八方
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon; 
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「威镇八方」只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") ||
  #             me->query_temp("secondary_weapon"))
  #                 return notify_fail("你必须空手才能使用「威镇八方」！\n");
  # 
  #         if (me->query_skill("force") < 300)
  #                 return notify_fail("你的内功的修为不够，不能使用这一绝技！\n");
  # 
  #         if (me->query_skill("shenzhang-bada", 1) < 200)
  #                 return notify_fail("你的神掌八打修为不够，目前不能使用「威镇八方」！\n");
  # 
  #         if (me->query("neili") < 700)
  #                 return notify_fail("你的真气不够，无法使用「威镇八方」！\n");
  # 
  #         if (me->query_skill_mapped("strike") != "shenzhang-bada")
  #                 return notify_fail("你没有激发神掌八打，不能使用「威镇八方」！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "深深的吸了一口气，大喝一声，全身衣袍无风自鼓，"
  #                    HIY "然后提气往上一纵，居高临下，双掌奋力击下，刹那间，内劲犹如旋风般"
  #                    "击向$n" + HIY "！\n" NOR;
  # 
  #         ap = me->query_skill("strike") + me->query_skill("shenzhang-bada",1);
  #         dp = target->query_skill("dodge") + target->query_skill("parry");
  # 
  #         if (ap / 3 + random(ap) > dp / 2)
  #         {
  #                 damage = ap / 2;
  #                 damage += random(damage);
  #                 me->add("neili", -350);
  #                 me->start_busy(2);
  #                msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70);
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "看破了$N" CYN "的企图，轻轻"
  #                        CYN "向后飘出数丈，躲过了这一致命的一击！\n"NOR;
  #         }
  #                 message_combatd(msg, me, target);
  # 
  #                 return 1;
  # }
end
