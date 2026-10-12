defmodule Kantele.Combat.Skills.Performs.BaguaDao.Tian do
  @moduledoc """
  天刀八势「tian」（对照 `kungfu/skill/bagua-dao/tian.c`）

  八卦刀法连击：持刀、`bagua-dao/wai-bagua/nei-bagua>=200`、`max_neili>=3000`、
  `neili>=500`、`mapped("blade")=="bagua-dao"`。

  攻击方广播起手式后连击 8 次（`COMBAT_D->do_attack`），期间以 `apply/attack`
  临时提升命中、随机使目标 `start_busy(1)`，收招后攻击方 `start_busy(1+random(8))`。

  攻击/目标分处两进程，命中结算交由目标侧 `resolve_incoming/4`：
  攻击方把每次连击的 `ap/damage` 随事件下发，目标侧做 `ap/2 + rand(ap) > dp` 判定。
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

  @perform_id "bagua-dao/tian"
  @move_name "「天刀八势」"

  # LPC: for (i = 0; i < 8; i++) { ... COMBAT_D->do_attack(me, target, weapon, 0); }
  @strikes 8

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bagua-dao")
    count = div(lvl, 6)
    ap = Stats.skill(stats, "blade")
    damage = count
    weapon_name = weapon_name(combat)

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_levels(stats),
         :ok <- check_resources(character),
         :ok <- check_mapped(stats) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          count: count,
          strikes: @strikes,
          ap: ap,
          damage: damage,
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon_name)
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

  # if (! objectp(weapon = me->query_temp("weapon")) || weapon->query("skill_type") != "blade")
  #     return notify_fail("你所使用的武器不对，难以施展" TIAN "。\n");
  defp check_weapon(character) do
    if weapon_name(character.meta.combat) == nil do
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # if (query_skill("bagua-dao",1) < 200) ... "你的八卦刀法不够娴熟，难以施展" TIAN "。\n"
  #     (wai-bagua < 200)                 ... "你的外八卦神功不够娴熟，难以施展" TIAN "。\n"
  #     (nei-bagua < 200)                 ... "你的内八卦神功不够娴熟，难以施展" TIAN "。\n"
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "bagua-dao") < 200 ->
        {:error, "你的八卦刀法不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "wai-bagua") < 200 ->
        {:error, "你的外八卦神功不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "nei-bagua") < 200 ->
        {:error, "你的内八卦神功不够娴熟，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # if (query("max_neili") < 3000) ... "你的内功修为不足，难以施展" TIAN "。\n"
  #     (query("neili") < 500)     ... "你现在真气不够，难以施展" TIAN "。\n"
  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 3000 -> {:error, "你的内功修为不足，难以施展#{@move_name}。\n"}
      vitals.neili < 500 -> {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
      true -> :ok
    end
  end

  # if (me->query_skill_mapped("blade") != "bagua-dao")
  #     return notify_fail("你没有激发八卦刀法，难以施展" TIAN "。\n");
  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "bagua-dao" do
      :ok
    else
      {:error, "你没有激发八卦刀法，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_effect(conn, character, target, weapon_name) do
    # LPC:
    #   message_combatd(HIY "$N蓦地一振手中" + weapon->name() + HIY
    #                   "，发出万千龙吟，霎时刀光滚滚，向四面涌出，笼罩$n全身。\n" NOR, me, target);
    #   me->add("neili", -250); me->add_temp("apply/attack", count);
    #   for (i=0;i<8;i++){ ... do_attack ... }
    #   me->add_temp("apply/attack", -count); me->start_busy(1 + random(8));
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 250}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    # 按 LPC 的字符串拼接结构拆分：`"…手中" + weapon->name() + "，发出…"`
    conn =
      Broadcast.publish(
        conn,
        "$N蓦地一振手中" <> weapon_name <> "，发出万千龙吟，霎时刀光滚滚，向四面涌出，笼罩$n全身。\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> nil
      weapon -> Map.get(weapon, :name)
    end
  end

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
    # LPC 连击 8 次，每次 `COMBAT_D->do_attack(me, target, weapon, 0)`；
    # 命中期间随机 `target->start_busy(1)`。此处按 LPC 的 ap/dp 判定合并结算。
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    {vitals, combat, hit?, busy?} =
      Enum.reduce(1..@strikes, {character.meta.vitals, character.meta.combat, false, false}, fn _,
                                                                                               {v, c,
                                                                                                hit?,
                                                                                                busy?} ->
        if Engine.rand(rng, max(ap, 1)) + div(ap, 2) > dp do
          v = Vitals.damage(v, :qi, damage)
          {v, c, true, busy?}
        else
          # if (random(3) == 1 && ! target->is_busy()) target->start_busy(1);
          {v, c, hit?, busy?}
        end
      end)

    # 目标侧忙乱（LPC `target->start_busy(1)`，random(3)==1 时）
    combat =
      if Engine.rand(rng, 3) == 1 and not Combat.busy?(combat) do
        Combat.start_busy(combat, 1)
      else
        combat
      end

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # me->add("neili", -250) 已在 apply_effect（攻击方本地）立即扣除，
    # 此处回执仅负责忙乱 `me->start_busy(1 + random(8))`，故 neili_cost 传 0。
    Performs.feedback(attacker, 0, 1 + Engine.rand(rng, 8))

    conn
    |> maybe_publish_hit(hit?)
    |> put_character(character)
  end

  defp maybe_publish_hit(conn, true), do: Broadcast.publish(conn, "被击中！")
  defp maybe_publish_hit(conn, false), do: conn

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define TIAN "「" HIY "天刀八势" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  # //      int damage;
  # //      string msg;
  #         object weapon;
  #         int i, count;
  # 
  #         if (userp(me) && ! me->query("can_perform/bagua-dao/tian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(TIAN "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你所使用的武器不对，难以施展" TIAN "。\n");
  # 
  #         if ((int)me->query_skill("bagua-dao", 1) < 200)
  #                 return notify_fail("你的八卦刀法不够娴熟，难以施展" TIAN "。\n");
  # 
  #         if ((int)me->query_skill("wai-bagua", 1) < 200)
  #                 return notify_fail("你的外八卦神功不够娴熟，难以施展" TIAN "。\n");
  # 
  #         if ((int)me->query_skill("nei-bagua", 1) < 200)
  #                 return notify_fail("你的内八卦神功不够娴熟，难以施展" TIAN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 3000)
  #                 return notify_fail("你的内功修为不足，难以施展" TIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你现在真气不够，难以施展" TIAN "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "bagua-dao")
  #                 return notify_fail("你没有激发八卦刀法，难以施展" TIAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         message_combatd(HIY "$N" HIY "蓦地一振手中" + weapon->name() +
  #                         HIY "，发出万千龙吟，霎时刀光滚滚，向四面涌出"
  #                         "，笼罩$n" HIY "全身。\n" NOR, me, target);
  # 
  #         count = me->query_skill("bagua-dao", 1) / 6;
  # 
  #         me->add("neili", -250);
  #         me->add_temp("apply/attack", count);
  # 
  #         for (i = 0; i < 8; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 if (random(3) == 1 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 me->add_temp("pfm_tiandao", 1);
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->add_temp("apply/attack", -count);
  #         me->delete_temp("pfm_tiandao");
  #         me->start_busy(1 + random(8));
  #         return 1;
  # }
end
