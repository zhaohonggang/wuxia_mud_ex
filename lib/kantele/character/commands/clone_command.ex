defmodule Kantele.Character.CloneCommand do
  @moduledoc """
  克隆命令：`clone <文件> [数量]`

  对应 LPC `cmds/wiz/clone.c` main/1。

  用法：
  - `clone <文件>`：克隆 1 个对象（缺省数量）
  - `clone <文件> <数量>`：克隆指定数量的对象

  仅 arch 巫师（wiz_level >= 2）可用。

  克隆后，对象放入克隆者的背包；若无法放入背包，则置于其所在房间。
  向房间广播：「只见$N伸手凌空一指，变出了$n。」
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Combat.Messages
  alias Kantele.World.ObjectClone

  require Logger

  def run(conn, %{"rest" => rest}) do
    character = conn.character

    if Access.archwizp(character) do
      {file, amount_str} = parse_rest(rest)

      cond do
        is_nil(file) ->
          reply(conn, "你要复制什麽对象？\n")

        is_nil(amount_str) ->
          # 数量缺省为 1
          do_clone(conn, character, file, 1)

      true ->
        amount =
          try do
            String.to_integer(amount_str)
          rescue
            _ -> nil
          end

        if is_integer(amount) and amount > 0 do
          do_clone(conn, character, file, amount)
        else
          reply(conn, "数量必须是正整数。\n")
        end
      end
    else
      reply(conn, "你不能复制物品。\n")
    end
  end

  def run(conn, _params) do
    character = conn.character

    if Access.archwizp(character) do
      reply(conn, "你要复制什麽对象？\n")
    else
      reply(conn, "你不能复制物品。\n")
    end
  end

  # --- 私有 ---

  defp parse_rest(rest) do
    rest = String.trim(rest)

    if rest == "" do
      {nil, nil}
    else
      parts = String.split(rest, " ", parts: 2)
      case parts do
        [file] -> {file, nil}
        [file, amount_str] -> {file, amount_str}
      end
    end
  end

  defp do_clone(conn, character, file, amount) do
    case ObjectClone.clone_by_path(file, amount, character) do
      {:ok, result} ->
        place_object(conn, character, result.object)
        text =
          Messages.interpolate("只见$N伸手凌空一指，变出了$n。", %{
            n1: character.name,
            n2: object_name(result.object)
          })

        reply(conn, text <> "\n")

      {:error, :not_authorized} ->
        reply(conn, "你没有权限使用 clone 命令。\n")

      {:error, :read_denied} ->
        reply(conn, "无法读取该对象文件。\n")

      {:error, :site_denied} ->
        reply(conn, "你的站点特权不允许克隆该路径的对象。\n")

      {:error, :not_found} ->
        reply(conn, "找不到对象：#{file}\n")

      {:error, :load_error} ->
        reply(conn, "载入对象失败：#{file}\n")

      {:error, :invalid_args} ->
        reply(conn, "参数错误。\n")
    end
  end

  defp place_object(conn, character, object) do
    case object do
      %Kalevala.World.Item.Instance{} = instance ->
        # 放入克隆者背包
        updated_character =
          %{character | inventory: [instance | character.inventory]}

        put_character(conn, updated_character)

      %Kalevala.Character{} = npc ->
        # 将 NPC 放入克隆者所在房间（对应 LPC `move(environment(actor))`）。
        # 若全局世界基础设施未启动（如测试环境），降级为不放入，仅返回提示。
        room_id = conn.character.room_id
        zone_id = String.split(room_id, ":") |> hd()
        sup_name = Kalevala.World.CharacterSupervisor.global_name(zone_id)

        if :global.whereis_name(sup_name) do
          npc = %{
            npc
            | room_id: room_id,
              meta: Map.put(npc.meta || %{}, :zone_id, zone_id)
          }

          config = [
            supervisor_name: sup_name,
            communication_module: Kantele.Communication,
            initial_controller: Kantele.Character.SpawnController,
            quit_view: {Kantele.Character.QuitView, "disconnected"}
          ]

          result =
            try do
              Kalevala.World.start_character(npc, config)
            catch
              :exit, _reason ->
                {:error, :supervisor_not_running}
            end

          case result do
            {:ok, _pid} -> :ok
            {:error, reason} ->
              Logger.warn("clone NPC 放入房间失败: #{inspect(reason)}")
              :ok
          end
        else
          Logger.warn("clone NPC：区 #{zone_id} CharacterSupervisor 未运行，NPC 不进入房间")
          :ok
        end
    end
  end

  defp object_name(object) do
    case object do
      %Kalevala.World.Item.Instance{} = inst -> inst.item.name
      %Kalevala.Character{} = char -> char.name
      _ -> "未知对象"
    end
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
