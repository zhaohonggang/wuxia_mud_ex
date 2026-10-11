defmodule Kantele.Combat.Skills.Performs.JindingZhang.Bashi do
  @moduledoc """
  perform「八式合一」（source jinding-zhang/bashi.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jinding-zhang/bashi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinding-zhang")

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
      Stats.skill(stats, "force") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "jinding-zhang") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "strike") != "jinding-zhang" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 100}
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
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 100, 3)
    result = Messages.interpolate("只见漫天掌影飘忽不定的罩向$n全身各个部位，$n顿时接连中了数掌！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}], "assign_refs": [{"damage", "linji-zhuang"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "100"}, {"jinding-zhang", "100"}], "map_gates": [{"strike", "jinding-zhang"}], "prepared_gates": [{"strike", "jinding-zhang"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define BASHI "「" HIY "八式合一" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  #         // int count,d_count,qi, maxqi, skill;
  # 
  #         if (userp(me) && ! me->query("can_perform/jinding-zhang/bashi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(BASHI "只能在战斗中对对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(BASHI "只能空手施展。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你的内力还不够，难以施展" BASHI "。\n");
  # 
  #         if ((int)me->query_skill("force") < 100)
  #                 return notify_fail("你的内功的修为不够，难以施展" BASHI "。\n");
  # 
  #         if ((int)me->query_skill("jinding-zhang", 1) < 100)
  #                 return notify_fail("你的金顶绵掌的修习不够，难以施展" BASHI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "jinding-zhang")
  #                 return notify_fail("你没有激发金顶绵掌，难以施展" BASHI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "jinding-zhang")
  #                 return notify_fail("你现在没有准备使用金顶绵掌，难以施展" BASHI "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "深深吸了一口气，提起全身的功力于"
  #               "双掌猛力拍出，只听得骨骼一阵爆响！\n" NOR;
  #         if (random(me->query_skill("strike")) > (int)target->query_skill("force") / 2)
  #         {
  #                 damage  = (int)me->query_skill("linji-zhuang", 1);
  #                 damage += (int)me->query_skill("jinding-zhang", 1);
  #                 damage /= 3;
  #                 damage += random(damage);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "只见漫天掌影飘忽不定的罩向$n" HIR
  #                                            "全身各个部位，$n" HIR "顿时接连中了数"
  #                                            "掌！\n" NOR);
  #                 me->add("neili", -100);
  #                 me->start_busy(2);
  #          } else
  #          {
  #                 msg += CYN "可是$p" CYN "猛地向后一跃，跳出了$P"
  #                        CYN "的攻击范围。\n" NOR;
  #                 me->start_busy(3);
  #          }
  #          message_combatd(msg, me, target);
  #          return 1;
  # }
end
