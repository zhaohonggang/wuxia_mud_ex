defmodule Kantele.Combat.Skills.Performs.NingxueZhang.Xue do
  @moduledoc """
  缤纷雪舞「xue」（对照 `kungfu/skill/ningxue-zhang/xue.c`）

  凝雪杖法绝技：需持杖、凝雪杖法>=50、激发 staff 为凝雪杖法、真气>=200、
  目标存活。起手广播后连出 `attack_time` 击
  （`attack_time = 4 + random(sword/40)`，上限 6；`COMBAT_D->do_attack`），
  扣 `attack_time*20` 真气并忙乱 `1 + random(attack_time)`。

  差异（TODO(migrate)）：
  - LPC 的 `attack_time` 次 `COMBAT_D->do_attack`（完整 AP/DP/招架/伤害管线）
    折算为逐击命中判定 + 伤害（同 `biyan_dao/luo.ex`）；`.c` 的 `dp`
    （目标 dodge）在 LPC 中赋值后未直接使用，折算时作为逐击防御值；
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - LPC 首句用 `message_sort`，本引擎统一走 `Broadcast.publish`。
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
  alias Kantele.Character.Vitals

  @perform_id "ningxue-zhang/xue"
  @move_name "「缤纷雪舞」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "ningxue-zhang")
    sword = Stats.skill(stats, "sword")

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
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

  # LPC: if (userp(me) && ! me->query("can_perform/ningxue-zhang/xue"))
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #         || (string)weapon->query("skill_type") != "staff")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "staff" do
      {:ok, weapon}
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("ningxue-zhang", 1) < 50)
  defp check_skill_level(level) do
    if level < 50 do
      {:error, "你的凝雪杖法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("staff") != "ningxue-zhang")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "staff") == "ningxue-zhang" do
      :ok
    else
      {:error, "你没有激发凝雪杖法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你目前的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: msg = HIC "\n$N" HIC "蓦的一声清啸，施出绝学「" HIM "缤纷雪舞"
    #           HIC "」，手中" + weapon->name() + HIC "呼呼作响。霎时间"
    #           "连连攻向$n" HIC "。" NOR;
    conn
    |> Broadcast.publish(
      "\n$N蓦的一声清啸，施出绝学「缤纷雪舞」，手中" <>
        weapon_name <> "呼呼作响。霎时间连连攻向$n。\n",
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
    ap = max(Map.get(data, :sword, 0), 1)
    dodge = Stats.skill(character.meta.stats, "dodge")

    # LPC: attack_time = 4; attack_time += random(ap / 40);
    #      if (attack_time > 6) attack_time = 6;
    attack_time = min(4 + Engine.rand(rng, div(ap, 40)), 6)

    # LPC: for (i = 0; i < attack_time; i++) { COMBAT_D->do_attack(me, target, weapon, 0); }
    # do_attack 第 5 参为 0（无自定义文案），命中/失手文案由引擎动作表另行生成。
    damage =
      Enum.reduce(1..attack_time, 0, fn _i, acc ->
        if div(ap, 2) + Engine.rand(rng, ap) > dodge do
          acc + ap + Engine.rand(rng, ap)
        else
          acc
        end
      end)

    vitals =
      if damage > 0 do
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 3))
      else
        character.meta.vitals
      end

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->add("neili", -attack_time * 20); me->start_busy(1 + random(attack_time));
    Performs.feedback(attacker, attack_time * 20, 1 + Engine.rand(rng, attack_time))

    put_character(conn, character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "ningxue-zhang/xue",
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
  # #define XUE "「" HIW "缤纷雪舞" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int ap, dp;
  #         int i, attack_time;
  # 
  #         if (userp(me) && ! me->query("can_perform/ningxue-zhang/xue"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(XUE "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon"))
  #            || (string)weapon->query("skill_type") != "staff")
  #                 return notify_fail("你所使用的武器不对，难以施展" XUE "。\n");
  # 
  #     if ((int)me->query_skill("ningxue-zhang", 1) < 50)
  #         return notify_fail("你的凝雪杖法不够娴熟，难以施展" XUE "。\n");
  # 
  #         if (me->query_skill_mapped("staff") != "ningxue-zhang")
  #                 return notify_fail("你没有激发凝雪杖法，难以施展" XUE "。\n");
  # 
  #     if (me->query("neili") < 200)
  #         return notify_fail("你目前的真气不够，难以施展" XUE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIC "\n$N" HIC "蓦的一声清啸，施出绝学「" HIM "缤纷雪舞"
  #               HIC "」，手中" + weapon->name() + HIC "呼呼作响。霎时间"
  #               "连连攻向$n" HIC "。" NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         attack_time = 4;
  # 
  #     ap = me->query_skill("sword");
  #     dp = target->query_skill("dodge");
  # 
  #         attack_time += random(ap / 40);
  # 
  #         if (attack_time > 6)
  #                 attack_time = 6;
  # 
  #     me->add("neili", -attack_time * 20);
  # 
  #         for (i = 0; i < attack_time; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  # 
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #     me->start_busy(1 + random(attack_time));
  # 
  #         return 1;
  # }
end
