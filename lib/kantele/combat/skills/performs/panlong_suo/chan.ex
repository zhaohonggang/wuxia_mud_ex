defmodule Kantele.Combat.Skills.Performs.PanlongSuo.Chan do
  @moduledoc """
  跗骨缠魂「chan」（对照 `kungfu/skill/panlong-suo/chan.c`）

  霹雳盘龙索绝技：需持鞭、内功>=180、霹雳盘龙索>=120、真气>=100、
  激发 whip 为霹雳盘龙索、目标未忙乱且存活。
  命中判定 `random(whip) > 目标parry/2`：命中令目标忙乱
  `panlong-suo/20 + 1` 轮、扣 80 真气、攻击方忙乱 1；
  未命中扣 30 真气、攻击方忙乱 2。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `target->is_busy()` 取引用快照（`%{id,pid,name,room_id}`）的 meta，缺 meta 时按「非忙」处理；
  - 命中引子含兵器名（在目标侧结算），兵器名随事件传递；
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

  @perform_id "panlong-suo/chan"
  @move_name "「跗骨缠魂」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "panlong-suo")
    whip = Stats.skill(stats, "whip")

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_target_busy(target),
         :ok <- check_force(stats),
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
          whip: whip,
          weapon_name: Map.get(weapon, :name, ""),
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

  # LPC: if (userp(me) && ! me->query("can_perform/panlong-suo/chan"))
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
  #          (string)weapon->query("skill_type") != "whip")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "whip" do
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

  # LPC: if ((int)me->query_skill("force") < 180)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 180 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("panlong-suo", 1) < 120)
  defp check_skill_level(level) do
    if level < 120 do
      {:error, "你的霹雳盘龙索还不到家，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("whip") != "panlong-suo")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "whip") == "panlong-suo" do
      :ok
    else
      {:error, "你没有激发霹雳盘龙索，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIM "$N" HIM "一声长啸，手中" + weapon->name() + HIM "一抖，登时"
    #           "幻化作万道紫芒向$n" HIM "身上猛套过去。\n" NOR;
    conn
    |> Broadcast.publish(
      "$N一声长啸，手中" <> weapon_name <> "一抖，登时幻化作万道紫芒向$n身上猛套过去。\n",
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
    level = Map.get(data, :level, 0)
    whip = max(Map.get(data, :whip, 0), 1)
    weapon_name = Map.get(data, :weapon_name, "")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(me->query_skill("whip")) > target->query_skill("parry") / 2)
    dp = div(Stats.skill(character.meta.stats, "parry"), 2)

    if Engine.rand(rng, whip) > dp do
      # LPC: msg += HIR "霎时$n" HIR "只觉" + weapon->name() + HIR
      #            "压力不断增加，便如跗骨之蛆，挥之不去。\n" NOR;
      #      target->start_busy(panlong-suo / 20 + 1);
      #      me->add("neili", -80); me->start_busy(1);
      combat = Combat.start_busy(character.meta.combat, div(level, 20) + 1)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn =
        Broadcast.publish(
          conn,
          "霎时$n只觉" <> weapon_name <> "压力不断增加，便如跗骨之蛆，挥之不去。\n",
          bindings
        )

      Performs.feedback(attacker, 80, 1)
      put_character(conn, character)
    else
      # LPC: msg += CYN "可是$n" CYN "小心应对，丝毫不受迷惑，纵身" "跃出了$N" CYN "的笼罩。\n" NOR;
      #      me->add("neili", -30); me->start_busy(2);
      conn =
        Broadcast.publish(
          conn,
          "可是$n小心应对，丝毫不受迷惑，纵身跃出了$N的笼罩。\n",
          bindings
        )

      Performs.feedback(attacker, 30, 2)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "panlong-suo/chan",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define CHAN "「" HIM "跗骨缠魂" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         object weapon;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/panlong-suo/chan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail(CHAN "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #         (string)weapon->query("skill_type") != "whip")
  #                 return notify_fail("你使用的武器不对，难以施展" CHAN "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #     if ((int)me->query_skill("force") < 180)
  #         return notify_fail("你的内功火候不够，难以施展" CHAN "。\n");
  # 
  #     if ((int)me->query_skill("panlong-suo", 1) < 120)
  #         return notify_fail("你的霹雳盘龙索还不到家，难以施展" CHAN "。\n");
  # 
  #         if (me->query_skill_mapped("whip") != "panlong-suo")
  #                 return notify_fail("你没有激发霹雳盘龙索，难以施展" CHAN "。\n");
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的真气不够，难以施展" CHAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIM "$N" HIM "一声长啸，手中" + weapon->name() + HIM "一抖，登时"
  #               "幻化作万道紫芒向$n" HIM "身上猛套过去。\n" NOR;
  # 
  #         if (random(me->query_skill("whip")) > target->query_skill("parry") / 2)
  #         {
  #             msg += HIR "霎时$n" HIR "只觉" + weapon->name() + HIR
  #                        "压力不断增加，便如跗骨之蛆，挥之不去。\n" NOR;
  #                 target->start_busy((int)me->query_skill("panlong-suo") / 20 + 1);
  #             me->add("neili", -80);
  #             me->start_busy(1);
  #         } else
  #     {
  #                 msg += CYN "可是$n" CYN "小心应对，丝毫不受迷惑，纵身"
  #                        "跃出了$N" CYN "的笼罩。\n" NOR;
  #             me->add("neili", -30);
  #             me->start_busy(2);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
