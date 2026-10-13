defmodule Kantele.Combat.Skills.Performs.JinwuGoufa.Duo do
  @moduledoc """
  perform「金钩夺魄」（source jinwu-goufa/duo.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 手持 sword 类武器 →
  激发 sword 为金蜈钩法 → 金蜈钩法>=160 → 真气>=300 → 目标存活。
  （`.c` 有 `can_perform`，故设「已知此招」检查。）
  起手广播（含武器名）后攻击方无条件扣 50 真气；命中判定
  `ap/2 + random(ap) > 目标 parry`，其中 `ap = 金蜈钩法 + sword/2`。
  命中分支：修为碾压即死（攻击方 max_neili > 2*目标 max_neili → qi=0 致死）、
  缴械（目标持武器且攻击方 sword > 目标 parry → 击落其兵器，落地未建模）、
  普通（damage = (ap+攻击方force)/2 + random(...)，40% 外伤）。
  命中攻击方扣 200 真气 / 忙乱 2+random(2)；未命中忙乱 4。

  差异（TODO(migrate)）：
  - 命中判定与伤害需目标 `parry`、缴械/修为碾压需攻击方属性，全部在目标侧结算；
    攻击方 `max_neili`/`sword`/`force`/`weapon_name` 经事件 data 传入；
  - 起手式把武器名插在中文串中间，按约定写成列表 + Enum.join("") 拆两段
    （C 侧 `"突然$N" HIY "一声冷哼，手中" + weapon->name() + …` 两段字面量）；
  - 缴械落地（weapon2->move(environment)）未建模；目标忙乱 2 已施加；
  - 修为碾压即死按 baihua_cuoquan/hong 先例置 qi=0（不主动置 dead 标记）；
  - 命中分支目标穴位（target->query("limbs") 随机项，无则「要害」）未建模，固定「要害」。
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

  @perform_id "jinwu-goufa/duo"
  @move_name "「金钩夺魄」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinwu-goufa")
    ap = Stats.skill(stats, "jinwu-goufa") + div(Stats.skill(stats, "sword"), 2)
    sword = Stats.skill(stats, "sword")
    force = Stats.skill(stats, "force")
    weapon_name = Map.get(Combat.weapon(combat) || %{}, :name, "")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_mapped(character),
         :ok <- check_levels(character),
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
          sword: sword,
          force: force,
          weapon_name: weapon_name,
          attacker_max_neili: character.meta.vitals.max_neili,
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

  # LPC: if (userp(me) && ! me->query("can_perform/jinwu-goufa/duo"))
  #          return notify_fail("你所使用的外功中没有这种功能。\n");
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  #          return notify_fail(DUO "只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #          || (string)weapon->query("skill_type") != "sword")
  #          return notify_fail("你使用的武器不对，无法施展" DUO "。\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "jinwu-goufa")
  #          return notify_fail("你没有激发金蜈钩法，无法施展" DUO "。\n");
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") == "jinwu-goufa" do
      :ok
    else
      {:error, "你没有激发金蜈钩法，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("jinwu-goufa", 1) < 160)
  #          return notify_fail("你的金蜈钩法还不够娴熟，无法施展" DUO "。\n");
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jinwu-goufa") < 160 do
      {:error, "你的金蜈钩法还不够娴熟，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili", 1) < 300)
  #          return notify_fail("你现在真气不够，无法施展" DUO "。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  #          return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: msg = HIY "$N" HIY "一声冷哼，手中" + weapon->name() +
  #          NOR + HIY "挥出，在空中划出个美丽的弧线，直攻$n" HIY "的要穴！\n" NOR;
  #      me->add("neili", -50);
  defp apply_effect(conn, character, target) do
    weapon_name = Map.get(Combat.weapon(character.meta.combat) || %{}, :name, "")

    msg =
      ["突然$N一声冷哼，手中", weapon_name, "挥出，在空中划出个美丽的弧线，直攻$n的要穴！\n"]
      |> Enum.join("")

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 50}
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
    attacker_sword = Map.get(data, :sword, 0)
    attacker_force = Map.get(data, :force, 0)
    attacker_max_neili = Map.get(data, :attacker_max_neili, 0)
    attacker_weapon_name = Map.get(data, :weapon_name, "")
    stats = character.meta.stats
    target_weapon = Combat.weapon(character.meta.combat)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry");
    #      if (ap / 2 + random(ap) > dp)
    dp = Stats.skill(stats, "parry")

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # ===== 命中分支 =====
      target_max_neili = character.meta.vitals.max_neili

      cond do
        # LPC: if (me->query("max_neili") > target->query("max_neili") * 2)
        attacker_max_neili > target_max_neili * 2 ->
          # 修为碾压即死：damage = -1 → target->die(me)
          vitals = %{character.meta.vitals | qi: 0}
          character = %{character | meta: %{character.meta | vitals: vitals}}

          Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 2))

          # LPC: 仅由颜色宏 NOR/RED 分隔，工具 join_adjacent 会合并为单条，
          # 故此处写单字面量（不可拆列表，否则 E 侧多出 2 条）
          msg = "只见$N这一击来势好快，寒光一闪，正钩中$n的咽喉，$n一声惨叫，软绵绵的瘫了下去。\n( $n受伤过重，已经有如风中残烛，随时都可能断气。)\n"

          conn
          |> Broadcast.publish(Messages.interpolate(msg, bindings))
          |> put_character(character)

        # LPC: else if (objectp(weapon2 = target->query_temp("weapon"))
        #               && me->query_skill("sword") > target->query_skill("parry"))
        target_weapon != nil and attacker_sword > dp ->
          # 缴械：击落目标兵器（落地未建模），目标忙乱 2
          combat = Combat.start_busy(character.meta.combat, 2)
          character = %{character | meta: %{character.meta | combat: combat}}

          Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 2))

          weapon2_name = Map.get(target_weapon, :name, "")

          msg =
            ["只听“嗤啦”一声，$n手腕被钩个正中，手中", weapon2_name, "再也捉拿不住，脱手而飞！\n"]
            |> Enum.join("")

          conn
          |> Broadcast.publish(Messages.interpolate(msg, bindings))
          |> put_character(character)

        # LPC: else（默认普通伤害）
        true ->
          # LPC: damage = ap + me->query_skill("force");
          #      damage = damage / 2 + random(damage / 2);
          damage = ap + attacker_force
          damage = div(damage, 2) + Engine.rand(rng, div(damage, 2))

          vitals =
            character.meta.vitals
            |> Vitals.damage(:qi, damage)
            |> Vitals.wound(:qi, div(damage * 40, 100))

          character = %{character | meta: %{character.meta | vitals: vitals}}

          # LPC: limb 取 target->query("limbs") 随机项，无则「要害」（未建模，固定要害）
          limb = "要害"

          Performs.feedback(attacker, 200, 2 + Engine.rand(rng, 2))

          # LPC: pmsg = "$n飞身躲闪…" + weapon->name() + "正钩在$n" + limb + "上，顿时鲜血狂溅而出。\n";
          #      do_damage(me, target, WEAPON_ATTACK, damage, 40, pmsg);
          msg =
            ["$n飞身躲闪，然而只听“嗤啦”一声，$N的", attacker_weapon_name,
             "正钩在$n", limb, "上，顿时鲜血狂溅而出。\n"]
            |> Enum.join("")

          conn
          |> Broadcast.publish(Messages.interpolate(msg, bindings))
          |> put_character(character)
      end
    else
      # LPC: msg += "可是$p看破了$P的企图，避开了这一招。\n";
      #      me->start_busy(4);
      Performs.feedback(attacker, 0, 4)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$p看破了$P的企图，避开了这一招。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DUO "「" HIY "金钩夺魄" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon, weapon2;
  #         int damage;
  #         string  msg;
  #         string  pmsg;
  #         string *limbs;
  #         string  limb;
  #         int ap, dp;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/jinwu-goufa/duo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DUO "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，无法施展" DUO "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "jinwu-goufa") 
  #                 return notify_fail("你没有激发金蜈钩法，无法施展" DUO "。\n");
  # 
  #         if ((int)me->query_skill("jinwu-goufa", 1) < 160)
  #                 return notify_fail("你的金蜈钩法还不够娴熟，无法施展" DUO "。\n");
  #                                 
  #         if ((int)me->query("neili", 1) < 300)
  #                 return notify_fail("你现在真气不够，无法施展" DUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "突然$N" HIY "一声冷哼，手中" + weapon->name() +
  #               NOR + HIY "挥出，在空中划出个美丽的弧线，直攻$n" HIY
  #               "的要穴！\n" NOR;
  #         me->add("neili", -50);
  # 
  #         ap = me->query_skill("jinwu-goufa", 1) +
  #              me->query_skill("sword", 1) / 2;
  #         dp = target->query_skill("parry");
  # 
  #         me->want_kill(target);
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->start_busy(2 + random(2));
  #                 me->add("neili", -200);
  #                 damage = 0;
  # 
  #                 if (me->query("max_neili") > target->query("max_neili") * 2)
  #                 {
  #                         msg += HIR "只见$N" HIR "这一击来势好快，寒光一"
  #                                "闪，正钩中$n" HIR "的咽喉，$n" HIR "一声"
  #                                "惨叫，软绵绵的瘫了下去。\n" NOR "( $n" RED
  #                                "受伤过重，已经有如风中残烛，随时都可能断"
  #                                "气。" NOR ")\n";
  #                         damage = -1;
  #                 } else
  #                 if (objectp(weapon2 = target->query_temp("weapon")) &&
  #                 me->query_skill("sword") > target->query_skill("parry"))
  #                 {
  #                         // if(userp(me))
  #                         msg += HIR "只听“嗤啦”一声，$n" HIR "手腕被"
  #                               "钩个正中，手中" + weapon2->name() + NOR
  #                               + HIR "再也捉拿不住，脱手而飞！\n" NOR;
  #                         me->start_busy(2 + random(2));
  #                         target->start_busy(2);
  #                         weapon2->move(environment(target));
  #                 } else
  #                 {
  #                         damage = ap + (int)me->query_skill("force");
  #                         damage = damage / 2 + random(damage / 2);
  #                         
  #                         if (arrayp(limbs = target->query("limbs")))
  #                                 limb = limbs[random(sizeof(limbs))];
  #                         else
  #                                 limb = "要害";
  #                         pmsg = HIR "$n" HIR "飞身躲闪，然而只听“嗤啦”"
  #                                "一声，$N" HIR "的" + weapon->name()+ NOR
  #                                + HIR "正钩在$n" HIR + limb + "上，顿时鲜"
  #                                "血狂溅而出。\n" NOR;
  #                         msg += COMBAT_D->do_damage(me, target,
  #                                WEAPON_ATTACK, damage, 40, pmsg);
  #                 }
  #         } else 
  #         {
  #                 me->start_busy(4);
  #                 msg += CYN "可是$p" CYN "看破了$P"
  #                        CYN "的企图，避开了这一招。\n"NOR;
  #         }
  # 
  #         message_combatd(msg, me, target);
  #         if (damage < 0) target->die(me);
  # 
  #         return 1;
  # }
end
