defmodule Kantele.Combat.Skills.Performs.JingangZhi.Fumo do
  @moduledoc """
  金刚伏魔诀「fumo」（对照 `kungfu/skill/jingang-zhi/fumo.c`）

  大力金刚指绝技：须空手，消耗 300 内力发出指劲远程攻击，发起
  `combat/perform-incoming` 事件，由目标侧 `resolve_incoming` 判定命中并施加伤害。

  差异（TODO(migrate)）：
  - LPC 另要求 force>=200；本版仅以 jingang-zhi>=150 把关；
  - LPC 要求 mapped force 为 hunyuan-yiqi/yijinjing/luohan-fumogong，本版保留；
  - LPC 命中/落空分别消耗 300/100，本版统一 300；
  - 命中判定：LPC 以 finger+force 对 dodge+parry，本版以 `rand(level) > parry/2` 代理；
  - 忙乱：命中 2 轮、落空 3 轮，本版 `level/22+2` 轮。
  - 伤害计算：`damage = level * 2`（简化），LPC 为 `ap/2+rand(ap/2)`。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "jingang-zhi/fumo"
  @move_name "「金刚伏魔诀」"

  @allowed_force ["hunyuan-yiqi", "yijinjing", "luohan-fumogong"]

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_unarmed(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_force_mapped(stats),
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
      [] -> {:error, @move_name <> "只能在战斗中对对手使用。\n"}
    end
  end

  defp check_unarmed(combat) do
    if Combat.weapon(combat) do
      {:error, "你必须空手才能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "jingang-zhi")

    if level < 150 do
      {:error, "你的大力金刚指修为不够，目前不能使用#{@move_name}！\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "finger") == "jingang-zhi" do
      :ok
    else
      {:error, "你没有激发大力金刚指，不能使用#{@move_name}！\n"}
    end
  end

  defp check_force_mapped(stats) do
    if Stats.mapped(stats, "force") in @allowed_force do
      :ok
    else
      {:error, "你现在没有激发少林内功为内功，难以施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 400 do
      {:error, "你的真气不够，无法使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn =
      Broadcast.publish(
        conn,
        "$N眼中闪过一道青光，汇聚全身功力，右手食指弹出一道劲气，划空而过，如同流星一般击向$n！\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        ap: level * 2,
        dp: 0
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    level = Map.get(data, :level, 0)
    ap = Map.get(data, :ap, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)
    parry = Stats.skill(character.meta.stats, "parry")

    bindings = [n1: attacker.name, n2: character.name, weapon2: weapon_name || "指"]

    hit = Engine.rand(rng, level) > div(parry, 2)

    if hit do
      damage = level * 2
      combat = Combat.start_busy(combat, div(level, 22) + 2)
      combat = Combat.apply_damage(combat, damage)

      conn
      |> Broadcast.publish(
        Messages.interpolate(
          "只见$p一声惨叫，已被点中胸口要穴，只觉得胸口气血汹涌，全身气血倒流，受到#{damage}点伤害！\n",
          bindings
        )
      )
      |> put_character(put_combat(character, combat))
    else
      text =
        if weapon_name do
          Messages.interpolate(
            "可是$p看破了$N的企图，轻轻向后飘出数丈，躲过了这一致命的一击！\n",
            bindings
          )
        else
          Messages.interpolate("但是$p双手戳点刺拍，将$N的来招一一架开。\n", bindings)
        end

      Broadcast.publish(conn, text)
    end
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end