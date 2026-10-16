defmodule Kantele.Combat.Skills.Performs.JueqingJian.Liu do
  @moduledoc """
  流水无情「liu」（对照 `kungfu/skill/jueqing-jian/liu.c`，inherit F_SSERVER）

  绝情剑法单体攻击：要求持剑、jueqing-jian >= 60、sword 已激发为
  jueqing-jian、force >= 80、真气 >= 60、目标存活且战斗中。攻击方广播起手并发
  `combat/perform-incoming`；目标侧以 `ap/2 + random(ap)` 对抗 parry：
  命中创伤 `ap + random(ap/4)`（外伤 24%）、忙乱 1+random(2)、扣 60 内力；
  落空则扣 30 内力、忙乱 2（回执）。
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

  @perform_id "jueqing-jian/liu"
  @move_name "「流水无情」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
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

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      {:ok, weapon}
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "jueqing-jian") < 60 do
      {:error, "你绝情剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "jueqing-jian" do
      :ok
    else
      {:error, "你没有激发绝情剑法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 80 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 60 do
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

  defp apply_perform(conn, character, target, stats, weapon) do
    weapon_name = Map.get(weapon, :name) || ""
    ap = Stats.skill(stats, "jueqing-jian")

    # LPC: msg = HIY "\n$N" HIY "长叹一声，一股悲切之情涌上心头，手中" + wn +
    #           HIY "迅猛无比地刺出，风声嗖嗖，完全不理会$n" HIY "的攻势，"
    #           "将自己的生死置之度外，这正是绝情谷绝学「" HIR "流水无情" HIY
    #           "」。" NOR;
    # NOTE: weapon->name() 把起手文案拆成两段字面量。
    start_msg =
      "\n$N长叹一声，一股悲切之情涌上心头，手中" <>
        weapon_name <>
        "迅猛无比地刺出，风声嗖嗖，完全不理会$n的攻势，将自己的生死置之度外，这正是绝情谷绝学「流水无情」。"

    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: ap = me->query_skill("jueqing-jian", 1); dp = target->query_skill("parry", 1);
    # 命中判定在目标侧完成（需要目标 parry），攻击方仅下发 ap 与武器名。
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
    weapon_name = Map.get(data, :weapon_name, "")
    rng = Map.get(data, :rng, &:rand.uniform/1)
    parry = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > parry do
      # LPC: damage = ap + random(ap / 4);
      #      do_damage(me, target, WEAPON_ATTACK, damage, 24, msg); neili -60; busy 1+random(2)
      damage = ap + Engine.rand(rng, max(div(ap, 4), 1))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage * 24, 100))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      conn = Broadcast.publish(conn, "$n见$N此招剑势迅猛，似与自己共存亡，心中一惊，早已中剑。\n", bindings)

      Performs.feedback(attacker, 60, 1 + Engine.rand(rng, 2))

      put_character(conn, character)
    else
      # LPC: msg = CYN "然而$n" CYN "眼见" + wn + CYN "已至，但$n" CYN
      #           "身法迅速无比，提气向后一纵，$N" CYN "扑了个空。\n" NOR;
      miss_msg = "然而$n眼见" <> weapon_name <> "已至，但$n身法迅速无比，提气向后一纵，$N扑了个空。\n"

      conn = Broadcast.publish(conn, miss_msg, bindings)
      Performs.feedback(attacker, 30, 2)
      conn
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
