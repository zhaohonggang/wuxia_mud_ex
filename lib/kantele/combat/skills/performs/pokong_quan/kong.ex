defmodule Kantele.Combat.Skills.Performs.PokongQuan.Kong do
  @moduledoc """
  perform「破碎虚空」（对照 `kungfu/skill/pokong-quan/kong.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 双手皆空
  （weapon / secondary_weapon 均为空）→ 破空拳法>=60 →
  激发 cuff 为破空拳法 → 准备 cuff 为破空拳法 → 内功>=80 →
  真气>=200 → 目标存活。
  起手广播后由目标侧单次判定 `ap/2 + random(ap) > 目标招架`：
  命中则 `damage = 破空拳 + random(damage/2)`（注意 .c 用的是
  `henshan-quan` 等级而非本门拳法等级，逐字保留）、外伤比例 40、
  攻击方扣真气 100 并 `start_busy(2 + random(2))`；未命中则扣真气 30 并
  `start_busy(2 + random(3))`。两种消耗都依赖命中结果，
  故经 `Performs.feedback(attacker, neili, busy)` 在目标侧回授。

  差异（TODO(migrate)）：
  - `damage` 基数（henshan-quan 等级）在攻击方 `run` 中算出并经 event
    data 传给目标侧，随机部分与命中判定同在目标侧消耗同一 `rng`
    （保持与 LPC 相同的随机消耗顺序）；
  - `message_sort` 起手广播在攻击方发布，命中/未命中文案在目标侧发布
    （`dp` 需目标属性）；
  - `.c` 起手文案以 `\n` 开头、结尾无换行，逐字保留；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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
  alias Kantele.Combat.Performs

  @perform_id "pokong-quan/kong"
  @move_name "「破碎虚空」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("cuff");
    ap = Stats.skill(stats, "cuff")

    # LPC: damage = (int)me->query_skill("henshan-quan", 1);
    #      （命中分支内再 random(damage / 2)）
    damage = Stats.skill(stats, "henshan-quan")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
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

  # LPC: if (userp(me) && ! me->query("can_perform/pokong-quan/kong"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #      return notify_fail(KONG "只能空手施展。\n");
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("pokong-quan", 1) < 60)
  #      if (me->query_skill_mapped("cuff") != "pokong-quan")
  #      if ((int)me->query_skill("force") < 80)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "pokong-quan") < 60 ->
        {:error, "你破空拳法不够娴熟，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "cuff") != "pokong-quan" ->
        {:error, "你没有激发破空拳法，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 80 ->
        {:error, "你的内功修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "pokong-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared != nil and hd(String.split(prepared, "/")) == "pokong-quan" do
      :ok
    else
      {:error, "你没有准备破空拳法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  #      return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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

  # LPC: msg = HIC "\n$N" HIC "仰天长啸，双拳挥出，施一招「" HIW "破碎虚空"
  #            HIC "」，拳速极快，破空长响，分袭$n" HIC "面门和胸口。" NOR;
  #      message_sort(msg, me, target);
  #      …分支与消耗都在目标侧结算…
  defp apply_effect(conn, character, target) do
    Broadcast.publish(
      conn,
      "\n$N仰天长啸，双拳挥出，施一招「破碎虚空」，拳速极快，破空长响，分袭$n面门和胸口。",
      n1: character.name,
      n2: target.name
    )
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    damage = Map.get(data, :damage, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage += random(damage / 2);
      #      msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
      #                               HIR "$N" HIR "出手既快，方位又奇，$n"
      #                               HIR "闪避不及，闷哼一声，已然中拳。\n" NOR);
      #      me->add("neili", -100);
      #      me->start_busy(2 + random(2));
      hit_damage = damage + Engine.rand(rng, div(damage, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, hit_damage)
        |> Vitals.wound(:qi, div(hit_damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 100, 2 + Engine.rand(rng, 2))

      conn
      |> Broadcast.publish(
        "$N出手既快，方位又奇，$n闪避不及，闷哼一声，已然中拳。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: msg = CYN "$n" CYN "不慌不忙，以快打快，将$N"
      #               CYN "这招化去。\n" NOR;
      #      me->add("neili", -30);
      #      me->start_busy(2 + random(3));
      Performs.feedback(attacker, 30, 2 + Engine.rand(rng, 3))

      conn
      |> Broadcast.publish("$n不慌不忙，以快打快，将$N这招化去。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define KONG "「" HIG "破碎虚空" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/pokong-quan/kong"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(KONG "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(KONG "只能空手施展。\n");
  # 
  #         if ((int)me->query_skill("pokong-quan", 1) < 60)
  #                 return notify_fail("你破空拳法不够娴熟，难以施展" KONG "。\n");
  # 
  #         if (me->query_skill_mapped("cuff") != "pokong-quan")
  #                 return notify_fail("你没有激发破空拳法，难以施展" KONG "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "pokong-quan")
  #                 return notify_fail("你没有准备破空拳法，难以施展" KONG "。\n");
  # 
  #         if (me->query_skill("force") < 80)
  #                 return notify_fail("你的内功修为不够，难以施展" KONG "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" KONG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("cuff");
  #         dp = target->query_skill("parry");
  # 
  #         msg = HIC "\n$N" HIC "仰天长啸，双拳挥出，施一招「" HIW "破碎虚空"
  #               HIC "」，拳速极快，破空长响，分袭$n" HIC "面门和胸口。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = (int)me->query_skill("henshan-quan", 1);
  #                 damage += random(damage / 2);
  # 
  #                 msg = COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 40,
  #                                           HIR "$N" HIR "出手既快，方位又奇，$n"
  #                                           HIR "闪避不及，闷哼一声，已然中拳。\n" NOR);
  # 
  #                 me->add("neili", -100);
  #             me->start_busy(2 + random(2));
  #         } else
  #         {
  #                 msg = CYN "$n" CYN "不慌不忙，以快打快，将$N"
  #                       CYN "这招化去。\n" NOR;
  # 
  #                 me->add("neili", -30);
  #             me->start_busy(2 + random(3));
  #         }
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
