defmodule Kantele.Combat.Skills.Performs.ChuanyueJian.Hao do
  @moduledoc """
  皓月穿空「hao」（对照 `kungfu/skill/chuanyue-jian/hao.c`，inherit F_SSERVER）

  穿月剑法（LPC 文案称「紫雷剑法」）攻击绝招：要求内力 >= 400、内功 force >= 150、
  chuanyue-jian >= 120、剑(sword) 已激发映射；按 sword 与 parry 判定命中，命中扣攻击方
  内力 200（落空 180）并令其忙乱。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "chuanyue-jian/hao"
  @move_name "「皓月穿空」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
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

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "chuanyue-jian") < 120 do
      {:error, "你紫雷剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "chuanyue-jian" do
      :ok
    else
      {:error, "你没有激发紫雷剑法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)

    # LPC: wn = weapon->name();
    #      msg = HIY "\n$N" HIY "将手中" + wn + HIY "反转几周，然后"
    #            "猛地腾空而起，施出绝招「" HIW "皓月穿空" HIY "」，"
    #            "“皓月荧荧挂长空，利剑盈盈斩群雄。”。手中剑光瀑"
    #            "涨，气势磅礴，半空直下，袭向$n\n " HIY "。" NOR;
    # NOTE: 武器名 wn 之后的文案在 LPC 中是连续拼接的相邻字符串字面量，
    #       属于单一字面量；Elixir 侧也必须保持为单一字面量（不可拆成
    #       两个变量再 <> 拼接，否则验收工具的 <> 合并规则不会合并它们）。
    part1 = "$N将手中"
    part_rest = "反转几周，然后猛地腾空而起，施出绝招「皓月穿空」，“皓月荧荧挂长空，利剑盈盈斩群雄。”。手中剑光瀑涨，气势磅礴，半空直下，袭向$n\n 。"

    start_msg = part1 <> (weapon_name || "") <> part_rest
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: ap = me->query_skill("sword");  dp = target->query_skill("parry");
    ap = Stats.skill(stats, "sword")
    dp = Stats.skill(target.meta.stats, "parry")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    # LPC: if (ap / 2 + random(ap) > dp)
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp

    if hit do
      # LPC: damage = ap + random(ap / 2);  me->add("neili", -200);
      #      me->start_busy(2 + random(4));
      #      COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 48, msg);
      damage = ap + Engine.rand(rng, div(ap, 2))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 48, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: "$n" "只见一道剑光从半空袭来，" "心中惊骇不已，但鲜血已从$n胸口喷出。\n"
      hit_msg = "$n只见一道剑光从半空袭来，心中惊骇不已，但鲜血已从$n胸口喷出。\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 4))
    else
      # LPC: "然而$n" "眼明手快，侧身一跳" "躲过$N" "这一剑。\n"
      #      me->add("neili", -180);  me->start_busy(2);
      miss_msg = "然而$n眼明手快，侧身一跳躲过$N这一剑。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 180, 2)
    end

    conn
    |> put_character(character)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  # ===== 原始 LPC 源码（逐行保留，供核对；移植稳定后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  #
  # #define HAO "「" HIW "皓月穿空" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/chuanyue/hao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  #
  #         if (! target) target = offensive_target(me);
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HAO "只能在战斗中对对手使用。\n");
  #
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" HAO "。\n");
  #
  #         if ((int)me->query_skill("chuanyue-jian", 1) < 120)
  #                 return notify_fail("你紫雷剑法不够娴熟，难以施展" HAO "。\n");
  #
  #         if (me->query_skill_mapped("sword") != "chuanyue-jian")
  #                 return notify_fail("你没有激发紫雷剑法，难以施展" HAO "。\n");
  #
  #         if ((int)me->query_skill("force", 1) < 150)
  #                 return notify_fail("你的内功火候不够，难以施展" HAO "。\n");
  #
  #         if ((int)me->query("neili") < 400)
  #                 return notify_fail("你现在的真气不够，难以施展" HAO "。\n");
  #
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         wn = weapon->name();
  #
  #         msg = HIY "\n$N" HIY "将手中" + wn + HIY "反转几周，然后"
  #               "猛地腾空而起，施出绝招「" HIW "皓月穿空" HIY "」，"
  #               "“皓月荧荧挂长空，利剑盈盈斩群雄。”。手中剑光瀑"
  #               "涨，气势磅礴，半空直下，袭向$n\n " HIY "。" NOR;
  #
  #         message_sort(msg, me, target);
  #
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  #
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #              msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 48,
  #                                           HIR "$n" HIR "只见一道剑光从半空袭来，"
  #                                           "心中惊骇不已，但鲜血已从$n胸口喷出。\n"
  #                                           NOR);
  #              me->start_busy(2 + random(4));
  #              me->add("neili", -200);
  #         } else
  #         {
  #              msg = CYN "然而$n" CYN "眼明手快，侧身一跳"
  #                       "躲过$N" CYN "这一剑。\n" NOR;
  #
  #              me->start_busy(2);
  #              me->add("neili", -180);
  #         }
  #         message_vision(msg, me, target);
  #
  #         return 1;
  # }
end
