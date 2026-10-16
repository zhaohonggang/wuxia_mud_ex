defmodule Kantele.Combat.Skills.Performs.FurongJian.Luan do
  @moduledoc """
  乱剑覆花「luan」（对照 `kungfu/skill/furong-jian/luan.c`，inherit F_SSERVER）

  芙蓉剑法（剑 sword）攻击绝招：要求真气 >= 100、内功 force >= 120、
  dodge >= 120、furong-jian >= 100、剑已激发映射；按 furong-jian 与
  dodge 判定命中（外伤 60%）。
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

  @perform_id "furong-jian/luan"
  @move_name "「乱剑覆花」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force(stats),
         :ok <- check_dodge(stats),
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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "furong-jian") < 100 do
      {:error, "你芙蓉剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "furong-jian" do
      :ok
    else
      {:error, "你没有激发芙蓉剑法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 120 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_dodge(stats) do
    if Stats.skill(stats, "dodge") < 120 do
      {:error, "你的轻功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在的真气不够，难以施展#{@move_name}。\n"}
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

    # LPC: msg = HIM "\n$N" HIM "轻啸一声，腾空而起，" + wn + "在空中挽出一个剑"
    #            HIM "花，顷刻间剑花四散，洋洋洒洒。\n犹如无数花瓣从半空洒向$n"
    #            HIM "全身。" NOR;
    # NOTE: wn (= weapon->name()) 把起始文案拆成两段字面量。
    p1 = "\n$N轻啸一声，腾空而起，"
    p2 = "在空中挽出一个剑花，顷刻间剑花四散，洋洋洒洒。\n犹如无数花瓣从半空洒向$n全身。"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "furong-jian")
    dp = Stats.skill(target.meta.stats, "dodge")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
        weapon_name: weapon_name,
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
      # LPC: damage = me->query_skill("furong-jian", 1);
      #      damage += random(damage / 3);
      #      msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
      #        HIR "$n" HIR "只见无数剑花袭来，将自己包围"
      #        "住，正犹豫间，$n" HIR "已被" + wn + HIR
      #        "刺得皮开肉绽。\n" NOR);
      #      me->start_busy(3); me->add("neili", -100);
      damage = div(ap, 2) + Engine.rand(rng, max(ap, 1))
      vitals = Vitals.damage(character.meta.vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage * 60, 100))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      hit_part1 = "$n只见无数剑花袭来，将自己包围住，正犹豫间，$n已被"
      hit_part2 = "刺得皮开肉绽。\n"
      hit_msg = hit_part1 <> (Map.get(data, :weapon_name) || "") <> hit_part2
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 3)

      conn
      |> put_character(character)
    else
      # LPC: msg += CYN "然而$n" CYN "看出其中的破绽，侧身一跳"
      #            "已然躲过$N" CYN "这一剑。\n" NOR;
      #      me->start_busy(3); me->add("neili", -100);
      miss_msg = "然而$n看出其中的破绽，侧身一跳已然躲过$N这一剑。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 100, 3)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
