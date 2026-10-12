defmodule Kantele.Combat.Skills.Performs.HuashanQuan.Song do
  @moduledoc """
  perform「苍松式」（source huashan-quan/song.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 华山拳法>=40 →
  真气>=100 → 准备 cuff 为华山拳法 → 目标存活。
  命中判定 `ap/2 + random(ap)` vs 目标 `force + 臂力*10`
  （`ap = 基本拳脚 + 臂力*10`）：命中则伤害 `ap/3 + random(ap/3)`
  （qi 伤 + 30% 外伤）、扣 60 真气、忙乱 2；
  未命中则扣 50 真气、忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `me->query_str()` / `target->query_str()` 折算为 `Stats.query_str/1`；
  - 攻击方消耗/忙乱分属命中与失手两支，经 `Performs.feedback/3` 由目标侧回传。
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

  @perform_id "huashan-quan/song"
  @move_name "「苍松式」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "huashan-quan")
    # LPC: ap = me->query_skill("cuff") + me->query_str() * 10;
    ap = Stats.skill(stats, "cuff") + Stats.query_str(stats) * 10

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
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

  # LPC: if (userp(me) && ! me->query("can_perform/huashan-quan/song"))
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

  # LPC: if ((int)me->query_skill("huashan-quan", 1) < 40)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "huashan-quan") < 40 do
      {:error, "你的华山拳法不够娴熟，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "huashan-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared == nil or prepared |> String.split("/") |> hd() != "huashan-quan" do
      {:error, "你没有准备使用劈石破玉拳，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
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
    # LPC: msg = HIY "$N" HIY "怒喝一声，右拳直出，刚猛有力，正是华山绝技「" HIG "苍松式" HIY
    #            "」，拳风呼响，袭向$n" HIY "。\n"NOR;
    #      命中/失手与攻击方消耗/忙乱均在目标侧结算（dp 需目标 force+臂力）。
    conn
    |> Broadcast.publish(
      "$N怒喝一声，右拳直出，刚猛有力，正是华山绝技#{@move_name}，拳风呼响，袭向$n。\n",
      n1: character.name,
      n2: target.name
    )
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") + target->query_str() * 10;
    dp = Stats.skill(stats, "force") + Stats.query_str(stats) * 10

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 3 + random(ap / 3);
      #      do_damage(me, target, UNARMED_ATTACK, damage, 30, HIR "只见$P" HIR "一拳直出，…");
      #      me->add("neili", -60); me->start_busy(2);
      damage = div(ap, 3) + Engine.rand(rng, max(div(ap, 3), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 30, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 60, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "只见$P一拳直出，$p正欲挡格，却已不及，一拳重重地打在身上！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P" HIC "这一招。\n"NOR;
      #      me->add("neili", -50); me->start_busy(3);
      Performs.feedback(attacker, 50, 3)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p奋力招架，硬生生的挡开了$P这一招。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // modify by rcwiz 2003
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define SONG "「" HIG "苍松式" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  # //    object weapon;
  #     int damage;
  #     string msg;
  #         int ap, dp;
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/huashan-quan/song"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(SONG "只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query_skill("huashan-quan", 1) < 40)
  #         return notify_fail("你的华山拳法不够娴熟，无法施展" SONG "。\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你现在真气不够，无法施展" SONG "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "huashan-quan")
  #                 return notify_fail("你没有准备使用劈石破玉拳，无法施展" SONG "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "怒喝一声，右拳直出，刚猛有力，正是华山绝技「" HIG "苍松式" HIY
  #                "」，拳风呼响，袭向$n" HIY "。\n"NOR;
  # 
  #         ap = me->query_skill("cuff") + me->query_str() * 10;
  #         dp = target->query_skill("force") + target->query_str() * 10;
  #     if (ap / 2 + random(ap) > dp)
  #     {
  #         damage = ap / 3 + random(ap / 3);
  # 
  #                 me->add("neili", -60);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                    HIR "只见$P" HIR "一拳直出，$p" HIR
  #                                            "正欲挡格，却已不及，一拳重重地打在身上！\n" NOR);
  #         me->start_busy(2);
  #     } else
  #     {
  #         msg += HIC "可是$p" HIC "奋力招架，硬生生的挡开了$P"
  #                        HIC "这一招。\n"NOR;
  #         me->add("neili", -50);
  #         me->start_busy(3);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
