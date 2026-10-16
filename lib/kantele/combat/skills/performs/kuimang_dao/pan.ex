defmodule Kantele.Combat.Skills.Performs.KuimangDao.Pan do
  @moduledoc """
  蝰蟒盘身「pan」（对照 `kungfu/skill/kuimang-dao/pan.c`，inherit F_SSERVER）

  蝰蟒刀法单体攻击：要求持刀、force >= 60、kuimang-dao >= 40、blade 已激发为
  kuimang-dao、真气 >= 50、目标存活且战斗中。攻击方广播起手并发
  `combat/perform-incoming`；目标侧以 `ap/2 + random(ap)` 对抗 parry：
  命中创伤 `ap/3 + random(ap/3)`（外伤 20%）、忙乱 2、扣 30 内力；
  落空则扣 10 内力、忙乱 3（回执）。
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

  @perform_id "kuimang-dao/pan"
  @move_name "「蝰蟒盘身」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_force(stats),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 60 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "kuimang-dao") < 40 do
      {:error, "你的蝰蟒刀法还不到家，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "kuimang-dao" do
      :ok
    else
      {:error, "你没有激发蝰蟒刀法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 50 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
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

  defp apply_perform(conn, character, target, stats, weapon) do
    weapon_name = Map.get(weapon, :name) || ""
    ap = Stats.skill(stats, "blade")

    # LPC: msg = HIR "$N" HIR "手中" + weapon->name() + HIR "翻转不定，忽然只见刀"
    #           "光一闪，刀锋已向$n" HIR "斜斜撩去。\n" NOR;
    # NOTE: weapon->name() 把起手文案拆成两段字面量。
    start_msg =
      "$N手中" <>
        weapon_name <>
        "翻转不定，忽然只见刀光一闪，刀锋已向$n斜斜撩去。\n"

    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: ap = me->query_skill("blade"); dp = target->query_skill("parry");
    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        weapon_name: weapon_name
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
    rng = Map.get(data, :rng, &:rand.uniform/1)
    parry = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > parry do
      # LPC: damage = ap / 3 + random(ap / 3); neili -30; busy 2
      #      do_damage(me, target, WEAPON_ATTACK, damage, 20, msg)
      damage = div(ap, 3) + Engine.rand(rng, max(div(ap, 3), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 20, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn = Broadcast.publish(conn, "$n微微一愣间，已被$N刀锋带中，划出一道鲜血淋漓的伤口！\n", bindings)

      Performs.feedback(attacker, 30, 2)

      put_character(conn, character)
    else
      # LPC: msg = CYN "可是$p" CYN "微微一笑，身子朝一旁偏过尺许，躲开$P"
      #           CYN "这一刀。\n" NOR; neili -10; busy 3
      conn = Broadcast.publish(conn, "可是$p微微一笑，身子朝一旁偏过尺许，躲开$P这一刀。\n", bindings)

      Performs.feedback(attacker, 10, 3)
      conn
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
