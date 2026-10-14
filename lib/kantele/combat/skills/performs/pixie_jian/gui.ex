defmodule Kantele.Combat.Skills.Performs.PixieJian.Gui do
  @moduledoc """
  perform「鬼魅身法」（对照 `kungfu/skill/pixie-jian/gui.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → **目标不忙乱** →
  辟邪剑法>=100 → 真气>=100 → 激发 dodge 为辟邪剑法 → 目标存活。
  起手广播后由目标侧判定 `ap/2 + random(ap) > 目标招架`
  （`ap = 辟邪剑法*2`）：命中则目标忙乱 `ap/45 + 2`、攻击方忙乱 1；
  未命中则攻击方忙乱 2。两种情况攻击方均扣 50 真气。

  差异（TODO(migrate)）：
  - **目标忙乱门槛**（`target->is_busy()`，文案 `target->name() + "目前正自顾不暇，
    放胆攻击吧。\\n"`——注意此处**无**全角叹号）在攻击方不可得，故移到目标侧
    `resolve_incoming` 判定，文案以 `$n` 绑定目标名（同 `miaojia_jian/zhai.ex`）；
  - `me->add("neili", -50)` 在 `.c` 里位于两条分支之后（无条件），而分支判定需
    目标招架，故经 `Performs.feedback(attacker, 50, busy)` 在目标侧回授；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "pixie-jian/gui"
  @move_name "「鬼魅身法」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("pixie-jian", 1) * 2;
    ap = Stats.skill(stats, "pixie-jian") * 2

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
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

  # LPC: if (userp(me) && ! me->query("can_perform/pixie-jian/gui"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill("pixie-jian", 1) < 100)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "pixie-jian") < 100 do
      {:error, "你的辟邪剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 100)
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("dodge") != "pixie-jian")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "dodge") == "pixie-jian" do
      :ok
    else
      {:error, "你没有准备使用辟邪剑法，难以施展#{@move_name}。\n"}
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
    # LPC: msg = HIR "$N" HIR "身子忽进忽退，宛若鬼魅，身形诡秘异常，在$n"
    #            HIR "身边飘忽不定。\n" NOR;
    #      之后按分支置忙乱，并 me->add("neili", -50)（在目标侧回授）。
    Broadcast.publish(
      conn,
      "$N身子忽进忽退，宛若鬼魅，身形诡秘异常，在$n身边飘忽不定。\n",
      n1: character.name,
      n2: target.name
    )
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # LPC: if (target->is_busy())
  #      return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 目标忙乱状态只在目标侧可见，故与死亡检查一并在此结算。
  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        conn

      Combat.busy?(character.meta.combat) ->
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧。\n",
          n1: attacker.name,
          n2: character.name
        )

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { msg += HIR "$p" HIR "霎时只觉眼花缭乱，只能紧守门户，不"
    #                     "敢妄自出击！\n" NOR;
    #        target->start_busy(ap / 45 + 2);
    #        me->start_busy(1); }
    #      else
    #      { msg += CYN "可是$p" CYN "看破了$P" CYN "的身法，并没有受"
    #                     "到任何影响。\n" NOR;
    #        me->start_busy(2); }
    #      me->add("neili", -50);
    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      combat = Combat.start_busy(character.meta.combat, div(ap, 45) + 2)

      # LPC: me->start_busy(1);  me->add("neili", -50);
      Performs.feedback(attacker, 50, 1)

      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish("$p霎时只觉眼花缭乱，只能紧守门户，不敢妄自出击！\n", bindings)
      |> put_character(character)
    else
      # LPC: me->start_busy(2);  me->add("neili", -50);
      Performs.feedback(attacker, 50, 2)

      conn
      |> Broadcast.publish("可是$p看破了$P的身法，并没有受到任何影响。\n", bindings)
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define GUI "「" HIR "鬼魅身法" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     string msg;
  # //      object weapon;
  #         int ap, dp;
  #         int skill;
  # 
  #         if (userp(me) && ! me->query("can_perform/pixie-jian/gui"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! me->is_fighting(target))
  #                 return notify_fail(GUI "只能对战斗中的对手使用。\n");
  # 
  #     if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         skill = me->query_skill("pixie-jian", 1);
  # 
  #         if (skill < 100)
  #                 return notify_fail("你的辟邪剑法不够娴熟，难以施展" GUI "。\n");
  # 
  #         if (me->query("neili") < 100)
  #                 return notify_fail("你现在的真气不足，难以施展" GUI "。\n");
  # 
  #         if (me->query_skill_mapped("dodge") != "pixie-jian")
  #                 return notify_fail("你没有准备使用辟邪剑法，难以施展" GUI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "身子忽进忽退，宛若鬼魅，身形诡秘异常，在$n"
  #               HIR "身边飘忽不定。\n" NOR;
  # 
  #         ap = me->query_skill("pixie-jian", 1) * 2;
  #         dp = target->query_skill("parry");
  # 
  #     if (ap / 2 + random(ap) > dp)
  #         {
  #         msg += HIR "$p" HIR "霎时只觉眼花缭乱，只能紧守门户，不"
  #                        "敢妄自出击！\n" NOR;
  #         target->start_busy(ap / 45 + 2);
  #         me->start_busy(1);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破了$P" CYN "的身法，并没有受"
  #                        "到任何影响。\n" NOR;
  #         me->start_busy(2);
  #     }
  #         me->add("neili", -50);
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
