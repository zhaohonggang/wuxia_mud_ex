defmodule Kantele.Combat.Skills.Performs.BaguaBiao.Xian do
  @moduledoc """
  镖中现掌「xian」（对照 `kungfu/skill/bagua-biao/xian.c`）

  八卦镖法/八卦掌单体攻击：手中须持暗器，先掷暗器（虚招）再近身出掌。

  门槛（攻击方，逐条对齐 LPC）：目标在战斗中、空手、手持 throwing 类暗器、
  `mapped("strike")=="bagua-zhang"`、`prepared("strike")=="bagua-zhang"`、
  `mapped("throwing")=="bagua-biao"`、`bagua-zhang>=120`、`bagua-biao>=120`、
  `force>=150`、`neili>=150`。

  攻击方广播起手式、扣 1 枚暗器、`start_busy(3)`，发 `perform-incoming`；
  目标侧按 `ap/2 + rand(ap) > dp`（ap=strike+throwing，dp=dodge+parry）判定命中：
  - 命中：`do_damage(qi, damage, 30)`，攻击方扣 100 内力；
  - 未中：不扣内力。

  攻击/目标分处两进程，命中需双方技能值，故由攻击方把 `ap/damage` 随事件下发，
  在目标侧 `resolve_incoming/4` 结算。
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

  @perform_id "bagua-biao/xian"
  @move_name "「镖中现掌」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bagua-biao")
    ap = Stats.skill(stats, "strike") + Stats.skill(stats, "throwing")
    damage = div(ap, 3) + Engine.rand(rng, div(ap, 2))

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_anqi(character),
         :ok <- check_mapped_strike(stats),
         :ok <- check_prepared_strike(stats),
         :ok <- check_mapped_throwing(stats),
         :ok <- check_levels(stats),
         :ok <- check_neili(character) do
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

      apply_effect(conn, character)
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # if (objectp(me->query_temp("weapon"))) return notify_fail(XIAN "只能空手施展。\n");
  defp check_weapon(character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # if (! objectp(anqi = me->query_temp("handing")) || anqi->query("skill_type") != "throwing")
  #     return notify_fail("你现在手中并没有拿着暗器。\n");
  defp check_anqi(character) do
    if has_throwing_anqi?(character) do
      :ok
    else
      {:error, "你现在手中并没有拿着暗器。\n"}
    end
  end

  # if (me->query_skill_mapped("strike") != "bagua-zhang")
  #     return notify_fail("你没有激发八卦掌，难以施展" XIAN "。\n");
  defp check_mapped_strike(stats) do
    if Stats.mapped(stats, "strike") == "bagua-zhang" do
      :ok
    else
      {:error, "你没有激发八卦掌，难以施展#{@move_name}。\n"}
    end
  end

  # if (me->query_skill_prepared("strike") != "bagua-zhang")
  #     return notify_fail("你没有准备八卦掌，难以施展" XIAN "。\n");
  defp check_prepared_strike(stats) do
    case Stats.prepared_perform(stats, "strike") do
      nil ->
        {:error, "你没有准备八卦掌，难以施展#{@move_name}。\n"}

      prepared ->
        if prepared |> String.split("/") |> hd() == "bagua-zhang" do
          :ok
        else
          {:error, "你没有准备八卦掌，难以施展#{@move_name}。\n"}
        end
    end
  end

  # if (me->query_skill_mapped("throwing") != "bagua-biao")
  #     return notify_fail("你没有激发八卦镖诀，难以施展" XIAN "。\n");
  defp check_mapped_throwing(stats) do
    if Stats.mapped(stats, "throwing") == "bagua-biao" do
      :ok
    else
      {:error, "你没有激发八卦镖诀，难以施展#{@move_name}。\n"}
    end
  end

  # if (me->query_skill("bagua-zhang",1) < 120) ... "你的八卦掌不够娴熟，难以施展" XIAN "。\n"
  #     (bagua-biao < 120)                        ... "你的八卦镖诀不够娴熟，难以施展" XIAN "。\n"
  #     (force < 150)                             ... "你的内功火候不够，难以施展" XIAN "。\n"
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "bagua-zhang") < 120 ->
        {:error, "你的八卦掌不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "bagua-biao") < 120 ->
        {:error, "你的八卦镖诀不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # if ((int)me->query("neili") < 150) return notify_fail("你现在真气不足，难以施展" XIAN "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    # LPC: msg = HIY "突然只听$N喝道：“$n看招！”说完单手一扬，袖底顿时窜出一道金光，直射$n而去！\n" NOR;
    #      me->start_busy(3)（攻击方忙乱走 Performs.feedback，见 resolve_incoming）；
    #      if (anqi->query_amount() > 0) anqi->add_amount(-1);
    character = consume_anqi(character, handing_anqi(character))

    conn =
      Broadcast.publish(
        conn,
        "突然只听$N喝道：“$n看招！”说完单手一扬，袖底顿时窜出一道金光，直射$n而去！\n",
        n1: character.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # 手持暗器：inventory 中带 handing 标记且 skill_type=="throwing" 的实例
  # （对应 LPC `me->query_temp("handing")`）
  defp handing_anqi(character) do
    Enum.find(character.inventory, fn item ->
      is_map(item.meta) and
        Map.get(item.meta, :handing) and
        Map.get(item.meta, :skill_type) == "throwing" and
        (Map.get(item.meta, :amount) || 1) >= 1
    end)
  end

  # LPC: anqi->add_amount(-1)；数量归零则移除该实例。
  defp consume_anqi(character, anqi) do
    if anqi do
      inventory =
        character.inventory
        |> Enum.map(fn item ->
          if item == anqi do
            amount = (Map.get(item.meta, :amount) || 1) - 1
            if amount >= 1, do: %{item | meta: Map.put(item.meta, :amount, amount)}, else: nil
          else
            item
          end
        end)
        |> Enum.reject(&is_nil/1)

      %{character | inventory: inventory}
    else
      character
    end
  end

  defp has_throwing_anqi?(character), do: handing_anqi(character) != nil

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    bindings = [n1: attacker.name, n2: character.name]

    if hit do
      vitals = Vitals.damage(vitals, :qi, damage)
      character = %{character | meta: %{character.meta | vitals: vitals}}
      # me->add("neili", -100); me->start_busy(3)
      Performs.feedback(attacker, 100, 3)

      conn
      |> Broadcast.publish(Messages.interpolate("可只见$n哈哈一笑，身子一矮，躲了过去。\n", bindings))
      |> Broadcast.publish(
        Messages.interpolate("哪知方才的暗器竟是虚招，等$p反应时$N已至跟前，双掌齐施，重重的印在$n胸前。\n", bindings)
      )
      |> put_character(character)
    else
      # me->start_busy(3)
      Performs.feedback(attacker, 0, 3)

      Broadcast.publish(
        conn,
        Messages.interpolate("可是$p看破了$P的企图，没有受到迷惑，招手将暗器全部揽了下来。\n", bindings)
      )
    end
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XIAN "「" HIY "镖中现掌" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object anqi;
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/bagua-biao/xian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XIAN "只能在战斗中对对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail(XIAN "只能空手施展。\n");
  # 
  #         if (! objectp(anqi = me->query_temp("handing"))
  #            || (string)anqi->query("skill_type") != "throwing")
  #                 return notify_fail("你现在手中并没有拿着暗器。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "bagua-zhang") 
  #                 return notify_fail("你没有激发八卦掌，难以施展" XIAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "bagua-zhang") 
  #                 return notify_fail("你没有准备八卦掌，难以施展" XIAN "。\n");
  # 
  #         if (me->query_skill_mapped("throwing") != "bagua-biao") 
  #                 return notify_fail("你没有激发八卦镖诀，难以施展" XIAN "。\n");
  # 
  #         if ((int)me->query_skill("bagua-zhang", 1) < 120)
  #                 return notify_fail("你的八卦掌不够娴熟，难以施展" XIAN "。\n");
  # 
  #         if ((int)me->query_skill("bagua-biao", 1) < 120)
  #                 return notify_fail("你的八卦镖诀不够娴熟，难以施展" XIAN "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" XIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在真气不足，难以施展" XIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "突然只听$N" HIY "喝道：“$n" HIY "看招！”"
  #               "说完单手一扬，袖底顿时窜出一道金光，直射$n" HIY
  #               "而去！\n" NOR;
  # 
  #         ap = me->query_skill("strike", 1) +
  #              me->query_skill("throwing");
  # 
  #         dp = target->query_skill("dodge", 1) +
  #              target->query_skill("parry", 1);
  # 
  #         me->start_busy(3);
  #         if (anqi->query_amount() > 0)anqi->add_amount(-1);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         { 
  #                 damage = ap / 3 + random(ap / 2);
  #                 me->add("neili", -100);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 30,
  #                                            HIY "可只见$n" HIY "哈哈一笑，身子一矮"
  #                                            "，躲了过去。\n" NOR + HIR "哪知方才的"
  #                                            "暗器竟是虚招，等$p" HIR "反应时$N" HIR
  #                                            "已至跟前，双掌齐施，重重的印在$n" HIR
  #                                            "胸前。\n" NOR);
  #         } else
  #         {
  #                 msg += HIY "可是$p" HIY "看破了$P" HIY "的企图，没"
  #                        "有受到迷惑，招手将暗器全部揽了下来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
