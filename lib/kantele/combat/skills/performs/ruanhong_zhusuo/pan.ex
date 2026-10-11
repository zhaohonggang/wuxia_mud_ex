defmodule Kantele.Combat.Skills.Performs.RuanhongZhusuo.Pan do
  @moduledoc """
  perform「盘鹰诀」（source ruanhong-zhusuo/pan.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "ruanhong-zhusuo/pan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "ruanhong-zhusuo")

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
      Stats.skill(stats, "ruanhong-zhusuo") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "whip") != "ruanhong-zhusuo" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 0, 1)
    result = Messages.interpolate("$n微作诧异，一时勘破不透$N招中奥妙，顿被攻了个措手不及！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "target->start_busy((int)me->query_skill("ruanhong-zhusuo") / 20 + 2);"], "level_gates": [{"ruanhong-zhusuo", "80"}], "map_gates": [{"whip", "ruanhong-zhusuo"}], "remote_damage": false, "resource_gates": [{"neili", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // panying.c 盘鹰诀
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PANYING "「" YEL "盘鹰诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  # //      int ap, dp;
  # //      int damage;
  #  
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/ruanhong-zhusuo/panying"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PANYING "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "whip")
  #                 return notify_fail("你使用的武器不对，无法施展" PANYING "。\n");
  # 
  #         if ((int)me->query_skill("ruanhong-zhusuo", 1) < 80)
  #                 return notify_fail("你的软红蛛索不够娴熟，无法施展" PANYING "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #         if (me->query("neili") < 100)
  #                 return notify_fail("你的真气不够，无法施展" PANYING "。\n");
  # 
  #         if (me->query_skill_mapped("whip") != "ruanhong-zhusuo")
  #                 return notify_fail("你没有激发软红蛛索，无法施展" PANYING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = YEL "$N" YEL "使出软红蛛索「盘鹰」诀，手腕轻轻一抖，顿时鞭"
  #               "影重重，完全笼罩$n" YEL "四周！\n";
  # 
  #         me->start_busy(1);
  # 
  #         if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
  #         {
  #                 msg += HIR "$n" HIR "微作诧异，一时勘破不透$N" HIR "招中"
  #                        "奥妙，顿被攻了个措手不及！\n" NOR;
  #                 target->start_busy((int)me->query_skill("ruanhong-zhusuo") / 20 + 2);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的企图，小心应对，并没有上当。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
