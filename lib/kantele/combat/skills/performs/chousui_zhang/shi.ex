defmodule Kantele.Combat.Skills.Performs.ChousuiZhang.Shi do
  @moduledoc """
  perform「腐尸毒」（source chousui-zhang/shi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 未持兵器 → 抽髓掌>=140 →
  毒技>=200 → 暗器手法>=180 → 激发 strike 为抽髓掌 → 准备抽髓掌 →
  内力上限>=1200 → 真气>=500 → 附近有可用尸体（抽髓掌<200 时） → 目标存活。
  命中判定 `(strike+poison)/2 + random(strike+poison)` vs 目标
  `dodge+martial-cognize`（玩家）/`dodge+parry`（NPC）：命中则伤害
  `ap + random(ap/2)`，按 75% 计 qi 伤并追加 `final` 回调（qi 伤、jing 伤
  damage/4、jing 创 damage/8、附加 corpse_poison），攻击方扣 300 真气并忙乱 3；
  未命中扣 200 真气并忙乱 4。

  差异（TODO(migrate)）：
  - `.c` 的 `filter_array(all_inventory(environment(me)), …)` 尸体选取在本引擎
    未建模（无 CORPSE_OB / defeated_by，尸体仅由 feature_damage 留钩子），
    尸体门槛恒判「附近有尸体」、尸体名恒取 `"路边的行人"`，且不消耗尸体；
  - `do_damage(..., 75, (: final, me, target, damage :))` 的回调折算为命中分支内
    的 `Vitals.damage(:jing, …)` / `Vitals.wound(:jing, …)` 与
    `ConditionEvent.apply_poison/2`（`.c` 未给毒名，此处补 `"name"` 供显示）；
  - `me->query_temp("secondary_weapon")` 副兵器检查未实现；
  - `living(target)` 门槛由目标侧 `combat/perform-incoming` 兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.ConditionEvent
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "chousui-zhang/shi"
  @move_name "「腐尸毒」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "chousui-zhang")
    lvp = Stats.skill(stats, "poison")
    # LPC: ap = me->query_skill("strike") + me->query_skill("poison", 1);
    ap = Stats.skill(stats, "strike") + lvp

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
         :ok <- check_corpse(character, lvl),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          poison: lvp,
          ap: ap,
          userp: true,
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

  # LPC: if (userp(me) && (me->query_temp("weapon") || me->query_temp("secondary_weapon")))
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "chousui-zhang") < 140 ->
        {:error, "你的抽髓掌不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "poison") < 200 ->
        {:error, "你对毒技的了解不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "throwing") < 180 ->
        {:error, "你暗器手法火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "chousui-zhang")
  defp check_mapped(character) do
    stats = character.meta.stats

    if Stats.mapped(stats, "strike") == "chousui-zhang" do
      :ok
    else
      {:error, "你没有激发抽髓掌，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "chousui-zhang")
  defp check_prepared(character) do
    stats = character.meta.stats

    case Stats.prepared_perform(stats, "strike") do
      nil ->
        {:error, "你没有准备抽髓掌，难以施展#{@move_name}。\n"}

      value ->
        if String.split(value, "/") |> hd() == "chousui-zhang" do
          :ok
        else
          {:error, "你没有准备抽髓掌，难以施展#{@move_name}。\n"}
        end
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 1200 ->
        {:error, "你的内力修为不足，难以施展#{@move_name}。\n"}

      vitals.neili < 500 ->
        {:error, "你现在的内息不足，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: corpse = filter_array(all_inventory(environment(me)),
  #          (: base_name($1) == CORPSE_OB && ($1->query("defeated_by") == this_player()
  #           || ! $1->query("defeated_by")) :));
  #      if (userp(me) && sizeof(corpse) < 1 && lvl < 200)
  #              return notify_fail("你附近没有合适的尸体，难以施展" SHI "。\n");
  # 本引擎未建模房间尸体（CORPSE_OB / defeated_by 均无），恒判「附近有尸体」。
  defp check_corpse(character, _lvl) do
    if corpse_available?(character) do
      :ok
    else
      {:error, "你附近没有合适的尸体，难以施展#{@move_name}。\n"}
    end
  end

  defp corpse_available?(_character), do: true

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
    # LPC: if (sizeof(corpse) >= 1) name = corpse[0]->name(); else name = "路边的行人";
    #      msg = WHT "$N" WHT "随手抓起" + name + WHT "，将「" HIR "腐尸毒" NOR + WHT
    #            "」毒质运于其上，朝$n" WHT "猛掷而去。\n" NOR;
    #      message_combatd(msg, me, target);
    # `.c` 用 `+` 把文案拆成三段（C 侧不合并），此处按原样拆为列表，运行时再拼接。
    # 命中/伤害/busy 在目标侧结算（dp 需目标技能）。
    name = "路边的行人"

    msg =
      ["$N随手抓起", name, "，将「腐尸毒", "」毒质运于其上，朝$n猛掷而去。\n"]
      |> Enum.join("")

    conn = Broadcast.publish(conn, msg, n1: character.name, n2: target.name)

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
    ap = max(Map.get(data, :ap, 0), 1)
    lvp = Map.get(data, :poison, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (userp(me)) dp = target->query_skill("dodge") + target->query_skill("martial-cognize",1);
    #      else          dp = target->query_skill("dodge") + target->query_skill("parry",1);
    dp =
      if Map.get(data, :userp, true) do
        Stats.skill(stats, "dodge") + Stats.skill(stats, "martial-cognize")
      else
        Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
      end

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap / 2);
      damage = ap + Engine.rand(rng, div(ap, 2))

      # LPC: COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 75, (: final, me, target, damage :));
      #      do_damage: receive_damage("qi", damage); wound = damage * 75 / 100 → receive_wound("qi", wound);
      #      final:     receive_damage("jing", damage / 4); receive_wound("jing", damage / 8);
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 75, 100))
        |> Vitals.damage(:jing, div(damage, 4))
        |> Vitals.wound(:jing, div(damage, 8))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: target->affect_by("corpse_poison", ([ "level"    : lvp + random(lvp),
      #                                            "id"       : me->query("id"),
      #                                            "duration" : 5 + random(lvp / 20) ]));
      poison_level = lvp + Engine.rand(rng, lvp)
      poison_duration = 5 + Engine.rand(rng, div(lvp, 20))

      conn =
        ConditionEvent.apply_poison(conn, %{
          "level" => poison_level,
          "duration" => poison_duration,
          "remain" => poison_duration,
          "id" => attacker.id,
          "name" => "腐尸毒"
        })

      # LPC: me->start_busy(3); me->add("neili", -300);
      Performs.feedback(attacker, 300, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("$n只闻一股恶臭传来，大惊之下难以招架，顿被尸体击个正中。\n", bindings)
      )
      |> put_character(character)
    else
      # LPC: me->start_busy(4); me->add("neili", -200);
      Performs.feedback(attacker, 200, 4)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$n见势不妙，急忙腾挪身形，终于避开了$N掷来的尸体。\n", bindings)
      )
      |> put_character(character)
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SHI "「" NOR + WHT "腐尸毒" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object *corpse;
  #         int lvl, lvp, damage;
  #         int ap, dp;
  #         string name, msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/chousui-zhang/shi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHI "只能对战斗中的对手使用。\n");
  # 
  #         if (userp(me) && (me->query_temp("weapon")
  #            || me->query_temp("secondary_weapon")))
  #                 return notify_fail(SHI "只能空手施展。\n");
  # 
  #         lvl = me->query_skill("chousui-zhang", 1);
  #         //lvp = me->query_skill("poison");
  #         lvp = me->query_skill("poison",1);
  # 
  #         if (lvl < 140)
  #                 return notify_fail("你的抽髓掌不够娴熟，难以施展" SHI "。\n");
  # 
  #         if (lvp < 200)
  #                 return notify_fail("你对毒技的了解不够，难以施展" SHI "。\n");
  # 
  #         if ((int)me->query_skill("throwing") < 180)
  #                 return notify_fail("你暗器手法火候不够，难以施展" SHI "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "chousui-zhang")
  #                 return notify_fail("你没有激发抽髓掌，难以施展" SHI "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "chousui-zhang")
  #                 return notify_fail("你没有准备抽髓掌，难以施展" SHI "。\n");
  # 
  #         if ((int)me->query("max_neili") < 1200)
  #                 return notify_fail("你的内力修为不足，难以施展" SHI "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在的内息不足，难以施展" SHI "。\n");
  # 
  #         corpse = filter_array(all_inventory(environment(me)),
  #                              (: base_name($1) == CORPSE_OB
  #                              && ($1->query("defeated_by") == this_player()
  #                              || ! $1->query("defeated_by")) :));
  # 
  #         //if (userp(me) && sizeof(corpse) < 1)
  #         if (userp(me) && sizeof(corpse) < 1 && lvl < 200)
  #                 return notify_fail("你附近没有合适的尸体，难以施展" SHI "。\n");
  # 
  #         // 允许等级 250 以上的任务 NPC 施展此招
  #         //if (! userp(me) && lvl < 250 && sizeof(corpse) < 1)
  #                 //return notify_fail("你附近没有合适的尸体，难以施展" SHI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         if (sizeof(corpse) >= 1)
  #                 name = corpse[0]->name();
  #         else
  #                 name = "路边的行人";
  # 
  #         msg = WHT "$N" WHT "随手抓起" + name + WHT "，将「"
  #               HIR "腐尸毒" NOR + WHT"」毒质运于其上，朝$n"
  #               WHT "猛掷而去。\n" NOR;
  # 
  #         ap = me->query_skill("strike") +
  #              //me->query_skill("poison");
  #              me->query_skill("poison",1);
  # 
  #         // 将任务NPC和玩家区分，再计算防御状况
  #         if (userp(me))
  #                 dp = target->query_skill("dodge") +
  #                      target->query_skill("martial-cognize",1);
  #         else
  #                 dp = target->query_skill("dodge") +
  #                      //target->query_skill("parry");
  #                      target->query_skill("parry",1);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 75,
  #                                           (: final, me, target, damage :));
  #                 me->start_busy(3);
  #                 me->add("neili", -300);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "见势不妙，急忙腾挪身形，终"
  #                        "于避开了$N" CYN "掷来的尸体。\n" NOR;
  #                 me->start_busy(4);
  #                 me->add("neili", -200);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (sizeof(corpse) >= 1)
  #                 destruct(corpse[0]);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         //int lvp = me->query_skill("poison") * 2 / 3;
  #         int lvp = me->query_skill("poison",1);
  # 
  #         target->affect_by("corpse_poison",
  #                 ([ "level"    : lvp + random(lvp),
  #                    "id"       : me->query("id"),
  #                    "duration" : 5 + random(lvp / 20) ]));
  # 
  #         target->receive_damage("jing", damage / 4, me);
  #         target->receive_wound("jing", damage / 8, me);
  # 
  #         return  HIR "$n" HIR "只闻一股恶臭传来，大惊之下难以招"
  #                 "架，顿被尸体击个正中。\n" NOR;
  # }
end
