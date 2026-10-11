defmodule Kantele.Combat.Skills.Performs.YuxiaoJian.Qing do
  @moduledoc """
  perform「天地情长」（source yuxiao-jian/qing.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "yuxiao-jian/qing"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yuxiao-jian")
    skill = Stats.skill(stats, "yuxiao-jian")

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
    with :ok <- check_mapped(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "yuxiao-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 1000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 120}
    vitals = %{vitals | neili: vitals.neili - 500}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 500, 2)
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-120"}, {"neili", "-500"}], "assign_refs": [{"ap", "sword"}, {"dp", "force"}, {"skill", "yuxiao-jian"}], "busy_lines": ["//me->start_busy(1 + random(3));", "me->start_busy(1);", "me->start_busy(2);"], "map_gates": [{"sword", "yuxiao-jian"}], "remote_damage": false, "resource_gates": [{"neili", "1000"}, {"neili", "300"}], "var_gates": [{"skill", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define QING "「" HIG "天地情长" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object weapon, target;
  #         int skill, ap, dp;
  #         int cost;
  # 
  #         if (userp(me) && ! me->query("can_perform/yuxiao-jian/qing"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(QING "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" QING "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "yuxiao-jian")
  #                 return notify_fail("你没有激发玉箫剑法，难以施展" QING "。\n");
  # 
  #         skill = me->query_skill("yuxiao-jian",1);
  # 
  #         if (skill < 150)
  #                 return notify_fail("你玉箫剑法等级不够，难以施展" QING "。\n");
  # 
  #         if (target->query("neili") < 300)
  #                 return notify_fail("看样子对方真气并不充沛，无需运用" QING "。\n");
  # 
  #         if (me->query("neili") < 1000)
  #                 return notify_fail("你现在的真气不足，难以施展" QING "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIG "$N" HIG "手中的" + weapon->name() + HIG "倏的刺出，卷起一阵"
  #               "阵气旋，不住的往里收缩。\n" NOR;
  # 
  #         ap = me->query_skill("sword") + me->query_skill("force") +
  #              me->query_skill("chuixiao-jiafa", 1);
  #         dp = target->query_skill("force") * 2;
  #         if (ap > dp && ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -500);
  #                 msg += HIM "$p" HIM "顿觉$P" HIM "的内力隐藏在一个个气旋中，难"
  #                        "以捉摸去处，只能强运内力抵消。\n" NOR;
  #                 cost = 500 + (ap - dp) * 3 / 2;
  #                 if (cost > target->query("neili"))
  #                         cost = target->query("neili");
  #                 target->add("neili", -cost);
  #                 //me->start_busy(1 + random(3));
  #                 me->start_busy(1);
  #         } else
  #         {
  #                 me->add("neili", -120);
  #                 msg += HIC "可是$p" HIC "心神安定，丝毫没有受到困惑。\n"NOR;
  #                 me->start_busy(2);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
