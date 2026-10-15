defmodule Kantele.Combat.Skills.Performs.ChanhunSuo.Duo do
  @moduledoc """
  夺魂势「duo」（对照 `kungfu/skill/chanhun-suo/duo.c`，inherit F_SSERVER）

  缠魂锁法攻击绝招：要求内力 >= 220、内功 force >= 130、chanhun-suo >= 100、
  武器为鞭(whip) 且已激发映射；命中后扣攻击方内力 180（未命中扣 100），
  对目标造成外伤，白丝材质武器且目标未忙乱时追加缠缚。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "chanhun-suo/duo"
  @move_name "「夺魂势」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats),
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
      {:error, "你使用的外功中没有这种功能。\n"}
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

    if weapon && Map.get(weapon, :skill_type) == "whip" do
      :ok
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 130 do
      {:error, "你的内功火候不够，使不了#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "chanhun-suo") < 100 do
      {:error, "你的缠魂索功力太浅，使不了#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 220 do
      {:error, "你的真气不够，无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "whip") == "chanhun-suo" do
      :ok
    else
      {:error, "你没有激发缠魂索法，使不了#{@move_name}。\n"}
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人快照若无 meta 可查时恒判存活，由目标侧 combat/perform-incoming 兜底。
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
    weapon_material = weapon && Map.get(weapon, :material)

    # LPC: msg = HIY "$N" HIY "诡异的一笑，手中" + weapon->name() +
    #            HIY "抖得笔直，劈向$n" HIY "手腕，可是待到中途却又停滞，转往$n"
    #            HIY "胸口挥去！\n" NOR;
    part1 = "$N诡异的一笑，手中"
    part2 = "抖得笔直，劈向$n手腕，可是待到中途却又停滞，转往$n胸口挥去！\n"
    start_msg = part1 <> (weapon_name || "") <> part2

    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "whip") + Stats.skill(stats, "force") + Stats.skill(stats, "poison")
    dp = Stats.skill(target.meta.stats, "force") + Stats.skill(target.meta.stats, "parry")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        weapon_name: weapon_name || "",
        weapon_material: weapon_material || "",
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
    stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    # LPC: if (ap / 2 + random(ap) > dp)
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp

    if hit do
      # LPC: damage = ap + random(ap / 3);  me->add("neili", -180);  me->start_busy(2);
      #      COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75, msg);
      damage = ap + Engine.rand(rng, div(ap, 3))

      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 3, 4))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: "结果$n" "一声惨叫，未能看破$N" "的企图，被这一鞭硬击在胸口，鲜血飞溅，皮肉绽开！\n"
      hit_msg = "结果$n一声惨叫，未能看破$N的企图，被这一鞭硬击在胸口，鲜血飞溅，皮肉绽开！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      # LPC: dp += target->query_skill("martial-cognize", 1) * 2;
      #      if (! target->is_busy() && weapon->query("material") == "white silk" &&
      #          ap / 2 + random(ap) > dp)
      dp2 = dp + Stats.skill(stats, "martial-cognize") * 2
      weapon_material = Map.get(data, :weapon_material, "")
      weapon_name = Map.get(data, :weapon_name, "")

      extra_hit =
        not Combat.busy?(character.meta.combat) and
          weapon_material == "white silk" and
          div(ap, 2) + Engine.rand(rng, ap) > dp2

      if extra_hit do
        # LPC: target->start_busy(1 + random(4));
        character_combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 4))
        character = %{character | meta: %{character.meta | combat: character_combat}}

        # LPC: message_vision(HIW "$N" HIW "一抖，手中的" + weapon->name() +
        #    HIW "“嗖“的串了出来，隐隐然缠向$n" HIW "。\n$n" HIW
        #    "大吃一惊，急忙退后，闪去这一招。\n" NOR, me, target);
        part1 = "$N一抖，手中的"
        part2 = "“嗖“的串了出来，隐隐然缠向$n。\n$n大吃一惊，急忙退后，闪去这一招。\n"
        wrap_msg = part1 <> weapon_name <> part2
        conn = Broadcast.publish(conn, wrap_msg, n1: attacker.name, n2: character.name)
      end

      # 攻击方补扣内力 180、忙乱 2 轮（跨进程回传）
      Performs.feedback(attacker, 180, 2)
    else
      # LPC: me->add("neili", -100);  me->start_busy(3);
      #      "可是$p" "飞身一跃而起，躲避开了" "$P" "的攻击！\n"
      miss_msg = "可是$p飞身一跃而起，躲避开了$P的攻击！\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      # 攻击方补扣内力 100、忙乱 3 轮
      Performs.feedback(attacker, 100, 3)
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
  # #define DUO "「" HIC "夺魂势" NOR "」"
  #
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  #
  #         if (playerp(me) && ! me->query("can_perform/chanhun-suo/duo"))
  #                 return notify_fail("你使用的外功中没有这种功能。\n");
  #
  #         if (! target) target = offensive_target(me);
  #
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DUO "只能在战斗中对对手使用。\n");
  #
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             weapon->query("skill_type") != "whip")
  #                 return notify_fail("你使用的武器不对。\n");
  #
  #         if (me->query_skill("force", 1) < 130)
  #                 return notify_fail("你的内功火候不够，使不了" DUO "。\n");
  #
  #         if (me->query_skill("chanhun-suo", 1) < 100)
  #                 return notify_fail("你的缠魂索功力太浅，使不了" DUO "。\n");
  #
  #         if (me->query("neili") < 220)
  #                 return notify_fail("你的真气不够，无法使用" DUO "。\n");
  #
  #         if (me->query_skill_mapped("whip") != "chanhun-suo")
  #                 return notify_fail("你没有激发缠魂索法，使不了" DUO "。\n");
  #
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #         msg = HIY "$N" HIY "诡异的一笑，手中" + weapon->name() +
  #               HIY "抖得笔直，劈向$n" HIY "手腕，可是待到中途却又停滞，转往$n"
  #               HIY "胸口挥去！\n" NOR;
  #
  #         ap = me->query_skill("whip") + me->query_skill("force") + me->query_skill("poison");
  #         dp = target->query_skill("force") + target->query_skill("parry");
  #
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap + random(ap / 3);
  #                 me->add("neili", -180);
  #                 me->start_busy(2);
  #
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 75,
  #                                            HIR "结果$n" HIR "一声惨叫，未能看破$N"
  #                                            HIR "的企图，被这一鞭硬击在胸口，鲜血飞"
  #                                            "溅，皮肉绽开！\n" NOR);
  #                 message_combatd(msg, me, target);
  #                 //if (ap > 400) ap = 400;
  #                 dp += target->query_skill("martial-cognize", 1) * 2;
  #                 if (! target->is_busy() &&
  #                     weapon->query("material") == "white silk" &&
  #                     ap / 2 + random(ap) > dp)
  #                 {
  #                         target->start_busy(1 + random(4));
  #                         message_vision(HIW "$N" HIW "一抖，手中的" + weapon->name() +
  #                                        HIW "“嗖“的串了出来，隐隐然缠向$n"
  #                                        HIW "。\n$n" HIW "大吃一惊，急忙退后，闪去这一招。\n" NOR,
  #                                        me, target);
  #                 }
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "飞身一跃而起，躲避开了"
  #                        CYN "$P" CYN "的攻击！\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  #
  #         return 1;
  # }
end
