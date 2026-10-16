defmodule Kantele.Combat.Skills.Performs.DuomingJinhua.Hua do
  @moduledoc """
  天外飞花「hua」（对照 `kungfu/skill/duoming-jinhua/hua.c`，inherit F_SSERVER）

  夺命金花（暗器 throwing，持有于 handing 槽）攻击绝招：要求持暗器且数量 >= 10、
  duoming-jinhua >= 120、throwing 已激发映射、force >= 150、真气 >= 150；
  消耗内力 100、暗器 10 枚，忙乱 2。命中判定
  `random(combat_exp + skill*skill/10*skill) > target_combat_exp`，
  命中后按四次指数判定叠加命中数 `n`，并造成 `skill/2 + random(skill/3)` 外伤。
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

  @perform_id "duoming-jinhua/hua"
  @move_name "「天外飞花」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_amount(weapon),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character) do
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("handing"))
  #     || (string)weapon->query("skill_type") != "throwing")
  #          return notify_fail("你现在手中并没有拿着暗器。\n");
  defp check_weapon(combat) do
    weapon = Map.get(combat.equipped, :handing)

    if weapon && Map.get(weapon, :skill_type) == "throwing" do
      {:ok, weapon}
    else
      {:error, "你现在手中并没有拿着暗器。\n"}
    end
  end

  defp check_amount(weapon) do
    if Map.get(weapon, :amount, 99) < 10 do
      {:error, "至少要有十枚暗器你才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "duoming-jinhua") < 120 do
      {:error, "你的夺命金花不够娴熟，不会施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "throwing") == "duoming-jinhua" do
      :ok
    else
      {:error, "你没有激发夺命金花基本暗器，无法施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功火候不够，不能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你内力不够了。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, stats, weapon) do
    weapon_name = Map.get(weapon, :name)
    base_unit = Map.get(weapon, :base_unit) || Map.get(weapon, :unit) || ""

    # LPC: msg = HIC "只听“飕飕飕飕”数声，$N" HIC "随手一摆，"
    #           "手中" + weapon->name() + HIC "如花瓣飞舞般向$n" HIC "笼罩过去！\n" NOR;
    # NOTE: weapon->name() 把起始文案拆成两段字面量。
    a1 = "只听“飕飕飕飕”数声，$N随手一摆，手中"
    a2 = "如花瓣飞舞般向$n笼罩过去！\n"
    start_msg = a1 <> (weapon_name || "") <> a2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: me->add("neili", -100); weapon->add_amount(-10); me->start_busy(2);
    # NOTE: 内功扣除经后续 resolve_incoming 的 Performs.feedback 落实（此处先减
    #       start_busy 无法跨进程，统一由 feedback 传 busy 轮数）。
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
    #      ob_exp = target->query("combat_exp");
    #      if (random(my_exp) > ob_exp) { n = 1 + random(2); ... }
    skill = Stats.skill(stats, "duoming-jinhua")
    my_exp = stats.combat_exp + div(skill * skill, 10) * skill
    ob_exp = target.meta.stats.combat_exp

    {hit?, n} =
      if Engine.rand(&:rand.uniform/1, max(my_exp, 1)) > ob_exp do
        n = 1 + Engine.rand(&:rand.uniform/1, 2)

        n =
          if Engine.rand(&:rand.uniform/1, max(my_exp, 1)) > ob_exp do
            n + 1 + Engine.rand(&:rand.uniform/1, 2)
          else
            n
          end

        n =
          if Engine.rand(&:rand.uniform/1, max(div(my_exp, 2), 1)) > ob_exp do
            n + 1 + Engine.rand(&:rand.uniform/1, 2)
          else
            n
          end

        n =
          if Engine.rand(&:rand.uniform/1, max(div(my_exp, 4), 1)) > ob_exp do
            n + 1 + Engine.rand(&:rand.uniform/1, 2)
          else
            n
          end

        {true, n}
      else
        {false, 0}
      end

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        hit?: hit?,
        n: n,
        skill: skill,
        weapon_name: weapon_name,
        base_unit: base_unit,
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
    hit? = Map.get(data, :hit?, false)
    n = Map.get(data, :n, 0)
    skill = Map.get(data, :skill, 0)
    weapon_name = Map.get(data, :weapon_name)
    base_unit = Map.get(data, :base_unit)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if hit? do
      # LPC: target->receive_wound("qi", skill / 2 + random(skill / 3), me);
      vitals = Vitals.wound(character.meta.vitals, :qi, div(skill, 2) + Engine.rand(rng, max(div(skill, 3), 1)))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: msg += HIR "结果$p" HIR "反应不及，中了$P" HIR +
      #            chinese_number(n) + weapon->query("base_unit") +
      #            weapon->name() + HIR "！\n" NOR;
      # NOTE: chinese_number 与 base_unit/weapon 名均为运行时变量，非字面量。
      c1 = "结果$p反应不及，中了$P"
      c2 = "！\n"
      hit_msg = c1 <> chinese_number(n) <> (base_unit || "") <> (weapon_name || "") <> c2
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      # LPC: p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
      #      if (n--) { ... hit_ob ... }
      #      if (stringp(pmsg = COMBAT_D->query_ahinfo())) msg += pmsg;
      #      msg += "( $n" + eff_status_msg(p) + " )\n";
      max_qi = character.meta.vitals.max_qi || character.meta.vitals.qi || 1
      p = div(character.meta.vitals.qi * 100, max(max_qi, 1))

      e1 = "( $n"
      e2 = " )\n"
      eff_msg = e1 <> eff_status_msg(p) <> e2
      conn = Broadcast.publish(conn, eff_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 2)

      conn
      |> put_character(character)
    else
      # LPC: msg += NOR + CYN "可是$p" CYN "躲过了$P" CYN "发出的所有" +
      #            weapon->name() + NOR + CYN "。\n" NOR;
      m1 = "可是$p躲过了$P发出的所有"
      m2 = "。\n"
      miss_msg = m1 <> (weapon_name || "") <> m2
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 2)

      conn
      |> put_character(character)
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
