defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Jiu do
  @moduledoc """
  perform「九曦混阳」（source jiuyang-shengong/perform/jiu.c，inherit F_SSERVER）

  门槛：已知此招 → 目标战斗中 → 空手 → max_neili>=4000 → 九阳神功>=200 →
  激发 unarmed/force 为九阳神功 → 准备 unarmed → 真气>=500 → 目标存活。
  ap = 拳脚 + con*20；命中 ap/2 + random(ap) > 目标(parry + con*20) 后给攻击临时加成
  （apply/attack = ap/9）并连击；未命中仅描述。消耗 300 内力，忙乱 1+random(8)。
  框架内 9 连击 + 临时攻击加成以单次命中近似（见 do_resolve_incoming 注释）。
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

  @perform_id "jiuyang-shengong/jiu"
  @move_name "「九曦混阳」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyang-shengong")
    ap = Stats.skill(stats, "unarmed") + Stats.query_con(stats) * 20

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_max_neili(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 4000 do
      {:error, "你的内力的修为不够，现在无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyang-shengong") < 200 do
      {:error, "你的九阳神功还不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "jiuyang-shengong" ->
        {:error, "你现在没有激发九阳神功为拳脚，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "force") != "jiuyang-shengong" ->
        {:error, "你现在没有激发九阳神功为内功，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "jiuyang-shengong")
  # prepared_perform 返回绝招 ID（如 jiuyang-shengong/jiu），须取技能前缀比对
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared = Stats.prepared_perform(stats, "unarmed")

    if prepared == nil or hd(String.split(prepared, "/")) != "jiuyang-shengong" do
      {:error, "你现在没有准备使用九阳神功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你的真气不够，无法运用#{@move_name}。\n"}
    else
      :ok
    end
  end

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
    msg = "$N大喝一声，顿时一股浩荡无比的真气至体内迸发，双掌猛然翻滚，朝$n闪电般拍去。\n"

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 300}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
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
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: dp = target->query_skill("parry") + target->query("con") * 20;
    dp = Stats.skill(stats, "parry") + Stats.query_con(stats) * 20

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: 命中：count = ap/9，给攻击临时加成（框架内以单次命中近似，未做 9 连击）
      # count = div(ap, 9)
      Performs.feedback(attacker, 300, 1 + Engine.rand(rng, 8))

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n只觉周围空气炽热无比，又见无数气团向自己袭来，顿感头晕目眩，不知该如何抵挡。\n",
          bindings
        )
      )
      |> put_character(character)
    else
      Performs.feedback(attacker, 300, 1 + Engine.rand(rng, 8))

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "$n只见$N无数气团向自己袭来，连忙强振精神，勉强抵挡。\n",
          bindings
        )
      )
      |> put_character(character)
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define JIU "「" HIR "九曦混阳" NOR "」"
  # 
  # inherit F_SSERVER;
  #  
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int count;
  #         int i;
  #  
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (userp(me) && ! me->query("can_perform/jiuyang-shengong/jiu"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(JIU "只能对战斗中的对手使用。\n");
  #  
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(JIU "只能空手施展。\n");
  #                 
  #         if (me->query("max_neili") < 4000)
  #                 return notify_fail("你的内力的修为不够，现在无法使用" JIU "。\n");
  # 
  #         if (me->query_skill("jiuyang-shengong", 1) < 200)
  #                 return notify_fail("你的九阳神功还不够娴熟，难以施展" JIU "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有激发九阳神功为拳脚，难以施展" JIU "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有激发九阳神功为内功，难以施展" JIU "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有准备使用九阳神功，难以施展" JIU "。\n");
  # 
  #         if ((int)me->query("neili") < 500)
  #                 return notify_fail("你的真气不够，无法运用" JIU "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIR "$N" HIR "大喝一声，顿时一股浩荡无比的真气至体内迸发，双掌"
  #               "猛然翻滚，朝$n" HIR "闪电般拍去。\n" NOR;
  # 
  #         ap = me->query_skill("unarmed") + me->query("con") * 20;
  #         dp = target->query_skill("parry") + target->query("con") * 20;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 count = ap / 9;
  #                 msg += HIR "$n" HIR "只觉周围空气炽热无比，又见无数气团向"
  #                        "自己袭来，顿感头晕目眩，不知该如何抵挡。\n" NOR;
  #         } else
  #         {
  #                 msg += HIY "$n" HIY "只见$N" HIY "无数气团向自己袭来，连"
  #                        "忙强振精神，勉强抵挡。\n" NOR;
  #                 count = 0;
  #         }
  # 
  #         message_vision(msg, me, target);
  #         me->add_temp("apply/attack", count);
  # 
  #         me->add("neili", -300);
  # 
  #         for (i = 0; i < 9; i++)
  #         {
  #                 if (! me->is_fighting(target))
  #                         break;
  #                 if (random(5) < 2 && ! target->is_busy())
  #                         target->start_busy(1);
  # 
  #                 COMBAT_D->do_attack(me, target, 0, 0);
  #         }
  # 
  #         me->start_busy(1 + random(8));
  #         me->add_temp("apply/attack", -count);
  # 
  #         return 1;
  # }
end
