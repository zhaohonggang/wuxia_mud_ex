defmodule Kantele.Combat.Skills.Performs.LingyuanXinfa.Break do
  @moduledoc """
  exert「以柔破钢」（source lingyuan-xinfa/break.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → 目标未忙乱 → 灵元心法>=150 →
  目标存活 → 目标持有兵刃。
  起手广播后攻击方忙乱 2；以柔劲包裹对手兵刃，按
  `random(攻击方 combat_exp)` > 目标 `combat_exp/3` 判定：成功则兵刃震落
  （卸下 :weapon 装备槽）且目标忙乱 `灵元心法/20` 轮；失败则对手急急拆招闪开。

  差异（TODO(migrate)）：
  - LPC 目标无兵器时以 notify_fail 打回攻击方；本引擎攻击方只能读到敌人
    引用快照（enemies 携带 meta 时才可查兵器），瘦引用时按有兵刃放行，
    目标侧无兵刃则放弃结算（不产生文案）；
  - 兵刃震落只卸下装备槽（保留快照语义），不生成房间掉落物，
    `target->reset_action()` 未建模；
  - `target->is_busy()` 门槛读敌人引用快照，目标侧 resolve_incoming 的
    死亡检查兜底；
  - 命中文案 C 侧被 target_w->query("name") 的 + 拆成两段字面量，
    E 侧用 <> weapon_name <> 复现（不合并）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine

  @perform_id "lingyuan-xinfa/break"
  @move_name "「以柔破钢」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- find_target(combat),
         :ok <- gate_target_busy(target),
         :ok <- gate_skill_level(stats),
         :ok <- gate_target_alive(target),
         :ok <- gate_target_weapon(target) do
      conn =
        Broadcast.publish(
          conn,
          "$N沉肩滑步，自丹田中升起一股阴柔之气顺着血脉经络传至双手劳宫穴，" <>
            "接着这股阴柔之气就激射而出，喷向$n手中的兵刃！\n",
          n1: character.name,
          n2: target.name
        )

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          skill: Stats.skill(stats, "lingyuan-xinfa"),
          combat_exp: stats.combat_exp || 0,
          rng: &:rand.uniform/1
        }
      })

      # LPC: me->start_busy(2);
      combat = Combat.start_busy(combat, 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> put_character(character)
      |> assign(:prompt, false)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp find_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你只能对战斗中的对手使用#{@move_name}。\n"}
    end
  end

  # LPC: if (target->is_busy())
  #         return notify_fail(target->name() + "目前正在发愣，是进攻的好时机！\n");
  defp gate_target_busy(target) do
    if busy?(target) do
      {:error, "#{target.name}目前正在发愣，是进攻的好时机！\n"}
    else
      :ok
    end
  end

  defp busy?(%{meta: %{combat: %{busy: busy}}}) when is_number(busy), do: busy > 0
  defp busy?(_), do: false

  # LPC: if ((int)me->query_skill("lingyuan-xinfa", 1) < 150)
  defp gate_skill_level(stats) do
    if Stats.skill(stats, "lingyuan-xinfa") < 150 do
      {:error, "你的灵元心法火候不够，还不会使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target))
  defp gate_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC: return notify_fail(target->name() + "目前是空手，没什么必要施展「以柔破钢」。\n");
  # 敌人引用快照可能不含 meta（瘦引用），此时无法判定，按有兵刃放行。
  defp gate_target_weapon(target) do
    case target do
      %{meta: %{combat: combat}} ->
        case Combat.weapon(combat) do
          nil -> {:error, "#{target.name}目前是空手，没什么必要施展#{@move_name}。\n"}
          _weapon -> :ok
        end

      _ ->
        :ok
    end
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
    skill = Map.get(data, :skill, 0)
    att_exp = Map.get(data, :combat_exp, 0)
    combat = character.meta.combat

    # LPC: if (target->query_temp("weapon") || target->query_temp("secondary_weapon"))
    case Combat.weapon(combat) do
      nil ->
        # 瘦引用放行后目标侧实际无兵刃：放弃结算（不产生文案）。
        conn

      weapon ->
        t_exp = character.meta.stats.combat_exp || 0

        # LPC: if (random(me->query("combat_exp")) > (int)target->query("combat_exp") / 3)
        if Engine.rand(rng, max(att_exp, 1)) > div(t_exp, 3) do
          # target_w->unequip(); target->start_busy(lingyuan-xinfa / 20);
          combat =
            combat
            |> Combat.unequip(:weapon)
            |> Combat.start_busy(max(div(skill, 20), 1))

          character = %{character | meta: %{character.meta | combat: combat}}
          weapon_name = Map.get(weapon, :name, "")

          # LPC: HIW "结果$p" HIW "手中的" + target_w->query("name") +
          #      "与这股阴柔之气一碰竟被震落在地上！\n" NOR;
          # 两段字面量被 weapon name 的 + 分隔，用 <> 拆段复现（不合并）。
          conn
          |> Broadcast.publish(
            "结果$p手中的" <> weapon_name <> "与这股阴柔之气一碰竟被震落在地上！\n",
            n1: attacker.name,
            n2: character.name
          )
          |> put_character(character)
        else
          # LPC: CYN "可是$p" CYN "急急拆招，躲了开去，使$P" CYN "的计谋没有得逞。\n" NOR;
          conn
          |> Broadcast.publish(
            "可是$p急急拆招，躲了开去，使$P的计谋没有得逞。\n",
            n1: attacker.name,
            n2: character.name
          )
        end
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // break -「以柔破钢」
  # // made by deaner
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # int exert(object me, object target)
  # {
  #         string msg;
  #         object target_w;
  # 
  #         target_w = target->query_temp("weapon");
  # 
  #         if (! target || target == me)
  #         {
  #             me->clean_up_enemy();
  #             target = me->select_opponent();
  #         }
  #     if (! target || ! me->is_fighting(target))
  #                 return notify_fail("你只能对战斗中的对手使用「以柔破钢」。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正在发愣，是进攻的好时机！\n");
  # 
  #         if ((int)me->query_skill("lingyuan-xinfa", 1) < 150)
  #                 return notify_fail("你的灵元心法火候不够，还不会使用「以柔破钢」。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIC "$N" HIC "沉肩滑步，自丹田中升起一股阴柔之气"
  #               "顺着血脉经络传至双手劳宫穴，接着这股阴柔之气就"
  #               "激射而出，喷向$n" HIC "手中的兵刃！\n" NOR;
  #         me->start_busy(2);
  # 
  #         if (target->query_temp("weapon") || target->query_temp("secondary_weapon"))
  #         {
  #                 if (random(me->query("combat_exp")) >
  #                     (int)target->query("combat_exp") / 3)
  #                 {
  #                         msg += HIW "结果$p" HIW "手中的" +
  #                                target_w->query("name") +
  #                                "与这股阴柔之气一碰竟被震落在地上！\n" NOR;
  #                         target_w->unequip();
  #                         target_w->move(environment(target));
  #                         target->reset_action();
  #                         target->start_busy((int)me->query_skill("lingyuan-xinfa") / 20);
  #                 } else
  #                 {
  #                         msg += CYN "可是$p" CYN "急急拆招，躲了"
  #                                "开去，使$P" CYN "的计谋没有得逞。\n" NOR;
  #                 }
  #                 message_combatd(msg, me, target);
  #                 return 1;
  #         }
  #         return notify_fail(target->name() + "目前是空手，没什么必要施展「以柔破钢」。\n");
  # }
end
