defmodule Kantele.Combat.Skills.Performs.BlueseaForce.Xuan do
  @moduledoc """
  perform「玄黄连环掌」（source bluesea-force/perform/xuan.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标为战斗中的对手 → 真气>=200 → 南海玄功>=150 →
  激发 strike 为南海玄功 → 准备 strike 招式 → 目标存活。
  ap = `南海玄功/2 + random(南海玄功)`，dp = 目标 `基本内功*2/3`（目标侧计算）。
  命中：连击数 `5 + random(5)`；失手：连击数恒 5。
  攻击方扣 `连击数*20` 真气并忙乱 `1+random(7)`。

  差异（TODO(migrate)）：
  - LPC `me->add_temp("apply/attack", count)`（count=南海玄功/5）为出击期间的临时加成，
    折算为每击命中/伤害基数的一部分（与 `biluo_zhang/lian.ex` 同构），
    循环结束后按 LPC `add_temp("apply/attack", -count)` 的形式自然抵消；
  - 5~9 次 `COMBAT_D->do_attack` 折叠为 `Enum.reduce`，每次独立命中判定；
    目标忙乱条件按 LPC `while (i--)` 的后置自减语义折算为
    `k < strikes - 4`（k 为 1 起计的第 k 击）。
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
  alias Kantele.Combat.Performs

  @perform_id "bluesea-force/xuan"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "bluesea-force")

    with {:ok, target} <- target(combat),
         :ok <- check_resources(character),
         :ok <- check_levels(stats),
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

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  #              return notify_fail("玄黄连环掌只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "玄黄连环掌只能对战斗中的对手使用。\n"}
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "你的真气不够，无法施展玄黄连环掌！\n"}
      true -> :ok
    end
  end

  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "bluesea-force") < 150 ->
        {:error, "你的南海玄功火候不够，无法施展玄黄连环掌！\n"}

      true -> :ok
    end
  end

  defp check_mapped(stats) do
    cond do
      Stats.mapped(stats, "strike") != "bluesea-force" ->
        {:error, "你没有激发南海玄功为掌法，无法施展玄黄连环掌！\n"}

      Stats.prepared_perform(stats, "strike") == nil or
          String.split(Stats.prepared_perform(stats, "strike"), "/") |> hd() != "bluesea-force" ->
        {:error, "你没有准备好使用南海玄功，无法施展玄黄连环掌！\n"}

      true ->
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIC "$N" HIC "轻轻划了个圈子，身形忽然变快，合数招为一击攻向$n"
    #              HIC "！\n" NOR;（命中/失手追加段由目标侧发布）
    conn =
      Broadcast.publish(
        conn,
        "$N轻轻划了个圈子，身形忽然变快，合数招为一击攻向$n！\n",
        n1: character.name,
        n2: target.name
      )

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
    lvl = max(Map.get(data, :level, 0), 1)
    # LPC: count = me->query_skill("bluesea-force", 1) / 5；（apply/attack 临时加成）
    count = div(lvl, 5)

    stats = character.meta.stats
    # LPC: dp = (int)target->query_skill("force") * 2 / 3;
    dp = div(Stats.skill(stats, "force") * 2, 3)

    # LPC: if (lvl / 2 + random(lvl) > target_force * 2 / 3)
    hit = div(lvl, 2) + Engine.rand(rng, lvl) > dp

    # LPC: i = 5; 命中支 i += random(5)
    strikes = if hit, do: 5 + Engine.rand(rng, 5), else: 5

    {vitals, combat} =
      Enum.reduce(1..strikes, {character.meta.vitals, character.meta.combat}, fn k,
                                                                               {v_acc, c_acc} ->
        # LPC: if (i > 4 && ! target->is_busy()) target->start_busy(1);
        # 折算 while (i--) 的后置自减语义：k 为 1 起计的第 k 击时循环变量已变为
        # strikes - k，故条件为 k < strikes - 4。
        c_acc =
          if k < strikes - 4 and not Combat.busy?(c_acc) do
            Combat.start_busy(c_acc, 1)
          else
            c_acc
          end

        # LPC: COMBAT_D->do_attack(me, target, 0, 0)（含 apply/attack + count 的加成）
        base = max(lvl + count, 1)

        if div(base, 2) + Engine.rand(rng, base) > dp do
          {Vitals.damage(v_acc, :qi, base + Engine.rand(rng, base)), c_acc}
        else
          {v_acc, c_acc}
        end
      end)

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    msg =
      [
        if hit do
          "内力激荡之下，$n登时觉得呼吸不畅，浑身有如重压，万分难受，只见$N一掌接一掌的攻到，有如海浪。\n"
        else
          "$n见来掌奇快，只好振作精神勉力抵挡。\n"
        end
      ]
      |> Enum.join("")

    result = Kantele.Combat.Messages.interpolate(msg, n1: attacker.name, n2: character.name)

    # LPC: me->add("neili", -i * 20);（连击数在上一段确定）
    #      me->start_busy(1 + random(7));
    Performs.feedback(attacker, strikes * 20, 1 + :rand.uniform(7))

    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"apply_adds": ["attack"], "assign_refs": [{"count", "bluesea-force"}, {"lvl", "bluesea-force"}], "busy_lines": ["if (i > 4 && ! target->is_busy())", "target->start_busy(1);", "me->start_busy(1 + random(7));"], "level_gates": [{"bluesea-force", "150"}], "map_gates": [{"strike", "bluesea-force"}], "prepared_gates": [{"strike", "bluesea-force"}], "remote_damage": false, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // yong.c 玄黄连环掌
  #
  # #include <ansi.h>
  #
  # inherit F_SSERVER;
  #
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int count;
  #         int lvl;
  #         int i;
  #
  #         if (! target)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  #
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("玄黄连环掌只能对战斗中的对手使用。\n");
  #
  #     if (me->query("neili") < 200)
  #         return notify_fail("你的真气不够，无法施展玄黄连环掌！\n");
  #
  #     if ((lvl = me->query_skill("bluesea-force", 1)) < 150)
  #         return notify_fail("你的南海玄功火候不够，无法施展玄黄连环掌！\n");
  #
  #         if (me->query_skill_mapped("strike") != "bluesea-force")
  #                 return notify_fail("你没有激发南海玄功为掌法，无法施展玄黄连环掌！\n");
  #
  #         if (me->query_skill_prepared("strike") != "bluesea-force")
  #                 return notify_fail("你没有准备好使用南海玄功，无法施展玄黄连环掌！\n");
  #
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  #
  #     msg = HIC "$N" HIC "轻轻划了个圈子，身形忽然变快，合数招为一击攻向$n"
  #               HIC "！\n" NOR;
  #         i = 5;
  #         if (lvl / 2 + random(lvl) > (int)target->query_skill("force") * 2 / 3)
  #         {
  #                 msg += HIY "内力激荡之下，$n" HIY "登时觉得呼吸"
  #                        "不畅，浑身有如重压，万分难受，只见$N"
  #                        HIY "一掌接一掌的攻到，有如海浪。\n" NOR;
  #                 count = me->query_skill("bluesea-force", 1) / 5;
  #                 me->add_temp("apply/attack", count);
  #                 i += random(5);
  #         } else
  #         {
  #                 msg += CYN "$n" CYN "见来掌奇快，只好振作精神勉力抵挡。\n" NOR;
  #                 count = 0;
  #         }
  #
  #     message_combatd(msg, me, target);
  #     me->add("neili", -i * 20);
  #
  #         while (i--)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (i > 4 && ! target->is_busy())
  #                         target->start_busy(1);
  #             COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  #
  #         me->add_temp("apply/attack", -count);
  #     me->start_busy(1 + random(7));
  #     return 1;
  # }
end
