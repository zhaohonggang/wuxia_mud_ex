defmodule Kantele.Combat.Skills.Performs.ShenghuoLing.Can do
  @moduledoc """
  perform「残血令」（source shenghuo-ling/can.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "shenghuo-ling/can"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "shenghuo-ling")
    skill = Stats.skill(stats, "shenghuo-ling")
    improve = 0
    n = 0
    m = 0
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
      Stats.skill(stats, "force") < 350 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "shenghuo-ling" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 5000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 300}
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
    Performs.feedback(attacker, 300, 1)
    result = Messages.interpolate("$N一声长啸，手中一转，招数顿时变得诡异无比，从意想不到的方位攻向$n！
$n完全无法看透$N招中虚实，不由得心生惧意，招式一滞，登时破绽百出。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-300"}], "apply_adds": ["attack"], "assign_refs": [{"count", "shenghuo-ling"}, {"skill", "shenghuo-ling"}], "busy_lines": ["if (random(3) == 1 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(4));"], "level_gates": [{"force", "350"}], "map_gates": [{"sword", "shenghuo-ling"}], "remote_damage": false, "resource_gates": [{"max_neili", "5000"}, {"neili", "400"}], "var_gates": [{"i", "7"}, {"skill", "220"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define CANXUE "「" HIR "残血令" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int count;
  #         int skill;
  #         int i;
  # 
  #         float improve;
  #         int lvl, m, n;
  #         string martial;
  #         string *ks;
  #         martial = "sword";
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/shenghuo-ling/can"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         skill = me->query_skill("shenghuo-ling", 1);
  # 
  #         if (! (me->is_fighting()))
  #                 return notify_fail(CANXUE "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的兵器不对，不能使用圣火令法之"
  #                                    CANXUE "。\n");
  # 
  #         if (skill < 220)
  #                 return notify_fail("你的圣火令法等级不够, 不能使用圣火令"
  #                                    "法之" CANXUE "。\n");
  # 
  #         if (me->query_skill("force") < 350)
  #                 return notify_fail("你的内功火候不够，不能使用圣火令法之"
  #                                    CANXUE "。\n");
  # 
  #         if (me->query("max_neili") < 5000)
  #                 return notify_fail("你的内力修为不足，不能使用圣火令法之"
  #                                    CANXUE "。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的内力不够，不能使用圣火令法之" CANXUE "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "shenghuo-ling")
  #                 return notify_fail("你没有激发圣火令法，无法使用" CANXUE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "一声长啸，手中" + weapon->name() +
  #               HIR "一转，招数顿时变得诡异无比，从意想不到的方"
  #               "位攻向$n" HIR "！\n" NOR;
  # 
  #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvl = lvl * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (m = 0; m < sizeof(ks); m++)
  #         {
  #             if (SKILL_D(ks[m])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[m], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 5 / 100 / lvl;
  # 
  #         // 配合圣火令法本身具备的 max_hit带来额外的伤害。
  #         // 原著中该令法乃很难看透的招数，所以出现增加攻
  #         // 击的效率非常大。
  #         if (random(me->query_skill("sword")) > target->query_skill("parry") / 3)
  #         {
  #                 msg += HIR "$n" HIR "完全无法看透$N" HIR "招中虚实，不由得心"
  #                        "生惧意，招式一滞，登时破绽百出。\n" NOR;
  #                 count = me->query_skill("shenghuo-ling", 1) / 6;
  #                 me->add_temp("shenghuo-ling/max_hit", 1);
  #         } else
  #         {
  #                 msg += HIY "$n" HIY "见$N" HIY "来势汹涌，心底一惊，打起精"
  #                        "神小心接招。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         me->add("neili", -300);
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 7; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->delete_temp("shenghuo-ling/max_hit");
  #         me->start_busy(1 + random(4));
  #         return 1;
  # }
end
