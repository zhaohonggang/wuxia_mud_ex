defmodule Kantele.Combat.Skills.Performs.QiankunDanuoyi.Nuoyi do
  @moduledoc """
  perform「大挪移」（对照 `kungfu/skill/qiankun-danuoyi/nuoyi.c`）

  门槛（按 .c 顺序）：战斗中的对手 → 乾坤大挪移>=50（"第二层"）→
  真气>=400 → 目标存活。（`.c` 无 `can_perform` 检查，故无「已学此招」。）
  起手广播后攻击方**无条件**忙乱 2 并扣 350 真气；随后由目标侧依
  `ap/3 + random(ap/3)` 与 `dp` 的大小关系分四种结果：
  - 大于 dp：目标自击要害，`qi` 受到 `max_qi/2` 的伤害与外伤（各一次
    `receive_damage`/`receive_wound`，非 `do_damage`）；
  - `ap/3 + random(ap) < dp`：目标内功深厚，不受带动；
  - 介于两者之间且攻击方无其他敌人：招式失控但无人遭殃；
  - 介于两者之间且有其他敌人：招式转向该敌人，随后由目标对其连出
    `2 + random(3)` 次普通攻击。

  差异（TODO(migrate)）：
  - `ap = 乾坤大挪移 + 内功*2/3`（第三层起再 +`level`）；`dp = 目标内功*2/3 +
    目标轻功`；`ultrap(target)` 时的 `matrial-cognize`（.c 技能名拼写如此）
    加成未建模，略去；
  - 第四分支的「另一个」前缀（转向的敌人与目标同名时）与两次插入同一名字
    的拆段按 `.c` 保留（`"突然攻向" + name + "，不禁令" + name + "大吃一惊，招架不迭！"`）；
  - 第四分支末尾 `do_attack(target, der, target->query_temp("weapon"))` 的完整
    攻击管线在 perform 内不可复用（由 `CombatEvent` 承担），折算为：目标侧把自己
    的拳脚/膂力折算的 `ap` 与连击数经 `role: :der` 事件传给该敌人进程，由其对自身
    落账「每击命中判定 + 命中伤害 + 每次前判忙乱」（同 `luohan_gun/shibaluohan.ex`
    的 `role:` 分派先例），命中判定与伤害公式沿用本仓库 do_attack 折叠约定；
  - 无条件消耗（busy 2 / neili -350）在 `apply_effect` 直接结算（`.c` 中位于
    分支判定之前，与命中结果无关）；
  - `me->clean_up_enemy()` 框架无对应动作，由 `combat.enemies` 直接取当前对手；
  - `.c` 起手文案结尾无 `NOR` 且第二段为独立字面量（`"的招式！\n"`），逐字保留；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
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

  @perform_id "qiankun-danuoyi/nuoyi"
  @move_name "「大挪移」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: (level = (int)me->query_skill("qiankun-danuoyi", 1))
    #      ap = level + me->query_skill("force") * 2 / 3;
    #      if (level >= 300) ap += level;  // layer 7 force
    level = Stats.skill(stats, "qiankun-danuoyi")
    ap = level + div(Stats.skill(stats, "force") * 2, 3)
    ap = if level >= 300, do: ap + level, else: ap

    # LPC: do_attack(target, der, ...) 的 ap 折算（目标侧属性，经 der 事件传入）
    target_ap = Stats.skill(stats, "unarmed") + Stats.query_str(stats) * 10

    with {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      # LPC: obs = me->query_enemy() - ({ target });
      others = Enum.reject(combat.enemies, &(&1.id == target.id))

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          others: others,
          target_name: target.name,
          target_ap: target_ap,
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

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if ((level = (int)me->query_skill("qiankun-danuoyi", 1)) < 50)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "qiankun-danuoyi") < 50 do
      {:error, "你的乾坤大挪移还没有修炼到第二层，无法施展大挪移。\n"}
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

  # LPC: msg = HIM "$N" HIM "招数忽然的一变，摹可明方，内力四处回旋，无形中牵引着$n"
  #            HIM "的招式！\n";
  #      me->start_busy(2);
  #      me->add("neili", -350);
  #      …分支在目标侧结算…
  defp apply_effect(conn, character, target) do
    conn =
      Broadcast.publish(
        conn,
        "$N招数忽然的一变，摹可明方，内力四处回旋，无形中牵引着$n的招式！\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->start_busy(2);
    combat = Combat.start_busy(character.meta.combat, 2)

    # LPC: me->add("neili", -350);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 350, 0)}

    character = %{
      character
      | meta: %{character.meta | combat: combat, vitals: vitals}
    }

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    case Map.get(data, :role) do
      :der -> apply_der(conn, character, data)
      _ -> do_resolve_incoming(conn, character, attacker, data)
    end
  end

  # LPC: if (ap / 3 + random(ap / 3) > dp) { 自击要害 }
  #      else if (ap / 3 + random(ap) < dp) { 内功深厚 }
  #      else if (sizeof(obs = me->query_enemy() - ({ target })) == 0) { 无人遭殃 }
  #      else { 招式转向 obs[random(sizeof(obs))]，随后 target 连击 der }
  defp do_resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      resolve(conn, character, attacker, data)
    end
  end

  defp resolve(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    others = Map.get(data, :others, [])
    target_name = Map.get(data, :target_name, "")
    target_ap = Map.get(data, :target_ap, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("force") * 2 / 3 + target->query_skill("dodge", 1);
    #      （ultrap(target) 的 matrial-cognize 加成未建模，略去）
    dp = div(Stats.skill(character.meta.stats, "force") * 2, 3) + Stats.skill(character.meta.stats, "dodge")

    cond do
      # LPC: msg += HIR "结果$p" HIR "一招击出，正好打在自己的"
      #               "要害上，不禁一声惨叫，摔跌开去。\n" NOR;
      #      damage = target->query("max_qi");
      #      target->receive_damage("qi", damage / 2, me);
      #      target->receive_wound("qi", damage / 2, me);
      div(ap, 3) + Engine.rand(rng, div(ap, 3)) > dp ->
        damage = div(character.meta.vitals.max_qi, 2)

        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, damage)

        character = %{character | meta: %{character.meta | vitals: vitals}}

        conn
        |> Broadcast.publish(
          "结果$p一招击出，正好打在自己的要害上，不禁一声惨叫，摔跌开去。\n",
          bindings
        )
        |> put_character(character)

      # LPC: msg += CYN "然而$p" CYN "内功深厚，并没有被$P"
      #               CYN "这巧妙的劲力所带动。\n" CYN;
      div(ap, 3) + Engine.rand(rng, ap) < dp ->
        conn
        |> Broadcast.publish(
          "然而$p内功深厚，并没有被$P这巧妙的劲力所带动。\n",
          bindings
        )
        |> put_character(character)

      # LPC: msg += HIC "结果$p" HIC "的招式莫名其妙的变"
      #               "了方向，竟然控制不住！幸好身边没有别"
      #               "人，没有酿成大祸。\n" NOR;
      others == [] ->
        conn
        |> Broadcast.publish(
          "结果$p的招式莫名其妙的变了方向，竟然控制不住！幸好身边没有别人，没有酿成大祸。\n",
          bindings
        )
        |> put_character(character)

      # LPC: der = obs[random(sizeof(obs))];
      #      name = der->name();
      #      if (name == target->name()) name = "另一个" + name;
      #      msg += HIG "结果$p" HIG "发出的招式不由自主"
      #                     "的变了方向，突然攻向" + name + HIG "，不禁令" +
      #                     name + HIG "大吃一惊，招架不迭！" NOR;
      #      if (der) { for (i = 0; i < 2 + random(3); i++) {
      #                   if (! der->is_busy()) der->start_busy(1);
      #                   COMBAT_D->do_attack(target, der, target->query_temp("weapon")); } }
      true ->
        der = Enum.at(others, Engine.rand(rng, length(others)))

        name =
          if der.name == target_name do
            "另一个" <> der.name
          else
            der.name
          end

        conn =
          Broadcast.publish(
            conn,
            "结果$p发出的招式不由自主的变了方向，突然攻向" <>
              name <> "，不禁令" <> name <> "大吃一惊，招架不迭！",
            bindings
          )

        # 连击由 der 自身进程落账（role: :der）
        send(der.pid, %Event{
          from_pid: self(),
          topic: "combat/perform-incoming",
          data: %{
            attacker: ref(character),
            perform_id: @perform_id,
            role: :der,
            strikes: 2 + Engine.rand(rng, 3),
            ap: target_ap,
            rng: rng
          }
        })

        put_character(conn, character)
    end
  end

  # LPC: for (i = 0; i < 2 + random(3); i++) {
  #        if (! der->is_busy()) der->start_busy(1);
  #        COMBAT_D->do_attack(target, der, ...); }
  # 连击数与攻击方（原目标）折算的 ap 经事件传入；命中判定/伤害沿用本仓库
  # do_attack 折叠约定（ap/2 + random(ap) vs 自身 dodge，每击 ap/15 基础伤害）。
  defp apply_der(conn, character, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    strikes = Map.get(data, :strikes, 2)
    dodge = Stats.skill(character.meta.stats, "dodge")

    {combat, damage} =
      Enum.reduce(1..strikes, {character.meta.combat, 0}, fn _, {combat_acc, damage_acc} ->
        combat_acc = Combat.start_busy(combat_acc, 1)

        if div(ap, 2) + Engine.rand(rng, ap) > dodge do
          per_hit = max(div(ap, 15), 1)
          {combat_acc, damage_acc + per_hit + Engine.rand(rng, per_hit)}
        else
          {combat_acc, damage_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    put_character(conn, character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // nuoyi.c 大挪移
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     // object weapon;
  #   object *obs;
  #   object der;
  #     string msg;
  #   int ap, dp;
  #   int damage;
  #   int level;
  #   int i;
  # 
  #   me->clean_up_enemy();
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「大挪移」只能对战斗中的对手使用。\n");
  # 
  #     if ((level = (int)me->query_skill("qiankun-danuoyi", 1)) < 50)
  #         return notify_fail("你的乾坤大挪移还没有修炼到第二层，无法施展大挪移。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，无法使用「大挪移」。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIM "$N" HIM "招数忽然的一变，摹可明方，内力四处回旋，无形中牵引着$n"
  #               HIM "的招式！\n";
  # 
  #         ap = level + me->query_skill("force") * 2 / 3;
  #         dp = target->query_skill("force") * 2 / 3 +
  #              target->query_skill("dodge", 1);
  #         if (level >= 300)
  #         {
  #                 // layer 7 force
  #                 ap += level;
  #         }
  # 
  #         if (ultrap(target))
  #                 dp += target->query_skill("matrial-cognize", 1);
  # 
  #         der = 0;
  #         me->start_busy(2);
  #         me->add("neili", -350);
  #         if (ap / 3 + random(ap / 3) > dp)
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
