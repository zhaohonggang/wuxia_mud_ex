defmodule Kantele.Combat.Skills.Performs.MingwangJian.Ruo do
  @moduledoc """
  若悲「ruo」（对照 `kungfu/skill/mingwang-jian/ruo.c`）

  明王剑法绝技：需持剑、不动明王剑>=100、激发 sword 为不动明王剑、真气>=100、
  目标未忙乱且存活。命中判定 `random(战斗经验) > 目标战斗经验/3`：
  命中令目标忙乱 `sword/26 + 2` 轮；未命中令攻击方忙乱 1 轮。LPC 不消耗真气。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `target->is_busy()` / 目标战斗经验取引用快照（`%{id,pid,name,room_id}`）的 meta，
    缺 meta 时分别按「非忙」「经验 0」处理；
  - 攻击方忙乱只在失手分支，经 `Performs.feedback/3` 由目标侧回传。
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

  @perform_id "mingwang-jian/ruo"
  @move_name "「若悲」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "mingwang-jian")
    sword = Stats.skill(stats, "sword")
    exp = Map.get(stats, :combat_exp, 0)

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_target_busy(target),
         :ok <- check_skill_level(level),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          sword: sword,
          exp: exp,
          rng: rng
        }
      })

      apply_perform(conn, character, target, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/mingwang-jian/ruo"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (target->is_busy())
  #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  defp check_target_busy(target) do
    if target_busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp target_busy?(target) do
    case get_in(target, [:meta, :combat, :busy]) do
      busy when is_integer(busy) -> busy > 0
      _ -> false
    end
  end

  # LPC: if ((int)me->query_skill("mingwang-jian", 1) < 100)
  defp check_skill_level(level) do
    if level < 100 do
      {:error, "你不动明王剑不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "mingwang-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "mingwang-jian" do
      :ok
    else
      {:error, "你没有激发不动明王剑，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIW "$N" HIW "手中的" + weapon->name() + HIW "轻轻递出，"
    #           "发出一阵轻鸣，$n" + HIW "听了心中不禁有些迷茫。\n" NOR;
    text =
      Enum.join(
        ["$N手中的", weapon_name, "轻轻递出，发出一阵轻鸣，$n", "听了心中不禁有些迷茫。\n"],
        ""
      )

    conn
    |> Broadcast.publish(text, n1: character.name, n2: target.name)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    exp = max(Map.get(data, :exp, 0), 1)
    sword = Map.get(data, :sword, 0)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 3 )
    dp = div(Map.get(stats, :combat_exp, 0), 3)

    if Engine.rand(rng, exp) > dp do
      # LPC: msg += HIR "$n" HIR "心头一震，一时竟然沉迷当中，忘记了" "继续攻击。\n" NOR;
      #      target->start_busy((int)me->query_skill("sword") / 26 + 2);
      combat = Combat.start_busy(character.meta.combat, div(sword, 26) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish(Messages.interpolate("$n心头一震，一时竟然沉迷当中，忘记了继续攻击。\n", bindings))
      |> put_character(character)
    else
      # LPC: msg += HIC "可是$n" HIC "神智只是略微一滞，随即清醒，没" "有被$P" HIC "所困扰。\n" NOR;
      #      me->start_busy(1);
      Performs.feedback(attacker, 0, 1)

      conn
      |> Broadcast.publish(Messages.interpolate("可是$n神智只是略微一滞，随即清醒，没有被$P所困扰。\n", bindings))
      |> put_character(character)
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "mingwang-jian/ruo",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define RUO "「" HIW "若悲" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #   // int ap, dp;
  # 
  #         if (userp(me) && ! me->query("can_perform/mingwang-jian/ruo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(RUO "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" RUO "。\n");
  # 
  #     if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #     if ((int)me->query_skill("mingwang-jian", 1) < 100)
  #         return notify_fail("你不动明王剑不够娴熟，难以施展" RUO "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "mingwang-jian")
  #                 return notify_fail("你没有激发不动明王剑，难以施展" RUO "。\n");
  # 
  #         if (me->query("neili") < 100)
  #                 return notify_fail("你现在的真气不足，难以施展" RUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIW "$N" HIW "手中的" + weapon->name() + HIW "轻轻递出，"
  #               "发出一阵轻鸣，$n" + HIW "听了心中不禁有些迷茫。\n" NOR;
  # 
  #     if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 3 )
  #         {
  #         msg += HIR "$n" HIR "心头一震，一时竟然沉迷当中，忘记了"
  #                        "继续攻击。\n" NOR;
  #         target->start_busy((int)me->query_skill("sword") / 26 + 2);
  #     } else
  #         {
  #         msg += HIC "可是$n" HIC "神智只是略微一滞，随即清醒，没"
  #                        "有被$P" HIC "所困扰。\n" NOR;
  #         me->start_busy(1);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
