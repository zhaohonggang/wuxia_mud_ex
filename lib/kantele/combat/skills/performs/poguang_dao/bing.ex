defmodule Kantele.Combat.Skills.Performs.PoguangDao.Bing do
  @moduledoc """
  寒冰环「bing」（对照 `kungfu/skill/poguang-dao/bing.c`）

  破光刀法绝技：需持刀、破光刀法>=100、激发 blade 为破光刀法、轻功>=150、
  真气>=200、目标未忙乱且存活。起手引子后扣 120 真气；命中判定
  `sword*2/3 + random(sword) > 目标dodge`：命中令目标忙乱
  `2 + random(sword/24)` 轮、攻击方忙乱 `random(2)`；未命中攻击方忙乱 2。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `target->is_busy()` 取引用快照（`%{id,pid,name,room_id}`）的 meta，缺 meta 时按「非忙」处理；
  - `.c` 的结果用 `message_combatd(msg, target, me)`（双方视角互换，$N=目标、$n=攻击方），
    本引擎在目标侧按互换后的绑定广播；
  - 攻击方真气/忙乱经 `Performs.feedback/3` 由目标侧回传。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "poguang-dao/bing"
  @move_name "「寒冰环」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "poguang-dao")
    sword = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_target_busy(target),
         :ok <- check_skill_level(level),
         :ok <- check_mapped(stats),
         :ok <- check_dodge(stats),
         :ok <- check_neili(character) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          sword: sword,
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

  # LPC: if (userp(me) && ! me->query("can_perform/poguang-dao/bing"))
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
  #          (string)weapon->query("skill_type") != "blade")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
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

  # LPC: if ((int)me->query_skill("poguang-dao", 1) < 100)
  defp check_skill_level(level) do
    if level < 100 do
      {:error, "你破光刀法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("blade") != "poguang-dao")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "poguang-dao" do
      :ok
    else
      {:error, "你没有激发破光刀法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("dodge") < 150)
  defp check_dodge(stats) do
    if Stats.skill(stats, "dodge") < 150 do
      {:error, "你的轻功修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon) do
    wn = Map.get(weapon, :name, "")

    # LPC: msg = HIC "\n$N" HIC "将" + wn + HIC "反手一转，内力运于其上，施出"
    #           "绝招「" HIW "寒冰环" HIC "」，猛然间身法忽地加快，" + wn + HIC
    #           "透出阵阵寒气，连连挥出，将$n" HIC "笼罩在寒气之中。" NOR;
    conn
    |> Broadcast.publish(
      "\n$N将" <>
        wn <>
        "反手一转，内力运于其上，施出绝招「寒冰环」，猛然间身法忽地加快，" <>
        wn <> "透出阵阵寒气，连连挥出，将$n笼罩在寒气之中。",
      n1: character.name,
      n2: target.name
    )
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
    level = max(Map.get(data, :sword, 0), 1)

    # LPC 结果用 message_combatd(msg, target, me)：$N 为目标、$n 为攻击方。
    bindings = [n1: character.name, n2: attacker.name]

    # LPC: level * 2 / 3 + random(level) > target->query_skill("dodge")
    if div(level * 2, 3) + Engine.rand(rng, level) >
         Stats.skill(character.meta.stats, "dodge") do
      # LPC: target->start_busy(2 + random(level / 24)); me->start_busy(random(2));
      combat = Combat.start_busy(character.meta.combat, 2 + Engine.rand(rng, div(level, 24)))
      character = %{character | meta: %{character.meta | combat: combat}}

      conn =
        Broadcast.publish(
          conn,
          "$N看不出$n招式中的虚实，连忙护住自己全身，一时竟无以应对！\n",
          bindings
        )

      Performs.feedback(attacker, 120, Engine.rand(rng, 2))
      put_character(conn, character)
    else
      # LPC: me->start_busy(2);
      # LPC: msg = CYN "可是$N" CYN "镇定自若，小心拆招，没有被" "$n" NOR
      #           + CYN "招式所困。\n" NOR;
      # C 侧被 `+` 切成 "…没有被$n" 与 "招式所困。\n" 两段，故用列表保持同粒度。
      conn =
        Broadcast.publish(
          conn,
          Enum.join(["可是$N镇定自若，小心拆招，没有被$n", "招式所困。\n"], ""),
          bindings
        )

      Performs.feedback(attacker, 120, 2)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "poguang-dao/bing",
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
  # #define BING "「" HIW "寒冰环" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg, wn;
  #         object weapon;
  #         int level;
  # 
  #         if (userp(me) && ! me->query("can_perform/poguang-dao/bing"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(BING "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "blade")
  #         return notify_fail("你使用的武器不对，难以施展" BING "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("poguang-dao", 1) < 100)
  #                 return notify_fail("你破光刀法不够娴熟，难以施展" BING "。\n");
  # 
  #         if (me->query_skill_mapped("blade") != "poguang-dao")
  #                 return notify_fail("你没有激发破光刀法，难以施展" BING "。\n");
  # 
  #         if (me->query_skill("dodge") < 150)
  #                 return notify_fail("你的轻功修为不够，难以施展" BING "。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" BING "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIC "\n$N" HIC "将" + wn + HIC "反手一转，内力运于其上，施出"
  #               "绝招「" HIW "寒冰环" HIC "」，猛然间身法忽地加快，" + wn + HIC
  #               "透出阵阵寒气，连连挥出，将$n" HIC "笼罩在寒气之中。" NOR;
  #         message_sort(msg, me, target);
  # 
  #         level = me->query_skill("sword");
  # 
  #         me->add("neili", -120);
  # 
  #         if (level * 2 / 3 + random(level) > target->query_skill("dodge"))
  #         {
  #         msg = HIY "$N" HIY "看不出$n" HIY "招式中的虚实，连忙"
  #                       "护住自己全身，一时竟无以应对！\n" NOR;
  #                 target->start_busy(2 + random(level / 24));
  #                 me->start_busy(random(2));
  #     } else
  #         {
  #         msg = CYN "可是$N" CYN "镇定自若，小心拆招，没有被"
  #                       "$n" NOR + CYN "招式所困。\n" NOR;
  # 
  #                 me->start_busy(2);
  #     }
  #     message_combatd(msg, target, me);
  # 
  #     return 1;
  # }
end
