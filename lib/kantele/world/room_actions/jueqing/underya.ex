defmodule Kantele.World.RoomActions.Jueqing.Underya do
  @moduledoc """
  `d/jueqing/underya.c` 的 `do_bao` / `do_climb` / `do_jump`
  （`add_action("do_bao", ({"bao"}))` + `do_climb`(climb/pa) + `do_jump`(tiao/jump)）。

  LPC 要点：
  - `do_bao "stone"`：busy/fighting 守卫；`marks/抱` 已置则「你已经抱了一块石头了」，
    否则提示抱起 + `set_temp("marks/抱", 1)`。
  - `do_climb "teng"`：busy/fighting 守卫；渲染攀爬文案 + `move(jueqing)`（绝情谷底→绝情谷）。
  - `do_jump "tan"`：busy/fighting 守卫；
      * `query("tiao")` 已置（正在潜水）→ 直接返回（LPC `return 1`）。
      * 没抱石：渲染「潜不下去」+ `set("tiao", 1)` + `call_out("out_water", 6)` → 回到 underya。
      * 抱石：渲染成功 + `move(underya2)` + `delete_temp("marks/抱")` + `delete("tiao")`。
  `out_water` 延时：`write("回到岸边")` + `move(underya)` + `delete("tiao")`。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]
  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.RoomActions.Helpers

  @impl true
  def run(conn, %{verb: verb, trailing: arg, room_id: _room_id}) do
    case verb do
      v when v in ["climb", "pa"] -> do_climb(conn, String.trim(arg))
      v when v in ["jump", "tiao"] -> do_jump(conn, String.trim(arg))
      "bao" -> do_bao(conn, String.trim(arg))
      _ -> conn
    end
  end

  defp do_climb(conn, arg) do
    if arg != "teng" do
      Helpers.render_to_player(conn, "你要做什么？\n")
    else
      case guard(conn) do
        {:halt, c} -> c
        :ok ->
          conn
          |> Helpers.render_to_player("你拉着树藤向上爬去…\n爬了许久，你感觉疲惫之极，但终于达到了山峰。\n\n")
          |> Helpers.move_to("jueqing:jueqing")
      end
    end
  end

  defp do_bao(conn, arg) do
    if arg != "stone" do
      Helpers.render_to_player(conn, "你要抱什么？\n")
    else
      case guard(conn) do
        {:halt, c} -> c
        :ok ->
          if PlayerMeta.get_temp(current(conn).meta, "marks/抱") do
            Helpers.render_to_player(conn, "你已经抱了一块石头了。\n")
          else
            conn
            |> Helpers.render_to_player("你将大石抱起，顿感异常沉重。\n")
            |> put_player_temp("marks/抱", 1)
          end
      end
    end
  end

  defp do_jump(conn, arg) do
    if arg != "tan" do
      Helpers.render_to_player(conn, "你要往哪儿跳？\n")
    else
      case guard(conn) do
        {:halt, c} -> c
        :ok -> dive_or_confirm(conn)
      end
    end
  end

  defp dive_or_confirm(conn) do
    if PlayerMeta.get_temp(current(conn).meta, "tiao") do
      # 已经在潜水途中，LPC 直接 return 1（no-op）。
      conn
    else
      if PlayerMeta.get_temp(current(conn).meta, "marks/抱") do
        # 抱石：直接潜入潭底（underya2）。
        conn
        |> Helpers.render_to_player(
          "你纵身入潭，由于抱有大石头，身体急沉而下，猛地里眼前一亮，你心念一动，" <>
            "忙向光亮处游去，只觉一股急流卷着你的身子冲了过去，光亮处竟是一洞。" <>
            "你抛下大石，手脚齐划，那洞内却是一道斜斜向上的冰窖。你顺势而上，过不多时，“波”的一响，跃出了水面。\n"
        )
        |> Helpers.move_to("jueqing:underya2")
        |> delete_player_temp("marks/抱")
        |> delete_player_temp("tiao")
      else
        # 没抱石：潜不下去，过会儿被冲回岸边。
        conn
        |> Helpers.render_to_player(
          "你长吸一口气，纵身入潭，直往深处潜去，那潭底越深越寒，潜了一会，" <>
            "四周蓝森森的都是玄冰。由于深处浮力太强，你用力冲了数次，也不过再潜下数丈，始终无法到底……\n"
        )
        |> put_player_temp("tiao", 1)
        |> schedule_out_water()
      end
    end
  end

  defp schedule_out_water(conn) do
    pid = current(conn).pid

    effects = [
      {:text, "此时你气息渐促，只好回到岸边。\n"},
      {:force_move, "jueqing:underya"},
      {:delete_temp, "tiao"}
    ]

    :timer.apply_after(6000, __MODULE__, :fire_effect, [pid, effects])
    conn
  end

  def fire_effect(pid, effects) when is_pid(pid) do
    send(pid, %Event{from_pid: self(), topic: "trap/effect", data: %{effects: effects}})
    :ok
  end

  defp guard(conn) do
    c = current(conn)

    cond do
      Combat.busy?(c.meta.combat) ->
        {:halt, Helpers.render_to_player(conn, "你现在正忙着呢！\n")}

      Combat.fighting?(c.meta.combat) ->
        {:halt, Helpers.render_to_player(conn, "你还是先把你面前这个家伙解决了再说。\n")}

      true ->
        :ok
    end
  end

  defp current(%{private: %{update_character: c}} = conn) when not is_nil(c), do: c
  defp current(%{character: c}), do: c

  defp put_player_temp(conn, key, value) do
    c = current(conn)
    put_character(conn, %{c | meta: PlayerMeta.put_temp(c.meta, key, value)})
  end

  defp delete_player_temp(conn, key) do
    c = current(conn)
    put_character(conn, %{c | meta: PlayerMeta.delete_temp(c.meta, key)})
  end
end
