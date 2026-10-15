defmodule Kantele.Combat.Skills.Performs.SongshanJian.Meng do
  @moduledoc """
  如梦如幻「meng」（对照 `kungfu/skill/songshan-jian/meng.c`）

  嵩山剑法牵制攻击：需持剑、目标未忙乱且存活、嵩山剑法>=40、激发 sword 为
  嵩山剑法、真气>=120。攻击方恒扣 80 真气；命中判定
  `level + random(level) > 目标dodge`（level = 嵩山剑法）：命中令目标忙乱
  `2 + random(level/26)` 轮，攻击方忙乱 `random(2)`；未命中攻击方忙乱 2。

  差异（TODO(migrate)）：
  - `.c` 的 `target->is_busy()` 与 `living(target)` 门槛由目标侧
    `combat/perform-incoming` 的 `cond` 兜底（攻击方拿不到目标 meta）；
  - `.c` 结果段用 `message_vision(msg, target, me)`，**参数顺序与惯例相反**，
    故 `$N` 指目标、`$n` 指攻击方：目标侧绑定相应反转
    （`n1: character.name, n2: attacker.name`）；
  - 引子仍走 `message_sort(msg, me, target)`，故攻击方侧绑定为常规方向。
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

  @perform_id "songshan-jian/meng"
  @move_name "「如梦如幻」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, weapon, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/songshan-jian/meng"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #           (string)weapon->query("skill_type") != "sword")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query_skill("songshan-jian", 1) < 40)
  defp check_level(stats) do
    if Stats.skill(stats, "songshan-jian") < 40 do
      {:error, "你嵩山剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("sword") != "songshan-jian")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "songshan-jian" do
      :ok
    else
      {:error, "你没有激发嵩山剑法，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if ((int)me->query("neili") < 120)
  defp check_neili(character) do
    if character.meta.vitals.neili < 120 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon, stats) do
    weapon_name = Map.get(weapon, :name, "")
    level = Stats.skill(stats, "songshan-jian")

    # LPC: msg = HIC "\n$N" HIC "怒啸一声，施展出绝招「" HIW "如梦如幻" HIC "」"
    #           "手中" + wn + HIC "似攻非攻，欲进忽退，令人匪夷所思。\n"NOR;
    #      message_sort(msg, me, target);
    #      level = me->query_skill("songshan-jian", 1);
    #      me->add("neili", -80);
    conn =
      Broadcast.publish(
        conn,
        "\n$N怒啸一声，施展出绝招「如梦如幻」手中" <>
          weapon_name <> "似攻非攻，欲进忽退，令人匪夷所思。\n",
        n1: character.name,
        n2: target.name
      )

    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 80, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    cond do
      character.meta.combat.dead ->
        # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
        Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
          n1: attacker.name,
          n2: character.name
        )

      character.meta.combat.busy > 0 ->
        # LPC: if (target->is_busy())
        #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
        Broadcast.publish(conn, "$n目前正自顾不暇，放胆攻击吧。",
          n1: attacker.name,
          n2: character.name
        )

      true ->
        do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    # LPC: message_vision(msg, target, me) —— 参数顺序与惯例相反，
    #      $N 指目标（character）、$n 指攻击方（attacker）。
    bindings = [n1: character.name, n2: attacker.name]

    # LPC: if (level + random(level) > target->query_skill("dodge"))
    level = max(Map.get(data, :level, 0), 1)
    dp = Stats.skill(stats, "dodge")

    if level + Engine.rand(rng, level) > dp do
      # LPC: msg = HIY "$N" HIW "看不出$n" HIW "招式中的虚实，连忙" "护住自己全身，一时竟无以应对！\n" NOR;
      #      target->start_busy(2 + random(level / 26));
      #      me->start_busy(random(2));
      combat =
        Combat.start_busy(character.meta.combat, 2 + Engine.rand(rng, max(div(level, 26), 1)))

      character = %{character | meta: %{character.meta | combat: combat}}

      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            "$N看不出$n招式中的虚实，连忙护住自己全身，一时竟无以应对！\n",
            bindings
          )
        )

      # LPC: me->start_busy(random(2)) —— 攻击方忙乱经 Performs.feedback/3 回传。
      Performs.feedback(attacker, 0, Engine.rand(rng, 2))
      put_character(conn, character)
    else
      # LPC: msg = CYN "可是$N" CYN "镇定自若，小心拆招，没有被" "$n" NOR
      #           + CYN "招式所困。\n" NOR;
      #      me->start_busy(2);
      conn =
        Broadcast.publish(
          conn,
          Messages.interpolate(
            Enum.join(["可是$N镇定自若，小心拆招，没有被$n", "招式所困。\n"], ""),
            bindings
          )
        )

      # LPC: me->start_busy(2) —— 攻击方忙乱经 Performs.feedback/3 回传。
      Performs.feedback(attacker, 0, 2)
      conn
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "songshan-jian/meng",
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
  # #define MENG "「" HIW "如梦如幻" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg, wn;
  #         object weapon;
  #         int level;
  # 
  #         if (userp(me) && ! me->query("can_perform/songshan-jian/meng"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(MENG "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "sword")
  #         return notify_fail("你使用的武器不对，难以施展" MENG "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((int)me->query_skill("songshan-jian", 1) < 40)
  #                 return notify_fail("你嵩山剑法不够娴熟，难以施展" MENG "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "songshan-jian")
  #                 return notify_fail("你没有激发嵩山剑法，难以施展" MENG "。\n");
  # 
  #         if ((int)me->query("neili") < 120)
  #                 return notify_fail("你现在的真气不够，难以施展" MENG "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         wn = weapon->name();
  # 
  #         msg = HIC "\n$N" HIC "怒啸一声，施展出绝招「" HIW "如梦如幻" HIC "」"
  #               "手中" + wn + HIC "似攻非攻，欲进忽退，令人匪夷所思。\n"NOR;
  # 
  #         message_sort(msg, me, target);
  # 
  #         level = me->query_skill("songshan-jian", 1);
  # 
  #         me->add("neili", -80);
  # 
  #         if (level + random(level) > target->query_skill("dodge"))
  #         {
  #         msg = HIY "$N" HIY "看不出$n" HIY "招式中的虚实，连忙"
  #                       "护住自己全身，一时竟无以应对！\n" NOR;
  #                 target->start_busy(2 + random(level / 26));
  #                 me->start_busy(random(2));
  #     } else
  #         {
  #         msg = CYN "可是$N" CYN "镇定自若，小心拆招，没有被"
  #                       "$n" NOR + CYN "招式所困。\n" NOR;
  # 
  #                 me->start_busy(2);
  #     }
  #     message_vision(msg, target, me);
  # 
  #     return 1;
  # }
end
