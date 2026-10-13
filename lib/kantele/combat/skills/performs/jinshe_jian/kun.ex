defmodule Kantele.Combat.Skills.Performs.JinsheJian.Kun do
  @moduledoc """
  perform「蛇困愁城」（source jinshe-jian/kun.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已知此招 → 目标为战斗中的对手 → 手持 sword →
  目标不在忙乱中 → 金蛇剑法>=140 → 激发 sword 为金蛇剑法 →
  真气>=200 → 目标存活。
  起手广播（含武器名）后按 `level/2 + random(level) vs 目标 dodge` 判定：
  命中播报「手忙脚乱」、目标忙乱 `1+random(level/13)`、攻击方忙乱 1；
  未命中播报「镇定解招」、攻击方忙乱 2。
  攻击方无条件扣 140 真气。

  差异（TODO(migrate)）：
  - 命中判定需目标 `dodge`，故两支文案与双方忙乱均在目标侧结算
    （攻击方忙乱经 `Performs.feedback/3` 回传）；
  - `.c` 的 `target->is_busy()` 门槛：敌人列表只存引用快照（%{id,pid,name,room_id}）
    时无 `meta.combat.busy` 可查，此时恒判不忙（同 `hujia_quan/kuai.ex` 约定），
    但保留文案字面量；
  - `.c` 起手式把武器名插在中文串中间，按约定写成 `"A" <> weapon_name <> "B"` 两段；
  - `.c` 命中/失手文案为 `msg` 重新赋值后的第二次 `message_combatd`，
    故与起手式分开广播。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "jinshe-jian/kun"
  @move_name "「蛇困愁城」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jinshe-jian")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_target_busy(target),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
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

  # LPC: if (userp(me) && ! me->query("can_perform/jinshe-jian/kun"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon != nil and Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (target->is_busy()) return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  defp check_target_busy(target) do
    if target_busy?(target) do
      {:error, target.name <> "目前正自顾不暇，放胆攻击吧。\n"}
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

  # LPC: if (level < 140)   (level = me->query_skill("jinshe-jian", 1))
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jinshe-jian") < 140 do
      {:error, "你金蛇剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "jinshe-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "sword") == "jinshe-jian" do
      :ok
    else
      {:error, "你没有激发金蛇剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIG "\n$N" HIG "轻叹一声，手中" + weapon->name() + HIG "犹如"
    #            "金蛇般的缠向$n" HIG "。\n" NOR; message_sort(msg, me, target);
    #      me->add("neili", -140);
    #      命中/失手与双方忙乱在目标侧结算（需目标 dodge）。
    weapon = Combat.weapon(character.meta.combat) || %{}
    weapon_name = Map.get(weapon, :name, "")
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 140}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    msg = ["\n$N轻叹一声，手中", weapon_name, "犹如金蛇般的缠向$n。\n"] |> Enum.join("")

    conn
    |> Broadcast.publish(msg, n1: character.name, n2: target.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 living(target) 门槛由目标侧 death 检查兜底
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (level / 2 + random(level) > target->query_skill("dodge", 1))
    if div(level, 2) + Engine.rand(rng, level) > Stats.skill(stats, "dodge") do
      # LPC: msg = HIY "一道金光闪过，$n已被$N" HIY "攻的目不暇接，手忙脚乱！\n" NOR;
      #      target->start_busy(1 + random(level / 13)); me->start_busy(1);
      combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(rng, div(level, 13)))
      character = %{character | meta: %{character.meta | combat: combat}}

      Performs.feedback(attacker, 0, 1)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "一道金光闪过，$n已被$N攻的目不暇接，手忙脚乱！\n",
          bindings
        )
      )
      |> put_character(character)
    else
      # LPC: msg = CYN "可是$n" CYN "看破了$N" CYN "的企图，镇定解招，一丝不乱。\n" NOR;
      #      me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate("可是$n看破了$N的企图，镇定解招，一丝不乱。\n", bindings)
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define HUI "「" HIG "蛇困愁城" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #         int level;
  # 
  #         if (userp(me) && ! me->query("can_perform/jinshe-jian/kun"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(HUI "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "sword")
  #                 return notify_fail("你使用的武器不对，难以施展" HUI "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         level = me->query_skill("jinshe-jian", 1);
  # 
  #         if (level < 140)
  #         return notify_fail("你金蛇剑法不够娴熟，难以施展" HUI "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "jinshe-jian")
  #                 return notify_fail("你没有激发金蛇剑法，难以施展" HUI "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你现在的真气不够，难以施展" HUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIG "\n$N" HIG "轻叹一声，手中" + weapon->name() + HIG "犹如"
  #               "金蛇般的缠向$n" HIG "。\n" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         me->add("neili", -140);
  #         if (level / 2 + random(level) > target->query_skill("dodge", 1))
  #         {
  #         msg = HIY "一道金光闪过，$n已被$N" HIY "攻的目不暇接，手忙脚乱！\n" NOR;
  #                 target->start_busy(1 + random(level / 13));
  #                 me->start_busy(1);
  #     } else
  #         {
  #         msg = CYN "可是$n" CYN "看破了$N"
  #                       CYN "的企图，镇定解招，一丝不乱。\n" NOR;
  #                 me->start_busy(2);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
