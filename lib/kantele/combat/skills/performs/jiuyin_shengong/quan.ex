defmodule Kantele.Combat.Skills.Performs.JiuyinShengong.Quan do
  @moduledoc """
  perform「九阴神拳」（source jiuyin-shengong/perform/quan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 九阴神功>=230 → 基本拳法>=220 →
  内力>=240 → 空手 → 准备 unarmed 或 cuff 为九阴神功 → 目标存活。
  ap = max(拳脚, 拳法) + 武学常识；dp = 闪避 + dex*20 + 武学常识。
  起手扣 50 内力、忙乱 2；命中再扣 90 内力，伤害 ap/2 + random(ap/2)，85+random(5)% 外伤。
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

  @perform_id "jiuyin-shengong/quan"
  @move_name "「九阴神拳」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-shengong")
    ap = max(Stats.skill(stats, "unarmed"), Stats.skill(stats, "cuff")) + Stats.skill(stats, "martial-cognize")
    damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))

    with {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(combat),
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
          damage: damage,
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill("jiuyin-shengong", 1) < 230) / if (me->query_skill("cuff", 1) < 220)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "jiuyin-shengong") < 230 ->
        {:error, "你的九阴神功还不够娴熟，不能使用#{@move_name}！\n"}

      Stats.skill(stats, "cuff") < 220 ->
        {:error, "你的基本拳法还不够娴熟，不能使用#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 240 do
      {:error, "你的内力不够，不能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_temp("weapon")) return notify_fail("此招只能空手施展！\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "此招只能空手施展！\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "jiuyin-shengong"
  #          && me->query_skill_prepared("cuff") != "jiuyin-shengong")
  # prepared_perform 返回绝招 ID（如 jiuyin-shengong/quan），须取技能前缀比对
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared_unarmed = Stats.prepared_perform(stats, "unarmed")
    prepared_cuff = Stats.prepared_perform(stats, "cuff")
    ok_unarmed = prepared_unarmed != nil and hd(String.split(prepared_unarmed, "/")) == "jiuyin-shengong"
    ok_cuff = prepared_cuff != nil and hd(String.split(prepared_cuff, "/")) == "jiuyin-shengong"

    if not ok_unarmed and not ok_cuff do
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

  # LPC: me->start_busy(2); me->add("neili", -50); 起手文案
  defp apply_effect(conn, character, target) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 50}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = Combat.start_busy(character.meta.combat, 2)
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish(
      Messages.interpolate(
        "$N一声冷哼，握拳击出，招式雄浑，难擢其威！\n",
        [n1: character.name, n2: target.name]
      )
    )
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
    damage = max(Map.get(data, :damage, 0), 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("dodge") + target->query("dex") * 20 +
    #          target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "dodge") + Stats.query_dex(stats) * 20 + Stats.skill(stats, "martial-cognize")

    if div(ap, 2) + Engine.rand(rng, ap) < dp do
      # LPC: 未命中
      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "只见$n不慌不忙，轻轻一闪，躲过了$N这一击！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: 命中：me->add("neili", -90); do_damage(me, target, UNARMED_ATTACK, damage, 85 + random(5), ...)
      percent = 85 + Engine.rand(rng, 5)
      character = apply_damage(character, damage, percent)
      Performs.feedback(attacker, 90, 0)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n连忙格挡，可是这一拳力道何等之重，哪里抵挡得住？只被打得吐血三尺，连退数步！\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end

  # LPC: COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, percent, msg)
  # wound = damage * percent / 100（armor 未建模，按 percent 直算）
  defp apply_damage(character, damage, percent) do
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage * percent, 100))

    %{character | meta: %{character.meta | vitals: vitals}}
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // quan 九阴神拳
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define QUAN "「" HIW "九阴神拳" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  #     int ap, dp;
  #     int damage;
  # 
  #     if (!target)
  #     {
  #         me->clean_up_enemy();
  #         target = me->select_opponent();
  #     }
  # 
  #     if (!target || !me->is_fighting(target))
  #         return notify_fail(QUAN "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query_skill("jiuyin-shengong", 1) < 230)
  #         return notify_fail("你的九阴神功还不够娴熟，不能使用" QUAN "！\n");
  # 
  #     if (me->query_skill("cuff", 1) < 220)
  #         return notify_fail("你的基本拳法还不够娴熟，不能使用" QUAN "！\n");
  # 
  #     if (me->query("neili") < 240)
  #         return notify_fail("你的内力不够，不能使用" QUAN "！\n");
  # 
  #     if (me->query_temp("weapon"))
  #         return notify_fail("此招只能空手施展！\n");
  # 
  #     if (me->query_skill_prepared("unarmed") != "jiuyin-shengong" && me->query_skill_prepared("cuff") != "jiuyin-shengong")
  #         return notify_fail("你没有准备使用九阴神功，无法施展" QUAN "。\n");
  # 
  #     if (!living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "$N" HIC "一声冷哼，握拳击出，招式雄浑，难擢其威！\n" NOR;
  # 
  #     ap = me->query_skill("unarmed");
  #     if (ap < me->query_skill("cuff"))
  #         ap = me->query_skill("cuff");
  #     ap += me->query_skill("martial-cognize", 1);
  #     dp = target->query_skill("dodge") + target->query("dex") * 20 +
  #          target->query_skill("martial-cognize", 1);
  # 
  #     me->start_busy(2);
  #     me->add("neili", -50);
  #     if (ap / 2 + random(ap) < dp)
  #     {
  #         msg += HIG "只见$n" HIG "不慌不忙，轻轻一闪，躲过了$N" HIG "这一击！\n" NOR;
  #     }
  #     else
  #     {
  #         me->add("neili", -90);
  #         damage = ap / 2 + random(ap / 2);
  #         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 85 + random(5),
  #                                    HIR "$n" HIR "连忙格挡，可是这一拳力道何等之重，哪里抵"
  #                                        "挡得住？只被打得吐血三尺，连退数步！\n" NOR);
  #     }
  # 
  #     message_combatd(msg, me, target);
  #     return 1;
  # }
end
