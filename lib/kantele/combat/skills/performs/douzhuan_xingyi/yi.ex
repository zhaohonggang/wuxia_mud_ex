defmodule Kantele.Combat.Skills.Performs.DouzhuanXingyi.Yi do
  @moduledoc """
  perform「斗转星移」（source douzhuan-xingyi/yi.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 斗转星移>=100 → 紫徽心法>=100 →
  真气>=60 → 目标存活 → 目标未持针类兵器。
  攻击方扣 50 真气、忙乱 2，并广播起手式（`$N运起紫徽心法…牵引着$n的招式！`）。

  对抗：`ap = 斗转星移 + 紫徽心法/2`，`dp = 目标 force`。
  - `ap > dp*13/10`：牵引成功，目标自伤 `max_qi/2`（qi 伤 + 创伤各半）；
  - 否则 `ap/3 + random(ap) < dp`：目标内功深厚，未被带动；
  - 否则攻击方无其它敌人：招式落空，未酿成大祸；
  - 否则：目标招式转向攻击方另一敌人（连击 `2 + random(3)` 次）。

  差异（TODO(migrate)）：
  - `der = me->query_enemy() - {target}` 在攻击方进程选取，随事件下发；
    目标侧结算分支文案，并以目标自身的 `combat/incoming` 快照连攻 `der`
    （`der->start_busy(1)` 需 der 进程状态，未建模）；
  - `.c` 把起手式与分支文案拼成一条 `message_combatd`；因分支判定依赖目标
    `force`，本版拆为攻击方起手广播 + 目标侧分支广播两条（起手文本本身以 `\\n`
    收尾，观感一致）；
  - 目标持针类兵器（`target->query_temp("weapon")`）的门槛在攻击方进程无
    目标武器快照，若敌人引用带 `meta` 则照常判定，否则跳过；
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
  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Messages

  @perform_id "douzhuan-xingyi/yi"
  @move_name "「斗转星移」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "douzhuan-xingyi")
    # LPC: ap = me->query_skill("douzhuan-xingyi", 1) + me->query_skill("zihui-xinfa", 1) / 2;
    ap = level + div(Stats.skill(stats, "zihui-xinfa"), 2)

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target),
         :ok <- check_target_weapon(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          skill: level,
          ap: ap,
          der: other_enemy(combat, target, rng),
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

  # LPC: if (userp(me) && ! me->query("can_perform/douzhuan-xingyi/yi"))
  #         return notify_fail("你还不会使用斗转星移。\n");
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你还不会使用斗转星移。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (query_skill("douzhuan-xingyi",1) < 100) ... "你的斗转星移不够娴熟，不会使用绝招。\n"
  #         (query_skill("zihui-xinfa",1) < 100)    ... "你的紫徽心法修为还不到家，难以运用「斗转星移」。\n"
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "douzhuan-xingyi") < 100 ->
        {:error, "你的斗转星移不够娴熟，不会使用绝招。\n"}

      Stats.skill(stats, "zihui-xinfa") < 100 ->
        {:error, "你的紫徽心法修为还不到家，难以运用#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 60) return notify_fail("你现在真气不够，无法使用「斗转星移」。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 60 do
      {:error, "你现在真气不够，无法使用#{@move_name}。\n"}
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

  # LPC: weapon = target->query_temp("weapon");
  #      if (weapon && weapon->query("skill_type") == "pin")
  #          return notify_fail("对方手里拿的是一根小小的针，你没有办法施展「斗转星移」。\n");
  # 敌人引用无武器快照，若带 meta 则照常判定，否则跳过（同 dead?/1 的保守兜底）。
  defp check_target_weapon(target) do
    case target do
      %{meta: %{combat: combat}} ->
        case Combat.weapon(combat) do
          %{skill_type: "pin"} ->
            {:error, "对方手里拿的是一根小小的针，你没有办法施展#{@move_name}。\n"}

          _ ->
            :ok
        end

      _ ->
        :ok
    end
  end

  # LPC: obs = me->query_enemy() - ({ target }); der = obs[random(sizeof(obs))];
  defp other_enemy(combat, target, rng) do
    others = Enum.reject(combat.enemies, fn enemy -> enemy.id == target.id end)

    case others do
      [] -> nil
      list -> Enum.at(list, Engine.rand(rng, length(list)))
    end
  end

  defp apply_effect(conn, character, target) do
    # LPC: me->start_busy(2); me->add("neili", -50);
    #      msg = HIM "$N运起紫徽心法，内力自气海穴出，经由任督二脉奔流而出，巧妙的牵引着$n的招式！\n";
    #      message_combatd(msg, me, target);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = Combat.start_busy(character.meta.combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish(
      "$N运起紫徽心法，内力自气海穴出，经由任督二脉奔流而出，巧妙的牵引着$n的招式！\n",
      n1: character.name,
      n2: target.name
    )
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
    der = Map.get(data, :der)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force");
    dp = Stats.skill(stats, "force")

    cond do
      # LPC: if (ap > dp * 13 / 10) —— 使目标打自己
      ap > div(dp * 13, 10) ->
        vitals = character.meta.vitals
        # LPC: damage = target->query("max_qi");
        #      target->receive_damage("qi", damage / 2, me);
        #      target->receive_wound("qi", damage / 2, me);
        damage = vitals.max_qi

        vitals =
          vitals
          |> Vitals.damage(:qi, div(damage, 2))
          |> Vitals.wound(:qi, div(damage, 2))

        character = %{character | meta: %{character.meta | vitals: vitals}}

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "结果$p一招击出，正好打在自己的要害上，不禁一声惨叫，摔跌开去。\n",
            bindings
          )
        )
        |> put_character(character)

      # LPC: else if (ap / 3 + random(ap) < dp) —— 对方内功深厚，未被带动
      div(ap, 3) + Engine.rand(rng, ap) < dp ->
        conn
        |> Broadcast.publish(
          Messages.interpolate("然而$p内功深厚，并没有被$P这巧妙的劲力所带动。\n", bindings)
        )

      # LPC: else if (sizeof(obs = me->query_enemy() - ({ target })) == 0) —— 身边没有别人
      der == nil ->
        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "结果$p的招式莫名其妙的变了方向，竟然控制不住！幸好身边没有别人，没有酿成大祸。\n",
            bindings
          )
        )

      # LPC: else —— 使目标攻向 me 的另一个敌人
      true ->
        name = der_name(der, character.name)

        conn
        |> Broadcast.publish(
          Messages.interpolate(
            "结果$p发出的招式不由自主的变了方向，突然攻向" <>
              name <> "，不禁令" <> name <> "大吃一惊，招架不迭！",
            bindings
          )
        )
        |> attack_other(character, der, rng)
    end
  end

  # LPC: name = der->name(); if (name == target->name()) name = "另一个" + name;
  defp der_name(der, target_name) do
    name = Map.get(der, :name)

    if name == target_name do
      "另一个" <> name
    else
      name
    end
  end

  # LPC: if (der) { for (i = 0; i < 2 + random(3); i++) {
  #         if (! der->is_busy()) der->start_busy(1);
  #         COMBAT_D->do_attack(target, der, target->query_temp("weapon")); } }
  # 跨进程：以目标自身战斗快照向 der 连发 combat/incoming。
  defp attack_other(conn, character, der, rng) do
    fighter = Fighter.from_character(character)

    Enum.each(1..(2 + Engine.rand(rng, 3)), fn _ ->
      send(der.pid, %Event{
        from_pid: self(),
        topic: "combat/incoming",
        data: %{attacker: ref(character), fighter: fighter, jiali_paid: 0}
      })
    end)

    conn
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // yi.c 斗转星移
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #         object *obs;
  #         object der;
  #     string msg;
  #         int ap, dp;
  #         int damage;
  #         int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/douzhuan-xingyi/yi"))
  #                 return notify_fail("你还不会使用斗转星移。\n");
  # 
  #         me->clean_up_enemy();
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「斗转星移」只能对战斗中的对手使用。\n");
  # 
  #     if ((int)me->query_skill("douzhuan-xingyi", 1) < 100)
  #         return notify_fail("你的斗转星移不够娴熟，不会使用绝招。\n");
  # 
  #         if ((int)me->query_skill("zihui-xinfa", 1) < 100)
  #                 return notify_fail("你的紫徽心法修为还不到家，"
  #                                    "难以运用「斗转星移」。\n");
  # 
  #         if (me->query("neili") < 60)
  #                 return notify_fail("你现在真气不够，无法使用「斗转星移」。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     weapon = target->query_temp("weapon");
  #         if (weapon && weapon->query("skill_type") == "pin")
  #                 return notify_fail("对方手里拿的是一根小小的针，"
  #                                    "你没有办法施展「斗转星移」。\n");
  # 
  #     msg = HIM "$N" HIM "运起紫徽心法，内力自气海穴出，经由"
  #               "任督二脉奔流而出，巧妙的牵引着$n" HIM "的招式！\n";
  # 
  #         ap = me->query_skill("douzhuan-xingyi", 1) +
  #              me->query_skill("zihui-xinfa", 1) / 2;
  #         dp = target->query_skill("force");
  #         der = 0;
  #         me->start_busy(2);
  #         me->add("neili", -50);
  #         if (ap > dp * 13 / 10)
  #         {
  #                 // Success to make the target attack hiself
  #                 msg += HIR "结果$p" HIR "一招击出，正好打在自己的"
  #                        "要害上，不禁一声惨叫，摔跌开去。\n" NOR;
  #                 damage = target->query("max_qi");
  #                 target->receive_damage("qi", damage / 2, me);
  #                 target->receive_wound("qi", damage / 2, me);
  #         } else
  #         if (ap / 3 + random(ap) < dp)
  #         {
  #                 // The enemy has defense
  #                 msg += CYN "然而$p" CYN "内功深厚，并没有被$P"
  #                        CYN "这巧妙的劲力所带动。\n" CYN;
  #         } else
  #         if (sizeof(obs = me->query_enemy() - ({ target })) == 0)
  #         {
  #                 // No other enemy
  #                 msg += HIC "结果$p" HIC "的招式莫名其妙的变"
  #                        "了方向，竟然控制不住！幸好身边没有别"
  #                        "人，没有酿成大祸。\n" NOR;
  #         } else
  #         {
  #                 string name;
  #                 // Sucess to make the target attack my enemy
  #                 der = obs[random(sizeof(obs))];
  #                 name = der->name();
  #                 if (name == target->name()) name = "另一个" + name;
  #                 msg += HIG "结果$p" HIG "发出的招式不由自主"
  #                        "的变了方向，突然攻向" + name + HIG "，不禁令" +
  #                        name + HIG "大吃一惊，招架不迭！" NOR;
  #         }
  # 
  #     message_combatd(msg, me, target);
  # 
  #         if (der)
  #         {
  #                 // Target attack my enemy
  #                 for (i = 0; i < 2 + random(3); i++)
  #                 {
  #                         if (! der->is_busy()) der->start_busy(1);
  #                         COMBAT_D->do_attack(target, der, target->query_temp("weapon"));
  #                 }
  #         }
  # 
  #     return 1;
  # }
end
