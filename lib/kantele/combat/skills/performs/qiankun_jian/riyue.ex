defmodule Kantele.Combat.Skills.Performs.QiankunJian.Riyue do
  @moduledoc """
  日月乾坤「riyue」（对照 `kungfu/skill/qiankun-jian/riyue.c`）

  乾坤剑法绝技：需持剑、内功>=220、乾坤神剑>=150、真气>=400、
  激发 sword 为乾坤神剑、目标存活。命中判定
  `ap/2 + random(ap*2) > 目标parry`（ap = 自身 sword）：命中后
  `attack_time = 4 + random(ap/45)`（上限 6）、临时 `apply/attack += ap/10`；
  未命中则 `attack_time = 4`。连出 `attack_time` 击后扣
  `attack_time*20` 真气，忙乱 `1 + random(attack_time)`。

  差异（TODO(migrate)）：
  - LPC 的 `attack_time` 次 `COMBAT_D->do_attack`（完整管线）折算为逐击命中
    判定 + 伤害（同 `biyan_dao/luo.ex`）；
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `message_combatd` 的命中/失手引子在目标侧结算。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "qiankun-jian/riyue"
  @move_name "「日月乾坤」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "qiankun-jian")
    sword = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_skill_level(level),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          sword: sword,
          rng: rng
        }
      })

      apply_perform(conn, character, target, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/qiankun-jian/riyue"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 220)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 220 do
      {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("qiankun-jian", 1) < 150)
  defp check_skill_level(level) do
    if level < 150 do
      {:error, "你的乾坤神剑修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 400)
  defp check_neili(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "qiankun-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "qiankun-jian" do
      :ok
    else
      {:error, "你没有激发乾坤神剑，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIY "只见$N" HIY "手中" + weapon->name() + HIY
    #           "一颤，将乾坤剑法连环施出，顿时幻出无数剑影，"
    #           "铺天盖地向$n" HIY "席卷而去！\n" NOR;
    conn
    |> Broadcast.publish(
      "只见$N手中" <>
        weapon_name <> "一颤，将乾坤剑法连环施出，顿时幻出无数剑影，铺天盖地向$n席卷而去！\n",
      n1: character.name,
      n2: target.name
    )
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :sword, 0), 1)
    dp = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap * 2) > dp) { count = ap / 10;
    #          me->add_temp("apply/attack", count); attack_time += random(ap / 45); }
    #      else { count = 0; }
    hit? = div(ap, 2) + Engine.rand(rng, ap * 2) > dp
    attack_time = if hit?, do: 4 + Engine.rand(rng, div(ap, 45)), else: 4
    count = if hit?, do: div(ap, 10), else: 0

    conn =
      if hit? do
        # LPC: msg += HIR "$n" HIR "只觉剑影重重，登时眼花缭" "乱，被攻了个措手不及，疲于奔命。\n" NOR;
        Broadcast.publish(
          conn,
          "$n只觉剑影重重，登时眼花缭乱，被攻了个措手不及，疲于奔命。\n",
          bindings
        )
      else
        # LPC: msg += HIC "$n" HIC "见$N" HIC "剑招汹涌，气" "势恢弘，急忙凝神聚气，小心应付。\n" NOR;
        Broadcast.publish(conn, "$n见$N剑招汹涌，气势恢弘，急忙凝神聚气，小心应付。\n", bindings)
      end

    attack_time = min(attack_time, 6)

    # LPC 连出 attack_time 击，每击 COMBAT_D->do_attack(me, target, weapon, 0)；
    # 期间 apply/attack += count（折算为每击 ap + count）。
    ap2 = ap + count

    damage =
      Enum.reduce(1..attack_time, 0, fn _i, acc ->
        if div(ap2, 2) + Engine.rand(rng, ap2) > dp do
          acc + div(ap2, 2) + Engine.rand(rng, max(div(ap2, 2), 1))
        else
          acc
        end
      end)

    vitals =
      if damage > 0 do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->add("neili", -attack_time * 20); me->start_busy(1 + random(attack_time));
    Performs.feedback(attacker, attack_time * 20, 1 + Engine.rand(rng, max(attack_time, 1)))

    put_character(conn, character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "qiankun-jian/riyue",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define RIYUE "「" HIY "日月乾坤" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int count;
  #         int i, attack_time;
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/qiankun-jian/riyue"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(RIYUE "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" RIYUE "。\n");
  # 
  #         if (me->query_skill("force") < 220)
  #                 return notify_fail("你的内功的修为不够，难以施展" RIYUE "。\n");
  # 
  #         if (me->query_skill("qiankun-jian", 1) < 150)
  #                 return notify_fail("你的乾坤神剑修为不够，难以施展" RIYUE "。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，难以施展" RIYUE "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "qiankun-jian")
  #                 return notify_fail("你没有激发乾坤神剑，难以施展" RIYUE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "只见$N" HIY "手中" + weapon->name() + HIY
  #               "一颤，将乾坤剑法连环施出，顿时幻出无数剑影，"
  #               "铺天盖地向$n" HIY "席卷而去！\n" NOR;
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  #         attack_time = 4;
  # 
  #         if (ap / 2 + random(ap * 2) > dp)
  #         {
  #                 msg += HIR "$n" HIR "只觉剑影重重，登时眼花缭"
  #                        "乱，被攻了个措手不及，疲于奔命。\n" NOR;
  #                 count = ap / 10;
  #                 me->add_temp("apply/attack", count);
  #                 attack_time += random(ap / 45);
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "见$N" HIC "剑招汹涌，气"
  #                        "势恢弘，急忙凝神聚气，小心应付。\n"
  #                        NOR;
  #                 count = 0;
  #         }
  #                 
  #         message_combatd(msg, me, target);
  # 
  #         if (attack_time > 6)
  #                 attack_time = 6;
  # 
  #         me->add("neili", -attack_time * 20);
  # 
  #         for (i = 0; i < attack_time; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->start_busy(1 + random(attack_time));
  #         return 1;
  # }
end
