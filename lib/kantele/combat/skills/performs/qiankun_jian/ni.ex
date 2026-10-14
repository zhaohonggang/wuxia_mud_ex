defmodule Kantele.Combat.Skills.Performs.QiankunJian.Ni do
  @moduledoc """
  perform「逆转乾坤」（对照 `kungfu/skill/qiankun-jian/ni.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 武器为 sword →
  内功>=300 → 乾坤神剑>=180 → 真气>=400 → 激发 sword 为乾坤神剑 →
  目标存活。
  起手前按 `combat_exp` 与「剑」类武学前 5 项等级折算 `improve`，
  `ap = 剑法 + 内功`，再 `ap += ap * improve`；随后由目标侧单次判定
  `ap/2 + random(ap) > 目标轻功 + 目标招架`：命中则
  `damage = ap/3 + random(ap/3)`、外伤比例 120（`.c` 原文如此）、
  攻击方扣 200 真气并忙乱 2；未命中则扣 80 真气并忙乱 4。
  两种消耗都依赖命中结果，故经 `Performs.feedback(attacker, neili, busy)`
  在目标侧回授。

  差异（TODO(migrate)）：
  - `improve` 的「最多累加 5 个可用剑类技能」折算为 `stats.skills` 取前 5 项
    等级之和（同 `baihua_cuoquan/hong.ex`、`poyang_jian/long.ex` 先例）；
  - `.c` 起手文案剥色后是**三段**字面量
    （`"…手中" + wn + "一振…直追$n" + "而去！\n"`，后两段只被 `+` 分隔），
    E 侧用 list + `Enum.join("")` 保持同样三段（相邻纯字面量若用 `<>`
    会被验收抽取器合并成一段）；
  - 命中文案中间的 `+ weapon->name() +` 为两段字面量拆段，且该文案在目标侧
    发布，故武器名经 event data 由攻击方传入（同 `dugu_jiujian/po.ex` 先例）；
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
  alias Kantele.Combat.Performs

  @perform_id "qiankun-jian/ni"
  @move_name "「逆转乾坤」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
    #      lvl = lvl * 4 / 5;
    #      ks = keys(me->query_skills("sword")); improve = 0; n = 0;
    #      for (i = 0; i < sizeof(ks); i++)
    #      {
    #              if (SKILL_D(ks[i])->valid_enable("sword"))
    #              {
    #                      n += 1; improve += (int)me->query_skill(ks[i], 1);
    #                      if (n > 4) break;
    #              }
    #      }
    #      improve = improve * 3 / 100 / lvl;
    lvl = trunc(:math.pow(max(stats.combat_exp, 1) * 10, 1 / 3) * 4 / 5)

    skill_sum =
      stats.skills
      |> Map.values()
      |> Enum.sort(:desc)
      |> Enum.take(5)
      |> Enum.sum()

    improve = skill_sum * 3 / 100 / max(lvl, 1)

    # LPC: ap = me->query_skill("sword") + me->query_skill("force");
    #      ap += ap * improve;
    base_ap = Stats.skill(stats, "sword") + Stats.skill(stats, "force")
    ap = base_ap + trunc(base_ap * improve)

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
          ap: ap,
          weapon_name: weapon_name(combat),
          rng: rng
        }
      })

      apply_effect(conn, character, target, combat)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/qiankun-jian/ni"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("force") < 300)
  #      if (me->query_skill("qiankun-jian", 1) < 180)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功的修为不够，难以施展#{@move_name}。\n"}

      Stats.skill(stats, "qiankun-jian") < 180 ->
        {:error, "你的乾坤神剑修为不够，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 400)
  defp check_resources(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "qiankun-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") == "qiankun-jian" do
      :ok
    else
      {:error, "你没有激发乾坤神剑，难以施展#{@move_name}。\n"}
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

  defp weapon_name(combat) do
    case Combat.weapon(combat) do
      nil -> ""
      weapon -> Map.get(weapon, :name)
    end
  end

  # LPC: msg = HIW "$N" HIW "一声清啸，手中" + weapon->name() +
  #            HIW "一振，将乾坤剑法逆行施展，顿时剑影重重，万"
  #            "道光华直追$n" + HIW "而去！\n" NOR;
  #      …分支与消耗都在目标侧结算…
  # .c 的三段字面量用 list + Enum.join 保持原样。
  defp apply_effect(conn, character, target, combat) do
    Broadcast.publish(
      conn,
      [
        "$N一声清啸，手中" <> weapon_name(combat),
        "一振，将乾坤剑法逆行施展，顿时剑影重重，万道光华直追$n",
        "而去！\n"
      ] |> Enum.join(""),
      n1: character.name,
      n2: target.name
    )
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    # 武器名经 event data 由攻击方传入（门槛已保证持械，此处仅防御性缺省）
    weapon_name = Map.get(data, :weapon_name, "")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("dodge") + target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "dodge") + Stats.skill(character.meta.stats, "parry")

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { damage = ap / 3 + random(ap / 3);
    #        me->add("neili", -200);
    #        me->start_busy(2);
    #        msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 120,
    #                                   HIR "$n" HIR "完全无法看不清招中虚实，微"
    #                                   "微一楞间，发现" + weapon->name() + HIR
    #                                   "竟已没入自己胸口数寸。\n" NOR); }
    #      else
    #      { me->add("neili", -80);
    #        me->start_busy(4);
    #        msg += CYN "可是$n" CYN "看破" CYN "$N" CYN
    #               "的招数，飞身一跃，闪开了这神鬼莫测"
    #               "的一击。\n"NOR; }
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      damage = div(ap, 3) + Engine.rand(rng, div(ap, 3))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 120, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: me->add("neili", -200);  me->start_busy(2);
      Performs.feedback(attacker, 200, 2)

      conn
      |> Broadcast.publish(
        "$n完全无法看清招中虚实，微微一楞间，发现" <>
          weapon_name <> "竟已没入自己胸口数寸。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: me->add("neili", -80);  me->start_busy(4);
      Performs.feedback(attacker, 80, 4)

      conn
      |> Broadcast.publish(
        "可是$n看破$N的招数，飞身一跃，闪开了这神鬼莫测的一击。\n",
        bindings
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define NI "「" HIW "逆转乾坤" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  #         int ap, dp;
  #         int damage;
  # 
  #         float improve;
  #         int lvl, i, n;
  #         string martial;
  #         string *ks;
  #         martial = "sword";
  # 
  #         if (userp(me) && ! me->query("can_perform/qiankun-jian/ni"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(NI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" NI "。\n");
  # 
  #         if (me->query_skill("force") < 300)
  #                 return notify_fail("你的内功的修为不够，难以施展" NI "。\n");
  # 
  #         if (me->query_skill("qiankun-jian", 1) < 180)
  #                 return notify_fail("你的乾坤神剑修为不够，难以施展" NI "。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你的真气不够，难以施展" NI "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "qiankun-jian")
  #                 return notify_fail("你没有激发乾坤神剑，难以施展" NI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "一声清啸，手中" + weapon->name() +
  #               HIW "一振，将乾坤剑法逆行施展，顿时剑影重重，万"
  #               "道光华直追$n" + HIW "而去！\n" NOR;
  # 
  #         lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  #         lvl = lvl * 4 / 5;
  #         ks = keys(me->query_skills(martial));
  #         improve = 0;
  #         n = 0;
  #         //最多给予5个技能的加成
  #         for (i = 0; i < sizeof(ks); i++)
  #         {
  #             if (SKILL_D(ks[i])->valid_enable(martial))
  #             {
  #                 n += 1;
  #                 improve += (int)me->query_skill(ks[i], 1);
  #                 if (n > 4 )
  #                     break;
  #             }
  #         }
  # 
  #         improve = improve * 3 / 100 / lvl;
  # 
  #         ap = me->query_skill("sword") + me->query_skill("force");
  #         dp = target->query_skill("dodge") + target->query_skill("parry");
  # 
  #         ap += ap * improve;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 3 + random(ap / 3);
  #                 me->add("neili", -200);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 120,
  #                                            HIR "$n" HIR "完全无法看清招中虚实，微"
  #                                            "微一楞间，发现" + weapon->name() + HIR
  #                                            "竟已没入自己胸口数寸。\n" NOR);
  #         } else
  #         {
  #                 me->add("neili", -80);
  #                 me->start_busy(4);
  #                 msg += CYN "可是$n" CYN "看破" CYN "$N" CYN
  #                        "的招数，飞身一跃，闪开了这神鬼莫测"
  #                        "的一击。\n"NOR;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
