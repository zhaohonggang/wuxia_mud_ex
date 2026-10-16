defmodule Kantele.Combat.Skills.Performs.HeixueShenzhen.Luo do
  @moduledoc """
  星罗棋布「luo」（对照 `kungfu/skill/heixue-shenzhen/luo.c`，inherit F_SSERVER）

  黑血神针（暗器 throwing，持有于 handing 槽）攻击绝招：要求持暗器且数量 >= 20、
  heixue-shenzhen >= 140、force >= 200、真气 >= 150；消耗内力 100、全部暗器，
  忙乱 2。命中判定 `random(combat_exp + skill*skill/10*skill) > target_combat_exp`，
  命中后按四次判定叠加命中数 `n`（以暗器余量为上限），并造成
  `skill+random(skill)` 外伤、`skill/2+random(skill/2)` 创伤。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "heixue-shenzhen/luo"
  @move_name "「星罗棋布」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_amount(weapon),
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("handing")) ||
  #     (string)weapon->query("skill_type") != "throwing")
  #          return notify_fail("你现在手中并没有拿着暗器。\n");
  defp check_weapon(combat) do
    weapon = Map.get(combat.equipped, :handing)

    if weapon && Map.get(weapon, :skill_type) == "throwing" do
      {:ok, weapon}
    else
      {:error, "你现在手中并没有拿着暗器。\n"}
    end
  end

  # LPC: if (weapon->query_amount() < 20)
  #          return notify_fail("至少要有二十枚暗器才能施展" LUO "。\n");
  defp check_amount(weapon) do
    if Map.get(weapon, :amount, 99) < 20 do
      {:error, "至少要有二十枚暗器才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((skill = me->query_skill("heixue-shenzhen", 1)) < 140)
  #          return notify_fail("你的黑血神针不够娴熟，难以施展" LUO "。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "heixue-shenzhen") < 140 do
      {:error, "你的黑血神针不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 200)
  #          return notify_fail("你的内功火候不够，难以施展" LUO "。\n");
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 150)
  #          return notify_fail("你现在真气不足，难以施展" LUO "。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if not dead?(target),
      do: :ok,
      else: {:error, "对方都已经这样了，用不着这么费力吧？\n"}
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats, weapon) do
    weapon_name = Map.get(weapon, :name) || ""
    amount = Map.get(weapon, :amount, 0)

    # LPC: msg = HIR "$N" HIR "纵身跃起，陡然间十指猛张，竟将手中所有的"
    #           + weapon->name() + HIR "打出，笼罩$n" HIR "四方！\n" NOR;
    # NOTE: weapon->name() 把起手文案拆成两段字面量。
    a1 = "$N纵身跃起，陡然间十指猛张，竟将手中所有的"
    a2 = "打出，笼罩$n四方！\n"
    start_msg = a1 <> weapon_name <> a2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
    #      ob_exp = target->query("combat_exp");（ob_exp 由目标侧 resolve 结算）
    skill = Stats.skill(stats, "heixue-shenzhen")
    my_exp = stats.combat_exp + div(skill * skill, 10) * skill

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        my_exp: my_exp,
        skill: skill,
        amount: amount,
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
    my_exp = Map.get(data, :my_exp, 0)
    skill = Map.get(data, :skill, 0)
    amount = Map.get(data, :amount, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ob_exp = character.meta.stats.combat_exp

    # LPC: if (random(my_exp) > ob_exp) { n = 4 + random(4);
    #      if (random(my_exp) > ob_exp) n += 4 + random(4); ... }
    n =
      if Engine.rand(rng, max(my_exp, 1)) > ob_exp do
        n = 4 + Engine.rand(rng, 4)
        n = if Engine.rand(rng, max(my_exp, 1)) > ob_exp, do: n + 4 + Engine.rand(rng, 4), else: n

        n =
          if Engine.rand(rng, max(div(my_exp, 2), 1)) > ob_exp,
            do: n + 4 + Engine.rand(rng, 4),
            else: n

        n =
          if Engine.rand(rng, max(div(my_exp, 4), 1)) > ob_exp,
            do: n + 4 + Engine.rand(rng, 8),
            else: n

        # LPC: if (weapon->query_amount() < n) n = weapon->query_amount();
        min(n, amount)
      else
        -1
      end

    bindings = [n1: attacker.name, n2: character.name]

    if n >= 0 do
      # LPC: target->receive_damage("qi", skill + random(skill), me);
      #      target->receive_wound("qi", skill / 2 + random(skill / 2), me);
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, skill + Engine.rand(rng, max(skill, 1)))
        |> Vitals.wound(:qi, div(skill, 2) + Engine.rand(rng, max(div(skill, 2), 1)))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: msg += HIR "结果$n" HIR "躲闪不及，全身上下被$P" HIR "射出"
      #            HIR + chinese_number(n) + HIR "个血肉淋漓的窟窿，惨"
      #            "不忍睹。\n" NOR;
      hit_msg =
        "结果$n躲闪不及，全身上下被$P射出" <>
          chinese_number(n) <> "个血肉淋漓的窟窿，惨不忍睹。\n"

      conn = Broadcast.publish(conn, hit_msg, bindings)

      max_qi = character.meta.vitals.max_qi || character.meta.vitals.qi || 1
      p = div(character.meta.vitals.qi * 100, max(max_qi, 1))

      conn = Broadcast.publish(conn, "( $n" <> eff_status_msg(p) <> " )\n", bindings)

      Performs.feedback(attacker, 100, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "$p" CYN "见得$P" CYN "招数奇特，不敢大意，当"
      #            "即飞身躲开了所有暗器。\n" NOR;
      Performs.feedback(attacker, 100, 2)

      Broadcast.publish(conn, "$p见得$P招数奇特，不敢大意，当即飞身躲开了所有暗器。\n", bindings)
    end
  end

  # LPC: chinese_number(n) —— 用码点构造避免在源码中留下中文字面量（1..9）。
  defp chinese_number(n) when is_integer(n) and n >= 1 and n <= 9 do
    <<0x4E00 + n - 1::utf8>>
  end

  defp chinese_number(n), do: Integer.to_string(n)

  # LPC: eff_status_msg(p) —— 定义于 /kungfu/skill/eff_msg.h（状态描述按 qi 百分比）。
  # TODO: 该表位于独立头文件，逐条移植待补；当前返回空串以避免引入额外文案。
  defp eff_status_msg(_p), do: ""

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
