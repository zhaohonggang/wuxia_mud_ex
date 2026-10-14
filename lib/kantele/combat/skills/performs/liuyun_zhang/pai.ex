defmodule Kantele.Combat.Skills.Performs.LiuyunZhang.Pai do
  @moduledoc """
  perform「排山倒海」（source liuyun-zhang/pai.c，inherit F_SSERVER）

  手工补齐：门槛文案按字符串宏 `PAI`（→「排山倒海」）展开；命中判定、伤害与
  分档内力/忙乱（命中 neili-200/busy3，失手 neili-100/busy4）按原始 LPC 语义建模。
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
  alias Kantele.Combat.Performs

  @perform_id "liuyun-zhang/pai"

  # LPC: #define PAI "「" HIM "排山倒海" NOR "」"
  @move_name "「排山倒海」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_resources(character),
         :ok <- check_mapped(stats) do
      # LPC: ap = me->query_skill("strike");
      #      damage = me->query_skill("liuyun-zhang", 1); damage += random(damage);
      ap = Stats.skill(stats, "strike")
      level = Stats.skill(stats, "liuyun-zhang")

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          level: level,
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("liuyun-zhang", 1) < 140)
  #      if (me->query_skill("force") < 180)
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "liuyun-zhang") < 140 ->
        {:error, "你流云掌不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "liuyun-zhang")
  #      if (me->query_skill_prepared("strike") != "liuyun-zhang")
  defp check_mapped(stats) do
    cond do
      Stats.mapped(stats, "strike") != "liuyun-zhang" ->
        {:error, "你没有激发流云掌，难以施展#{@move_name}。\n"}

      prepared_is_not?(stats, "strike", "liuyun-zhang") ->
        {:error, "你没有准备流云掌，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC query_skill_prepared 返回绝招 ID（如 "liuyun-zhang/pai"），需按技能前缀比对。
  defp prepared_is_not?(stats, skill, mapped) do
    case Stats.prepared_perform(stats, skill) do
      nil -> true
      prepared -> hd(String.split(prepared, "/")) != mapped
    end
  end

  # 本式无「无条件」消耗：neili/busy 均分档（见 resolve_incoming 的 feedback）。
  defp apply_effect(conn, character, target) do
    # LPC: msg = HIC "\n$N" HIC "运转真气，将内力注于掌风之中，双掌猛"
    #               "然拍向$n" HIC "，雄浑有力，气势磅礴，毫无滞带，正是"
    #               "衡山派绝学「" HIM "排山倒海" HIC "」。" NOR;（合并为单段）
    conn =
      Broadcast.publish(
        conn,
        "\n$N运转真气，将内力注于掌风之中，双掌猛然拍向$n，雄浑有力，气势磅礴，毫无滞带，正是衡山派绝学「排山倒海」。",
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
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    level = max(Map.get(data, :level, 0), 0)
    stats = character.meta.stats
    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = me->query_skill("liuyun-zhang", 1); damage += random(damage);
      damage = level + Engine.rand(rng, level)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 60, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->start_busy(3); me->add("neili", -200);（仅命中分支）
      _ = Performs.feedback(attacker, 200, 3)

      # LPC: HIR "但见$N" HIR "双掌拍来，掌风作响，" "当真迅捷无比。$n" HIR "顿觉心惊胆战，"
      #      "毫无招架之力，微作迟疑间$N" HIR "这掌" "已正中$n" HIR "胸口，顿将$p震退数步。"
      #      " \n" NOR;（合并为单段，尾随一个空格）
      conn
      |> Broadcast.publish(
        "但见$N双掌拍来，掌风作响，当真迅捷无比。$n顿觉心惊胆战，毫无招架之力，微作迟疑间$N这掌已正中$n胸口，顿将$p震退数步。 \n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(4); me->add("neili", -100);（仅失手分支）
      _ = Performs.feedback(attacker, 100, 4)

      # LPC: CYN "$n" CYN "见$N" CYN "这掌拍来，内力" "充盈，只得向后一纵，才躲过这一掌。\n" NOR;
      # （合并为单段）
      conn
      |> Broadcast.publish("$n见$N这掌拍来，内力充盈，只得向后一纵，才躲过这一掌。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define PAI "「" HIM "排山倒海" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/liuyun-zhang/pai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(PAI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(PAI "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("liuyun-zhang", 1) < 140)
  #                 return notify_fail("你流云掌不够娴熟，难以施展" PAI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "liuyun-zhang")
  #                 return notify_fail("你没有激发流云掌，难以施展" PAI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "liuyun-zhang")
  #                 return notify_fail("你没有准备流云掌，难以施展" PAI "。\n");
  # 
  #         if (me->query_skill("force") < 180)
  #                 return notify_fail("你的内功修为不够，难以施展" PAI "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不够，难以施展" PAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("strike");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "\n$N" HIC "运转真气，将内力注于掌风之中，双掌猛"
  #               "然拍向$n" HIC "，雄浑有力，气势磅礴，毫无滞带，正是"
  #               "衡山派绝学「" HIM "排山倒海" HIC "」。" NOR;
  # 
  #         message_sort(msg, me, target); 
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = (int)me->query_skill("liuyun-zhang", 1);
  #                 damage += random(damage);
  # 
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 60,
  #                                            HIR "但见$N" HIR "双掌拍来，掌风作响，"
  #                                            "当真迅捷无比。$n" HIR "顿觉心惊胆战，"
  #                                            "毫无招架之力，微作迟疑间$N" HIR "这掌"
  #                                            "已正中$n" HIR "胸口，顿将$p震退数步。"
  #                                            " \n" NOR);
  # 
  #                 me->start_busy(3);
  #                 me->add("neili", -200);
  #         } else
  #         {
  #                 msg = CYN "$n" CYN "见$N" CYN "这掌拍来，内力"
  #                       "充盈，只得向后一纵，才躲过这一掌。\n" NOR;
  # 
  #                 me->start_busy(4);
  #                 me->add("neili", -100);
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
