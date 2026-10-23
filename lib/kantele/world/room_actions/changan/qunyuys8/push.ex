defmodule Kantele.World.RoomActions.Changan.Qunyuys8.Push do
  @moduledoc """
  `d/changan/qunyuys8.c` 的 `do_push`（LPC 目标词 `bed`/`床`/`大床`）。

  - 参数为空 → :not_handled
  - 目标词非 `bed`/`床`/`大床` → :not_handled
  - `query_str()` ≥ 30 → 开 enter→changan:qunyums（已开则只提示、不重置定时器）、
    5 秒后自关，并提示「床下露出了一个暗格。」
  - 臂力不足 → 提示「试着推了推后面的暗格，但没有推开。」
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Push

  @room_id "changan:qunyuys8"
  @args ["bed", "床", "大床"]
  @prefix "你用力推开一张大床，"
  @revealed "床下露出了一个暗格。\n"
  @too_weak "试着推了推后面的暗格，但没有推开。\n"
  @closed "暗格又悄无声息地合上了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    arg = String.trim(arg)

    cond do
      arg == "" ->
        :not_handled

      arg in @args ->
        open_or_reveal(conn, room_id)

      true ->
        :not_handled
    end
  end

  defp open_or_reveal(conn, room_id) do
    char = Push.current(conn)
    conn = Push.render(conn, @prefix)

    if Push.str(char) >= 30 do
      conn = Push.render(conn, @revealed)

      unless Push.open?(room_id, "enter") do
        Push.reveal(conn, room_id, "enter", "changan:qunyums", "",
          [{room_id, "enter", @closed}], 5)
      else
        conn
      end
    else
      Push.render(conn, @too_weak)
    end
  end
end
