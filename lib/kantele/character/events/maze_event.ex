defmodule Kantele.Character.MazeEvent do
  @moduledoc """
  心魔幻境入口（玩家侧，Q5-T3 子虚道人问询延伸，P-D）

  子虚道人 `:ask_maze` 把 `maze/enter` 事件送回玩家进程；本模块：
  - 门控：未持乾坤宝镜（背包无 `liuxi:item/mirror` 且 `mirror_count` < 1）则拒绝进入；
  - 校验通过：置位 `conn.private[:maze_room]` seam、传送进 `liuxi:maze_room`、
    生成心魔 NPC（best-effort，失败不阻断进入）；
  - 击败心魔后由 `CombatEvent.enemy_died` 按 name 识别「心魔」发放神魂引踪香
    并送回子虚观（见 combat_event.ex）。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Teleport
  alias Kantele.World.MirrorDaemon.Zixu

  @maze_room "liuxi:maze_room"

  def enter(conn, %{data: %{asker_id: asker_id}}) do
    character = conn.character

    cond do
      asker_id != character.id ->
        conn

      not has_mirror?(character) ->
        conn
        |> render(CommandView, "text", %{
          text: "子虚道人微微摇头：未持乾坤宝镜，心魔幻境岂是你说进便能进的？\n"
        })
        |> prompt(CommandView, "prompt", %{})

      true ->
        conn
        |> Map.put(:private, Map.put(conn.private, :maze_room, @maze_room))
        |> Teleport.teleport(@maze_room)
        |> spawn_xinmo(character.id)
        |> render(CommandView, "text", %{
          text:
            "眼前光影扭曲，你踏入心魔幻境。一尊心魔自虚空中凝形，面目竟与你一般无二，举剑便刺了过来！\n"
        })
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def enter(conn, _event), do: conn

  defp has_mirror?(character) do
    Enum.any?(character.inventory, fn instance -> instance.item_id == "liuxi:item/mirror" end) or
      Map.get(character.meta.stats, :mirror_count, 0) >= 1
  end

  # 在镜像房间生成心魔 NPC（仅供当前玩家挑战）。世界未加载时 supervisor 不存在，
  # start_xinmo 返回 {:error, :supervisor_not_started}；任何异常都被吞掉，不阻断进入。
  defp spawn_xinmo(conn, player_id) do
    try do
      Zixu.start_xinmo("liuxi", player_id)
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end

    conn
  end
end
