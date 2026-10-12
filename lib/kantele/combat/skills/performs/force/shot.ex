defmodule Kantele.Combat.Skills.Performs.Force.Shot do
  @moduledoc """
  exert「shot」（source force/shot.c）

  仅限 5 种内功（修罗/化功/蛤蟆/神农/华血），门槛（按 `.c` 顺序）：
  已映射内功在允许表内 → 内功>=150 → `poison>=100` → `throwing>=100` →
  房间非 `no_fight`/`skybook`（同文案 ×2）→ 真气>=300 →
  手中有 `handing` 的毒药 → 该物有 `poison` → 非 `no_shot` →
  目标存在且非自身、为角色、非 `not_living` → 非 `die_guard` →
  非比武对手 → 目标存活。
  起手广播「默运…弹射了出去」，忙乱 `1+random(3)`、扣真气 100；
  随后以 `max_neili+neili/2` 对抗，失败则目标震落；否则以
  `force+poison+throwing` 对目标 `dodge+parry+martial-cognize` 判定，
  命中则施加毒药并令目标忙乱 2，否则被避开；最后消耗一枚毒药。

  差异（TODO(migrate)）：
  - 真实运行为 `Kantele.Combat.Skills.Force.Shot`（`skills/force_shot.ex`），
    本文件为并存的对齐副本（仅供文案对齐）；内力对抗、毒素施加与目标忙乱
    在真实实现的目标侧 `resolve_incoming/4` 结算；
  - 敌列表仅存引用快照（无 meta/condition），`die_guard`/比武对手/存活三道
    目标门槛保守放行（真实实现在目标侧校验）；
  - 毒药数量扣减（`add_amount(-1)` / `destruct`）与 `want_kill`/`kill_ob`
    敌对关系建立引擎未建模；
  - `to_chinese(f)` 折算为映射 id 原样（引擎未维护内功 id→中文名 表）；
  - 手中毒药名缺省为空串，避免引入 `.c` 之外的文案。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @allowed_forces ~w(xiuluo-yinshagong huagong-dafa hamagong shennong-xinjing huaxue-shengong)

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character),
         {:ok, du} <- find_handing_poison(character),
         :ok <- check_du(du),
         {:ok, target} <- find_target(character),
         :ok <- check_target_gates(target) do
      apply_effect(conn, character, du, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_gates(character) do
    with :ok <- check_allowed_force(character),
         :ok <- check_force_level(character),
         :ok <- check_poison_level(character),
         :ok <- check_throwing_level(character),
         :ok <- check_no_fight(character),
         :ok <- check_skybook(character),
         :ok <- check_neili(character) do
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("force") != "xiuluo-yinshagong" && ... && != "huaxue-shengong")
  #        return notify_fail("你所学的内功中没有这种功能。\n");
  defp check_allowed_force(character) do
    if Stats.mapped(character.meta.stats, "force") in @allowed_forces do
      :ok
    else
      {:error, "你所学的内功中没有这种功能。\n"}
    end
  end

  # LPC: skill = me->query_skill("force"); if (skill < 150)
  #        return notify_fail("你的内功修为不够。\n");
  defp check_force_level(character) do
    if Stats.skill(character.meta.stats, "force") < 150 do
      {:error, "你的内功修为不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("poison", 1) < 100)
  #        return notify_fail("你的基本毒技火候不够。\n");
  defp check_poison_level(character) do
    if Stats.skill(character.meta.stats, "poison") < 100 do
      {:error, "你的基本毒技火候不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("throwing", 1) < 100)
  #        return notify_fail("你的基本暗器火候不够。\n");
  defp check_throwing_level(character) do
    if Stats.skill(character.meta.stats, "throwing") < 100 do
      {:error, "你的基本暗器火候不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (environment(me)->query("no_fight")) return notify_fail("在这里不能攻击他人。\n");
  defp check_no_fight(character) do
    if room_flag(character, :no_fight) do
      {:error, "在这里不能攻击他人。\n"}
    else
      :ok
    end
  end

  # LPC: // 执行天书任务的特殊房间防止弹毒中断剧情。
  #      if (environment(me)->query("skybook")) return notify_fail("在这里不能攻击他人。\n");
  defp check_skybook(character) do
    if room_flag(character, :skybook) do
      {:error, "在这里不能攻击他人。\n"}
    else
      :ok
    end
  end

  defp room_flag(character, flag) do
    Map.get(Map.get(character.meta, :room, %{}), flag, false)
  end

  # LPC: if ((int)me->query("neili") < 300) return notify_fail("你的真气不够。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你的真气不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (! objectp(du = me->query_temp("handing")))
  #        return notify_fail("你得先准备(hand)好毒药再说。\n");
  defp find_handing_poison(character) do
    case character.inventory |> Enum.find(&(&1.meta && &1.meta.handing)) do
      nil -> {:error, "你得先准备(hand)好毒药再说。\n"}
      du -> {:ok, du}
    end
  end

  defp check_du(du) do
    with :ok <- check_du_is_poison(du),
         :ok <- check_du_throwable(du) do
      :ok
    end
  end

  # LPC: if (! mapp(du->query("poison")))
  #        return notify_fail("你手中所拿的" + du->name() + NOR "不是毒药，无法弹射。\n");
  # C 侧被 `+ du->name() +` 切成两段，E 侧同粒度。
  defp check_du_is_poison(du) do
    if Map.get(du.meta || %{}, :poison) == nil do
      {:error, "你手中所拿的" <> du_name(du) <> "不是毒药，无法弹射。\n"}
    else
      :ok
    end
  end

  # LPC: if (du->query("no_shot"))
  #        return notify_fail("将" + du->name() + NOR "弹射出去" "？似乎不太好吧。\n");
  # C 侧被 `+ du->name() +` 切成两段（后段含 join_adjacent 合并），E 侧同粒度。
  defp check_du_throwable(du) do
    if Map.get(du.meta || %{}, :no_shot) == true do
      {:error, "将" <> du_name(du) <> "弹射出去？似乎不太好吧。\n"}
    else
      :ok
    end
  end

  # LPC: if (! target || me == target || ! target->is_character() || target->query("not_living"))
  #        return notify_fail("你想攻击谁？\n");
  defp find_target(character) do
    case character.meta.combat.enemies do
      [%{id: id} = target | _] when id != character.id -> {:ok, target}
      _ -> {:error, "你想攻击谁？\n"}
    end
  end

  defp check_target_gates(target) do
    with :ok <- check_die_guard(target),
         :ok <- check_competitor(target),
         :ok <- check_target_alive(target) do
      :ok
    end
  end

  # LPC: if (target->query_condition("die_guard"))
  #        return notify_fail("这个人正被官府保护着，还是别去招惹。\n");
  # 敌列表仅存引用快照，无 condition 可查，保守放行（真实实现在目标侧校验 session）。
  defp check_die_guard(target) do
    if Map.get(target, :die_guard) == true do
      {:error, "这个人正被官府保护着，还是别去招惹。\n"}
    else
      :ok
    end
  end

  # LPC: if (target->query_competitor()) return notify_fail("比武的时候最好是正大光明的较量。\n");
  # 同上，引用快照无该属性，保守放行。
  defp check_competitor(target) do
    if Map.get(target, :competitor) != nil do
      {:error, "比武的时候最好是正大光明的较量。\n"}
    else
      :ok
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

  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活。
  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, du, target) do
    force = Stats.mapped(character.meta.stats, "force")
    vitals = character.meta.vitals

    # LPC: msg = HIM "$N" HIM "一声冷笑，默运" + to_chinese(f) +
    #            HIM "内劲，手指粘住" + du->name() +
    #            HIM "对准$n" HIM "「嗖」的弹射了出去。\n" NOR;
    # C 侧被 `+ to_chinese(f) +` 与 `+ du->name() +` 切成三段，E 侧同粒度。
    message =
      "$N一声冷笑，默运" <>
        to_chinese(force) <>
        "内劲，手指粘住" <> du_name(du) <> "对准$n「嗖」的弹射了出去。\n"

    # LPC: me->start_busy(1 + random(3)); me->add("neili", -100);
    combat = Combat.start_busy(character.meta.combat, 1 + :rand.uniform(3))
    vitals = %{vitals | neili: max(vitals.neili - 100, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: message_combatd(msg, me, target);
    # 内力对抗、毒素施加、目标忙乱 2 在真实实现的目标侧结算；
    # 三段分支文案见 target_resisted_message/0 等（`@doc false`）。
    conn
    |> Broadcast.publish(message, n1: character.name, n2: Map.get(target, :name))
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: if (an / 2 + random(an) < dn * 2 / 3)
  #        msg += WHT "然而$n" WHT "全然不放在心上，轻轻一抖，已将$N" WHT "射来的毒素尽数震落。\n" NOR;
  @doc false
  def target_resisted_message,
    do: "然而$n全然不放在心上，轻轻一抖，已将$N射来的毒素尽数震落。\n"

  # LPC: if (ap / 2 + random(ap) > dp) msg += HIG "$n" HIG "急忙飞身躲避，可已然不及，霎时"
  #            "绿光闪过，$p" HIG "顿感一阵麻痹。\n" NOR;
  @doc false
  def target_poisoned_message,
    do: "$n急忙飞身躲避，可已然不及，霎时绿光闪过，$p顿感一阵麻痹。\n"

  # LPC: else msg += CYN "可是$n" CYN "见势不妙，急忙腾挪身形，终"
  #            "于避开了$N" CYN "的弹毒攻击。\n" NOR;
  @doc false
  def target_evaded_message,
    do: "可是$n见势不妙，急忙腾挪身形，终于避开了$N的弹毒攻击。\n"

  defp du_name(du), do: Map.get(du.item, :name, "")

  # LPC: to_chinese(f) —— 引擎未维护内功 id→中文名 表，保留 id 原样
  # （同 `sanku_shengong/dispel.ex` 的对齐副本约定）。
  defp to_chinese(name), do: name
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int exert(object me, object target)
  # {
  #         object du;
  #         int an, dn, ap, dp;
  #         int f, skill;
  #         string msg;
  # 
  #         f = me->query_skill_mapped("force");
  #         skill = me->query_skill("force");
  # 
  #         if (me->query_skill_mapped("force") != "xiuluo-yinshagong"
  #            && me->query_skill_mapped("force") != "huagong-dafa"
  #            && me->query_skill_mapped("force") != "hamagong"
  #            && me->query_skill_mapped("force") != "shennong-xinjing"
  #            && me->query_skill_mapped("force") != "huaxue-shengong")
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if (skill < 150)
  #                 return notify_fail("你的内功修为不够。\n");
  # 
  #         if ((int)me->query_skill("poison", 1) < 100)
  #                 return notify_fail("你的基本毒技火候不够。\n");
  # 
  #         if ((int)me->query_skill("throwing", 1) < 100)
  #                 return notify_fail("你的基本暗器火候不够。\n");
  # 
  #         if (environment(me)->query("no_fight"))
  #                 return notify_fail("在这里不能攻击他人。\n");
  # 
  #         // 执行天书任务的特殊房间防止弹毒中断剧情。
  #         if (environment(me)->query("skybook"))
  #                 return notify_fail("在这里不能攻击他人。\n");
  # 
  #         if ((int)me->query("neili") < 300)
  #                 return notify_fail("你的真气不够。\n");
  # 
  #         if (! objectp(du = me->query_temp("handing")))
  #                 return notify_fail("你得先准备(hand)好毒药再说。\n");
  # 
  #         if (! mapp(du->query("poison")))
  #                 return notify_fail("你手中所拿的" + du->name() + NOR
  #                                    "不是毒药，无法弹射。\n");
  # 
  #         if (du->query("no_shot"))
  #                 return notify_fail("将" + du->name() + NOR "弹射出去"
  #                                    "？似乎不太好吧。\n");
  # 
  #         if (! target || me == target
  #            || ! target->is_character()
  #            || target->query("not_living"))
  #                 return notify_fail("你想攻击谁？\n");
  # 
  #         if (target->query_condition("die_guard"))
  #                 return notify_fail("这个人正被官府保护着，还是别去招惹。\n");
  # 
  #         if (target->query_competitor())
  #                 return notify_fail("比武的时候最好是正大光明的较量。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIM "$N" HIM "一声冷笑，默运" + to_chinese(f) +
  #               HIM "内劲，手指粘住" + du->name() +
  #               HIM "对准$n" HIM "「嗖」的弹射了出去。\n" NOR;
  # 
  #         me->start_busy(1 + random(3));
  #         me->add("neili", -100);
  # 
  #         an = me->query("max_neili") + me->query("neili") / 2;
  #         dn = target->query("max_neili") + target->query("neili") / 2;
  # 
  #         if (an / 2 + random(an) < dn * 2 / 3)
  #         {
  #                 msg += WHT "然而$n" WHT "全然不放在心上，轻轻一抖，已将$N"
  #                        WHT "射来的毒素尽数震落。\n" NOR;
  #         } else
  #         {
  #                 ap = me->query_skill("force") +
  #                      me->query_skill("poison") +
  #                      me->query_skill("throwing");
  # 
  #                 dp = target->query_skill("dodge") +
  #                      target->query_skill("parry") +
  #                      target->query_skill("martial-cognize",1);
  # 
  #                 if (ap / 2 + random(ap) > dp)
  #                 {
  #                         msg += HIG "$n" HIG "急忙飞身躲避，可已然不及，霎时"
  #                                "绿光闪过，$p" HIG "顿感一阵麻痹。\n" NOR;
  #                         target->affect_by(du->query("poison_type"),
  #                                           du->query("poison"));
  # 
  #                         if (! target->is_busy())
  #                                 target->start_busy(2);
  #                 } else
  #                 {
  #                         msg += CYN "可是$n" CYN "见势不妙，急忙腾挪身形，终"
  #                                "于避开了$N" CYN "的弹毒攻击。\n" NOR;
  #                 }
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         if (du->query_amount())
  #         {
  #                 du->add_amount(-1);
  # 
  #                 if (du->query_amount() < 1)
  #                         destruct(du);
  #         } else
  #                 destruct(du);
  # 
  #         me->want_kill(target);
  # 
  #         if (! target->is_killing(me))
  #                 target->kill_ob(me);
  # 
  #         return 1;
  # }
end
