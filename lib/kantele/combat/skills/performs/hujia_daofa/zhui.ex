defmodule Kantele.Combat.Skills.Performs.HujiaDaofa.Zhui do
  @moduledoc """
  卸甲锥心势「zhui」（对照 `kungfu/skill/hujia-daofa/zhui.c`）

  胡家刀法单体攻击：发出无形刀气，发起 `combat/perform-incoming` 事件，
  由目标侧 `resolve_incoming` 判定命中并施加伤害。

  已按原始 LPC 对齐：
  - 门槛：perform_known / 战斗中目标 / 手中持刀 / hujia-daofa>=140 /
    激发胡家刀法 / neili>=200。（LPC 另有 force>=200 内功门槛）
  - ap = blade + force；dp = 目标 force；
    命中判定 `ap/4 + rand(ap/2) > dp`。
  - 伤害 `ap/3 + rand(ap/2)`（目标侧结算）。
  - 内力消耗与忙乱按命中/落空分别回执攻击方：命中 -150 / busy 2；
    落空 -50 / busy 3。
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

  @perform_id "hujia-daofa/zhui"
  @move_name "「卸甲锥心势」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_weapon(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, level)
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
      :ok
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "hujia-daofa")

    if level < 140 do
      {:error, "你的胡家刀法还不到家，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "hujia-daofa" do
      :ok
    else
      {:error, "你没有激发胡家刀法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, _level) do
    stats = character.meta.stats
    weapon = Combat.weapon(character.meta.combat)
    weapon_name = (weapon && Map.get(weapon, :name)) || ""

    # LPC: ap = me->query_skill("blade") + me->query_skill("force")
    ap = Stats.skill(stats, "blade") + Stats.skill(stats, "force")

    # 消耗在 resolve_incoming 中按命中/落空分别结算（150/50），此处不预先扣除。
    conn =
      Broadcast.publish(
        conn,
        "$N手中的" <> weapon_name <> "一振，施出#{@move_name}，顿时一股凌厉无比的无形刀气破空袭向$n！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: ap,
        ap: ap,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    level = Map.get(data, :level, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)

    # LPC: ap = me->query_skill("blade") + me->query_skill("force")
    #      dp = target->query_skill("force")
    # The attacker sends the summed ap; recompute dp from the victim's force.
    ap = Map.get(data, :ap, level * 2)
    dp = Stats.skill(character.meta.stats, "force")

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || ""]

    # LPC: if (ap / 4 + random(ap / 2) > dp) → hit
    hit = div(ap, 4) + Engine.rand(rng, max(div(ap, 2), 1)) > dp

    if hit do
      # LPC: damage = ap / 3 + random(ap / 2); me->add("neili", -150); busy 2
      damage = div(ap, 3) + Engine.rand(rng, max(div(ap, 2), 1))
      combat = Combat.apply_damage(combat, damage)
      Performs.feedback(attacker, 150, 2)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "只见$n一声惨叫，整个人如遭电击，刀气穿心，口中鲜血狂喷而出！\n",
          bindings
        )
      )
      |> put_character(put_combat(character, combat))
    else
      # LPC: me->add("neili", -50); busy 3
      Performs.feedback(attacker, 50, 3)

      text = Messages.interpolate("可是$p默运内力，硬是抵挡了$P的这记无形刀气。\n", bindings)

      Broadcast.publish(conn, text)
    end
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "hujia-daofa/zhui",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
