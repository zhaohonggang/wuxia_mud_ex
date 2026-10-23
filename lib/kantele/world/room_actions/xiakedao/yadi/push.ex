defmodule Kantele.World.RoomActions.Xiakedao.Yadi.Push do
  @moduledoc """
  `d/xiakedao/yadi.c` 的 `do_push`（LPC 目标词 `men`）。

  - 参数非 `men` → 提示「你想推什么呀? 」，恒 handle（LPC `write` + return 1）
  - 玩家无 `yadi_swim` 临时标记 → 同样提示「你想推什么呀? 」
  - 否则消费 `yadi_swim`，`neili` > 150 → 开 west→xiakedao:shidong9、扣 150 内力、
    5 秒后自关；否则内力清零、提示「石门却纹丝没动」。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Push

  @room_id "xiakedao:yadi"
  @grabbed "$N深深吸了一口气，紧紧抓住石门的一侧。\n"
  @opened "只见$N一运丹田气，双膀一使劲，石门竟缓缓的开了。\n"
  @weak "$N使尽了全身的力，石门却纹丝没动。\n"
  @what "你想推什么呀? \n"
  @closed "石门又缓缓地合上了。\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    char = Push.current(conn)

    cond do
      String.trim(arg) != "men" ->
        Push.render(conn, @what)

      not has_swim?(char) ->
        Push.render(conn, @what)

      true ->
        open_or_fail(conn, room_id, char)
    end
  end

  defp open_or_fail(conn, room_id, char) do
    conn = Push.consume_temp(conn, "yadi_swim")
    conn = Push.broadcast(conn, room_id, @grabbed)

    if Push.neili(char) > 150 do
      conn
      |> Push.reveal(room_id, "west", "xiakedao:shidong9", @opened,
        [{room_id, "west", @closed}], 5)
      |> Push.deduct_neili(150)
      else
        conn = Push.set_neili(conn, 0)
        Push.broadcast(conn, room_id, @weak)
      end
  end

  defp has_swim?(%{meta: %{temp: temp}}) when is_map(temp),
    do: Map.get(temp, "yadi_swim") != nil

  defp has_swim?(_char), do: false
end
