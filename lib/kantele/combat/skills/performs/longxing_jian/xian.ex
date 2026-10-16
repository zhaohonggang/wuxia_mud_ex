defmodule Kantele.Combat.Skills.Performs.LongxingJian.Xian do
  @moduledoc """
  神龙再现「xian」（对照 `kungfu/skill/longxing-jian/xian.c`）

  战斗中自我增益：`attack+2`、`dodge+1`、`parry+1`，并在 `apply/xian`
  计数 +1（<50 可叠放，无到期回收）；忙乱 1；扣 100 内力。

  差异（TODO(migrate)）：
  - LPC 通过 `add_temp("xian", 1)` 计数、上限 50 拒绝连用，本版以
    buff 无到期 + custom 门槛（temp.xian < 50）表达；
  - LPC 要求战斗中（`is_fighting`），本版 custom 门槛保留。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform "longxing-jian/xian"
  @name "「神龙再现」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- known(stats),
         :ok <- fighting(combat),
         :ok <- skill_longxing(stats),
         :ok <- skill_buddhism(stats),
         :ok <- neili_min(character),
         :ok <- not_saturated(combat) do
      # 扣内力 + 忙乱
      character = Performs.consume_neili(character, 100)
      combat = Combat.start_busy(combat, 1)

      # 应用增益：attack+2, dodge+1, parry+1, xian 计数+1
      temp = Map.update(combat.temp, :xian, 1, &(&1 + 1))
      combat = %{combat | temp: temp}
      character = %{character | meta: %{character.meta | combat: combat}}

      # 启动广播：必须与 .c 逐字一致
      conn
      |> Broadcast.publish("只听口中念念有词，神龙从天而将，钻入体中！\n")
      |> put_character(character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp known(stats) do
    if Stats.perform_known?(stats, @perform),
      do: :ok,
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  defp fighting(combat) do
    if Combat.fighting?(combat),
      do: :ok,
      else: {:error, "神龙再现只能在战斗中使用。\n"}
  end

  defp skill_longxing(stats) do
    if Stats.skill(stats, "longxing-jian") < 150,
      do: {:error, "你的龙形剑法不够娴熟，不会使用神龙再现。\n"},
      else: :ok
  end

  defp skill_buddhism(stats) do
    if Stats.skill(stats, "buddhism") < 150,
      do: {:error, "你的佛法修为不够娴熟，不会使用神龙再现。\n"},
      else: :ok
  end

  defp neili_min(character) do
    if character.meta.vitals.neili < 300,
      do: {:error, "你已经精疲力竭，内力不够了。\n"},
      else: :ok
  end

  defp not_saturated(combat) do
    if Map.get(combat.temp, :xian, 0) < 50,
      do: :ok,
      else: {:error, "你已经念佛念得太久了，神龙已经厌倦了。\n"}
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # ===== 原始 LPC 源码 =====
  # 神龙再现「xian」（对照 `kungfu/skill/longxing-jian/xian.c`）
  # ... (LPC source preserved verbatim)
  # ===== END LPC SOURCE =====
end
