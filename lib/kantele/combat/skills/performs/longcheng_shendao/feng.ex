defmodule Kantele.Combat.Skills.Performs.LongchengShendao.Feng do
  @moduledoc """
  风雨交加「feng」（对照 `kungfu/skill/longcheng-shendao/feng.c`，inherit F_SSERVER）

  龙城神刀（刀 blade）多段攻击绝招：要求内力 >= 270、内功 force >= 150、
  longcheng-shendao >= 120、刀已激发映射；按 blade 与 dodge 判定命中，
  命中后多轮 do_attack（attack_time = 3 + random(ap/40)，上限 7）。
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

  @perform_id "longcheng-shendao/feng"
  @move_name "「风雨交加」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "longcheng-shendao") < 120 do
      {:error, "你的龙城神刀不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功修为不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "longcheng-shendao" do
      :ok
    else
      {:error, "你没有激发龙城神刀，难以施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 270 do
      {:error, "你目前的真气不够，难以施展#{@move_name}。\n"}
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

    # LPC: msg = HIC "$N" HIC "大喝一声，施出绝招「" HIW "风雨交加" HIC "」手"
    #           "中的" + weapon->name() + HIC "如雨点一般向$n" HIC "打去，$n" HIC
    #           "如同小舟一般在刀雨中漂泊不定。\n" NOR;
    # NOTE: weapon->name() 把起始文案拆成两段独立字面量。
    p1 = "$N大喝一声，施出绝招「风雨交加」手中的"
    p2 = "如雨点一般向$n打去，$n如同小舟一般在刀雨中漂泊不定。\n"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "blade")
    dp = Stats.skill(target.meta.stats, "dodge")

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

    # LPC: attack_time = 3 + random(ap/40)（上限 7）；命中后循环 do_attack。
    #      hit 文案对应 ap/2+random(ap) > dp。
    # TODO: 多段攻击循环（Engine.attack_round）跨进程补全。
    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: msg += HIR "$n" HIR "见$P" HIR "这招来势汹涌，势不可"
      #            "挡，被$N" HIR "攻得连连后退。\n" NOR;
      hit_msg = "$n见$P这招来势汹涌，势不可挡，被$N攻得连连后退。\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 0, 1)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "$n" CYN "见$N" CYN "这几刀来势迅猛无比，毫"
      #            "无破绽，只得小心应付。\n" NOR;
      miss_msg = "$n见$N这几刀来势迅猛无比，毫无破绽，只得小心应付。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 0, 1)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
