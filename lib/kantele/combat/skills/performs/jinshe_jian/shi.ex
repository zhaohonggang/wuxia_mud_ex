defmodule Kantele.Combat.Skills.Performs.JinsheJian.Shi do
  @moduledoc """
  perform「金蛇噬天」（source jinshe-jian/shi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 手持 sword →
  金蛇剑法>=200 → 激发 sword 为金蛇剑法 → 基本内功>=240 → 基本轻功>=240 →
  内力上限>=4500 → 真气>=400 → 目标存活。
  起手广播（含武器名）后：
  `ap = 金蛇剑法 + 基本武学修养`，`dp = 目标轻功 + 目标武学修养`；
  命中判定 `ap*2/3 + random(ap) > random(dp)`。
  命中后 `damage = 金蛇剑法 + 基本内功 + 武学修养`，`damage += random(damage/2)`；
  其中「十分之一几率可被招架」子支（`random(10)<=1 且 ap/2<dp`）伤害折为 `damage/3`、
  播报「奋力招架…喷出一口鲜血」（qi 伤 + 50% 外伤）、攻击方扣 200 真气 / 忙乱 `3+random(2)`；
  否则播报「剑气透体而过」（qi 伤 + 85% 外伤）、攻击方扣 300 真气 / 忙乱 `2+random(3)`。
  未命中播报「以快对快…躲过」、攻击方扣 150 真气 / 忙乱 2。

  差异（TODO(migrate)）：
  - 命中判定与伤害均需目标 `dodge`/`martial-cognize`，故全部在目标侧结算；
  - 攻击方消耗/忙乱分属三个分支，经 `Performs.feedback/3` 由目标侧回传；
  - `.c` 起手式把武器名插在中文串中间，按约定写成 `"A" <> weapon_name <> "B"` 两段；
  - `.c` 两处 `do_damage(..., damage, N, ...)` 的第 5 参为外伤百分比（50 / 85）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "jinshe-jian/shi"
  @move_name "「金蛇噬天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinshe-jian")
    # LPC: ap = jinshe-jian + martial-cognize
    ap = Stats.skill(stats, "jinshe-jian") + Stats.skill(stats, "martial-cognize")
    # LPC: damage = jinshe-jian + force + martial-cognize
    damage_base =
      Stats.skill(stats, "jinshe-jian") + Stats.skill(stats, "force") +
        Stats.skill(stats, "martial-cognize")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
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
          damage_base: damage_base,
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

  # LPC: if (userp(me) && ! me->query("can_perform/jinshe-jian/shi"))
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (jinshe-jian < 200) / if (force < 240) / if (dodge < 240)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "jinshe-jian") < 200 ->
        {:error, "你金蛇剑法不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 240 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "dodge") < 240 ->
        {:error, "你的轻功火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "jinshe-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") == "jinshe-jian" do
      :ok
    else
      {:error, "你没有激发金蛇剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (max_neili < 4500) / if (neili < 400)
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 4500 -> {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}
      vitals.neili < 400 -> {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIY "一道金光划过，$N" HIY "消失得无影无踪，猛然间只见一条"
    #            "金蛇从天而下，" + weapon->name() + HIY "已将$n" HIY "笼罩。\n" NOR;
    #      message_sort(msg, me, target);
    #      命中/失手与攻击方消耗/忙乱在目标侧结算（需目标 dodge/martial-cognize）。
    weapon = Combat.weapon(character.meta.combat) || %{}
    weapon_name = Map.get(weapon, :name, "")

    msg =
      ["一道金光划过，$N消失得无影无踪，猛然间只见一条金蛇从天而下，", weapon_name, "已将$n笼罩。\n"]
      |> Enum.join("")

    conn
    |> Broadcast.publish(msg, n1: character.name, n2: target.name)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 living(target) 门槛由目标侧 death 检查兜底
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    damage_base = max(Map.get(data, :damage_base, 0), 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target dodge + target martial-cognize
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "martial-cognize")

    # LPC: if (ap * 2 / 3 + random(ap) > random(dp))
    if div(ap * 2, 3) + Engine.rand(rng, ap) > Engine.rand(rng, dp) do
      # LPC: damage += random(damage / 2);
      damage = damage_base + Engine.rand(rng, div(damage_base, 2))

      # LPC: if (random(10) <= 1 && ap / 2 < dp)
      if Engine.rand(rng, 10) <= 1 and div(ap, 2) < dp do
        # LPC: damage = damage / 3;
        #      do_damage(me, target, WEAPON_ATTACK, damage, 50, HIG "…喷出一口鲜血。\n" NOR);
        #      me->add("neili", -200); me->start_busy(3 + random(2));
        dmg = div(damage, 3)

        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, dmg)
          |> Vitals.wound(:qi, div(dmg * 50, 100))

        character = %{character | meta: %{character.meta | vitals: vitals}}

        Performs.feedback(attacker, 200, 3 + Engine.rand(rng, 2))

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$n见$N一道金光闪过，急忙收敛心神奋力招架。哪知$P这招力道非凡，$p一声闷哼，连退几步，喷出一口鲜血。\n",
            bindings
          )
        )
        |> put_character(character)
      else
        # LPC: do_damage(me, target, WEAPON_ATTACK, damage, 85, HIR "…剑气透体而过。\n" NOR);
        #      me->add("neili", -300); me->start_busy(2 + random(3));
        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * 85, 100))

        character = %{character | meta: %{character.meta | vitals: vitals}}

        Performs.feedback(attacker, 300, 2 + Engine.rand(rng, 3))

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$n见$N金光划过，心底不由大惊，登时听得“噗嗤”一声，剑气透体而过。\n",
            bindings
          )
        )
        |> put_character(character)
      end
    else
      # LPC: msg = CYN "\n然而$n" CYN "以快对快，飞身一跳" "已然躲过$N" CYN "这一招。\n" NOR;
      #      me->add("neili", -150); me->start_busy(2);
      Performs.feedback(attacker, 150, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("\n然而$n以快对快，飞身一跳已然躲过$N这一招。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SHEN "「" HIY "金蛇噬天" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg, wn;
  #         object weapon;
  #         int ap, dp;
  #         me = this_player();
  # 
  #         if (userp(me) && ! me->query("can_perform/jinshe-jian/shi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHEN "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" SHEN "。\n");
  # 
  #         if ((int)me->query_skill("jinshe-jian", 1) < 200)
  #                 return notify_fail("你金蛇剑法不够娴熟，难以施展" SHEN "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "jinshe-jian")
  #                 return notify_fail("你没有激发金蛇剑法，难以施展" SHEN "。\n");
  # 
  #         if ((int)me->query_skill("force", 1) < 240)
  #                 return notify_fail("你的内功火候不够，难以施展" SHEN "。\n");
  # 
  #         if ((int)me->query_skill("dodge", 1) < 240)
  #                 return notify_fail("你的轻功火候不够，难以施展" SHEN "。\n");  
  # 
  #         if ((int)me->query("max_neili") < 4500)
  #                 return notify_fail("你的内力修为不足，难以施展" SHEN "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你现在的真气不够，难以施展" SHEN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIY "一道金光划过，$N" HIY "消失得无影无踪，猛然间只见一条"
  #               "金蛇从天而下，" + weapon->name() + HIY "已将$n" HIY "笼罩。\n" NOR;
  # 
  #         message_sort(msg, me, target);
  #         
  #         ap = me->query_skill("jinshe-jian", 1) +
  #              me->query_skill("martial-cognize", 1);
  # 
  #         dp = target->query_skill("dodge", 1) +
  #              target->query_skill("martial-cognize", 1);
  # 
  #         if (ap * 2 / 3 + random(ap) > random(dp))
  #         {
  #                 damage = me->query_skill("jinshe-jian", 1) +
  #                          me->query_skill("force", 1) +
  #                          me->query_skill("martial-cognize", 1);
  # 
  #                 damage += random(damage / 2);
  # 
  #                 // 十分之一的几率可被招架
  #                 if (random(10) <= 1 && ap / 2 < dp)
  #                 {
  #                         damage = damage / 3;
  # 
  #                         msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                                   HIG "$n" HIG "见$N" HIG "一道金光闪过"
  #                                                   "，急忙收敛心神奋力招架。哪知$P这"
  #                                                   "招力道非凡，$p一声闷哼，连退几步，喷"
  #                                                   "出一口鲜血。\n" NOR);
  #                         me->add("neili", -200);
  #                         me->start_busy(3 + random(2));
  #                 } else 
  #                 {
  #                         msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85,
  #                                                   HIR "$n" HIR "见$N" HIR "金光划过，心"
  #                                                   "底不由大惊，登时听得“噗嗤”一声，剑"
  #                                                   "气透体而过。\n" NOR);
  #                         me->add("neili", -300);
  #                         me->start_busy(2 + random(3));
  #                 }
  #         } else
  #         {
  #                 msg = CYN "\n然而$n" CYN "以快对快，飞身一跳"
  #                       "已然躲过$N" CYN "这一招。\n" NOR;
  #                 me->add("neili", -150);
  #                 me->start_busy(2);
  #         }
  #         message_sort(msg, me, target);
  #         return 1;
  # }
end
