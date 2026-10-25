defmodule Kantele.World.RoomActions.Yanziwu.Lanyue.Say do
  @moduledoc """
  `d/yanziwu/lanyue.c` 的 `do_say`（`add_action("do_say", "whisper")`）——
  燕子坞暗语谜题的消费端（`knock` 后 4s 置 `can_whisper`，9s 清理）。

  LPC 原文：

      int do_say(string arg)
      {
              object me = this_player();

              if (me->query_temp("can_whisper")) {
                      if (arg == "光复大燕") {
                              me->delete_temp("can_whisper");
                              me->move(load_object("yanziwu/huanshi"));
                              return 1;
                      }
              }
              return 0;
      }

  ## 移植要点

  - 只在玩家 `can_whisper == 1` 时生效（`knock` 后 4s 设置，9s 清理）。
  - 答对「光复大燕」：清 `can_whisper`，`move_to` 到 `yanziwu:huanshi`。
  - 答错或未置标记：`:not_handled`，放行全局 `do_say`。
  - UCL `yanziwu:lanyue` 已有 `whisper = "do_say"`，**零 UCL 改动**。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.PlayerMeta
  alias Kantele.World.RoomActions.Helpers

  @target "yanziwu:huanshi"
  @phrase "光复大燕"

  @impl true
  def run(conn, %{trailing: arg}) do
    character = conn.private.update_character || conn.character

    cond do
      is_nil(character) ->
        :not_handled

      not can_whisper?(character) ->
        :not_handled

      String.trim(arg) == @phrase ->
        conn
        |> delete_player_temp("can_whisper")
        |> Helpers.move_to(@target)

      true ->
        :not_handled
    end
  end

  defp can_whisper?(character) do
    Map.get(character.meta.temp || %{}, "can_whisper") == 1
  end

  defp delete_player_temp(conn, key) do
    character = conn.private.update_character || conn.character
    put_character(conn, %{character | meta: PlayerMeta.delete_temp(character.meta, key)})
  end
end
