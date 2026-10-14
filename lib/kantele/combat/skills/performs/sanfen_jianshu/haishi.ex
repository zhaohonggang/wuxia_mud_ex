defmodule Kantele.Combat.Skills.Performs.SanfenJianshu.Haishi do
  @moduledoc """
  perform「海市蜃楼」（对照 `kungfu/skill/sanfen-jianshu/haishi.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 持剑 → 基本剑法>=150 →
  三分剑术>=150 → 基本轻功>=150 → 真气>=200 → 目标存活。
  起手广播后攻击方无条件扣 150 真气并忙乱 `1 + random(2)`；命中判定
  `ap/2 + random(ap)` 对目标闪避（`ap = 基本剑法`）：命中则
  `damage = ap/2 + random(ap)`、外伤 70；再判 `ap/3 + random(ap)` 对同一
  闪避值，又中则 `damage = ap/2 + random(ap/2)`、外伤 80 并追加第二段
  刺中文案；未命中只发避招文案。

  差异（TODO(migrate)）：
  - 起手文案被 `+ weapon->name() +` 切成两段（`.c` 里 `逼向$n` 与 `！\n\n`
    之间只有颜色宏，抽取器已合并成一体），故起手用 list + `Enum.join("")`；
    第二段刺中文案只有一次名字插入，用 `<>` 即可；
  - `me->start_busy(1 + random(2))` 与 `neili -150` 都是无条件消耗，
    在攻击方 `apply_effect` 直接落账（不经 feedback）；
  - 两段命中的 `dp` 在 `.c` 里取自同一处（目标闪避），E 侧算一次复用；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底；
  - `.c` 的战斗门槛原文是「只能在战斗中**对**对手使用」（无「的」），逐字保留。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Vitals
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "sanfen-jianshu/haishi"
  @move_name "「海市蜃楼」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("sword");
    ap = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          weapon_name: weapon_name(combat),
          rng: rng
        }
      })

      apply_effect(conn, character, target, combat, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/sanfen-jianshu/haishi"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你不会使用#{@move_name}这一绝技！\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #      (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: "sword"} -> :ok
      _ -> {:error, "你使用的武器不对。\n"}
    end
  end

  # LPC: if (me->query_skill("sword", 1) < 150)
  #      if (me->query_skill("sanfen-jianshu", 1) < 150)
  #      if (me->query_skill("dodge",1) < 150)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "sword") < 150 ->
        {:error, "你的剑术修为不够，目前不能使用#{@move_name}！\n"}

      Stats.skill(stats, "sanfen-jianshu") < 150 ->
        {:error, "你的三分剑术的修为不够，不能使用这一绝技！\n"}

      Stats.skill(stats, "dodge") < 150 ->
        {:error, "你的轻功修为不够，无法使用#{@move_name}！\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够！\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
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

  # LPC: msg = HIW "$N" HIW "狂喝一声，手中" + weapon->name() +
  #              HIW "将到之际，突然圈转，使出三分剑术的独得之秘"
  #              "「海市蜃楼」，一招之中\n又另蕴涵三招，招式繁复狠"
  #              "辣，剑招虚虚实实，霍霍剑光径直逼向$n"
  #              HIW "！\n\n" NOR;
  #      me->add("neili", -150);
  #      me->start_busy(1 + random(2));
  #      …命中/失手在目标侧结算（dp 需目标闪避）…
  defp apply_effect(conn, character, target, combat, rng) do
    # .c 的起手只有一次名字插入（`+ weapon->name() +`），故 E 侧两段即可：
    # 前一段带名字（`<>` 不会被判据合并），后一段是 .c 里被颜色宏分隔、
    # 抽取器已合并成一体的整段。
    opener =
      [
        "$N狂喝一声，手中" <> weapon_name(combat),
        "将到之际，突然圈转，使出三分剑术的独得之秘「海市蜃楼」，一招之中\n又另蕴涵三招，招式繁复狠辣，剑招虚虚实实，霍霍剑光径直逼向$n！\n\n"
      ]
      |> Enum.join("")

    # LPC: me->add("neili", -150);（无条件）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 150, 0)}

    # LPC: me->start_busy(1 + random(2));（无条件）
    combat_after = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, 2))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat_after}}

    conn
    |> Broadcast.publish(opener, n1: character.name, n2: target.name)
    |> put_character(character)
    |> assign(:prompt, false)
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
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = Map.get(data, :ap, 0)
    weapon_name = Map.get(data, :weapon_name, "")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("dodge");
    dp = Stats.skill(character.meta.stats, "dodge")

    # LPC: if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 2 + random(ap);
      #      msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70, HIR "…");
      damage = div(ap, 2) + Engine.rand(rng, ap)

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 70, 100))

      conn =
        conn
        |> Broadcast.publish(
          "$n完全无法辨清虚实，只感一阵触心的刺痛，一声惨叫，已被$N凌厉的剑招刺中。\n",
          bindings
        )

      # LPC: if (ap / 3 + random(ap) > dp)
      if div(ap, 3) + Engine.rand(rng, ap) > dp do
        # LPC: damage = ap / 2 + random(ap / 2);
        #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
        #                                 HIR "\n$N" HIR "见$n" HIR "重创之下不禁破绽迭出，"
        #                                 HIR "冷笑一声，手中" + weapon->name() +
        #                                 HIR "挥洒，又攻出一剑，正中$p" HIR "胸口。\n" NOR);
        second = div(ap, 2) + Engine.rand(rng, div(ap, 2))

        vitals =
          vitals
          |> Vitals.damage(:qi, second)
          |> Vitals.wound(:qi, div(second * 80, 100))

        conn =
          Broadcast.publish(
            conn,
            "\n$N见$n重创之下不禁破绽迭出，冷笑一声，手中" <>
              weapon_name <> "挥洒，又攻出一剑，正中$p胸口。\n",
            bindings
          )

        conn
        |> put_character(%{character | meta: %{character.meta | vitals: vitals}})
      else
        conn
        |> put_character(%{character | meta: %{character.meta | vitals: vitals}})
      end
    else
      # LPC: msg += HIC "$n" HIC "见状身形急退，避开了$N" HIC "凌厉的攻击！\n" NOR;
      conn
      |> Broadcast.publish("$n见状身形急退，避开了$N凌厉的攻击！\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // haishi.c 海市蜃楼
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # //      int delta;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/sanfen-jianshu/haishi"))
  #                 return notify_fail("你不会使用「海市蜃楼」这一绝技！\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("「海市蜃楼」只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对。\n");
  # 
  #         if (me->query_skill("sword", 1) < 150)
  #                 return notify_fail("你的剑术修为不够，目前不能使用「海市蜃楼」！\n");
  # 
  #         if (me->query_skill("sanfen-jianshu", 1) < 150)
  #                 return notify_fail("你的三分剑术的修为不够，不能使用这一绝技！\n");
  # 
  #         if (me->query_skill("dodge",1) < 150)
  #                 return notify_fail("你的轻功修为不够，无法使用「海市蜃楼」！\n");
  #  
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "狂喝一声，手中" + weapon->name() +
  #               HIW "将到之际，突然圈转，使出三分剑术的独得之秘"
  #               "「海市蜃楼」，一招之中\n又另蕴涵三招，招式繁复狠"
  #               "辣，剑招虚虚实实，霍霍剑光径直逼向$n"
  #               HIW "！\n\n" NOR;
  # 
  #         me->add("neili", -150);
  #         ap = me->query_skill("sword");
  #         dp = target->query_skill("dodge");
  #         me->start_busy(1 + random(2));
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap);
  #                 msg += COMBAT_D->do_damage(me, target, REMOTE_ATTACK, damage, 70,
  #                                            HIR "$n" HIR "完全无法辨清虚实，只感一阵触心的刺痛，一声惨叫，已被$N"
  #                                            HIR "凌厉的剑招刺中。\n" NOR);
  #                 if (ap / 3 + random(ap) > dp)
  #                 {
  #                         //damage /= 2;
  #                         damage = ap / 2 + random(ap / 2);
  #                         msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 80,
  #                                                    HIR "\n$N" HIR "见$n" HIR "重创之下不禁破绽迭出，"
  #                                                    HIR "冷笑一声，手中" + weapon->name() +
  #                                                    HIR "挥洒，又攻出一剑，正中$p" HIR "胸口。\n" NOR);
  #                 }
  #         } else
  #         {
  #                 msg += HIC "$n" HIC "见状身形急退，避开了$N"
  #                        HIC "凌厉的攻击！\n" NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
