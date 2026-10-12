defmodule Kantele.Combat.Skills.Performs.Sougu.Muyeyingyang do
  @moduledoc """
  牧野鹰扬「muyeyingyang」（对照 `kungfu/skill/sougu/muyeyingyang.c`）

  搜骨鹰爪功单体攻击。逐条对应 `muyeyingyang.c` 的 `perform()`：

  门槛（攻击方）：目标须在战斗中、`query_str()>=30`、`sougu>=150`、`neili>=800`。
  攻击方广播起手式后发 `perform-incoming`；目标侧依次判定
  `target->is_busy()`、`!living(target)`，再掷
  `random(me->combat_exp) > target->combat_exp / 2`：
  - 命中：目标 `start_busy(sougu/22 + 1)`，攻击方扣 150 内力；
  - 未中：攻击方 `start_busy(4)`，不扣内力。

  攻击/目标分处两个进程：攻击方只持有轻量 enemy 引用，命中判定需双方
  `combat_exp`，故由攻击方把 `combat_exp` 随事件下发，在目标侧
  `resolve_incoming/4` 结算（与 `fenglei-zifa/she` 同构）。

  差异（TODO(migrate)）：无。LPC 的 `offensive_target(me)` 在本库
  等价于取 `combat.enemies` 首项（perform 命令无目标参数）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "sougu/muyeyingyang"
  @name "牧野鹰扬"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_str(stats),
         :ok <- check_level(stats),
         :ok <- check_neili(character) do
      rng = &:rand.uniform/1

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: Stats.skill(stats, "sougu"),
          combat_exp: stats.combat_exp,
          rng: rng
        }
      })

      conn
      |> Broadcast.publish(
        "$N使出搜骨鹰爪功绝技「#{@name}」，双爪蓦地抓向$n的全身要穴。\n",
        n1: character.name,
        n2: target.name
      )
      |> assign(:prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@name}只能对战斗中的对手使用。\n"}
    end
  end

  # if ((int)me->query_str() < 30) return notify_fail("你臂力不够,不能使用牧野鹰扬！\n");
  defp check_str(stats) do
    if stats.str < 30 do
      {:error, "你臂力不够,不能使用#{@name}！\n"}
    else
      :ok
    end
  end

  # if ((int)me->query_skill("sougu",1) < 150)
  #     return notify_fail("你的搜骨鹰爪功修为不够,目前还不能使用牧野鹰扬！\n");
  defp check_level(stats) do
    if Stats.skill(stats, "sougu") < 150 do
      {:error, "你的搜骨鹰爪功修为不够,目前还不能使用#{@name}！\n"}
    else
      :ok
    end
  end

  # if ((int)me->query("neili") < 800)
  #     return notify_fail("你内力现在不够, 不能使用牧野鹰扬！\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 800 do
      {:error, "你内力现在不够, 不能使用#{@name}！\n"}
    else
      :ok
    end
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 0)
    my_exp = max(Map.get(data, :combat_exp, 0), 0)
    ob_exp = character.meta.stats.combat_exp
    bindings = [n1: attacker.name, n2: character.name]

    cond do
      # if (target->is_busy()) return notify_fail(target->name()+"目前正自顾不暇，放胆攻击吧！\n");
      character.meta.combat.busy > 0 ->
        conn
        |> Broadcast.publish(
          Messages.interpolate("$n目前正自顾不暇，放胆攻击吧！\n", bindings)
        )

      # if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      character.meta.combat.dead ->
        Broadcast.publish(
          conn,
          Messages.interpolate("对方都已经这样了，用不着这么费力吧？\n", bindings)
        )

      # if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
      Engine.rand(rng, max(my_exp, 1)) > div(ob_exp, 2) ->
        # msg += "结果$p被$P点中要穴，立时动弹不得！\n";
        # target->start_busy( (int)me->query_skill("sougu",1) / 22 + 1);
        # me->add("neili", -150);
        combat = Combat.start_busy(character.meta.combat, div(level, 22) + 1)
        character = %{character | meta: %{character.meta | combat: combat}}
        Performs.feedback(attacker, 150, 0)

        conn
        |> Broadcast.publish(
          Messages.interpolate("结果$p被$P点中要穴，立时动弹不得！\n", bindings)
        )
        |> put_character(character)

      # else: msg += "可是$p看破了$P的企图，并没有上当。\n"; me->start_busy(4);
      true ->
        Performs.feedback(attacker, 0, 4)

        Broadcast.publish(
          conn,
          Messages.interpolate("可是$p看破了$P的企图，并没有上当。\n", bindings)
        )
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: @perform_id,
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-150"}], "busy_lines": ["if (target->is_busy())", "target->start_busy( (int)me->query_skill("sougu",1) / 22 + 1);", "me->start_busy(4);"], "level_gates": [{"sougu", "150"}], "remote_damage": false, "resource_gates": [{"neili", "800"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // muyeyingyang.c 牧野鹰扬
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("牧野鹰扬只能对战斗中的对手使用。\n");
  # 
  #         if ((int)me->query_str() < 30)
  #                 return notify_fail("你臂力不够,不能使用牧野鹰扬！\n");
  # 
  #         if ((int)me->query_skill("sougu",1) < 150)
  #                 return notify_fail("你的搜骨鹰爪功修为不够,目前还不能使用牧野鹰扬！\n");
  # 
  #         if ((int)me->query("neili") < 800)
  #                 return notify_fail("你内力现在不够, 不能使用牧野鹰扬！\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧！\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "使出搜骨鹰爪功绝技「牧野鹰扬」，双爪蓦地抓向$n"
  #               HIY "的全身要穴。\n" NOR;
  # 
  #         if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 2)
  #         {
  #                 msg += HIR "结果$p" HIR "被$P" HIR "点中要穴，立时动弹不得！\n" NOR;
  #                 target->start_busy( (int)me->query_skill("sougu",1) / 22 + 1);
  #                 me->add("neili", -150);
  #         } else
  #         {
  #                 msg += HIG "可是$p" HIG "看破了$P" HIG "的企图，并没有上当。\n" NOR;
  #                 me->start_busy(4);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
