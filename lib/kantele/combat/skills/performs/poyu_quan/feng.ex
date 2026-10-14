defmodule Kantele.Combat.Skills.Performs.PoyuQuan.Feng do
  @moduledoc """
  perform「封闭手」（对照 `kungfu/skill/poyu-quan/feng.c`）

  门槛（按 .c 顺序）：战斗中的对手 → 已学此招 → 目标未忙乱 →
  劈石破玉拳>=60 → 准备 cuff 为劈石破玉拳 → 真气>=80 → 目标存活。
  起手广播后**无条件**扣 40 真气（`me->add("neili", -40)` 在分支之外，
  直接在 apply_effect 结算）；随后由目标侧判定
  `random(拳法) > 目标内功/2`：命中则目标忙乱 `拳法/20 + 2`；
  未命中则攻击方忙乱 1（经 `Performs.feedback(attacker, 0, busy)` 回授）。
  本招不产生伤害。

  差异（TODO(migrate)）：
  - 目标忙乱门槛（`target->is_busy()`）与命中后的目标忙乱都在目标侧结算
    （目标 ref 无 combat，攻击方不可查）；未命中的攻击方忙乱 1 经
    `Performs.feedback(attacker, 0, 1)` 回授（neili 代价 0，已在 apply_effect
    无条件结算，不再重复）；
  - 命中判定用的 `me->query_skill("cuff")` 与目标忙乱时长同源，经 event data
    由攻击方传入；
  - 起手与分支文案分两次发布（`.c` 都累加进同一 `msg` 后一次
    `message_sort`）；E 侧拆两处——起手在攻击方发布，分支文案在目标侧发布
    （判定需目标内功）；
  - 未命中文案与本招命中判定中的 `$p`/`$P` 分别绑 `:n2`/`:n1`
    （`$n/$p → :n2`、`$N/$P → :n1`）；
  - `.c` 起手文案以 `\n` 开头、结尾有换行，逐字保留；
  - 目标忙乱文案以目标名字开头（`target->name() + "目前正自顾不暇，放胆攻击吧！\n"`，
    注意 .c 是全角叹号），目标侧以自身名字前缀拼接；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧
    `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "poyu-quan/feng"
  @move_name "「封闭手」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: random(me->query_skill("cuff")) ... target->start_busy(cuff / 20 + 2)
    # 两者都依赖攻击方拳法等级，经 event data 传给目标侧。
    cuff = Stats.skill(stats, "cuff")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          cuff: cuff,
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

  # LPC: if (userp(me) && ! me->query("can_perform/poyu-quan/feng"))
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

  # LPC: if ((int)me->query_skill("poyu-quan", 1) < 60)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "poyu-quan") < 60 do
      {:error, "你的劈石破玉拳不够娴熟，不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("cuff") != "poyu-quan")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "cuff")

    if prepared != nil and hd(String.split(prepared, "/")) == "poyu-quan" do
      :ok
    else
      {:error, "你没有准备使用劈石破玉拳，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 80)
  defp check_resources(character) do
    if character.meta.vitals.neili < 80 do
      {:error, "你现在真气不够，无法施展#{@move_name}。\n"}
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

  # LPC: msg = HIC "\n只见$N" HIC "左掌虚探，右拳飕的一声从掌风中"
  #            "猛穿过来，正是劈石破玉拳法的绝招之一「" HIG "封闭手" HIC "」。\n" NOR;
  #      message_sort(msg, me, target);
  #      me->add("neili", -40);
  #      …分支在目标侧结算…
  defp apply_effect(conn, character, target) do
    conn =
      Broadcast.publish(
        conn,
        "\n只见$N左掌虚探，右拳飕的一声从掌风中猛穿过来，正是劈石破玉拳法的绝招之一「封闭手」。\n",
        n1: character.name,
        n2: target.name
      )

    # LPC: me->add("neili", -40);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 40, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: if (target->is_busy())
  #      return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 目标忙乱状态只在目标侧可见，故与死亡检查一并在此结算。
  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        conn

      Combat.busy?(character.meta.combat) ->
        Broadcast.publish(
          conn,
          "#{character.name}目前正自顾不暇，放胆攻击吧！\n",
          n1: attacker.name,
          n2: character.name
        )

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    cuff = Map.get(data, :cuff, 0)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("cuff")) > (int)target->query_skill("force") / 2)
    force = Stats.skill(character.meta.stats, "force")

    if Engine.rand(rng, cuff) > div(force, 2) do
      # LPC: msg += HIR "结果$p" HIR "运力招架，一时却觉得"
      #               "内力不济，被$P" HIR "抢住手腕一拉，顿时立足"
      #               "不稳，滴溜溜打了两个圈子。\n" NOR;
      #      target->start_busy((int)me->query_skill("cuff") / 20 + 2);
      combat = Combat.start_busy(character.meta.combat, div(cuff, 20) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish(
        "结果$p运力招架，一时却觉得内力不济，被$P抢住手腕一拉，顿时立足不稳，滴溜溜打了两个圈子。\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "奋力一架，硬生生格开了$P"
      #               CYN "这一拳。\n" NOR;
      #      me->start_busy(1);
      Performs.feedback(attacker, 0, 1)

      conn
      |> Broadcast.publish("可是$p奋力一架，硬生生格开了$P这一拳。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // feng.c 破玉拳「封闭手」
  # 
  # #include <ansi.h>
  # 
  # #define FENG "「" HIG "封闭手" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     // object weapon;
  #     string msg;
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/poyu-quan/feng"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(FENG "只能对战斗中的对手使用。\n");
  # 
  #     if (target->is_busy())
  #         return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #     if ((int)me->query_skill("poyu-quan", 1) < 60)
  #         return notify_fail("你的劈石破玉拳不够娴熟，不会使用" FENG "。\n");
  # 
  #         if (me->query_skill_prepared("cuff") != "poyu-quan")
  #                 return notify_fail("你没有准备使用劈石破玉拳，无法施展" FENG "。\n");
  # 
  #         if (me->query("neili") < 80)
  #                 return notify_fail("你现在真气不够，无法施展" FENG "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "\n只见$N" HIC "左掌虚探，右拳飕的一声从掌风中"
  #               "猛穿过来，正是劈石破玉拳法的绝招之一「" HIG "封闭手" HIC "」。\n" NOR;
  # 
  #         me->add("neili", -40);
  #     if (random(me->query_skill("cuff")) > (int)target->query_skill("force") / 2)
  #         {
  #         msg += HIR "结果$p" HIR "运力招架，一时却觉得"
  #                        "内力不济，被$P" HIR "抢住手腕一拉，顿时立足"
  #                        "不稳，滴溜溜打了两个圈子。\n" NOR;
  #         target->start_busy((int)me->query_skill("cuff") / 20 + 2);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "奋力一架，硬生生格开了$P"
  #                        CYN "这一拳。\n" NOR;
  #         me->start_busy(1);
  #     }
  #     message_sort(msg, me, target);
  # 
  #     return 1;
  # }
end
