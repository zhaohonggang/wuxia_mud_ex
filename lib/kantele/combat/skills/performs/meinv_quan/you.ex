defmodule Kantele.Combat.Skills.Performs.MeinvQuan.You do
  @moduledoc """
  perform「古墓幽居」（对照 `kungfu/skill/meinv-quan/you.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 空手（未持武器）→
  美女拳法>=80 → 内功>=120 → 真气>=180 → 激发 `unarmed` 为美女拳法 →
  准备美女拳法 → 目标存活。
  起手文案在攻击方广播；命中判定 `random(攻击方内功) > 目标内功/2` 在目标侧结算：
  命中则攻击方扣 100 真气、忙乱 2，目标 qi 伤 `(unarmed/2 + random(unarmed/2))`、
  qi 上限伤 `damage*45/100`；未命中则攻击方忙乱 3。

  差异（TODO(migrate)）：
  - `.c` 把起手与分支文案累积到 `msg` 后一次 `message_sort`；此处按引擎惯例拆分
    （起手在攻击方 `apply_effect` 广播，分支在目标侧广播，同 `guzhuo_zhang/yu.ex`），
    `message_sort`（按感知排序）→ 房间广播 `Broadcast.publish/3`；
  - 命中条件依赖目标 `force`、伤害依赖攻击方 `unarmed`，均经 `combat/perform-incoming`
    事件数据传递到目标侧；
  - 命中分支内的 `me->start_busy(2)` 与 `me->add("neili", -100)`、未命中分支的
    `me->start_busy(3)` 均经 `Performs.feedback/3` 跨进程回执；
  - `COMBAT_D->do_damage(...,damage,45,msg)` → `damage(:qi,damage)` +
    `wound(:qi, div(damage*45,100))` 并广播该文案；
  - `!living(target)` 门槛在攻击方无 meta 可查，恒判存活，由目标侧
    `combat/perform-incoming` 的死亡检查兜底；
  - `me->query_skill("force")` → `Stats.skill(stats, "force")`。
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

  @perform_id "meinv-quan/you"
  @move_name "「古墓幽居」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "meinv-quan")
    # LPC: damage = (int)me->query_skill("unarmed");（目标侧折算用）
    unarmed = Stats.skill(stats, "unarmed")
    force = Stats.skill(stats, "force")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats),
         :ok <- check_prepared(stats),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          unarmed: unarmed,
          force: force,
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

  # LPC: if (userp(me) && ! me->query("can_perform/meinv-quan/you"))
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

  # LPC: if (me->query_temp("weapon"))
  defp check_weapon(combat) do
    if Combat.weapon(combat) == nil do
      :ok
    else
      {:error, "你必须空手才能施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("meinv-quan", 1) < 80)
  #      if ((int)me->query_skill("force") < 120)
  defp check_levels(stats) do
    cond do
      Stats.skill(stats, "meinv-quan") < 80 ->
        {:error, "你的美女拳法别不够，不会使用#{@move_name}。\n"}

      Stats.skill(stats, "force") < 120 ->
        {:error, "你的内功还未娴熟，不能使用#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 180)
  defp check_neili(character) do
    if character.meta.vitals.neili < 180 do
      {:error, "你现在真气不够，不能使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("unarmed") != "meinv-quan")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "unarmed") != "meinv-quan" do
      {:error, "你没有激发美女拳法，不能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "meinv-quan")
  defp check_prepared(stats) do
    prepared = Stats.prepared_perform(stats, "unarmed")

    if is_binary(prepared) and String.split(prepared, "/") |> hd() == "meinv-quan" do
      :ok
    else
      {:error, "你没有准备美女拳法，难以施展#{@move_name}。\n"}
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

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIW "\n$N" HIW "右手支颐，左袖轻轻挥出，长叹一声，使"
    #            "出古墓派绝学「古墓幽居」，一脸尽现寂寥之意。\n" NOR;
    Broadcast.publish(
      conn,
      "\n$N右手支颐，左袖轻轻挥出，长叹一声，使出古墓派绝学#{@move_name}，一脸尽现寂寥之意。\n",
      n1: character.name,
      n2: target.name
    )
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
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]
    unarmed = max(Map.get(data, :unarmed, 0), 0)
    force = max(Map.get(data, :force, 0), 0)

    # LPC: if (random(me->query_skill("force")) > target->query_skill("force") / 2)
    #      { me->start_busy(2); damage = unarmed / 2 + random(unarmed / 2);
    #        me->add("neili", -100);
    #        msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45, "…"); }
    #      else { me->start_busy(3); msg += "可是$p看破了$P的企图…这一拳。\n"; }
    if Engine.rand(rng, force) > div(Stats.skill(stats, "force"), 2) do
      damage = div(unarmed, 2) + Engine.rand(rng, div(unarmed, 2))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 45, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}
      Performs.feedback(attacker, 100, 2)

      conn
      |> Broadcast.publish(
        "但见$N双拳袭来，柔中带刚，迅猛无比，其间仿佛蕴藏着无穷的威力，$n正迟疑间， $N却已中拳，闷哼一声，倒退几步，一口鲜血喷出。\n",
        bindings
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 0, 3)

      Broadcast.publish(
        conn,
        "可是$p看破了$P的企图，稳如泰山，抬手一架格开了$P这一拳。\n",
        bindings
      )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define YOU "「" HIG "古墓幽居" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  # //      string pmsg;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/meinv-quan/you"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(YOU "只能对战斗中的对手使用。\n");
  # 
  #     if (me->query_temp("weapon"))
  #         return notify_fail("你必须空手才能施展" YOU "。\n");
  # 
  #         if ((int)me->query_skill("meinv-quan", 1) < 80)
  #                 return notify_fail("你的美女拳法别不够，不会使用" YOU "。\n");
  # 
  #         if ((int)me->query_skill("force") < 120)
  #                 return notify_fail("你的内功还未娴熟，不能使用" YOU "。\n");
  # 
  #         if ((int)me->query("neili") < 180)
  #                 return notify_fail("你现在真气不够，不能使用" YOU "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "meinv-quan")
  #                 return notify_fail("你没有激发美女拳法，不能施展" YOU "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "meinv-quan")
  #                 return notify_fail("你没有准备美女拳法，难以施展" YOU "。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "\n$N" HIW "右手支颐，左袖轻轻挥出，长叹一声，使"
  #               "出古墓派绝学「古墓幽居」，一脸尽现寂寥之意。\n" NOR;
  # 
  #         if (random(me->query_skill("force")) > target->query_skill("force") / 2)
  #         {
  #                 //me->start_busy(2 + random(2));
  #                 me->start_busy(2);
  # 
  #                 damage = (int)me->query_skill("unarmed");
  #                 damage = damage / 2 + random(damage / 2);
  # 
  #                 me->add("neili", -100);
  # 
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
  #                                            HIR "但见$N" HIR "双拳袭来，柔中带刚，迅"
  #                                            "猛无比，其间仿佛蕴藏着无穷的威力，$n" HIR
  #                                            "正迟疑间， $N" HIR "却已中拳，闷哼一声，倒"
  #                                            "退几步，一口鲜血喷出。\n" NOR);
  #         } else
  #         {
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "看破了$P" CYN
  #                        "的企图，稳如泰山，抬手一架格开了$P"
  #                        CYN "这一拳。\n"NOR;
  #         }
  #         message_sort(msg, me, target);
  # 
  #         return 1;
  # }
end
