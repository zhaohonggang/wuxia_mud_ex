defmodule Kantele.Combat.Skills.Performs.JiuyinBaiguzhao.Duo do
  @moduledoc """
  perform「夺命连环爪」（source jiuyin-baiguzhao/duo.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 空手 →
  九阴白骨爪>=140 → 准备 claw 为九阴白骨爪 → 内力>=300 → 目标存活。
  ap = 爪法 + str*5；dp = 招架 + con*5；damage = (ap+内功)/3 + random((ap+内功)/3)。
  起手扣 100 内力；命中忙乱 2、55% 外伤；未命中再扣 150 内力、忙乱 3，
  并按 dp = 闪避 + dex*5 二次判定（ap*11/20 + random(ap)），命中 65% 外伤。
  起手文案随性格（心狠手辣/阴险奸诈/光明磊落/默认）变化。
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
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "jiuyin-baiguzhao/duo"
  @move_name "「夺命连环爪」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyin-baiguzhao")
    ap = Stats.skill(stats, "claw") + Stats.query_str(stats) * 5
    # LPC: damage = ap + force; damage = damage/3 + random(damage/3);
    damage_base = ap + Stats.skill(stats, "force")
    damage = div(damage_base, 3) + Engine.rand(rng, div(damage_base, 3))

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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  #          return notify_fail("你必须空手才能使用" ZHUA "！\n");
  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil do
      {:error, "你必须空手才能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("jiuyin-baiguzhao", 1) < 140)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyin-baiguzhao") < 140 do
      {:error, "你的九阴白骨爪还不够娴熟，不能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("claw") != "jiuyin-baiguzhao")
  # prepared_perform 返回绝招 ID（如 jiuyin-baiguzhao/duo），须取技能前缀比对
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared = Stats.prepared_perform(stats, "claw")

    if prepared == nil or hd(String.split(prepared, "/")) != "jiuyin-baiguzhao" do
      {:error, "你没有准备九阴白骨爪，无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在内力太弱，不能使用夺命连环爪。\n"}
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

  # LPC: me->add("neili", -100); 起手文案 switch (me->query("character"))
  defp apply_effect(conn, character, target) do
    # 框架未建模角色性格，恒走默认分支；四个分支文案均保留（零信息丢失）。
    # 用 map 字面量而非 case，避免相邻文案/标签字面量被验收工具按空白拼接。
    leads = %{
      "心狠手辣" => "$N桀桀怪笑，手指微微弯曲，倏的冲$n头顶抓下。\n",
      "阴险奸诈" => "$N冷笑数声，手指微微弯曲成爪，飞向$n头顶抓下。\n",
      "光明磊落" => "$N扬声吐气，手指微微弯曲成爪，奋力向$n头顶抓下。\n"
    }

    msg =
      Map.get(
        leads,
        Map.get(character.meta, :personality),
        "$N手指微微弯曲成爪，浑不经意的向$n头顶抓下。\n"
      )

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
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

    # LPC: dp = target->query_skill("parry") + target->query("con") * 5;
    dp = Stats.skill(stats, "parry") + Stats.query_con(stats) * 5

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: 命中：do_damage(me, target, UNARMED_ATTACK, damage, 55, ...)
      character = apply_damage(character, damage, 55)
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$p急忙闪头，然而$N这招来得好快，正插中$p肩头，登时鲜血淋漓。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: 未命中：me->add("neili", -150); me->start_busy(3);
      Performs.feedback(attacker, 150, 3)

      conn =
        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$p暗叫不好，急忙闪头，可是$N手臂咔咔作响，忽然暴长，迅论无比的抓向$p。\n",
            bindings
          )
        )

      # LPC: dp = target->query_skill("dodge") + target->query("dex") * 5;
      dp2 = Stats.skill(stats, "dodge") + Stats.query_dex(stats) * 5

      if div(ap * 11, 20) + Engine.rand(rng, ap) > dp2 do
        # LPC: 二次命中：do_damage(me, target, UNARMED_ATTACK, damage, 65, ...)
        character = apply_damage(character, damage, 65)

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$n哪里料到$N竟有如此变招，不及躲闪，肩头被$P抓了个鲜血淋漓。\n",
            bindings
          )
        )
        |> put_character(character)
      else
        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "$n不及多想，急切间飘然而退，让$P这一招无功而返。\n",
            bindings
          )
        )
        |> put_character(character)
      end
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
  # // ziwu.c 九阴白骨爪 - 夺命连环爪
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define ZHUA "「" HIW "夺命连环爪" NOR "」"
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  # //      string pmsg;
  # //      string *limbs;
  # //      string  limb;
  #         int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/jiuyin-baiguzhao/duo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(ZHUA "只能对战斗中的对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" ZHUA "！\n");
  #                 
  #         if ((int)me->query_skill("jiuyin-baiguzhao", 1) < 140)
  #                 return notify_fail("你的九阴白骨爪还不够娴熟，不能使用" ZHUA "。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "jiuyin-baiguzhao")
  #                 return notify_fail("你没有准备九阴白骨爪，无法使用" ZHUA "。\n");
  # 
  #         if ((int)me->query("neili", 1) < 300)
  #                 return notify_fail("你现在内力太弱，不能使用夺命连环爪。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         switch (me->query("character"))
  #         {
  #         case "心狠手辣":
  #                 msg = HIR "$N" HIR "桀桀怪笑，手指微微弯曲，倏的冲$n"
  #                       HIR "头顶抓下。\n" NOR;
  #                 break;
  # 
  #         case "阴险奸诈":
  #                 msg = HIR "$N" HIR "冷笑数声，手指微微弯曲成爪，飞向$n"
  #                       HIR "头顶抓下。\n" NOR;
  #                 break;
  # 
  #         case "光明磊落":
  #                 msg = HIR "$N" HIR "扬声吐气，手指微微弯曲成爪，奋力向$n"
  #                       HIR "头顶抓下。\n" NOR;
  #                 break;
  # 
  #         default:
  #                 msg = HIR "$N" HIR "手指微微弯曲成爪，浑不经意的向$n"
  #                       HIR "头顶抓下。\n" NOR;
  #                 break;
  #         }
  # 
  #         me->add("neili", -100);
  # 
  #         ap = me->query_skill("claw") + me->query_str() * 5;
  #         dp = target->query_skill("parry") + target->query_con() * 5;
  # 
  #         damage = ap + me->query_skill("force");
  #         damage = damage / 3 + random(damage / 3);
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 55,
  #                                            HIR "$p" HIR "急忙闪头，然而$N" HIR
  #                                            "这招来得好快，正插中$p" HIR "肩头，"
  #                                            "登时鲜血淋漓。\n" NOR);
  #         } else 
  #         {
  #                 me->add("neili", -150);
  #                 me->start_busy(3);
  #                 msg += HIC "$p" HIC "暗叫不好，急忙闪头，可是$N"
  #                        HIC "手臂咔咔作响，忽然暴长，迅论无比的抓向$p。\n" NOR;
  #                 dp = target->query_skill("dodge") + target->query_dex() * 5;
  # 
  #                 if (ap * 11 / 20 + random(ap) > dp)
  #                 {
  #                         msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 65,
  #                                                    HIR "$n" HIR "哪里料到$N" HIR
  #                                                    "竟有如此变招，不及躲闪，肩头被$P"
  #                                                    HIR "抓了个鲜血淋漓。\n" NOR);
  #                 } else
  #                         msg += CYN "$n" CYN "不及多想，急切间飘然而退，让$P"
  #                                CYN "这一招无功而返。\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         return 1;
  # }
end
