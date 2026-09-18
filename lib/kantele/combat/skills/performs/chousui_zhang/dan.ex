defmodule Kantele.Combat.Skills.Performs.ChousuiZhang.Dan do
  @moduledoc """
  绝招「炼心弹」（对照 kungfu/skill/chousui-zhang/dan.c）

  星宿派远程火弹：按 `chousui-zhang`/`poison` 等级分档决定威力与焰色，弹射
  火团袭向战斗中的对手。与「截手式」同为攻击型 perform，走 `combat/perform-incoming`
  由目标结算；内力消耗分三档（被震灭 -150 / 命中 -220 / 被闪避 -100），
  目标以 `combat/perform-feedback` 回执由本模块补扣，忙乱同理由回执设置。

  TODO(migrate):
  - 手中毒药（`query_temp("handing")`）与消耗：本引擎无 handing/毒药物品，暂免检。
  - `query_skill_prepared("strike")` 前置：prepare_skill 状态未实现。
  - 命中后的 `fire_poison` 附加毒与护甲 `consistence` 损耗、`receive_wound("jing", ...)`：
    条件宿主（NPC）/jing 创伤/装备耐久未接，见目标侧 TODO。
  """

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "chousui-zhang/dan"
  @dan "「炼心弹」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

with :ok <- check_perform_known(stats),
          {:ok, target} <- check_target(combat),
          {:ok, lvl} <- check_chousui(stats),
          {:ok, lvp} <- check_poison(stats),
          :ok <- check_throwing(stats),
          :ok <- check_mapped(stats),
          :ok <- check_max_neili(character),
          :ok <- check_neili(character),
          :ok <- check_handing(character) do
      apply_perform(conn, character, target, lvl, lvp)
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
      [] -> {:error, @dan <> "只能对战斗中的对手使用。\n"}
    end
  end

  defp check_chousui(stats) do
    level = Stats.skill(stats, "chousui-zhang")

    if level < 120 do
      {:error, "你的抽髓掌不够娴熟，难以施展#{@dan}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_poison(stats) do
    level = Stats.skill(stats, "poison")

    if level < 180 do
      {:error, "你对毒技的了解不够，难以施展#{@dan}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_throwing(stats) do
    if Stats.skill(stats, "throwing") < 190 do
      {:error, "你暗器手法火候不够，难以施展#{@dan}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "strike") == "chousui-zhang" do
      :ok
    else
      {:error, "你没有激发抽髓掌，难以施展#{@dan}。\n"}
    end
  end

  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 1800 do
      {:error, "你的内力修为不足，难以施展#{@dan}。\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你现在的内息不足，难以施展#{@dan}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, lvl, lvp) do
    rng = &:rand.uniform/1
    {pos, fire} = power_tier(lvl, lvp, rng)
    damage = div(pos, 2) + Engine.rand(rng, div(pos, 2))

    vitals = character.meta.vitals
    stats = character.meta.stats

    conn =
      Broadcast.publish(
        conn,
        "$N单掌一抖，施出星宿派绝技「炼心弹」，将手中毒丸「嗖」的弹射了出去。\n" <>
          "却见那毒丸射至中途，竟蓦地爆裂开，化作#{fire}飘然袭向$n。\n",
        n1: character.name,
        n2: target.name
      )

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: lvl,
        poison: lvp,
        pos: pos,
        damage: damage,
        an: vitals.max_neili + div(vitals.neili, 4),
        ap: Stats.effective(stats, "strike") + Stats.skill(stats, "poison"),
        userp: true
      }
    })

    # 消耗手中毒药（若有）
    temp = Map.get(character.meta, :temp, %{})
    handing = Map.get(temp, "handing")
    new_inventory =
      if handing && is_map(handing) do
        Enum.reject(character.inventory, &(&1.id == handing.id))
      else
        character.inventory
      end
    new_temp = Map.put(temp, "handing", nil)
    new_meta = Map.put(character.meta, :temp, new_temp)
    new_character = %{character | inventory: new_inventory, meta: new_meta}

    conn
    |> put_character(new_character)
    |> assign(:prompt, false)
  end

  # 威力分档（dan.c 64-83）：等级越高，基础威力 pos 与焰色越强
  defp power_tier(lvl, lvp, rng) do
    cond do
      lvl >= 200 and lvp >= 270 ->
        {300 + Engine.rand(rng, div(lvp * 4, 3)), "一团莹绿色的碧焰"}

      lvl >= 180 and lvp >= 240 ->
        {200 + Engine.rand(rng, div(lvp * 3, 4)), "一个殷红色的火球"}

      lvl >= 150 and lvp >= 210 ->
        {100 + Engine.rand(rng, div(lvp * 2, 3)), "数点殷红色的火星"}

      true ->
        {50 + Engine.rand(rng, div(lvp, 2)), "一点暗红色的火星"}
    end
  end

  defp ref(character),
do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

defp check_handing(character) do
    handing =
      character.meta
      |> Map.get(:temp, %{})
      |> Map.get("handing")

    cond do
      handing == nil ->
        # TODO(migrate): 后续强制校验 handing 必须存在
        :ok

      not is_map(handing) ->
        {:error, "你必须拿着(hand)些毒药才能施展\"炼心弹\"。\n"}

      true ->
        meta = Map.get(handing, :meta, %{})

        if Map.get(meta, "can_daub") == true && Map.get(meta, "poison_type") do
          :ok
        else
          {:error, "你必须拿着(hand)些毒药才能施展\"炼心弹\"。\n"}
        end
    end
  end
 end
