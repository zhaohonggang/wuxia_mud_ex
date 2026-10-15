defmodule Kantele.Combat.Skills.Performs.BaibianDaxue.Dian do
  @moduledoc """
  点字诀「dian」（对照 `kungfu/skill/baibian-daxue/dian.c`）

  百变大学杖法绝技：须持 staff 类武器，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加忙乱。

  门槛（攻击方，逐条对齐 LPC）：目标在战斗中、手持 staff 类武器、
  `force>=100`、`staff>=150`。（LPC 无 `can_perform` 门槛，本版保留
  `perform_known?` 守卫，多 1 条信息性 EXTRA。）

  攻击方广播起手式（`$N手中的<杖>忽然变得诡秘异常…笼罩了$n多处大穴！`）、
  发 `perform-incoming`；目标侧按 `ap/2 + rand(ap) > dp`（ap=staff，dp=dodge）判定：
  - 命中：`$n大惊之下，慌忙抵挡，一时间无暇反击！`，目标忙乱 `ap/27+2`；
  - 未中：`可是$p身法灵动，躲开了$n的缠身进击！`，攻击方忙乱 2。
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

  @perform_id "baibian-daxue/dian"
  @move_name "「点字诀」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon_name} <- check_weapon(combat),
         :ok <- check_force_level(stats),
         :ok <- check_skill_level(stats) do
      apply_perform(conn, character, target, weapon_name)
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

  # if (! objectp(weapon = me->query_temp("weapon")) ||
  #     (string)weapon->query("skill_type") != "staff")
  #         return notify_fail("运用「点字诀」手中必须持杖！\n");
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "staff" do
      {:ok, Map.get(weapon, :name) || ""}
    else
      {:error, "运用#{@move_name}手中必须持杖！\n"}
    end
  end

  # if ((int)me->query_skill("force") < 100)
  #         return notify_fail("你的内功火候不够！\n");
  defp check_force_level(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的内功火候不够！\n"}
    else
      :ok
    end
  end

  # if ((int)me->query_skill("staff") < 150)
  #         return notify_fail("你的杖法还不到家，无法使用「点字诀」！\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "staff") < 150 do
      {:error, "你的杖法还不到家，无法使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, weapon_name) do
    ap = Stats.skill(character.meta.stats, "staff")

    # LPC: msg = HIG "$N" HIG "手中的" + weapon->name() +
    #      HIG "忽然变得诡秘异常，忽伸忽缩，笼罩了$n" HIG "多处大穴！\n" NOR;
    opening = "$N手中的" <> weapon_name <> "忽然变得诡秘异常，忽伸忽缩，笼罩了$n多处大穴！\n"

    conn = Broadcast.publish(conn, opening, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{attacker: ref(character), perform_id: @perform_id, ap: ap}
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(character.meta.stats, "dodge")

    bindings = [n1: attacker.name, n2: character.name]

    # LPC: ap = me->query_skill("staff"); dp = target->query_skill("dodge");
    #      if (ap / 2 + random(ap) > dp)
    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: target->start_busy(ap / 27 + 2)
      combat = Combat.start_busy(character.meta.combat, div(ap, 27) + 2)

      conn
      |> Broadcast.publish(Messages.interpolate("$n大惊之下，慌忙抵挡，一时间无暇反击！\n", bindings))
      |> put_character(put_combat(character, combat))
    else
      # LPC: me->start_busy(2)
      Performs.feedback(attacker, 0, 2)

      Broadcast.publish(conn, Messages.interpolate("可是$p身法灵动，躲开了$n的缠身进击！", bindings))
    end
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
