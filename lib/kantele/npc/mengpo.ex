defmodule Kantele.NPC.Mengpo do
  @moduledoc """
  孟婆 NPC 问询处理器（对应 LPC `d/death/npc/mengpo.c` 的 `ask_me`）。

  玩家于地府向孟婆 `ask 孟婆 about 孟婆汤`（或 `汤` / `喝汤` / `tang`）
  可获取一碗孟婆汤，用于通过奈河桥（qiao1 → qiao2）的孟婆拦截。

  与 LPC `ask_me` 严格对齐的前置检查：

  1. 仅限幽灵态（`meta.env[:ghost] == true`），否则「阳人喝什么孟婆汤？」
  2. combat_exp >= 10,000,000，否则「你还是回去吧，这汤…你不喝也罢。」
  3. 身上已有「孟婆汤」，否则「你身上不是还有一碗吗？怎么死了还这么贪心？」
  4. 距上次喝汤未满 200 秒，否则「你不是刚刚才喝了一碗吗？」
  5. 库存 count > 0（LPC `set("count", 10)`），否则「汤已经舀完了，待我再煮一锅。」

  通过后给玩家发放 `death:tang`（孟婆汤）物品，记录
  `meta.temp[:last_eat_mengpo_tang]` 时间戳。

  孟婆的 `valid_leave` 拦截（qiao1 向 north）已在
  `data/world/death.ucl` 中以 `valid_leave.condition` 配置；喝汤后
  `last_eat/mengpo_tang` 被置位，玩家即可通过。
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.World.Items

  @cooldown_sec 200

  @impl true
  def ask_specs do
    %{
      "mengpo_tang" => mengpo_spec(),
      "汤" => mengpo_spec(),
      "喝汤" => mengpo_spec(),
      "tang" => mengpo_spec()
    }
  end

  defp mengpo_spec do
    %{
      check: &mengpo_check/2,
      execute: &mengpo_execute/2,
      effects: []
    }
  end

  @impl true
  def check(asker, npc, keyword), do: dispatch(:check, asker, npc, keyword)

  @impl true
  def execute(asker, npc, keyword), do: dispatch(:execute, asker, npc, keyword)

  @impl true
  def effects(asker, npc, keyword), do: dispatch(:effects, asker, npc, keyword)

  defp dispatch(fn_name, asker, npc, keyword) do
    case ask_specs()[keyword] do
      nil ->
        if fn_name == :check do
          {:error, "孟婆闭目不语。"}
        else
          {:error, "无此问询。"}
        end

      spec ->
        spec[fn_name].(asker, npc)
    end
  end

  # ---- check ----

  defp mengpo_check(asker, _npc) do
    cond do
      # 1. 仅限幽灵态
      Map.get(asker.meta.env || %{}, :ghost) != true ->
        {:error, "阳人喝什么孟婆汤？\n"}

      # 2. combat_exp >= 10,000,000
      combat_exp_of(asker) < 10_000_000 ->
        {:error, "你还是回去吧，这汤…你不喝也罢。\n"}

      # 3. 身上已有孟婆汤
      carries_tang?(asker) ->
        {:error, "你身上不是还有一碗吗？怎么死了还这么贪心？\n"}

      # 4. 冷却 200 秒
      within_cooldown?(asker) ->
        {:error, "你不是刚刚才喝了一碗吗？\n"}

      true ->
        :ok
    end
  end

  defp combat_exp_of(%{meta: %{stats: stats}}) when is_map(stats) do
    Map.get(stats, :combat_exp, 0) || 0
  end

  defp combat_exp_of(_), do: 0

  defp carries_tang?(%{inventory: inventory}) when is_list(inventory) do
    Enum.any?(inventory, fn inst ->
      inst.item_id == "death:tang" or
        (inst.aliases and "mengpo tang" in inst.aliases) or
        (inst.aliases and "tang" in inst.aliases)
    end)
  end

  defp carries_tang?(_), do: false

  defp within_cooldown?(%{meta: %{temp: temp}}) when is_map(temp) do
    last = Map.get(temp, :last_eat_mengpo_tang)
    is_integer(last) and (System.system_time(:second) - last) < @cooldown_sec
  end

  defp within_cooldown?(_), do: false

  # ---- execute ----

  defp mengpo_execute(asker, _npc) do
    now = System.system_time(:second)

    # 设置 last_eat/mengpo_tang 时间戳（LPC query_temp/put_temp）
    character =
      asker
      |> put_temp_character(:last_eat_mengpo_tang, now)

    # 给玩家发放孟婆汤
    case Items.get("death:tang") do
      {:ok, _item} ->
        instance = %{
          id: :"mengpo_tang_#{now}_#{:rand.uniform(1_000_000)}",
          item_id: "death:tang",
          created_at: DateTime.utc_now()
        }

        character = %{character | inventory: [instance | (character.inventory || [])]}

        # 落盘
        Records.save(character)

        # 返回自定义成功消息 + 更新后的角色
        {:ok, "孟婆弓下腰，舀了一碗孟婆汤递到你手中。\n孩子，喝了这汤就该上路了。\n", character}

      _ ->
        {:error, "孟婆叹了口气，说道：汤已经舀完了，待我再煮一锅。\n", character}
    end
  end

  defp put_temp_character(character, key, value) do
    meta = PlayerMeta.put_temp(character.meta, key, value)
    %{character | meta: meta}
  end
end
