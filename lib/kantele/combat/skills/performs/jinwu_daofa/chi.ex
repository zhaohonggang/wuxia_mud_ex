defmodule Kantele.Combat.Skills.Performs.JinwuDaofa.Chi do
  @moduledoc """
  perform「赤焰暴长」（source jinwu-daofa/chi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 手持 blade →
  金乌刀法>=120 → 真气>=200 → 激发 blade 为金乌刀法 → 目标存活。
  （`.c` 有 `can_perform`，故设「已知此招」检查。）
  起手广播（含武器名）后攻击方无条件扣 150 真气 / 忙乱 3；
  命中判定 `ap/2 + random(ap) > 目标 parry`，其中 `ap = 金乌刀法`，
  若目标持 sword 且激发为雪山剑法则 `ap += ap/2`（并播报克星文案）。
  命中 `damage = ap/2 + random(ap/2)`、qi 伤 + 40% 外伤，播报
  `final()`「被这一刀劈个正中…鲜血四处飞溅」；未命中播报「镇定逾恒…化解」。

  差异（TODO(migrate)）：
  - 命中判定与伤害需目标 `parry`、雪山剑法克星判定需目标武器/激发，
    故全部在目标侧结算；攻击方消耗/忙乱（无条件）在起手侧处理；
  - `.c` 起手式把武器名插在中文串中间，按约定写成 `"A" <> weapon_name <> "B"`；
  - 雪山剑法克星文案属起手广播的一部分，此处并入目标侧命中/未命中广播
    （与「镇定逾恒…」同一条），文案与 `ap += ap/2` 的增益保留。
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
  alias Kantele.Combat.Messages

  @perform_id "jinwu-daofa/chi"
  @move_name "「赤焰暴长」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinwu-daofa")
    ap = Stats.skill(stats, "blade")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
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

  # LPC: if (userp(me) && ! me->query("can_perform/jinwu-daofa/chi"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  #          return notify_fail(CHI "只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #          || (string)weapon->query("skill_type") != "blade")
  #          return notify_fail("你使用的武器不对，无法施展" CHI "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "blade" do
      :ok
    else
      {:error, "你使用的武器不对，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("jinwu-daofa", 1) < 120)
  #          return notify_fail("你的金乌刀法不够娴熟，无法施展" CHI "。\n");
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jinwu-daofa") < 120 do
      {:error, "你的金乌刀法不够娴熟，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 200)
  #          return notify_fail("你现在真气不够，无法施展" CHI "。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("blade") != "jinwu-daofa")
  #          return notify_fail("你没有激发金乌刀法，无法施展" CHI "。\n");
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "blade") == "jinwu-daofa" do
      :ok
    else
      {:error, "你没有激发金乌刀法，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIY "$N" HIY "凝神聚气，将全身之力注入" + weapon->name() + HIY "刀身顺势劈下…"
  #      me->add("neili", -150); me->start_busy(3);
  defp apply_effect(conn, character, target) do
    weapon = Combat.weapon(character.meta.combat) || %{}
    weapon_name = Map.get(weapon, :name, "")

    msg =
      ["$N凝神聚气，将全身之力注入", weapon_name, "刀身顺势劈下，顿时一股凌厉的刀芒直贯$n而去。\n"]
      |> Enum.join("")

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 150}
    combat = Combat.start_busy(character.meta.combat, 3)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(msg, n1: character.name, n2: target.name)
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (objectp(weapon2 = target->query_temp("weapon"))
    #          && (string)weapon2->query("skill_type") == "sword"
    #          && target->query_skill_mapped("sword") == "xueshan-jian")
    #      { msg += 克星文案; ap += ap / 2; }
    target_weapon = Combat.weapon(character.meta.combat)
    {ap, special} = xueshan_special(target_weapon, stats, ap)

    # LPC: dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap) > dp)
    dp = Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: damage = ap / 2 + random(ap / 2);
      #      do_damage(me, target, WEAPON_ATTACK, damage, 40, (: final, ... :));
      damage = div(ap, 2) + Engine.rand(rng, div(ap, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 40, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC final(): "只听$n一声惨叫，被这一刀劈个正中，伤口深可见骨，鲜血四处飞溅。\n"
      text = special <> "只听$n一声惨叫，被这一刀劈个正中，伤口深可见骨，鲜血四处飞溅。\n"

      conn
      |> Broadcast.publish(Messages.interpolate(text, bindings))
      |> put_character(character)
    else
      # LPC: msg += "可$n却是镇定逾恒，一丝不乱，全神将此招化解开来。\n";
      text = special <> "可$n却是镇定逾恒，一丝不乱，全神将此招化解开来。\n"

      conn
      |> Broadcast.publish(Messages.interpolate(text, bindings))
      |> put_character(character)
    end
  end

  # LPC: 雪山剑法克星分支（起手广播的一部分，此处并入目标侧结算文案）
  defp xueshan_special(target_weapon, stats, ap) do
    if target_weapon != nil and
         Map.get(target_weapon, :skill_type) == "sword" and
         Stats.mapped(stats, "sword") == "xueshan-jian" do
      wn = Map.get(target_weapon, :name, "")

      msg =
        ["$n慌忙中忙以雪山剑法作出抵挡，哪知$N刀法竟似雪山剑法克星般，", wn,
         "焰芒霎时\n又暴涨数倍，完全封锁$n的所有剑招！\n"]
        |> Enum.join("")

      {ap + div(ap, 2), msg}
    else
      {ap, ""}
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define CHI "「" HIY "赤焰暴长" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # string final(object me, object target, int damage);
  # 
  # int perform(object me, object target)
  # {
  #         object weapon, weapon2;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/jinwu-daofa/chi"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CHI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "blade")
  #                 return notify_fail("你使用的武器不对，无法施展" CHI "。\n");
  # 
  #         if ((int)me->query_skill("jinwu-daofa", 1) < 120)
  #                 return notify_fail("你的金乌刀法不够娴熟，无法施展" CHI "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在真气不够，无法施展" CHI "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "jinwu-daofa")
  #                 return notify_fail("你没有激发金乌刀法，无法施展" CHI "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "凝神聚气，将全身之力注入" + weapon->name() +
  #               HIY "刀身顺势劈下，顿时一股凌厉的刀芒直贯$n" HIY "而去。\n"
  #               NOR;
  # 
  #         me->add("neili", -150);
  #         ap = me->query_skill("blade");
  #         dp = target->query_skill("parry");
  # 
  #         if (objectp(weapon2 = target->query_temp("weapon"))
  #            && (string)weapon2->query("skill_type") == "sword"
  #            && target->query_skill_mapped("sword") == "xueshan-jian")
  #     {
  #                 msg += HIY "$n" HIY "慌忙中忙以雪山剑法作出抵挡，哪知$N"
  #                        HIY "刀法竟似雪山剑法克星般，" + weapon->name() +
  #                        HIY "焰芒霎时\n又暴涨数倍，完全封锁$n" HIY "的所"
  #                        "有剑招！\n" NOR;
  #         ap += ap / 2;
  #     }
  # 
  #         me->start_busy(3);
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap / 2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 40,
  #                                            (: final, me, target, damage :));
  #         } else
  #         {
  #                 msg += HIC "可$n" HIC "却是镇定逾恒，一丝不乱，"
  #                        "全神将此招化解开来。\n" NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
  # 
  # string final(object me, object target, int damage)
  # {
  #         return  HIR "只听$n" HIR "一声惨叫，被这一刀劈个正中，伤口"
  #                 "深可见骨，鲜血四处飞溅。\n" NOR;
  # }
end
