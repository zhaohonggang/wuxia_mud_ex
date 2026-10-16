defmodule Kantele.Combat.Skills.Performs.DuguJiujian.Qi do
  @moduledoc """
  破气式「qi」（对照 `kungfu/skill/dugu-jiujian/qi.c`，inherit F_SSERVER）

  独孤九剑（剑 sword）攻击绝招：要求 duigu-jiujian >= 120、剑已激发映射；
  命中判定 `ap/2 + random(ap) > dp`，其中 `ap = sword + parry`，
  `dp = force + parry`；命中伤害 `damage = ap + random(ap)`（外伤 85%）。
  LPC 通过 `final()` 令目标 `no_exert`，并在 10+random(ap/30) 秒后由
  `poqi_end()` 恢复——此处保留其文案，跨进程延时回调待补。
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

  @perform_id "dugu-jiujian/qi"
  @move_name "「破气式」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_can_learn(character),
         :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_weapon(combat),
         :ok <- check_mapped(stats),
         :ok <- check_target_no_exert(target),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (me->query("can_learn/dugu-jiujian/nothing"))
  #          return notify_fail("你所使用的外功中没有这种功能。\n");
  defp check_can_learn(character) do
    if Map.get(character_marks(character), :"can_learn/dugu-jiujian/nothing") do
      {:error, "你所使用的外功中没有这种功能。\n"}
    else
      :ok
    end
  end

  # LPC: if (userp(me) && me->query("can_perform/dugu/qi") < 100)
  #          return notify_fail("你所使用的外功中没有这种功能。\n");
  # NOTE: LPC 两处返回同一文案，故需保留两次该字面量。
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! me->is_fighting(target)) return notify_fail(QI "只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "dugu-jiujian") < 120 do
      {:error, "你独孤九剑等级不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你所使用的武器不对，无法施展#{@move_name}。\n"}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "dugu-jiujian" do
      :ok
    else
      {:error, "你没有激发独孤九剑，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (target->query_temp("no_exert"))
  #          return notify_fail("对方现在已经无法控制真气，放胆攻击吧。\n");
  # TODO: no_exert 由 final() 置位、poqi_end() 清除（跨进程状态待补）。
  defp check_target_no_exert(target) do
    if Map.get(target.meta, :no_exert) do
      {:error, "对方现在已经无法控制真气，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)

    # LPC: msg = HIW "$N" HIW "施出独孤九剑「破气式」，手中" + weapon->name() +
    #           HIW "中攻直进，遥指$n" HIW "的气海要穴。\n" NOR;
    # NOTE: weapon->name() 把起始文案拆成两段字面量。
    p1 = "$N施出独孤九剑「破气式」，手中"
    p2 = "中攻直进，遥指$n的气海要穴。\n"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: ap = me->query_skill("sword") + me->query_skill("parry");
    #      dp = target->query_skill("force") + target->query_skill("parry");
    ap = Stats.skill(stats, "sword") + Stats.skill(stats, "parry")
    dp = Stats.skill(target.meta.stats, "force") + Stats.skill(target.meta.stats, "parry")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: damage = ap + random(ap);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 85,
      #                                 (: final, me, target, damage :));
      #      me->start_busy(3);
      damage = ap + Engine.rand(rng, max(ap, 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 85, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: final() 返回消息，并 target->set_temp("no_exert", 1);
      #      call_out("poqi_end", 10 + random(ap / 30), me, target);
      # TODO: 置位 no_exert + 10+random(ap/30) 秒后 poqi_end 恢复（跨进程待补）。
      character = Map.put(character, :meta, Map.put(character.meta, :no_exert, true))

      hit_msg = "$n被$N一剑划过气门，登感一阵锥心的刺痛，全身真气源源而泻！\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 0, 3)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "可$n" CYN "深知$N" CYN "这招的厉"
      #            "害，当即向后横移数尺，躲闪开来。\n" NOR;
      #      me->start_busy(4);
      miss_msg = "可$n深知$N这招的厉害，当即向后横移数尺，躲闪开来。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 0, 4)

      conn
      |> put_character(character)
    end
  end

  # ===== 破气式收束（LPC: poqi_end）=====
  # LPC: void poqi_end(object me, object target)
  # {
  #         if (target && target->query_temp("no_exert"))
  #         {
  #                 if (living(target))
  #                 {
  #                         message_combatd(HIC "$N" HIC "深深吸入一口气，脸色由"
  #                                         "白转红，看起来好多了。\n" NOR, target);
  #                         tell_object(target, HIY "你感到被扰乱的真气慢慢平静"
  #                                             "了下来。\n" NOR);
  #                 }
  #                 target->delete_temp("no_exert");
  #         }
  # }
  # TODO: 延时回调（Process.send_after / handle_info）补全。
  @doc false
  def poqi_end do
    {
      "$N深深吸入一口气，脸色由白转红，看起来好多了。\n",
      "你感到被扰乱的真气慢慢平静了下来。\n"
    }
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  # LPC: me->query("can_learn/dugu-jiujian/nothing") —— 临时标记，未实现时为空。
  defp character_marks(character), do: Map.get(character.meta, :marks, %{})
end
