defmodule Kantele.Combat.Skills.Performs.TaijiJian.Zhuan do
  @moduledoc """
  剑轮岚转「zhuan」（对照 `kungfu/skill/taiji-jian/zhuan.c`）

  太极剑法绝技：需持剑、太极剑法>=160、真气>=250、激发 sword 为太极剑法、
  目标存活。命中判定 `ap/2 + random(ap*2) > 目标parry`（ap = sword）：命中后
  `attack_time = 5 + random(ap/45)`、临时 `apply/attack += ap/10`；未命中则
  `attack_time = 5`。`attack_time` 上限 10，扣 `attack_time*20` 真气，
  连出 `attack_time` 击，忙乱 `1 + random(attack_time)`。

  差异（TODO(migrate)）：
  - LPC 的 `attack_time` 次 `COMBAT_D->do_attack`（完整管线）折算为逐击命中
    判定 + 伤害（同 `biyan_dao/luo.ex`、`miaojia_jian/qian.ex`）；
  - `living(target)` 门槛由目标侧 `combat/perform-incoming` 的 `dead` 分支兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "taiji-jian/zhuan"
  @move_name "「剑轮岚转」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_level(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target, weapon, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_level(stats) do
    if Stats.skill(stats, "taiji-jian") < 160 do
      {:error, "你的太极剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "taiji-jian" do
      :ok
    else
      {:error, "你没有激发太极剑法，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIW "$N" HIW "一声清啸，手中" + weapon->name()
    #           + HIW "龙吟不定，化出一个个圆圈，把$n" HIW "圈在当中。\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N一声清啸，手中" <> weapon_name <> "龙吟不定，化出一个个圆圈，把$n圈在当中。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        sword: Stats.skill(stats, "sword"),
        rng: &:rand.uniform/1
      }
    })

    conn
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target))
      #          return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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

    # LPC: ap = me->query_skill("sword"); dp = target->query_skill("parry");
    #      attack_time = 5;
    #      if (ap / 2 + random(ap * 2) > dp) {
    #          msg += HIY "结果$p" HIY "被$P" HIY
    #                   "攻了个措手不及，连连后退不暇！\n" NOR;
    #          count = ap / 10;
    #          me->add_temp("apply/attack", count);
    #          attack_time += random(ap / 45);
    #      } else {
    #          msg += HIC "$n" HIC "见$N" HIC "这几剑并无破绽"
    #                   "，不敢大意，小心应付。\n" NOR;
    #          count = 0;
    #      }
    hit? = div(ap, 2) + Engine.rand(rng, ap * 2) > dp
    attack_time = if hit?, do: 5 + Engine.rand(rng, max(div(ap, 45), 1)), else: 5
    count = if hit?, do: div(ap, 10), else: 0

    conn =
      if hit? do
        Broadcast.publish(
          conn,
          Messages.interpolate("结果$p被$P攻了个措手不及，连连后退不暇！\n", bindings)
        )
      else
        Broadcast.publish(
          conn,
          Messages.interpolate("$n见$N这几剑并无破绽，不敢大意，小心应付。\n", bindings)
        )
      end

    # LPC: if (attack_time > 10) attack_time = 10;
    attack_time = min(attack_time, 10)

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

    # LPC: me->add("neili", -attack_time * 20);
    #      me->add_temp("apply/attack", -count);
    #      me->start_busy(1 + random(attack_time));
    Performs.feedback(attacker, attack_time * 20, 1 + Engine.rand(rng, max(attack_time, 1)))

    put_character(conn, character)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "taiji-jian/zhuan",
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
  # #define ZHUAN "「" HIW "剑轮岚转" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int ap, dp;
  #         int count;
  #     int i, attack_time;
  # 
  #         if (userp(me) && ! me->query("can_perform/taiji-jian/zhuan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUAN "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" ZHUAN "。\n");
  # 
  #     if ((int)me->query_skill("taiji-jian", 1) < 160)
  #         return notify_fail("你的太极剑法不够娴熟，难以施展" ZHUAN "。\n");
  # 
  #     if (me->query("neili") < 250)
  #         return notify_fail("你的真气不够，难以施展" ZHUAN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "taiji-jian")
  #                 return notify_fail("你没有激发太极剑法，难以施展" ZHUAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "一声清啸，手中" + weapon->name() +
  #               HIW "龙吟不定，化出一个个圆圈，把$n" HIW "圈在当"
  #               "中。\n" NOR;
  # 
  #     ap = me->query_skill("sword");
  #     dp = target->query_skill("parry");
  #         attack_time = 5;
  #     if (ap / 2 + random(ap * 2) > dp)
  #     {
  #         msg += HIY "结果$p" HIY "被$P" HIY
  #                        "攻了个措手不及，连连后退不暇！\n" NOR;
  #                 count = ap / 10;
  #                 me->add_temp("apply/attack", count);
  #                 attack_time += random(ap / 45);
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "见$N" HIC "这几剑并无破绽"
  #                        "，不敢大意，小心应付。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #     message_combatd(msg, me, target);
  # 
  #         if (attack_time > 10)
  #                 attack_time = 10;
  # 
  #     me->add("neili", -attack_time * 20);
  # 
  #     for (i = 0; i < attack_time; i++)
  #     {
  #         if (! me->is_fighting(target))
  #             break;
  #         COMBAT_D->do_attack(me, target, weapon, 0);
  #     }
  # 
  #         me->add_temp("apply/attack", -count);
  #     me->start_busy(1 + random(attack_time));
  # 
  #     return 1;
  # }
end
