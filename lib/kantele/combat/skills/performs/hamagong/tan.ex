defmodule Kantele.Combat.Skills.Performs.Hamagong.Tan do
  @moduledoc """
  exert「tan」（source hamagong/tan.c，inherit F_SSERVER）

  门槛（按 `.c` 顺序）：房间非 `no_fight` → 目标存在且非自身 → 非比武对手 →
  基本毒技>=80 → 蛤蟆功>=100 → 真气>=500 → 手中有 `handing` 的毒药 →
  该物有 `poison` → 目标存活。
  起手广播「…轻轻悬起一些<毒药>对准…弹了过去」，攻击方忙乱 `2+random(2)`、
  扣 200 真气；随后以 `真气/2 + random(真气)` 对目标真气判定，不足则被震开；
  否则以 `poison/2 + force` 对目标 `dodge*3/2` 判定，命中则施加毒药，
  否则被避开；最后消耗手中毒药。

  差异（TODO(migrate)）：
  - `.c` 在攻击方一处 `message_combatd` 汇总全部文案；引擎把「被震开 / 被避开 /
    中毒」三段分支放在目标侧 `resolve_incoming/4` 结算（与 `force/shot.c` 的真实
    实现 `skills/force_shot.ex` 同构），攻击方只发前置广播；
  - `me->query_temp("handing")` 引擎未建模（`hand_command.ex` 为占位），此处按
    `inventory` 中 `meta.handing` 的物件近似（同 `force/shot.ex` 约定）；
  - `du->name()` 缺省为空串，避免引入 `.c` 之外的文案；
  - 毒药数量扣减（`destruct`）折算为移出 `inventory`；
  - `want_kill` / `kill_ob` 敌对关系建立引擎未建模。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "hamagong/tan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    rng = &:rand.uniform/1

    with :ok <- check_no_fight(character),
         {:ok, target} <- find_target(character),
         :ok <- check_competitor(target),
         :ok <- check_poison_level(stats),
         :ok <- check_hamagong_level(stats),
         :ok <- check_neili(character),
         {:ok, du} <- find_handing_poison(character),
         :ok <- check_du_is_poison(du),
         :ok <- check_target_alive(target) do
      apply_effect(conn, character, du, target, rng)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (environment(me)->query("no_fight"))
  #        return notify_fail("这里不能战斗，你不可以使用毒技伤人。\n");
  defp check_no_fight(character) do
    if room_flag(character, :no_fight) do
      {:error, "这里不能战斗，你不可以使用毒技伤人。\n"}
    else
      :ok
    end
  end

  defp room_flag(character, flag) do
    Map.get(Map.get(character.meta, :room, %{}), flag, false)
  end

  # LPC: if (! target || me == target) return notify_fail("你想攻击谁？\n");
  defp find_target(character) do
    case character.meta.combat.enemies do
      [%{id: id} = target | _] when id != character.id -> {:ok, target}
      _ -> {:error, "你想攻击谁？\n"}
    end
  end

  # LPC: if (target->query_competitor())
  #        return notify_fail("比武的时候最好是正大光明的较量。\n");
  # 敌人引用快照（%{id,pid,name,room_id}）无该属性，保守放行（由目标侧校验）。
  defp check_competitor(target) do
    if Map.get(target, :competitor) != nil do
      {:error, "比武的时候最好是正大光明的较量。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("poison", 1) < 80)
  #        return notify_fail("你的基本毒技火候不够。\n");
  defp check_poison_level(stats) do
    if Stats.skill(stats, "poison") < 80 do
      {:error, "你的基本毒技火候不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("hamagong", 1) < 100)
  #        return notify_fail("你的内功火候不够。\n");
  defp check_hamagong_level(stats) do
    if Stats.skill(stats, "hamagong") < 100 do
      {:error, "你的内功火候不够。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 500)
  #        return notify_fail("你现在内力不足，不能弹射毒药。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在内力不足，不能弹射毒药。\n"}
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

  # LPC: if (! mapp(du->query("poison")))
  #        return notify_fail(du->name() + "又不是毒药，你乱弹什么？\n");
  # C 侧被 `+ du->name() +` 切成两段，E 侧同粒度。
  defp check_du_is_poison(du) do
    if Map.get(du.meta || %{}, :poison) == nil do
      {:error, du_name(du) <> "又不是毒药，你乱弹什么？\n"}
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

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, du, target, rng) do
    du_name = du_name(du)

    # LPC: msg = CYN "$N" CYN "运转内力，轻轻悬起一些" + du->name() +
    #            CYN "对准$n" CYN "弹了过去。\n" NOR;
    # C 侧被 `+ du->name() +` 切成两段，E 侧同粒度（`Enum.join` 保留拆段）。
    message = Enum.join(["$N运转内力，轻轻悬起一些", du_name, "对准$n弹了过去。\n"], "")

    # LPC: me->start_busy(2 + random(2)); me->add("neili", -200);
    vitals = character.meta.vitals
    vitals = %{vitals | neili: max(vitals.neili - 200, 0)}
    combat = Combat.start_busy(character.meta.combat, 2 + Engine.rand(rng, 2))

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        neili: vitals.neili,
        poison_skill: Stats.skill(character.meta.stats, "poison"),
        force_skill: Stats.skill(character.meta.stats, "force"),
        du_name: du_name,
        poison_type: Map.get(du.meta || %{}, :poison_type),
        poison: Map.get(du.meta || %{}, :poison),
        rng: rng
      }
    })

    # LPC: destruct(du);
    inventory = Enum.reject(character.inventory, &(&1 == du))

    character = %{
      character
      | meta: %{character.meta | vitals: vitals, combat: combat},
        inventory: inventory
    }

    conn
    |> Broadcast.publish(message, n1: character.name, n2: target.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: du->name() —— handing 未建模，取物品实例名，缺省为空串。
  defp du_name(du) do
    item = Map.get(du, :item) || %{}
    meta = Map.get(du, :meta) || %{}
    Map.get(item, :name) || Map.get(meta, :name) || ""
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
    neili = Map.get(data, :neili, 0)
    poison_skill = Map.get(data, :poison_skill, 0)
    force_skill = Map.get(data, :force_skill, 0)
    du_name = Map.get(data, :du_name, "")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (me->query("neili") / 2 + random(me->query("neili")) < target->query("neili"))
    if div(neili, 2) + Engine.rand(rng, max(neili, 1)) < character.meta.vitals.neili do
      # LPC: msg += WHT "然而$n轻轻一抖，将$N射过来的" + du->name() + WHT "悉数震开。\n" NOR;
      Broadcast.publish(
        conn,
        Enum.join(["然而$n轻轻一抖，将$N射过来的", du_name, "悉数震开。\n"], ""),
        bindings
      )
    else
      # LPC: ap = me->query_skill("poison", 1) / 2 + me->query_skill("force");
      ap = div(poison_skill, 2) + force_skill
      dodge = Stats.skill(character.meta.stats, "dodge")

      # LPC: if (ap / 2 + random(ap) < target->query_skill("dodge") * 3 / 2)
      if div(ap, 2) + Engine.rand(rng, max(ap, 1)) < div(dodge * 3, 2) do
        # LPC: msg += WHT "$n见势不妙，急忙腾挪身形，避开了$N的攻击。\n" NOR;
        Broadcast.publish(conn, "$n见势不妙，急忙腾挪身形，避开了$N的攻击。\n", bindings)
      else
        # LPC: msg += GRN "$n连忙躲闪，结果仍然觉得微微一阵酸麻。\n" NOR;
        #      target->affect_by(du->query("poison_type"), du->query("poison"));
        conn =
          case Map.get(data, :poison_type) do
            nil ->
              conn

            poison_type ->
              conditions =
                Map.put(get_session(conn, "conditions") || %{}, poison_type, Map.get(data, :poison))

              put_session(conn, "conditions", conditions)
          end

        Broadcast.publish(conn, "$n连忙躲闪，结果仍然觉得微微一阵酸麻。\n", bindings)
      end
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 弹射毒药
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int exert(object me, object target)
  # {
  #     object du;
  #     // int damage;
  #   int ap;
  #     string msg;
  # 
  #   if (environment(me)->query("no_fight"))
  #           return notify_fail("这里不能战斗，你不可以使用毒技伤人。\n");
  # 
  #   if (! target || me == target)
  #           return notify_fail("你想攻击谁？\n");
  # 
  #     if (target->query_competitor())
  #         return notify_fail("比武的时候最好是正大光明的较量。\n");
  # 
  #     if ((int)me->query_skill("poison", 1) < 80)
  #         return notify_fail("你的基本毒技火候不够。\n");
  # 
  #     if ((int)me->query_skill("hamagong", 1) < 100)
  #         return notify_fail("你的内功火候不够。\n");
  # 
  #     if ((int)me->query("neili") < 500)
  #         return notify_fail("你现在内力不足，不能弹射毒药。\n");
  # 
  #   if (! objectp(du = me->query_temp("handing")))
  #           return notify_fail("你得先准备(hand)好毒药再说。\n");
  # 
  #   if (! mapp(du->query("poison")))
  #           return notify_fail(du->name() + "又不是毒药，你乱弹什么？\n");
  # 
  #   if (! living(target))
  #         return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = CYN "$N" CYN "运转内力，轻轻悬起一些" + du->name() +
  #               CYN "对准$n" CYN "弹了过去。\n" NOR;
  #         me->start_busy(2 + random(2));
  #         me->add("neili", -200);
  # 
  #         if (me->query("neili") / 2 + random(me->query("neili")) <
  #             target->query("neili"))
  #         {
  #                 msg += WHT "然而$n轻轻一抖，将$N射过来的" + du->name() +
  #                        WHT "悉数震开。\n" NOR;
  #         } else
  #         {
  #                 ap = me->query_skill("poison", 1) / 2 +
  #                      me->query_skill("force");
  #                 if (ap / 2 + random(ap) < target->query_skill("dodge") * 3 / 2)
  #                 {
  #                         msg += WHT "$n见势不妙，急忙腾挪身形，避开了$N的攻击。\n" NOR;
  #                 } else
  #                 {
  #                         msg += GRN "$n连忙躲闪，结果仍然觉得微微一阵酸麻。\n" NOR;
  #                         target->affect_by(du->query("poison_type"), du->query("poison"));
  #                 }
  #         }
  # 
  #         destruct(du);
  #     message_combatd(msg, me, target);
  #         me->want_kill(target);
  #         if (! target->is_killing(me)) target->kill_ob(me);
  # 
  #     return 1;
  # }
end
