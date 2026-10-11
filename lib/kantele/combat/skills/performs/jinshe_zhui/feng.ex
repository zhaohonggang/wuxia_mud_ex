defmodule Kantele.Combat.Skills.Performs.JinsheZhui.Feng do
  @moduledoc """
  perform「截脉封穴」（source jinshe-zhui/feng.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jinshe-zhui/feng"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinshe-zhui")
    skill = Stats.skill(stats, "jinshe-zhui")
    count = 0
    ap = Stats.skill(stats, "throwing")

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
      Stats.skill(stats, "force") < 150 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "throwing") != "jinshe-zhui" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

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
    vitals = %{vitals | neili: vitals.neili - 200}
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
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
    Performs.feedback(attacker, 50, 3)
    result = Messages.interpolate("$N飞身一跃而起，贴至$n跟前，点向$n要穴！
$p微微一楞，已被$N点中要穴，顿时瘫软无力，缓缓瘫倒。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "apply_adds": ["armor", "damage", "defense", "dodge", "force", "parry"], "assign_refs": [{"ap", "throwing"}, {"dp", "force"}, {"skill", "jinshe-zhui"}], "busy_lines": ["me->start_busy(1);", "me->start_busy(3);"], "level_gates": [{"force", "150"}], "map_gates": [{"throwing", "jinshe-zhui"}], "remote_damage": false, "resource_gates": [{"neili", "500"}], "var_gates": [{"skill", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FENG "「" HIR "截脉封穴" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object target, anqi;
  #         int skill, count, ap, dp;
  # 
  #         //anqi = me->query_temp("handing");
  #         skill = me->query_skill("jinshe-zhui", 1);
  # 
  #         if (! objectp(anqi = me->query_temp("handing"))
  #            || (string)anqi->query("skill_type") != "throwing")
  #         {
  #             count = 0;
  #         }    else
  #         {
  #             count = anqi->query("weapon_prop/damage");
  #         }
  # 
  #         if (me->query_temp("jinshe/feng"))
  #         return notify_fail("你才用过截脉封穴，没法接着就出招。\n");
  # 
  #         if (! target) target = offensive_target(me);
  #         if (! target ||    ! me->is_fighting(target))
  #         return notify_fail("截脉封穴只能在战斗中使用。\n");
  # 
  #         if (me->query_skill("force") < 150)
  #                 return notify_fail("你的内功的修为不够，难以施展" FENG "。\n");
  # 
  #         if (skill < 100)
  #                 return notify_fail("你的金蛇锥法修为有限，难以施展" FENG "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不足，难以施展" FENG "。\n");
  # 
  #         if (me->query_skill_mapped("throwing") != "jinshe-zhui")
  #                 return notify_fail("你没有激发金蛇锥法，难以施展" FENG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "飞身一跃而起，贴至$n" HIR "跟前，点向$n" HIR "要穴！\n" NOR;
  # 
  #         ap = me->query_skill("throwing");
  #         dp = target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  # 
  #             msg += HIR "$p" HIR "微微一楞，已被$N" HIR
  #                 "点中要穴，顿时瘫软无力，缓缓瘫倒。\n" NOR;
  #                 me->add("neili", -200);
  #                 me->start_busy(1);
  #                 me->set_temp("jinshe/feng", 1);
  #                 me->start_call_out((: call_other, __FILE__, "feng_end", me :), 5);
  # 
  #                 switch (random(6))
  #                 {
  #                     case 0:
  #                             target->add_temp("apply/damage", -skill / 6);
  #                             break;
  # 
  #                     case 1:
  #                             target->add_temp("apply/dodge", -skill / 4);
  #                             break;
  # 
  #                     case 2:
  #                             target->add_temp("apply/parry", -skill / 4);
  #                             break;
  # 
  #                     case 3:
  #                             target->add_temp("apply/force", -skill / 4);
  #                             break;
  # 
  #                     case 4:
  #                             target->add_temp("apply/armor", -skill / 4);
  #                             break;
  # 
  #                     default:
  #                             target->add_temp("apply/defense", -skill / 4);
  #                             break;
  #                 }
  # 
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "的看破了$P" CYN
  #                        "的招式，巧妙的一一拆解，没露半点破绽！\n" NOR;
  #                 me->add("neili", -50);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # void feng_end(object me)
  # {
  #         me->delete_temp("jinshe/feng");
  # }
end
