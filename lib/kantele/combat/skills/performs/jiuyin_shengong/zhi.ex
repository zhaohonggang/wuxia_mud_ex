defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Zhi do
  @moduledoc """
  perform「九阴神指」（source jiuyin-shengong/perform/zhi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  九阴神功>=250 → 内力>=250 → 准备 finger 或 unarmed 为九阴神功 → 目标存活。
  ap = max(拳脚, 指法) + 武学常识；dp = 招架 + 武学常识（目标侧）。
  起手扣 100 内力。命中后二次判定：
  - 二次命中：连出 4+random(4) 指（每击 do_attack 折算伤害、随机打断目标），
    之后按目标武器与修为判定「兵器脱手」（解除目标武器）或「勉力抵挡」。
  - 二次未命中：目标忙乱 4+random(九阴神功/30)。
  - 首击未中：自身忙乱 3+random(2)。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.Vitals

  @perform_id "jiuyin-shengong/zhi"
  @move_name "「九阴神指」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = max(Stats.skill(stats, "unarmed"), Stats.skill(stats, "finger")) + Stats.skill(stats, "martial-cognize")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_prepared(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon")) return notify_fail(ZHI "只能空手施展！\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "#{@move_name}只能空手施展！\n"}
    else
      :ok
    end
  end

  # LPC: if (skill < 250)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyin-shengong") < 250 do
      {:error, "你的九阴神功等级不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 250 do
      {:error, "你现在真气不够，难以施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("finger") != "jiuyin-shengong"
  #          && me->query_skill_prepared("unarmed") != "jiuyin-shengong")
  # prepared_perform 返回绝招 ID（如 jiuyin-shengong/zhi），须取技能前缀比对
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared_finger = Stats.prepared_perform(stats, "finger")
    prepared_unarmed = Stats.prepared_perform(stats, "unarmed")
    ok_finger = prepared_finger != nil and hd(String.split(prepared_finger, "/")) == "jiuyin-shengong"
    ok_unarmed = prepared_unarmed != nil and hd(String.split(prepared_unarmed, "/")) == "jiuyin-shengong"

    if not ok_finger and not ok_unarmed do
      {:error, "你没有准备使用九阴神功，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: me->add("neili", -100); 起手文案（`HIY +` 颜色续行把文案拆成两段字面量）
  defp apply_effect(conn, character, target) do
    lead =
      ["$N出手成指，随意点戳，似乎看尽了$n", "招式中的破绽。\n"]
      |> Enum.join("")

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(Messages.interpolate(lead, [n1: character.name, n2: target.name]))
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
    ap = max(Map.get(data, :ap, 0), 1)
    skill = max(Map.get(data, :skill, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry") + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "martial-cognize")

    # LPC: if (ap / 2 + random(ap * 2) > dp)
    if div(ap, 2) + Engine.rand(rng, ap * 2) > dp do
      # LPC: n = 4 + random(4);
      n = 4 + Engine.rand(rng, 4)

      # LPC: if (ap * 11 / 20 + random(ap) > dp)
      if div(ap * 11, 20) + Engine.rand(rng, ap) > dp do
        flurry(conn, character, attacker, bindings, ap, dp, n, rng)
      else
        # LPC: msg += "$n不及多想，连忙抵挡，全然无法反击。\n";
        #          if (!target->is_busy()) target->start_busy(4 + random(skill / 30));
        combat = character.meta.combat
        combat = if not Combat.busy?(combat), do: Combat.start_busy(combat, 4 + Engine.rand(rng, div(skill, 30))), else: combat
        character = %{character | meta: %{character.meta | combat: combat}}

        conn
        |> Broadcast.publish(
          Messages.interpolate("$n不及多想，连忙抵挡，全然无法反击。\n", bindings)
        )
        |> put_character(character)
      end
    else
      # LPC: msg += "不过$n紧守门户，不露半点破绽。\n"; me->start_busy(3 + random(2));
      Performs.feedback(attacker, 0, 3 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish(
        Messages.interpolate("不过$n紧守门户，不露半点破绽。\n", bindings)
      )
      |> put_character(character)
    end
  end

  # LPC: 二次命中后的连指出击 + 缴械判定
  defp flurry(conn, character, attacker, bindings, ap, dp, n, rng) do
    # LPC: msg += "…随手连出" + chinese_number(n) + "指！\n"（`+ chinese_number(n) +` 拆成两段）
    flurry_msg =
      "$n见来指玄幻无比，全然无法抵挡，慌乱之下破绽迭出，$N随手连出" <>
        chinese_number(n) <> "指！\n"

    conn = Broadcast.publish(conn, Messages.interpolate(flurry_msg, bindings))

    # LPC: while (n-- && me->is_fighting(target)) { if (random(2) && !target->is_busy())
    #          target->start_busy(1); COMBAT_D->do_attack(me, target, 0, 0); }
    # 折算：每击命中判定 + 伤害；循环结束后 n 自减为 0，故 me->start_busy(1 + random(n)) = 1。
    stats = character.meta.stats
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(ap, 15), 1)

    {damage, combat} =
      Enum.reduce(1..n, {0, character.meta.combat}, fn _, {dmg_acc, combat} ->
        combat =
          if Engine.rand(rng, 2) == 1 and not Combat.busy?(combat) do
            Combat.start_busy(combat, 1)
          else
            combat
          end

        if div(ap, 2) + Engine.rand(rng, ap) > dodge do
          {dmg_acc + per_hit + Engine.rand(rng, per_hit), combat}
        else
          {dmg_acc, combat}
        end
      end)

    Performs.feedback(attacker, 0, 1)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: weapon = target->query_temp("weapon");
    #      if (weapon && random(ap) / 2 > dp && weapon->query("type") != "pin")
    #          { msg = "…手中的" + weapon->name() + "…脱手而出！\n"; weapon->move(...); }
    #      else msg = "$n勉力抵挡，一时间再也无力反击。\n";
    weapon = Combat.weapon(combat)

    if weapon != nil and div(Engine.rand(rng, ap), 2) > dp and Map.get(weapon, :skill_type) != "pin" do
      weapon_name = Map.get(weapon, :name)
      combat = Combat.unequip(combat, :weapon)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish(
        "$n觉得眼前眼花缭乱，手中的" <> weapon_name <> "一时竟然拿捏不住，脱手而出！\n",
        bindings
      )
      |> put_character(character)
    else
      conn
      |> Broadcast.publish(
        Messages.interpolate("$n勉力抵挡，一时间再也无力反击。\n", bindings)
      )
      |> put_character(character)
    end
  end

  # LPC: chinese_number(n)，n = 4 + random(4) ∈ 4..7
  defp chinese_number(4), do: "四"
  defp chinese_number(5), do: "五"
  defp chinese_number(6), do: "六"
  defp chinese_number(7), do: "七"
  defp chinese_number(_), do: "数"
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // zhi.c 九阴神指
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define ZHI "「" HIY "九阴神指" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #     object weapon;
  #     int n;
  #     int skill, ap, dp;
  # 
  #     if (userp(me) && !me->query("can_perform/jiuyin-shengong/zhi"))
  #         return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (!target)
  #     {
  #         me->clean_up_enemy();
  #         target = me->select_opponent();
  #     }
  # 
  #     skill = me->query_skill("jiuyin-shengong", 1);
  # 
  #     if (!me->is_fighting(target))
  #         return notify_fail(ZHI "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query_temp("weapon"))
  #         return notify_fail(ZHI "只能空手施展！\n");
  # 
  #     if (skill < 250)
  #         return notify_fail("你的九阴神功等级不够，无法施展" ZHI "！\n");
  # 
  #     if (me->query("neili") < 250)
  #         return notify_fail("你现在真气不够，难以施展" ZHI "！\n");
  # 
  #     if (me->query_skill_prepared("finger") != "jiuyin-shengong" && me->query_skill_prepared("unarmed") != "jiuyin-shengong")
  #         return notify_fail("你没有准备使用九阴神功，无法施展" ZHI "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     me->add("neili", -100);
  # 
  #     ap = me->query_skill("unarmed");
  #     if (ap < me->query_skill("finger"))
  #         ap = me->query_skill("finger");
  #     ap += me->query_skill("martial-cognize", 1);
  #     dp = target->query_skill("parry") + target->query_skill("martial-cognize", 1);
  # 
  #     msg = HIY "$N" HIY "出手成指，随意点戳，似乎看尽了$n" HIY + "招式中的破绽。\n" NOR;
  #     if (ap / 2 + random(ap * 2) > dp)
  #     {
  #         n = 4 + random(4);
  #         if (ap * 11 / 20 + random(ap) > dp)
  #         {
  #             msg += HIY "$n" HIY "见来指玄幻无比，全然无法抵挡，慌乱之下破绽迭出，$N" HIY "随手连出" + chinese_number(n) + "指！\n" NOR;
  #             message_combatd(msg, me, target);
  #             while (n-- && me->is_fighting(target))
  #             {
  #                 if (random(2) && !target->is_busy())
  #                     target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #             }
  #             me->start_busy(1 + random(n));
  # 
  #             weapon = target->query_temp("weapon");
  #             if (weapon && random(ap) / 2 > dp && weapon->query("type") != "pin")
  #             {
  #                 msg = HIW "$n" HIW "觉得眼前眼花缭乱，手中的" + weapon->name() +
  #                       HIW "一时竟然拿捏不住，脱手而出！\n" NOR;
  #                 weapon->move(environment(me));
  #             }
  #             else
  #             {
  #                 msg = HIY "$n勉力抵挡，一时间再也无力反击。\n" NOR;
  #             }
  # 
  #             if (!me->is_fighting(target))
  #                 // Don't show the message
  #                 return 1;
  #         }
  #         else
  #         {
  #             msg += HIY "$n" HIY "不及多想，连忙抵挡，全然无法反击。\n" NOR;
  #             if (!target->is_busy())
  #                 target->start_busy(4 + random(skill / 30));
  #         }
  #     }
  #     else
  #     {
  #         msg += HIC "不过$n" HIC "紧守门户，不露半点破绽。\n" NOR;
  #         me->start_busy(3 + random(2));
  #     }
  # 
  #     message_combatd(msg, me, target);
  #     return 1;
  # }
end
