defmodule Kantele.World.InquiryHandlers.LuohanZhen do
  @moduledoc """
  十八罗汉大阵问询处理器（`kind = "luohan_zhen"`）。

  LPC 对应：kungfu/class/shaolin/xuan-ku.h / xuan-nan.h 的 ask_me。

  玩家向 玄苦 或 玄难 打听「十八罗汉阵/罗汉大阵」时触发。
  执行全部门控后通过 `Coordinator.start_challenge/2` 注册挑战，
  并将会话级临时标志（xuanku-asked / xuannan-asked、assigned_fighter）
  写入玩家 conn。

  新 kind 仅需在 `Kantele.World.InquiryHandlers` 的 `@handlers` 注册，
  无需改动 `NpcAskEvent`。
  """

  alias Kantele.World.Loader
  alias Kantele.World.LuohanZhen.Coordinator
  alias Kantele.World.NpcActions.Helpers

  @doc """
  问询入口（由 `NpcScriptEvent` 调用）。

  `config` 为 UCL inquiry 配置（`kind = "luohan_zhen"`），
  `data` 含 `:npc_id`/`:npc_name`/`:npc_room_id`/`:asker_id` 等。
  """
  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)
    npc_id = Map.get(data, :npc_id)

    npc = find_npc(npc_id)

    case npc do
      nil ->
        render(conn, "这里没有这位长老。\n")

      %{} = master_npc ->
        case Coordinator.start_challenge(character, master_npc) do
          {:ok, _challenge, effects} ->
            conn2 = apply_player_effects(conn, effects, character.id)

            # 若玩家已在练武场，通知 Coordinator 玩家到场
            if character.room_id == "shaolin:wuchang" do
              Coordinator.handle_event(character.id, :fighter_arrived)
            end

            conn2

          {:error, :challenge_in_progress} ->
            render(conn, "，今日已有人挑战罗汉大阵，你过一段时间再来吧。\n")

          {:error, reason} ->
            render(conn, error_message(reason) <> "\n")
        end
    end
  end

  def run(_conn, _config, _data), do: :ok

  # === 私有 ===

  defp find_npc(npc_id) when is_binary(npc_id) do
    Enum.find(Loader.load().characters, &(&1.id == npc_id))
  end

  defp find_npc(_), do: nil

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp render(conn, text) do
    Helpers.render(conn, text)
  end

  defp error_message(:not_shaolin_master), do: "又不是我们少林寺的人，打听罗汉阵做什么？"
  defp error_message(:skills_insufficient), do: "功力不够，不够资格闯罗汉大阵。"
  defp error_message(:already_winner), do: "已然闯过罗汉大阵，可不要拿老衲开这等玩笑。"
  defp error_message(:generation_mismatch), do: "辈份不合，不够资格闯罗汉大阵。"
  defp error_message(:guilty), do: "你累犯数戒，身带重罪，我如何能准许你闯罗汉大阵！"
  defp error_message(_), do: "罗汉大阵暂时无法开启。"

  # 把纯状态机产生的 player 侧效果应用到 conn；
  # 房间/定时器效果已由 Coordinator 执行。
  defp apply_player_effects(conn, effects, fighter_id) when is_binary(fighter_id) do
    Enum.reduce(effects, conn, fn effect, acc ->
      apply_player_effect(acc, effect, fighter_id)
    end)
  end

  defp apply_player_effects(conn, _effects, _fighter_id), do: conn

  defp apply_player_effect(conn, {:put_temp, fid, key, value}, fighter_id)
       when fid == fighter_id do
    Helpers.put_temp(conn, key, value)
  end

  defp apply_player_effect(conn, {:delete_temp, fid, key}, fighter_id)
       when fid == fighter_id do
    Helpers.delete_temp(conn, key)
  end

  defp apply_player_effect(conn, {:set_env, fid, key, value}, fighter_id)
       when fid == fighter_id do
    Helpers.put_env(conn, key, value)
  end

  defp apply_player_effect(conn, {:delete_env, fid, key}, fighter_id)
       when fid == fighter_id do
    Helpers.delete_env(conn, key)
  end

  defp apply_player_effect(conn, _effect, _fighter_id), do: conn
end
