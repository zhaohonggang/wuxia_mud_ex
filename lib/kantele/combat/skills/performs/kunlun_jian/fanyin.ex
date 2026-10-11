defmodule Kantele.Combat.Skills.Performs.KunlunJian.Fanyin do
  @moduledoc """
  perform「域外梵音」（source kunlun-jian/fanyin.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "kunlun-jian/fanyin"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "kunlun-jian")
    skill = Stats.skill(stats, "kunlun-jian")
    ap = Stats.skill(stats, "sword")
    dp = 1

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
      Stats.skill(stats, "force") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "kunlun-jian") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "tanqin-jifa") < 120 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "kunlun-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 2000 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
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
    result = Messages.interpolate("", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}, {"neili", "-50"}], "assign_refs": [{"ap", "sword"}, {"dp", "force"}, {"jing_wound", "sword"}, {"skill", "kunlun-jian"}], "busy_lines": ["me->start_busy(2 + random(2));", "me->start_busy(3);"], "level_gates": [{"force", "180"}, {"kunlun-jian", "120"}, {"tanqin-jifa", "120"}], "map_gates": [{"sword", "kunlun-jian"}], "remote_damage": true, "resource_gates": [{"max_neili", "2000"}, {"neili", "300"}], "var_gates": [{"dp", "1"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define FANYIN "「" MAG "域外梵音" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object weapon, target;
  #         int skill, ap, dp, jing_wound;
  # 
  #         if (userp(me) && ! me->query("can_perform/kunlun-jian/fanyin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(FANYIN "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" FANYIN "。\n");
  # 
  #         if (me->query_skill("tanqin-jifa", 1) < 120)
  #                 return notify_fail("你的弹琴技法尚且不够熟练, 难以施展" FANYIN "。\n");
  # 
  #         if (me->query_skill("kunlun-jian", 1) < 120)
  #                 return notify_fail("你的昆仑剑法等级不够, 难以施展" FANYIN "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" FANYIN "。\n");
  # 
  #         if (me->query("max_neili") < 2000)
  #                 return notify_fail("你的内力修为尚浅，难以施展" FANYIN "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你的真气不够，难以施展" FANYIN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "kunlun-jian")
  #                 return notify_fail("你没有激发昆仑剑法，难以施展" FANYIN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = MAG "$N" MAG "微微一笑，左手横握剑柄，右手五"
  #               "指对准" + weapon->name() + NOR + MAG "剑脊"
  #               "轻轻弹拨，剑身微颤，声若龙吟。\n顿时发出一"
  #               "阵清脆的琴音……\n" NOR;
  # 
  #         skill = me->query_skill("kunlun-jian", 1);
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("force");
  #         if (dp < 1) dp = 1;
  #         if (random(ap) > dp / 2)
  #         {
  #                 me->add("neili", -200);
  #                 jing_wound = (int)me->query_skill("sword") +
  #                              (int)me->query_skill("tanqin-jifa", 1);
  #                 jing_wound = jing_wound / 2 + random(jing_wound / 2);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK,
  #                        jing_wound, 60, MAG "$n" MAG "顿时只觉琴音犹"
  #                        "如两柄利剑一般刺进双耳，刹那间头晕目眩，全身"
  #                        "刺痛！\n" NOR);
  #                 me->start_busy(2 + random(2));
  #         } else
  #         {
  #                 me->add("neili", -50);
  #                 msg += CYN "可是$n" CYN "赶忙宁心静气，收敛心神，丝"
  #                        "毫不受$N" CYN "琴音的干扰。\n" NOR;
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
