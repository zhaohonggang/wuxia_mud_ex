defmodule Kantele.Combat.Skills.Performs.DaojianGuizhen.Xue do
  @moduledoc """
  perform「天下有血」（source daojian-guizhen/xue.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 刀剑归真>=200（`.c` 以此代替 can_perform 检查）→
  目标在战斗中 → 持剑或刀 → 对应用法（sword/blade）>=250 → 激发该用法为刀剑归真 →
  刀剑归真>=250 → 真气>=500 → 目标存活。
  命中判定 `ap/2 + random(ap)`（`ap = 刀剑归真*3/2 + martial-cognize`）对目标
  `parry + martial-cognize`：命中 `count = ap/6`，未命中 `count = ap/12`；随后
  攻击方 `apply/attack += count`、`apply/damage += count*2/3`，连出 9 击
  （`do_attack`），收招撤除加成并忙乱 `1 + random(8)`；攻击方扣 300 真气。

  差异（TODO(migrate)）：
  - LPC 的 9 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）折算为每击
    `ap/10` 基础伤害 + `apply/damage` 加成 `count*2/3`，命中判定
    `ap/2 + count`（`apply/attack` 加成）+ `random(ap)` vs 目标 `dodge`；
    加成/撤除折算进该判定与伤害，不写入 `combat.temp`；
  - `me->set_temp("daojian-guizhen/max_pfm", 1)` 供 `hit_ob` 追加创伤与文案
    （`daojian-guizhen.c`），本引擎无 per-skill `hit_ob` 钩子，未建模（无文案，
    不影响文案比对）；
  - `.c` 文案因显式 `+`（`weapon->name()` 两侧、`NOR + WHT`）被切成 4 段，
    E 侧用列表 + `Enum.join("")` 保持同粒度；
  - `to_chinese(type)` 折算为 `type_name/1`（sword→剑法、blade→刀法）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
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
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "daojian-guizhen/xue"
  @move_name "「天下有血」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "daojian-guizhen")
    # LPC: ap = me->query_skill("daojian-guizhen", 1) * 3 / 2
    #            + me->query_skill("martial-cognize", 1);
    ap = div(lvl * 3, 2) + Stats.skill(stats, "martial-cognize")

    with :ok <- check_perform_known(character),
         :ok <- check_skill_min(character),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- weapon(combat),
         :ok <- check_type_skill(character, weapon),
         :ok <- check_mapped(character, weapon),
         :ok <- check_level(character),
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
          rng: rng
        }
      })

      apply_effect(conn, character, target, weapon)
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

  # LPC: if (me->query_skill("daojian-guizhen", 1) < 200)
  #        return notify_fail("你所使用的外功中没有这种功能。\n");
  # 该 .c 以技能等级代替 can_perform 检查，文案与 perform_known 相同。
  defp check_skill_min(character) do
    if Stats.skill(character.meta.stats, "daojian-guizhen") < 200 do
      {:error, "你所使用的外功中没有这种功能。\n"}
    else
      :ok
    end
  end

  # LPC: if (! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #       || (string)weapon->query("skill_type") != "sword"
  #       && (string)weapon->query("skill_type") != "blade")
  defp weapon(combat) do
    case Combat.weapon(combat) do
      %{skill_type: type} = weapon when type in ["sword", "blade"] -> {:ok, weapon}
      _ -> {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: type = weapon->query("skill_type");
  #      if (me->query_skill(type, 1) < 250)
  #        return notify_fail("你的" + to_chinese(type) + "太差，难以施展" XUE "。\n");
  defp check_type_skill(character, weapon) do
    type = Map.get(weapon, :skill_type)

    if Stats.skill(character.meta.stats, type) < 250 do
      # C 侧 "你的" + to_chinese(type) + "太差，…" 被显式 `+` 切成两段，E 侧同粒度。
      {:error, ["你的", type_name(type), "太差，难以施展#{@move_name}。\n"] |> Enum.join("")}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped(type) != "daojian-guizhen")
  defp check_mapped(character, weapon) do
    type = Map.get(weapon, :skill_type)

    if Stats.mapped(character.meta.stats, type) == "daojian-guizhen" do
      :ok
    else
      {:error, "你没有激发刀剑归真，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("daojian-guizhen", 1) < 250)
  defp check_level(character) do
    if Stats.skill(character.meta.stats, "daojian-guizhen") < 250 do
      {:error, "你的刀剑归真等级不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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

  # LPC: to_chinese(type)（本招仅 sword/blade 可达）
  defp type_name("sword"), do: "剑法"
  defp type_name("blade"), do: "刀法"
  defp type_name(_), do: "兵器"

  defp apply_effect(conn, character, target, weapon) do
    # LPC: msg = HIW "$N" HIW "手中" + weapon->name() + HIW "蓦地一抖" "，将「"
    #            NOR + WHT "胡家刀法" HIW "」并「" NOR + WHT "苗家剑法" HIW
    #            "」连环施出。霎时寒\n光点点，犹如夜陨" "划空，铺天盖地罩向$n" HIW
    #            "，正是一招「" HIW "天下" "有" HIR "血" HIW "」。\n" NOR;
    #      message_combatd(msg, me, target);
    # 命中/连击在目标侧结算（dp 需目标 parry/martial-cognize）。
    # C 侧显式 `+` 把文案切成 4 段，E 侧用列表保持同粒度（不得用 `<>` 合并）。
    msg =
      [
        "$N手中",
        Map.get(weapon, :name),
        "蓦地一抖，将「",
        "胡家刀法」并「",
        "苗家剑法」连环施出。霎时寒\n光点点，犹如夜陨划空，铺天盖地罩向$n，正是一招「天下有血」。\n"
      ]
      |> Enum.join("")

    conn
    |> Broadcast.publish(msg, n1: character.name, n2: target.name)
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

    # LPC: dp = target->query_skill("parry") + target->query_skill("martial-cognize", 1);
    dp = Stats.skill(stats, "parry") + Stats.skill(stats, "martial-cognize")

    # LPC: if (ap / 2 + random(ap) > dp) { count = ap / 6; … } else { count = ap / 12; }
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    count = if hit, do: div(ap, 6), else: div(ap, 12)

    # LPC: for (i = 0; i < 9; i++) COMBAT_D->do_attack(me, target, weapon, 0);
    # 折算：每击 ap/10 基础伤害 + apply/damage 加成 count*2/3；
    #      命中判定 ap/2 + apply/attack 加成 count + random(ap) vs 目标 dodge。
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(ap, 10), 1)
    bonus = div(count * 2, 3)
    hit_ap = div(ap, 2) + count

    damage =
      Enum.reduce(1..9, 0, fn _, acc ->
        if hit_ap + Engine.rand(rng, ap) > dodge do
          acc + per_hit + bonus + Engine.rand(rng, per_hit)
        else
          acc
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->add("neili", -300); … me->start_busy(1 + random(8));
    Performs.feedback(attacker, 300, 1 + Engine.rand(rng, 8))

    msg =
      if hit,
        do: "$n只见无数刀光剑影向自己逼来，顿感眼花缭乱，心底寒意油然而生。\n",
        else: "$n突然发现自己四周皆被刀光剑影所包围，心知不妙，急忙小心招架。\n"

    conn
    |> Broadcast.publish(Messages.interpolate(msg, bindings))
    |> put_character(character)
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define XUE "「" HIW "天下有" HIR "血" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string type, msg;
  #         object weapon;
  #         int i, count;
  #         int ap, dp;
  # 
  #         if (me->query_skill("daojian-guizhen", 1) < 200)
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(XUE "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword"
  #            && (string)weapon->query("skill_type") != "blade" )
  #                 return notify_fail("你所使用的武器不对，难以施展" XUE "。\n");
  # 
  #         type = weapon->query("skill_type");
  # 
  #         if (me->query_skill(type, 1) < 250)
  #                 return notify_fail("你的" + to_chinese(type) + "太差，"
  #                                    "难以施展" XUE "。\n");
  # 
  #         if (me->query_skill_mapped(type) != "daojian-guizhen")
  #                 return notify_fail("你没有激发刀剑归真，难以施展" XUE "。\n");
  # 
  #         if (me->query_skill("daojian-guizhen", 1) < 250)
  #                 return notify_fail("你的刀剑归真等级不够，难以施展" XUE "。\n");
  # 
  #         if (me->query("neili") < 500)
  #                 return notify_fail("你现在的真气不够，难以施展" XUE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "手中" + weapon->name() + HIW "蓦地一抖"
  #               "，将「" NOR + WHT "胡家刀法" HIW "」并「" NOR + WHT
  #               "苗家剑法" HIW "」连环施出。霎时寒\n光点点，犹如夜陨"
  #               "划空，铺天盖地罩向$n" HIW "，正是一招「" HIW "天下"
  #               "有" HIR "血" HIW "」。\n" NOR;
  # 
  #         ap = me->query_skill("daojian-guizhen", 1) * 3 / 2 +
  #              me->query_skill("martial-cognize", 1);
  # 
  #         dp = target->query_skill("parry") +
  #              target->query_skill("martial-cognize", 1);
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += HIW "$n" HIW "只见无数刀光剑影向自己逼"
  #                        "来，顿感眼花缭乱，心底寒意油然而生。\n" NOR;
  #                 count = ap / 6;
  #                 me->set_temp("daojian-guizhen/max_pfm", 1);
  #         } else
  #         {
  #                 msg += HIG "$n" HIG "突然发现自己四周皆被刀光"
  #                        "剑影所包围，心知不妙，急忙小心招架。\n" NOR;
  #                 count = ap / 12;
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         me->add("neili", -300);
  #         me->add_temp("apply/attack", count);
  #         me->add_temp("apply/damage", count * 2 / 3);
  # 
  #         for (i = 0; i < 9; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  #         me->add_temp("apply/attack", -count);
  #         me->add_temp("apply/damage", -count * 2 / 3);
  #         me->delete_temp("daojian-guizhen/max_pfm");
  #         me->start_busy(1 + random(8));
  #         return 1;
  # }
end
