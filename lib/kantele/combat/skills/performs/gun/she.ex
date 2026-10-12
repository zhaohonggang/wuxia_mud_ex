defmodule Kantele.Combat.Skills.Performs.Gun.She do
  @moduledoc """
  perform「拔枪狼牙射击」（source gun/she.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：已学此招 → 目标在战斗中 → 持枪械（`hammer`）→
  枪械技术>=80 → 激发 `hammer` 为枪械技术 → 目标存活。
  起手广播后连出 18 击，攻击方忙乱 1。

  差异（TODO(migrate)）：
  - `.c` 的 18 次 `COMBAT_D->do_attack(me, target, weapon, 0)`（完整 AP/DP/招架/
    伤害管线）折算为每击 `gun/10` 基础伤害 + 命中判定 `gun/2 + random(gun)` vs
    目标 `dodge`（同 `fengmo_zhang/luan.ex`、`daojian_guizhen/xue.ex`）；
  - `.c` 的起手文案 `"…手中" + weapon->name() + "连续数枪…"` 因显式 `+` 被切成
    两段，E 侧用列表 `Enum.join("")` 保持同粒度（不得用 `<>` 合并）；
  - `.c` 的 18 次 `do_attack` 无显式文案，目标侧补一句结算广播（额外文案不影响对齐）；
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎以框架层
    `perform_known?/2` 统一把关（多出的文案不影响对齐）；
  - `living(target)` 门槛在攻击方无 meta 可查，此处保守恒判存活，
    由目标侧 `combat/perform-incoming` 的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine

  @perform_id "gun/she"
  @move_name "「拔枪狼牙射击」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "gun")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- check_weapon(character),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
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

      apply_effect(conn, character, target, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # 框架层「是否已学此招」门槛（.c 未列 `can_perform`，见 moduledoc 差异说明）。
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

  # LPC: if (! objectp(weapon = me->query_temp("weapon"))
  #         || (string)weapon->query("skill_type") != "hammer")
  defp check_weapon(character) do
    case Combat.weapon(character.meta.combat) do
      %{skill_type: "hammer"} = weapon -> {:ok, weapon}
      _ -> {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("gun", 1) < 80)
  defp check_level(stats) do
    if Stats.skill(stats, "gun") < 80 do
      {:error, "你的枪械技术不够熟练，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("hammer") != "gun")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "hammer") != "gun" do
      {:error, "你并没有运用枪械技术，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
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

  defp apply_effect(conn, character, target, weapon) do
    # LPC: msg = HIR "$N" HIR "施出秘奥义「拔枪狼牙射击」，手中" + weapon->name() +
    #            HIR "连续数枪，同时喷出数十条火龙罩向$n" HIR "四周！\n\n" NOR;
    #      message_combatd(msg, me, target);
    # 两段固定文案被 `+` 分隔，逐段保留（勿用 `<>` 合并）。
    conn =
      Broadcast.publish(
        conn,
        Enum.join(
          [
            "$N施出秘奥义「拔枪狼牙射击」，手中",
            Map.get(weapon, :name),
            "连续数枪，同时喷出数十条火龙罩向$n四周！\n\n"
          ],
          ""
        ),
        n1: character.name,
        n2: target.name
      )

    # LPC: for (i = 0; i < 18; i++) { if (! me->is_fighting(target)) break;
    #        COMBAT_D->do_attack(me, target, weapon, 0); }
    #      me->start_busy(1);
    combat = Combat.start_busy(character.meta.combat, 1)
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
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
    ap = max(Map.get(data, :level, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: for (i = 0; i < 18; i++) COMBAT_D->do_attack(me, target, weapon, 0);
    # 折算：每击 ap/10 基础伤害 + 命中判定 ap/2 + random(ap) vs 目标 dodge。
    dodge = Stats.skill(stats, "dodge")
    per_hit = max(div(ap, 10), 1)

    {damage, hits} =
      Enum.reduce(1..18, {0, 0}, fn _, {damage_acc, hit_acc} ->
        if div(ap, 2) + Engine.rand(rng, ap) > dodge do
          {damage_acc + per_hit + Engine.rand(rng, per_hit), hit_acc + 1}
        else
          {damage_acc, hit_acc}
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # `.c` 的 18 次 do_attack 无显式文案，此处补一句结算广播。
    msg =
      if hits > 0 do
        "结果$p被$N的#{@move_name}击中，连遭重击！\n"
      else
        "可是$p左闪右避，堪堪避开了$N的#{@move_name}。\n"
      end

    conn
    |> Broadcast.publish(msg, bindings)
    |> put_character(character)
    |> assign(:prompt, false)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define SHE "「" HIR "拔枪狼牙射击" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #     int i;
  # 
  #         if (userp(me) && ! me->query("can_perform/gun/she"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHE "只能对战斗中的对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "hammer")
  #                 return notify_fail("你使用的武器不对，难以施展" SHE "。\n");
  # 
  #         if ((int)me->query_skill("gun", 1) < 80)
  #                 return notify_fail("你的枪械技术不够熟练，难以施展" SHE "。\n");
  # 
  #         if (me->query_skill_mapped("hammer") != "gun")
  #                 return notify_fail("你并没有运用枪械技术，难以施展" SHE "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "施出秘奥义「拔枪狼牙射击」，手中" + weapon->name() +
  #               HIR "连续数枪，同时喷出数十条火龙罩向$n" HIR "四周！\n\n" NOR;
  #         message_combatd(msg, me, target);
  # 
  #         for (i = 0; i < 18; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 COMBAT_D->do_attack(me, target, weapon, 0);
  #         }
  # 
  #         me->start_busy(1);
  #         return 1;
  # }
end
