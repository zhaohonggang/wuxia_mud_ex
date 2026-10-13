defmodule Kantele.Combat.Skills.Performs.LingsheZhangfa.Wanshi do
  @moduledoc """
  perform「千蛇万噬」（source lingshe-zhangfa/wanshi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 持杖类武器 → 灵蛇杖法>=160 →
  真气>=400 → 激发 staff 为灵蛇杖法 → 目标存活。
  前置广播后攻击方忙乱 `2+random(4)`；命中判定 `ap/3 + random(ap)` > 目标 `parry`
  （目标为正派时 ap 再加 1/10）；命中扣 350 真气、伤害 `ap + random(ap/4)`
  （50% 外伤比例）并附 final() 的 jing 伤害（damage/4 伤、damage/8 创）与拐杖文案；
  未命中扣 100 真气、化解文案。

  差异（TODO(migrate)）：
  - `COMBAT_D->do_damage(WEAPON_ATTACK, damage, 50, final)` 折算为
    `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage, 2))`；
  - final() 的 `receive_damage("jing", damage/4)` / `receive_wound("jing", damage/8)`
    折算为 `Vitals.damage(:jing, div(damage,4)) |> Vitals.wound(:jing, div(damage,8))`；
  - `target->is_good()`（`query("shen")>500 || query("shen_type")==1`）框架只建模
    `character.meta.shen`，取 `shen > 500`，`shen_type` 未建模；
  - 灵蛇杖专属淬毒（`LINGSHE_ZHANG->query("poison_applied")`、
    `apply_condition("snake_poison", ap/2)`）框架未建模，仅保留注释。
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

  @perform_id "lingshe-zhangfa/wanshi"
  @move_name "「千蛇万噬」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "lingshe-zhangfa")
    ap = Stats.skill(stats, "staff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
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
          weapon_name: weapon_name,
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

  # LPC: if (userp(me) && ! me->query("can_perform/lingshe-zhangfa/wanshi"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你还不会使用#{@move_name}这一绝技。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon) || weapon->query("skill_type") != "staff")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "staff" do
      :ok
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("lingshe-zhangfa", 1) < 160)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "lingshe-zhangfa") < 160 do
      {:error, "你的灵蛇杖法不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 400)
  defp check_resources(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你现在真气不够，无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("staff") != "lingshe-zhangfa")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "staff") == "lingshe-zhangfa" do
      :ok
    else
      {:error, "你没有激发灵蛇杖法，无法使用#{@move_name}！\n"}
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIB "$N" HIB "手持" + weapon->name() + HIB "，直捣$n中宫" HIB "。\n" NOR;
    # 前后两段字面量被 weapon->name() 的 + 分隔，用 <> 拆段复现（不合并）。
    # me->start_busy(2 + random(4)) 与分支 neili 由目标侧 feedback 回执。
    weapon_name =
      case Combat.weapon(character.meta.combat) do
        nil -> ""
        weapon -> Map.get(weapon, :name)
      end

    conn =
      Broadcast.publish(
        conn,
        "$N手持" <> weapon_name <> "，直捣$n中宫。\n",
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
    weapon_name = Map.get(data, :weapon_name, "")
    stats = character.meta.stats
    dp = Stats.skill(stats, "parry")

    # LPC: if (target->is_good()) ap += ap / 10;
    # is_good() = query("shen") > 500 || query("shen_type") == 1；框架仅建模 shen。
    shen = Map.get(character.meta, :shen, 0) || 0
    ap = if shen > 500, do: ap + div(ap, 10), else: ap

    # LPC: me->start_busy(2 + random(4));
    #      if (ap / 3 + random(ap) > dp)
    busy = 2 + Engine.rand(rng, 4)
    hit? = div(ap, 3) + Engine.rand(rng, ap) > dp

    # LPC: damage = ap + random(ap / 4);
    #      COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50, (: final :));
    #      me->add("neili", -350);
    {vitals, msg, neili_cost} =
      if hit? do
        damage = ap + Engine.rand(rng, div(ap, 4))

        v =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage, 2))
          # LPC final(): receive_damage("jing", damage / 4) / receive_wound("jing", damage / 8)
          |> Vitals.damage(:jing, div(damage, 4))
          |> Vitals.wound(:jing, div(damage, 8))

        {v, final_message(weapon_name), 350}
      else
        # LPC: me->add("neili", -100);
        {character.meta.vitals, "可是$p看破了$P的企图，一缩胸，急退三步，避开了这一招。\n", 100}
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    Performs.feedback(attacker, neili_cost, busy)

    conn
    |> Broadcast.publish(msg, n1: attacker.name, n2: character.name)
    |> put_character(character)
  end

  # LPC: string final(object me, object target, int damage, object weapon)
  #      return HIW "哪知" HIW + weapon->name() + HIW "突然拐弯，绕到$p" HIW "背后，"
  #             "重重地击在了$p" HIW "的颈脖子上！\n"
  #             HIB "$p" HIB ""噗"地吐出一口鲜血，随" HIB "即只觉脖颈一阵麻痒。\n" NOR;
  # 中间各段被 weapon->name() 与颜色宏 + 分隔，C 侧 join_adjacent 只合并空白分隔的
  # 相邻段；这里 weapon_name 前后用 <>，其余段之间用 list + Enum.join("") 复现。
  defp final_message(weapon_name) do
    [
      "哪知",
      weapon_name,
      "突然拐弯，绕到$p背后，重重地击在了$p的颈脖子上！\n$p“噗”地吐出一口鲜血，随即只觉脖颈一阵麻痒。\n"
    ]
    |> Enum.join("")
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // wanshi.c 灵蛇杖法「千蛇万噬」
  # // by jeeny
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # //#define LINGSHE_ZHANG    "/clone/weapon/lingshe"
  # #define LINGSHE_ZHANG    "d/baituo/obj/lingshezhang"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage, object weapon);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  #         
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/lingshe-zhangfa/wanshi"))
  #                 return notify_fail("你还不会使用「千蛇万噬」这一绝技。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「千蛇万噬」只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "staff")
  #                 return notify_fail("你使用的武器不对。\n");
  # 
  # 
  #         if ((int)me->query_skill("lingshe-zhangfa", 1) < 160)
  #                 return notify_fail("你的灵蛇杖法不够娴熟，不会使用「千蛇万噬」。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，无法使用「千蛇万噬」。\n");
  # 
  #         if (me->query_skill_mapped("staff") != "lingshe-zhangfa") 
  #                 return notify_fail("你没有激发灵蛇杖法，无法使用「千蛇万噬」！\n");
  # 
  #         if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIB "$N" HIB "手持" + weapon->name() + HIB "，直捣$n中宫" HIB "。\n" NOR;
  # 
  #         ap = me->query_skill("staff");
  #         dp = target->query_skill("parry");
  #         
  #         if (target->is_good()) ap += ap / 10;
  # 
  #         me->start_busy(2 + random(4));
  #         if (ap / 3 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 4);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 50,
  #                                            (: final, me, target, damage, weapon :));
  #                 me->add("neili", -350);
  #                 if (LINGSHE_ZHANG->query("poison_applied") > 0 && weapon == find_object("/d/baituo/obj/lingshezhang"))
  #                 {
  #                         target->apply_condition("snake_poison", ap / 2, me);
  #                         LINGSHE_ZHANG->add("poison_applied", -1);
  #                 }
  #         } else
  #         {
  #                 msg += HIG "可是$p" HIG "看破了$P" HIG "的企图，一"
  #                        "缩胸，急退三步，避开了这一招。\n" NOR;
  #                 me->add("neili", -100);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage, object weapon)
  # {
  #         target->receive_damage("jing", damage / 4, me);
  #         target->receive_wound("jing", damage / 8, me);
  #         return HIW "哪知" HIW + weapon->name() + HIW "突然拐弯，绕到$p" HIW "背后，"
  #                 "重重地击在了$p" HIW "的颈脖子上！\n"
  #                 HIB "$p" HIB "“噗”地吐出一口鲜血，随"
  #                 HIB "即只觉脖颈一阵麻痒。\n" NOR;
  # }
end
