defmodule Kantele.Combat.Skills.Performs.JinyuanGun.Qian do
  @moduledoc """
  perform「乾坤一击」（source jinyuan-gun/qian.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "jinyuan-gun/qian"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinyuan-gun")
    ap = Stats.skill(stats, "club")
    damage = (div(ap, 2) + Engine.rand(rng, div((ap * 2), 3)))

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
      Stats.skill(stats, "force") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "jinyuan-gun") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "club") != "jinyuan-gun" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
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
    vitals = %{vitals | neili: vitals.neili - 150}
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
    Performs.feedback(attacker, 150, 3)
    result = Messages.interpolate("$n浑身被劲风笼罩，登感窒息，“哇”的吐出一口鲜血，仰面便倒！", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-150"}], "assign_refs": [{"ap", "club"}, {"dp", "dodge"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "180"}, {"jinyuan-gun", "120"}], "map_gates": [{"club", "jinyuan-gun"}], "remote_damage": true, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define QIAN "「" HIY "乾坤一击" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/jinyuan-gun/qian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(QIAN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "club")
  #                 return notify_fail("你使用的武器不对，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功的修为不够，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill("jinyuan-gun", 1) < 120)
  #                 return notify_fail("你的金猿棍法修为不够，难以施展" QIAN "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，难以施展" QIAN "。\n");
  # 
  #         if (me->query_skill_mapped("club") != "jinyuan-gun")
  #                 return notify_fail("你没有激发金猿棍法，难以施展" QIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "大步上前，怒吼一声，手中" + weapon->name() +
  #               HIY "急速舞动，霎时间飞沙走石，罡气激荡。\n便在狂沙飓风中"
  #               "，$N" HIY "忽然高高跃起，迎头一棒朝$n" HIY "劈落！\n" NOR;
  # 
  #         ap = me->query_skill("club");
  #         dp = target->query_skill("dodge");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap * 2 / 3);
  #                 me->add("neili", -150);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 35,
  #                                            HIR "$n" HIR "浑身被劲风笼罩，登感窒息"
  #                                            "，“哇”的吐出一口鲜血，仰面便倒！\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "$n" CYN "不敢有丝毫大意，急忙纵身后跃，躲"
  #                        "开这足以断金裂石的一击。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
