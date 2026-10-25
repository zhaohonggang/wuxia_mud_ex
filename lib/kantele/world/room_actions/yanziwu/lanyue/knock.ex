defmodule Kantele.World.RoomActions.Yanziwu.Lanyue.Knock do
  @moduledoc """
  `d/yanziwu/lanyue.c` 的 `do_knock`（`add_action("do_knock", "knock")`，目标词
  `penjing` 盆景）——燕子坞暗语谜题的入口。

  LPC 原文：

      int do_knock(string arg)
      {
              object me = this_player();

              if (!arg || (arg!="penjing" ) )
                       return  notify_fail("你要敲什么？\\n");

              if (me->query_temp("marks/pen"))
                       return notify_fail("别敲了！\\n");

              me->set_temp("marks/pen",1);
              write(HIC "你在盆景上敲了几下...\\n" NOR, me);
              remove_call_out("check_pass");
              call_out("check_pass", 4, me);

              return 1;
      }

      int check_pass(object me)
      {
             write(HIC "不一会儿，只听不远处隐约传来一阵说话声：“洒国梦语…”\\n" NOR);
             write(HIY "你想了想，觉得像是一句暗语，你很想回答(whisper)但又不知道说些什么！\\n" NOR);
             me->set_temp("can_whisper", 1);
             remove_call_out("end_whisper");
             call_out("end_whisper", 9, me);
             return 1;
      }

      int end_whisper(object me)
      {
            write(HIM "过了良久，只听见一阵不耐烦的声音传来：“算了，没事别在这来捣乱。”\\n" NOR);
            me->delete_temp("marks/pen");
            me->delete_temp("can_whisper");
            return 1;
      }

  ## 移植要点

  - 目标词只认 `penjing`，否则 `notify_fail("你要敲什么？\\n")`。
  - `marks/pen` 已置 → 「别敲了！」（防重复触发；`remove_call_out` 在单次触发下
    无实际效果，未建模）。
  - 两段 `call_out`（4s `check_pass` / 再 9s `end_whisper`）走
    `:timer.apply_after` + `trap/effect` 事件（同 `Jueqing.Duanchang`）：
    延时进程无 `conn`，按角色 pid 下发 `:text` / `:set_temp` / `:delete_temp`。
  - `write(...)` 是只给本人的文本，用 `:text` effect（不广播）。
  - `can_whisper` 的消费者是同房 `whisper`（`do_say`，答对「光复大燕」后
    `move` 去 `yanziwu:huanshi`）——**该 verb 尚未实现**（不在门/容器批次内），
    已登记进度文档；在此期间 `can_whisper` 只会被 `end_whisper` 定时清掉。
  """
  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [put_character: 2]
  alias Kalevala.Event

  alias Kantele.Character.PlayerMeta
  alias Kantele.World.RoomActions.Helpers

  @check_pass_ms 4_000
  @end_whisper_ms 9_000

  @impl true
  def run(conn, %{trailing: arg}) do
    case String.trim(arg) do
      "penjing" -> knock(conn)
      _other -> Helpers.render_to_player(conn, "你要敲什么？\n")
    end
  end

  defp knock(conn) do
    character = conn.private.update_character || conn.character

    if PlayerMeta.get_temp(character.meta, "marks/pen") do
      Helpers.render_to_player(conn, "别敲了！\n")
    else
      conn
      |> put_player_temp("marks/pen", 1)
      |> Helpers.render_to_player("你在盆景上敲了几下...\n")
      |> schedule_check_pass()
    end
  end

  defp schedule_check_pass(conn) do
    :timer.apply_after(@check_pass_ms, __MODULE__, :fire_check_pass, [pid_of(conn)])
    conn
  end

  @doc "`call_out(\"check_pass\", 4)` 的独立进程回调：按角色 pid 下发 trap 副作用。"
  def fire_check_pass(pid) when is_pid(pid) do
    effects = [
      {:text, "不一会儿，只听不远处隐约传来一阵说话声：“洒国梦语…”\n"},
      {:text, "你想了想，觉得像是一句暗语，你很想回答(whisper)但又不知道说些什么！\n"},
      {:set_temp, "can_whisper", 1}
    ]

    send(pid, %Event{from_pid: self(), topic: "trap/effect", data: %{effects: effects}})
    :timer.apply_after(@end_whisper_ms, __MODULE__, :fire_end_whisper, [pid])
    :ok
  end

  @doc "`call_out(\"end_whisper\", 9)` 的独立进程回调：清理两枚临时标记。"
  def fire_end_whisper(pid) when is_pid(pid) do
    effects = [
      {:text, "过了良久，只听见一阵不耐烦的声音传来：“算了，没事别在这来捣乱。”\n"},
      {:delete_temp, "marks/pen"},
      {:delete_temp, "can_whisper"}
    ]

    send(pid, %Event{from_pid: self(), topic: "trap/effect", data: %{effects: effects}})
    :ok
  end

  defp pid_of(conn), do: (conn.private.update_character || conn.character).pid

  defp put_player_temp(conn, key, value) do
    character = conn.private.update_character || conn.character
    put_character(conn, %{character | meta: PlayerMeta.put_temp(character.meta, key, value)})
  end
end
