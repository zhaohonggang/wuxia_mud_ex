defmodule Kantele.World.NpcActions.ConvertBian do
  @moduledoc """
  灵蛇/毒蛇 `bian` 动作（NPC 私有动词通道，P5-1c 扩展）。

  对应 LPC `lingshe.c` / `snake.c` 的 `do_bian`：

      int do_bian(string arg)
      {
          if (arg != "lingshe" && arg != "she" && arg != "snake")
              return notify_fail("你要化什么？\n");
          ob = new("/d/baituo/obj/lingshezhang");
          ob->move(environment(this_object()));
          destruct(this_object());
          return 1;
      }

  handler 名：`bian`（LPC `lingshe.c`/`snake.c` 的 `add_action("bian", "do_bian")`）。

  成功后：在 NPC 所在房间地上生成对应法杖，将 NPC 从房间移除（销毁 NPC 进程），
  向房间广播化杖文案。

  ## 房间级注册限制

  `NpcActionHandlers` 按 `room_id` 注册，而 `lingshe`/`snake` 是动态 spawn 的 NPC，
  预先不知道会出现在哪个房间。因此在 `NpcActionHandlers` 中为 `bian` 添加了
  全局兜底（非 room_id 索引），使其对任意房间内的灵蛇/毒蛇均生效。
  """
  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  # NPC 名字/别名 → 对应的法杖 item_id
  @npc_to_item %{
    "灵蛇" => "baituo:lingshezhang",
    "lingshe" => "baituo:lingshezhang",
    "she" => "baituo:lingshezhang",
    "snake" => "baituo:lingshezhang",
    "毒蛇" => "baituo:shezhang",
    "shezhang" => "baituo:shezhang"
  }

  # 法杖 item_id → 中文名（广播文案用）
  @item_cname %{
    "baituo:lingshezhang" => "灵蛇杖",
    "baituo:shezhang" => "蛇杖"
  }

  @impl true
  def run(conn, %{verb: _verb, trailing: trailing, npc: npc, room_id: room_id}) do
    trailing = String.trim(trailing)

    item_id =
      case @npc_to_item[trailing] do
        nil ->
          # arg 不命中：LPC return 0，放行
          :not_handled

        iid when is_binary(iid) -> iid
      end

    cond do
      item_id == :not_handled ->
        :not_handled

      true ->
        do_bian(conn, npc, item_id, room_id)
    end
  end

  defp do_bian(conn, npc, item_id, room_id) do
    cname = Map.get(@item_cname, item_id, item_id)

    # 在房间地上生成法杖实例 + 从房间移除 NPC（原子更新 state.private）
    case add_item_and_remove_npc(room_id, item_id, npc) do
      :ok ->
        conn
        |> RoomHelpers.broadcast_vision(room_id, "#{npc.name}化作一#{cname}，落在地上。\n")
        |> render("你将#{npc.name}化作一#{cname}，放在地上。\n")

      {:error, :no_room} ->
        render(conn, "化杖之术施展失败，无法在当前房间生成法杖。\n")
    end
  end

  # 原子地向 room.private.item_instances 插入法杖、从 room.private.characters 移除 NPC，
  # 并停止 NPC 进程。
  defp add_item_and_remove_npc(room_id, item_id, npc) do
    case :global.whereis_name({Kalevala.World.Room, room_id}) do
      pid when is_pid(pid) ->
        instance = %Kalevala.World.Item.Instance{
          id: Kalevala.World.Item.Instance.generate_id(),
          item_id: item_id,
          created_at: DateTime.utc_now()
        }

        :sys.replace_state(pid, fn state ->
          private = Map.get(state, :private, %{}) || %{}
          item_instances = Map.get(private, :item_instances, []) || []
          characters = Map.get(private, :characters, []) || []

          new_private = %{
            private
            | item_instances: [instance | item_instances],
              characters: Enum.reject(characters, fn c -> c.id == npc.id end)
          }

          %{state | private: new_private}
        end)

        # 停止 NPC 进程（避免孤立的 foreman）
        if is_pid(npc.pid) do
          Process.exit(npc.pid, :shutdown)
        end

        :ok

      _ ->
        {:error, :no_room}
    end
  rescue
    _ -> {:error, :no_room}
  end

  defp render(conn, text) when is_binary(text) do
    RoomHelpers.render_to_player(conn, text)
  end
end
