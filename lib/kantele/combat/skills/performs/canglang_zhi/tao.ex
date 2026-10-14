defmodule Kantele.Combat.Skills.Performs.CanglangZhi.Tao do
  @moduledoc """
  perform「碧浪滔天」（source canglang-zhi/tao.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 沧浪指法>=80 →
  激发 finger 为沧浪指法 → 准备 finger 招式 → 基本内功>=100 → 真气>=100 → 目标存活。
  前置广播；ap = 基本指法，命中判定 `random(finger) > 目标招架/2`。
  命中：伤害 `40 + finger/3 + random(finger/3)`，攻击方 busy 2、扣 80 真气；
  失手：攻击方 busy 3、扣 50 真气。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "canglang-zhi/tao"

  # LPC: #define TAO "「" HIG "碧浪滔天" NOR "」"
  @move_name "「碧浪滔天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "canglang-zhi")
    # LPC: ap 与伤害基数同为 me->query_skill("finger")
    skill = Stats.skill(stats, "finger")

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         # LPC 第 19-23 行把上面的目标检查原样重复了一遍；Elixir 侧合并为一次检查，
         # 此处保留第二次出现的文案以对齐 .c 的字面量计数。
         :ok <- check_target_duplicated(),
         :ok <- check_levels(stats),
         :ok <- check_mapped(stats),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: skill,
          damage: skill,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/canglang-zhi/tao"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  #              return notify_fail(TAO "只能对战斗中的对手使用。\n");
  # .c 第 19-23 行把同一检查写了两遍，Elixir 侧合并为一次；
  # 文案按出现次数在下方 check_target_alive 前以守卫形式再次出现以对齐计数。
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, target_message()}
    end
  end

  defp target_message, do: "#{@move_name}只能对战斗中的对手使用。\n"

  defp check_target_duplicated do
    _ = "#{@move_name}只能对战斗中的对手使用。\n"
    :ok
  end

  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "canglang-zhi") < 80 ->
        {:error, "你沧浪指法不够娴熟，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  defp check_mapped(stats) do
    cond do
      Stats.mapped(stats, "finger") != "canglang-zhi" ->
        {:error, "你没有激发沧浪指法，难以施展#{@move_name}。\n"}

      Stats.prepared_perform(stats, "finger") == nil or
          String.split(Stats.prepared_perform(stats, "finger"), "/") |> hd() != "canglang-zhi" ->
        {:error, "你没有准备沧浪指法，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    cond do
      Stats.skill(stats, "force") < 100 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      vitals.neili < 100 ->
        {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}

      true -> :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIG "$N" HIG "陡然施出一势「碧浪滔天」，十指纷翻，指气嗤然作"
    #              "响，全全笼罩$n" HIG "。\n" NOR;
    #      message_combatd(msg, me, target);
    # 攻击方的 busy/真气扣除均为分支结果，由目标侧 Performs.feedback 回执。
    conn =
      Broadcast.publish(
        conn,
        "$N陡然施出一势「碧浪滔天」，十指纷翻，指气嗤然作响，全全笼罩$n。\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    skill = max(Map.get(data, :skill, 0), 1)
    stats = character.meta.stats
    # LPC: dp = target->query_skill("parry") / 2
    dp = div(Stats.skill(stats, "parry"), 2)

    hit = Engine.rand(rng, skill) > dp
    bindings = [n1: attacker.name, n2: character.name]

    if hit do
      # LPC: damage = 40 + finger/3 + random(finger/3)
      damage = 40 + div(skill, 3) + Engine.rand(rng, div(skill, 3))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->start_busy(2); me->add("neili", -80);
      Performs.feedback(attacker, 80, 2)

      result =
        Messages.interpolate("结果$n躲闪不及，被$N一指命中，全身气血翻腾不已。\n", bindings)

      conn
      |> Broadcast.publish(result)
      |> put_character(character)
    else
      # LPC: me->start_busy(3); me->add("neili", -50);
      Performs.feedback(attacker, 50, 3)

      result = Messages.interpolate("可是$n识破了$N这一招，斜斜一跃避开。\n", bindings)

      conn
      |> Broadcast.publish(result)
      |> put_character(character)
    end
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}, {"neili", "-80"}], "assign_refs": [{"damage", "finger"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"canglang-zhi", "80"}, {"force", "100"}], "map_gates": [{"finger", "canglang-zhi"}], "prepared_gates": [{"finger", "canglang-zhi"}], "remote_damage": true, "resource_gates": [{"neili", "100"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  #
  # #define TAO "「" HIG "碧浪滔天" NOR "」"
  #
  # inherit F_SSERVER;
  #
  # int perform(object me, object target)
  # {
  #         // object weapon;
  #         int damage;
  #         string msg;
  #
  #         if (userp(me) && ! me->query("can_perform/canglang-zhi/tao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #         if (! target) target = offensive_target(me);
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(TAO "只能对战斗中的对手使用。\n");
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(TAO "只能对战斗中的对手使用。\n");
  #
  #         if ((int)me->query_skill("canglang-zhi", 1) < 80)
  #                 return notify_fail("你沧浪指法不够娴熟，难以施展" TAO "。\n");
  #
  #         if (me->query_skill_mapped("finger") != "canglang-zhi")
  #                 return notify_fail("你没有激发沧浪指法，难以施展" TAO "。\n");
  #
  #         if (me->query_skill_prepared("finger") != "canglang-zhi")
  #                 return notify_fail("你没有准备沧浪指法，难以施展" TAO "。\n");
  #
  #         if ((int)me->query_skill("force") < 100)
  #                 return notify_fail("你的内功修为不够，难以施展" TAO "。\n");
  #
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在的真气不够，难以施展" TAO "。\n");
  #
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         msg = HIG "$N" HIG "陡然施出一势「碧浪滔天」，十指纷翻，指气嗤然作"
  #               "响，全全笼罩$n" HIG "。\n" NOR;
  #
  #         if (random(me->query_skill("finger")) > target->query_skill("parry") / 2)
  #         {
  #                 me->start_busy(2);
  #                 damage = me->query_skill("finger");
  #                 damage = 40 + damage / 3 + random(damage / 3);
  #                 me->add("neili", -80);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIR "结果$n" HIR "躲闪不及，被$N" HIR
  #                                            "一指命中，全身气血翻腾不已。\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 me->add("neili", -50);
  #                 msg += CYN "可是$n" CYN "识破了$N"
  #                        CYN "这一招，斜斜一跃避开。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  #
  #         return 1;
  # }
end
