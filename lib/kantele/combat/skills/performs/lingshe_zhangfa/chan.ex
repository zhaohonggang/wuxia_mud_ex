defmodule Kantele.Combat.Skills.Performs.LingsheZhangfa.Chan do
  @moduledoc """
  灵蛇缠身「chan」（对照 `kungfu/skill/lingshe-zhangfa/chan.c`，inherit F_SSERVER）

  灵蛇杖法单体攻击：要求持杖、force >= 80、staff >= 80、目标存活且战斗中。
  攻击方广播起手并发 `combat/perform-incoming`；目标侧以
  `ap/2 + random(ap)` 对抗 dodge：命中令目标忙乱 `ap/19 + 2`；落空则攻击方
  忙乱 2（回执）。攻击方不消耗内力。
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

  @perform_id "lingshe-zhangfa/chan"
  @move_name "「灵蛇缠身」"

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

    if weapon && Map.get(weapon, :skill_type) == "staff" do
      {:ok, weapon}
    else
      {:error, "运用#{@move_name}手中必须持杖！\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 80 do
      {:error, "你的内功火候不够！\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "staff") < 80 do
      {:error, "你的杖法还不到家，无法使用#{@move_name}！\n"}
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
    ap = Stats.skill(stats, "staff")

    # LPC: msg = HIG "$N" HIG "手中的" + weapon->name() +
    #           HIG "不住的颤动，活现一条灵蛇，缠向$n" HIG "，难以捉摸。\n" NOR;
    # NOTE: weapon->name() 把起手文案拆成两段字面量。
    start_msg =
      "$N手中的" <>
        weapon_name <>
        "不住的颤动，活现一条灵蛇，缠向$n，难以捉摸。\n"

    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: ap = me->query_skill("staff"); dp = target->query_skill("dodge");
    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{attacker: ref(character), perform_id: @perform_id, ap: ap}
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
    dodge = Stats.skill(character.meta.stats, "dodge")
    bindings = [n1: attacker.name, n2: character.name]

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dodge do
      # LPC: target->start_busy(ap / 19 + 2);
      combat = Combat.start_busy(character.meta.combat, div(ap, 19) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn = Broadcast.publish(conn, "$n仓皇之下只有严守门户，无暇反击！\n", bindings)

      put_character(conn, character)
    else
      # LPC: msg += HIC "可是$p" HIC "看破了$N" HIC
      #            "的虚招，巧妙的运用身法躲过了$P的攻击！" NOR;
      #      me->start_busy(2);
      conn = Broadcast.publish(conn, "可是$p看破了$N的虚招，巧妙的运用身法躲过了$P的攻击！", bindings)

      Performs.feedback(attacker, 0, 2)
      conn
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "lingshe-zhangfa/chan",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
