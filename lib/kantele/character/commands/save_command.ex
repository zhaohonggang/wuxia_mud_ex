defmodule Kantele.Character.SaveCommand do
  @moduledoc """
  手动存档：`save`（cmds/usr/save.c；实时已自存，此命令仅给安心感）

  Batch 6：直接调用 `Records.save/1` 落盘并反馈结果。为降低负载，
  LPC 限制 30 秒内的重复存档，Kantele 侧实时自存已覆盖，故不再限流。

  LPC valid_startroom 逻辑（对应 user.c save()）：若当前房间的
  `valid_startroom` 为 true，则将 meta.env.startroom 更新为当前房间，
  使下次登录直接落点于此（如岳王庙、客栈等）。

  整库 `character_metadata` 备份已移至登录时自动触发（见
  `Kantele.Character.LoginController`），此命令不再备份。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.World.Room

  def run(conn, _params) do
    character = conn.character

    # LPC valid_startroom：若当前房间标记 valid_startroom，将
    # meta.env.startroom 更新为当前房间，下次登录直接落点于此
    character =
      case Room.snapshot(character.room_id) do
        %{attrs: attrs} when is_map(attrs) ->
          if Map.get(attrs, "valid_startroom", true) do
            env = Map.get(character.meta, :env, %{})
            %{character | meta: %{character.meta | env: Map.put(env, :startroom, character.room_id)}}
          else
            character
          end

        _ ->
          character
      end

    conn =
      case Records.save(character) do
        :ok ->
          render(conn, CommandView, "text", %{text: "档案储存完毕。\n"})

        :error ->
          render(conn, CommandView, "text", %{text: "储存失败。\n"})
      end

    prompt(conn, CommandView, "prompt", %{})
  end
end
