defmodule Kantele.Combat.Skills.Performs.LingyunJian.Xiao do
  @moduledoc """
  perform「剑气冲霄」（source lingyun-jian/xiao.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 持剑类武器 → 凌云剑法>=120 →
  激发 sword 为凌云剑法 → 内功>=120 → 真气>=300 → 目标存活。
  起手广播（兵刃名出现两次，把文案拆成三段）；命中判定 `sword/2 + random(sword)`
  > 目标 `parry`，命中伤害 `sword + random(sword/2)`（40% 外伤比例）、扣 200 真气、
  忙乱 `2+random(4)`；未命中扣 180 真气、忙乱 2。

  差异（TODO(migrate)）：
  - `COMBAT_D->do_damage(WEAPON_ATTACK, damage, 40, msg)` 折算为
    `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage*40, 100))`；
  - 起手文案在攻击方发出，命中/未命中文案与分支 neili 由目标侧 feedback 回执
    （feedback(200, 2+rand(4)) / feedback(180, 2)）；
  - XIAO 宏展开+去色后合并为单段「剑气冲霄」，E 侧用 @move_name 属性插值复现；
  - 起手式里斩向 $n 后有一个 `\n` 再接句号，逐字保留。
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
  alias Kantele.Combat.Performs

  @perform_id "lingyun-jian/xiao"
  @move_name "「剑气冲霄」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lingyun-jian")
    ap = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_force(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      weapon_name =
        case Combat.weapon(combat) do
          nil -> ""
          weapon -> Map.get(weapon, :name)
        end

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

      apply_effect(conn, character, target, weapon_name)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/lingyun-jian/xiao"))
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

  # LPC: if (! objectp(weapon) || weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("lingyun-jian", 1) < 120)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "lingyun-jian") < 120 do
      {:error, "你凌云剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "lingyun-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") == "lingyun-jian" do
      :ok
    else
      {:error, "你没有激发凌云剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 120)
  defp check_force(character) do
    if Stats.skill(character.meta.stats, "force") < 120 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target, weapon_name) do
    # LPC: msg = HIW "\n$N" HIW "长叹一声，语调宛然，忽然右手斜指长"
    #               "空，手中" + wn + HIW "寒光闪闪，猛然间使出绝"
    #               "招「" HIY "剑气冲霄" HIW "」，刹时间剑风凌厉"
    #               "，" + wn + HIW "以直冲云霄之势，斩向$n\n" HIW "。" NOR;
    # wn 出现两次把文案拆成三段；其余相邻字面量在 C 侧被空白分隔合并为一段。
    # me->start_busy / 分支 neili 由目标侧 feedback 回执。
    conn =
      Broadcast.publish(
        conn,
        "\n$N长叹一声，语调宛然，忽然右手斜指长空，手中" <> weapon_name <>
          "寒光闪闪，猛然间使出绝招「剑气冲霄」，刹时间剑风凌厉，" <> weapon_name <>
          "以直冲云霄之势，斩向$n\n。",
        n1: character.name,
        n2: target.name
      )

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
    dp = Stats.skill(character.meta.stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    hit? = div(ap, 2) + Engine.rand(rng, ap) > dp

    # LPC: damage = ap + random(ap / 2);
    #      COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40, msg);
    #      me->add("neili", -200); me->start_busy(2 + random(4));
    # else: me->add("neili", -180); me->start_busy(2);
    {vitals, msg, neili_cost, attacker_busy} =
      if hit? do
        damage = ap + Engine.rand(rng, div(ap, 2))

        v =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * 40, 100))

        {v, hit_message(), 200, 2 + Engine.rand(rng, 4)}
      else
        {character.meta.vitals, miss_message(), 180, 2}
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    Performs.feedback(attacker, neili_cost, attacker_busy)

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end

  # LPC: HIR "$n" HIR "只见一道金光闪过，心中惊骇不已，但鲜血已从$n胸口喷出。\n" NOR
  # （相邻字面量合并为单段）
  defp hit_message do
    "$n只见一道金光闪过，心中惊骇不已，但鲜血已从$n胸口喷出。\n"
  end

  # LPC: CYN "然而$n" CYN "眼明手快，侧身一跳躲过$N" CYN "这一剑。\n" NOR
  # （相邻字面量合并为单段）
  defp miss_message do
    "然而$n眼明手快，侧身一跳躲过$N这一剑。\n"
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XIAO "「" HIW "剑气冲霄" NOR "」"
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
  #         if (userp(me) && ! me->query("can_perform/lingyun-jian/xiao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XIAO "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你所使用的武器不对，难以施展" XIAO "。\n");
  # 
  #         if ((int)me->query_skill("lingyun-jian", 1) < 120)
  #                 return notify_fail("你凌云剑法不够娴熟，难以施展" XIAO "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "lingyun-jian")
  #                 return notify_fail("你没有激发凌云剑法，难以施展" XIAO "。\n");
  # 
  #         if ((int)me->query_skill("force") < 120)
  #                 return notify_fail("你的内功火候不够，难以施展" XIAO "。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你现在的真气不够，难以施展" XIAO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIW "\n$N" HIW "长叹一声，语调宛然，忽然右手斜指长"
  #               "空，手中" + wn + HIW "寒光闪闪，猛然间使出绝"
  #               "招「" HIY "剑气冲霄" HIW "」，刹时间剑风凌厉"
  #               "，" + wn + HIW "以直冲云霄之势，斩向$n\n" HIW "。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("parry");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 2);
  #              msg = COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
  #                                           HIR "$n" HIR "只见一道金光闪过，心中"
  #                                           "惊骇不已，但鲜血已从$n胸口喷出。\n"
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
