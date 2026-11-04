defmodule Kantele.World.RoomActions.Death.WujiandaoEnter do
  @moduledoc """
  `d/death/liudaolunhui/wujiandao.c` 的 `do_enter`（`add_action("do_enter", "enter")`）。

  玩家向铜镜走去，触发转世进入动画：
  1. 门控：poem_said=1、HellZhenPass=true、martial-cognize≥600 或 force≥800、无鬼在场
  2. 广播 "$N向着铜镜的方向走去。"
  3. 依次发送 6 段 entering_world 文案（间隔 3 秒）
  4. 最后一段：调用 Reborn.trigger 转世，传送至 city:wumiao

  对应 LPC `entering_world/2` 的 call_out 链，改用 `character/entering_world_step`
  事件经玩家 foreman 路由，各步在 handler 内拿到完整 conn。
  """

  use Kantele.World.RoomAction

  alias Kalevala.Event
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers

  import Kalevala.Character.Conn, only: [put_character: 2]

  @poem_said_key "poem_said"
  @entering_world_key "entering_world"
  @hell_zhen_pass :HellZhenPass

  @enter_vision "$N向着铜镜的方向走去。\n"

  @no_poem "你对着铜镜张了张嘴，却什么也说不出来。镜面平静如水，没有任何反应。\n"
  @no_hell_zhen "施主怎么来，还请怎么回去吧 ！\n"
  @too_weak "你的武功修为太差，去练练再来吧！\n"
  @ghosts_present "你还是先解决掉这些亡魂吧！\n"

  @impl true
  def run(conn, %{room_id: room_id}) do
    character = current(conn)

    cond do
      not poem_said?(room_id) ->
        Helpers.render_to_player(conn, @no_poem)

      not hell_zhen_pass?(character) ->
        Helpers.render_to_player(conn, @no_hell_zhen)

      not skill_ok?(character) ->
        Helpers.render_to_player(conn, @too_weak)

      ghosts_present?(room_id) ->
        Helpers.render_to_player(conn, @ghosts_present)

      true ->
        enter(conn, character, room_id)
    end
  end

  defp poem_said?(room_id) do
    case Room.get_state_by_id(room_id, @poem_said_key) do
      1 -> true
      _ -> false
    end
  end

  defp hell_zhen_pass?(%{meta: %{env: env}}) do
    Map.get(env || %{}, @hell_zhen_pass) == true
  end

  defp skill_ok?(character) do
    martial_cognize = Stats.skill(character.meta.stats, "martial-cognize") || 0
    force = Stats.skill(character.meta.stats, "force") || 0
    martial_cognize >= 600 or force >= 800
  end

  # LPC `present("ghost", environment(me))`：房间内是否有 alias 为 "ghost" 的 NPC
  defp ghosts_present?(room_id) do
    room_id
    |> Room.npc_characters_by_id()
    |> List.wrap()
    |> Enum.any?(&ghost?/1)
  end

  defp ghost?(%{meta: %{aliases: aliases}}) when is_list(aliases),
    do: "ghost" in aliases

  defp ghost?(_), do: false

  defp enter(conn, character, room_id) do
    # 置位 entering_world 进度标记（LPC set_temp("entering_world", 1)）
    character = put_temp(character, @entering_world_key, 0)
    # Records.save 只负责落盘副作用，返回 :ok 或 :error，不覆盖 character
    Records.save(character)

    # 广播
    conn =
      conn
      |> put_character(character)
      |> Helpers.broadcast_vision(room_id, @enter_vision)

    # 记入房间会话：pid -> step，供定时回调读取
    Room.put_state_by_id(room_id, @entering_world_key, %{character.pid => 0})

    # 第一段文案延迟 1 秒发送（LPC call_out("entering_world", 1, me, 0)）
    Process.send_after(
      character.pid,
      %Event{
        from_pid: self(),
        topic: "character/entering_world_step",
        data: %{step: 0, room_id: room_id, character_id: character.id}
      },
      1000
    )

    conn
  end

  defp put_temp(%{meta: meta} = character, key, value) do
    temp = Map.put(meta.temp || %{}, key, value)
    %{character | meta: %{meta | temp: temp}}
  end

  defp current(%{private: %{update_character: c}} = _conn) when not is_nil(c),
    do: c

  defp current(%{character: c}), do: c
end
