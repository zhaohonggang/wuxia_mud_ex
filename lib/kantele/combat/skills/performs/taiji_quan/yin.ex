defmodule Kantele.Combat.Skills.Performs.TaijiQuan.Yin do
  @moduledoc """
  perform「引字诀」（source taiji-quan/yin.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "taiji-quan/yin"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "taiji-quan")
    skill = Stats.skill(stats, "taiji-quan")
    ap = Stats.skill(stats, "unarmed")
    damage = (div(ap, 8) + Engine.rand(rng, div(ap, 8)))

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
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "taiji-quan") < 150 -> {:error, "你的太极拳等级不够，难以施展。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "taiji-quan" ->
        {:error, "你没有激发太极拳，难以施展。\n"}

      Stats.prepared_perform(stats, "unarmed") == nil or String.split(Stats.prepared_perform(stats, "unarmed"), "/") |> hd() != "taiji-quan" ->
        {:error, "你现在没有准备使用太极拳，无法使用。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "你的真气不够，难以施展。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "只能空手施展。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 10}
    vitals = %{vitals | neili: vitals.neili - 30}
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 1)
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}
    conn = Broadcast.publish(conn, "$N双手一圈，施出「引」字诀，如抱太极，一股雄浑无比的力道组成了一个旋涡，圈向$n。", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「引字诀」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
      character.meta.combat.busy > 0 ->
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧。", n1: attacker.name, n2: character.name)
      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.damage(vitals, :qi, damage)
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 50, 3)
    msg = if hit, do: "$n微微一楞，登时被这力道带得在原地急转七八下，如转陀螺，如旋纺锤。", else: "$n见状连忙使出“千斤坠”之力定住身形，摆脱了$N的力道。"
    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-10"}, {"neili", "-30"}, {"neili", "-50"}], "assign_refs": [{"ap", "unarmed"}, {"dp", "parry"}, {"skill", "taiji-quan"}], "busy_lines": ["if (target->is_busy())", "me->start_busy(1);", "if (ap / 2 + random(ap) > dp && ! target->is_busy())", "target->start_busy(ap / 30 + 2);", "me->start_busy(3);"], "map_gates": [{"unarmed", "taiji-quan"}], "prepared_gates": [{"unarmed", "taiji-quan"}], "remote_damage": true, "resource_gates": [{"neili", "200"}], "var_gates": [{"skill", "150"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YIN "「" HIW "引字诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int skill, ap, dp, damage;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/taiji-quan/yin"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YIN "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(YIN "只能空手施展。\n");
  # 
  #         skill = me->query_skill("taiji-quan", 1);
  # 
  #         if (skill < 150)
  #                 return notify_fail("你的太极拳等级不够，难以施展" YIN "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，难以施展" YIN "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "taiji-quan")
  #                 return notify_fail("你没有激发太极拳，难以施展" YIN "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "taiji-quan")
  #                 return notify_fail("你现在没有准备使用太极拳，无法使用" YIN "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "双手一圈，施出「引」字诀，如抱太极，一股"
  #               "雄浑无比的力道组成了一个旋涡，圈向$n" HIW "。\n" NOR;
  #     me->add("neili", -50);
  # 
  #         ap = me->query_skill("unarmed");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap * 4 / 3) > dp)
  #         {
  #                 me->add("neili", -30);
  #                 damage = ap / 8 + random(ap / 8);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 0,
  #                                            HIR "$n" HIR "微微一楞，登时被这力道带"
  #                                            "得在原地急转七八下，如转陀螺，如旋纺"
  #                                            "锤。\n" NOR);
  #                 me->start_busy(1);
  #                 if (ap / 2 + random(ap) > dp && ! target->is_busy())
  #                         target->start_busy(ap / 30 + 2);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见状连忙使出“千斤坠”之力定"
  #                        "住身形，摆脱了$N" CYN "的力道。\n" NOR;
  #                 me->add("neili", -10);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
