defmodule Kantele.Combat.Skills.Performs.PoguangDao.Yang do
  @moduledoc """
  perform「破阳刀」（对照 `kungfu/skill/poguang-dao/yang.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 武器为 blade →
  破光刀法>=120 → 激发 blade 为破光刀法 → 内功>=150 → 真气>=400 →
  目标存活。
  起手广播（带武器名）后由目标侧单次判定
  `ap/2 + random(ap) > 目标招架`：命中则
  `damage = ap + random(ap/2)`、外伤比例 40、攻击方
  `start_busy(2 + random(4))` 并扣真气 200；未命中则攻击方
  `start_busy(2)` 并扣真气 180。两种消耗都依赖命中结果，
  故经 `Performs.feedback(attacker, neili, busy)` 在目标侧回授。

  差异（TODO(migrate)）：
  - `.c` 在命中分支内才算 `damage` 与消耗；E 侧目标侧结算时重新取
    `rng`（经 event data 传递）以保证与 LPC 同分布的随机消耗；
  - `message_sort` 起手广播在攻击方发布，命中/未命中文案在目标侧发布
    （`dp` 需目标属性）；
  - `.c` 起手文案以 `\n` 开头、结尾无换行，逐字保留；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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

  @perform_id "poguang-dao/yang"
  @move_name "「破阳刀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("blade");
    ap = Stats.skill(stats, "blade")

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

  # LPC: if (userp(me) && ! me->query("can_perform/poguang-dao/yang"))
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #       || (string)weapon->query("skill_type") != "blade")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "blade" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("poguang-dao", 1) < 120)
  #      if ((int)me->query_skill("force") < 150)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "poguang-dao") < 120 ->
        {:error, "你破光刀法不够娴熟，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "force") < 150 ->
        {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_mapped("blade") != "poguang-dao")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "blade") == "poguang-dao" do
      :ok
    else
      {:error, "你没有激发破光刀法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 400)
  defp check_resources(character) do
    if character.meta.vitals.neili < 400 do
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

  # LPC: wn = weapon->name();
  #      msg = HIW "\n$N" HIW "一声怒喝，内劲瀑涨，施展出绝招「" HIY "破阳刀" HIW
  #            "」手中" + wn + HIW "出神般的挥舞而出，虽然招式看似简单，但其中却"
  #            "蕴藏着无穷的威力，有如神助一般。" NOR;
  #      message_sort(msg, me, target);
  #      …分支与消耗都在目标侧结算…
  defp apply_effect(conn, character, target) do
    Broadcast.publish(
      conn,
      "\n$N一声怒喝，内劲瀑涨，施展出绝招「破阳刀」手中" <>
        weapon_name(character.meta.combat) <>
        "出神般的挥舞而出，虽然招式看似简单，但其中却蕴藏着无穷的威力，有如神助一般。",
      n1: character.name,
      n2: target.name
    )
  end

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> ""
      weapon -> Map.get(weapon, :name)
    end
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
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap + random(ap / 2);
      #      msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
      #                               HIR "$n" HIR "见$N" HIR "来势凶猛，刀"
      #                               "光闪烁，惊骇间肩膀已中一刀，一股鲜血"
      #                               "喷涌而出。\n" NOR);
      #      me->start_busy(2 + random(4));
      #      me->add("neili", -200);
      damage = ap + Engine.rand(rng, div(ap, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 4))

      conn
      |> Broadcast.publish(
        "$n见$N来势凶猛，刀光闪烁，惊骇间肩膀已中一刀，一股鲜血喷涌而出。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: msg = CYN "然而$n" CYN "以快制快，侧身"
      #               "一跳，躲过这招。\n" NOR;
      #      me->start_busy(2);
      #      me->add("neili", -180);
      Performs.feedback(attacker, 180, 2)

      conn
      |> Broadcast.publish("然而$n以快制快，侧身一跳，躲过这招。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YANG "「" HIY "破阳刀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg, wn;
  #         object weapon;
  #         int ap, dp;
  # 
  #         me = this_player();
  # 
  #         if (userp(me) && ! me->query("can_perform/poguang-dao/yang"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YANG "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你所使用的武器不对，难以施展" YANG "。\n");
  # 
  #         if ((int)me->query_skill("poguang-dao", 1) < 120)
  #                 return notify_fail("你破光刀法不够娴熟，难以施展" YANG "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "poguang-dao")
  #                 return notify_fail("你没有激发破光刀法，难以施展" YANG "。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" YANG "。\n");
  # 
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你现在的真气不够，难以施展" YANG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIW "\n$N" HIW "一声怒喝，内劲瀑涨，施展出绝招「" HIY "破阳刀" HIW
  #               "」手中" + wn + HIW "出神般的挥舞而出，虽然招式看似简单，但其中却"
  #               "蕴藏着无穷的威力，有如神助一般。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         ap = me->query_skill("blade");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #              msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
  #                                           HIR "$n" HIR "见$N" HIR "来势凶猛，刀"
  #                                           "光闪烁，惊骇间肩膀已中一刀，一股鲜血"
  #                                           "喷涌而出。\n" NOR);
  #              me->start_busy(2 + random(4));
  #              me->add("neili", -200);
  #         } else
  #         {
  #              msg = CYN "然而$n" CYN "以快制快，侧身"
  #                       "一跳，躲过这招。\n" NOR;
  # 
  #              me->start_busy(2);
  #              me->add("neili", -180);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
