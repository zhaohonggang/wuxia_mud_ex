defmodule Kantele.World.RoomActions.VisionMove do
  @moduledoc """
  数据驱动的「文案 + 位移 + 文案」handler（P5-1b-3 批量机制 #2）。

  LPC 语料里有一大批 `do_*` 长成同一个形状：

      int do_jump(string arg)
      {
              object me = this_player();
              if (! arg || arg != "chi") { write("你往哪里跳呀? \\n"); return 1; }

              message_vision("\\n$N 往太乙池中跳去。\\n", me);   // 旧房间
              me->move("/d/gumu/taiyi2");
              message_vision("\\n$N跳进了太乙池中来。\\n", me);   // 新房间
              return 1;
      }

  差别只在「参数名 / 两段文案 / 目标房间 / 参数不符时怎么办」。把这些差异集中
  成 `@moves` 数据表，避免每个房间写一个近乎相同的模块（与 `MessageOnly`
  同一思路：重复形状走数据，独有逻辑才写专用模块）。

  ## 表结构

      {{room_id, verb}, %{
        arg:       参数名（`nil` = 不校验参数；`:none` = 参数必须为空，对应 LPC `if (!arg)`）,
        empty_arg: 空参数时的特殊处理（目前只有 `:not_handled`，对应 LPC `if (!arg) return 0;`）,
        before:    旧房间广播（`nil` = 不广播）,
        target:    目标房间 id（必填）,
        after:     新房间广播（`nil` = 不广播）,
        otherwise: 参数不符时（`{:write, text}` 只提示本人 / `{:vision, text}` 房间广播 /
                   `:not_handled` 对应 LPC `return 0`）,
        exclude_actor: `true` = 两段广播都排除行动者（LPC `message(..., ({me}))`）
      }}

  `after` 广播**必须**显式用 `target`（新房间）—— `move_to/2` 之后
  `conn.character.room_id` 已是新房间，但 `params.room_id` 仍是旧房间。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Helpers

  @moves %{
    # d/mingjiao/gudi3.c: 沿洞壁往外爬
    {"mingjiao:gudi3", "enter"} => %{
      arg: "dong",
      before: "$N深吸了一口气，慢慢沿着洞壁往外爬。\n",
      target: "mingjiao:gudi2",
      after: nil,
      otherwise: {:write, "你想干什么呀?\n"}
    },
    # d/gumu/taiyi1.c: 跳进太乙池
    {"gumu:taiyi1", "jump"} => %{
      arg: "chi",
      before: "\n$N 往太乙池中跳去。\n",
      target: "gumu:taiyi2",
      after: "\n$N跳进了太乙池中来。\n",
      otherwise: {:write, "你往哪里跳呀? \n"}
    },
    # d/gumu/taiyi2.c: 从太乙池爬上岸
    {"gumu:taiyi2", "climb"} => %{
      arg: "up",
      before: "$N在太乙池中往岸上爬了上去。\n",
      target: "gumu:taiyi1",
      after: "$N从太乙池中爬了上去。\n",
      otherwise: {:write, "那个方向没法爬。\n"}
    },
    # d/emei/hcawest.c: 从华藏庵跳窗出去（参数不符 return 0）
    {"emei:hcawest", "jump"} => %{
      arg: "chuang",
      before: "$N趁人不注意，跳出窗外。\n",
      target: "emei:xiaoshulin1",
      after: "$N从华藏庵里跳窗出来。\n",
      otherwise: :not_handled
    },
    # d/emei/xiaoshulin1.c: 从窗外跳进华藏庵（参数不符 return 0）
    {"emei:xiaoshulin1", "jump"} => %{
      arg: "chuang",
      before: "$N趁人不注意，跳进窗里。\n",
      target: "emei:hcawest",
      after: "$N从华藏庵外跳窗进来。\n",
      otherwise: :not_handled
    },
    # d/emei/ssyb.c: 爬上去到密林（LPC 用 message(..., ({me})) 排除行动者）
    {"emei:ssyb", "climb"} => %{
      arg: nil,
      before: "$N使劲爬上去，花了九牛二虎之力。\n",
      target: "emei:gudelin1",
      after: "$N花了九牛二虎之力，到了这个地方，却不知道在哪里？\n",
      exclude_actor: true,
      otherwise: :not_handled
    },
    # d/wudu/minju7.c: 往供桌下面钻（同样排除行动者）
    {"wudu:minju7", "enter"} => %{
      arg: "zhuo",
      before: "$N一弯腰往供桌下面钻了进去。\n",
      target: "wudu:minju9",
      after: "$N从外面钻了进来。\n",
      exclude_actor: true,
      otherwise: :not_handled
    },
    # d/mingjiao/tohsq3.c: 不带参数才跳潭（`if (!arg)` → `arg: :none`）
    {"mingjiao:tohsq3", "jump"} => %{
      arg: :none,
      before: "$N一闭眼，向潭中跳了下去，只觉冰冷刺骨，赶紧运气相抗。\n",
      target: "mingjiao:hsqtan1",
      after: nil,
      otherwise: {:write, "你要跳到哪儿？\n"}
    },
    # d/wudu/dijiao.c / d/wudu/minju10.c: pull xi 掀草席上下地道；
    # 无参数 return 0，其它参数给一句「什么也没抓住」的房间广播。
    {"wudu:dijiao", "pull"} => %{
      arg: "xi",
      empty_arg: :not_handled,
      before: "\n$N掀开盖在洞口的草席爬了上去。\n",
      target: "wudu:minju10",
      after: "\n盖在地上的草席忽然一掀，$N从下面钻了出来。\n",
      otherwise: {:vision, "\n$N双手在空中比划了几下，但似乎什么也没抓住。\n"}
    },
    {"wudu:minju10", "pull"} => %{
      arg: "xi",
      empty_arg: :not_handled,
      before: "\n$N掀开盖在洞口的草席走了下去。\n",
      target: "wudu:dijiao",
      after: "\n盖在洞口的草席一掀，$N从上面走了下来。\n",
      otherwise: {:vision, "\n$N双手在空中比划了几下，但似乎什么也没抓住。\n"}
    }
  }

  @doc "已配置的 `{room_id, verb}` 列表（覆盖度自查用）"
  def entries, do: @moves

  @impl true
  def run(conn, %{verb: verb, trailing: arg, room_id: room_id}) do
    case Map.fetch(@moves, {room_id, verb}) do
      {:ok, move} -> perform(conn, room_id, move, String.trim(arg))
      :error -> :not_handled
    end
  end

  defp perform(conn, room_id, move, arg) do
    cond do
      # LPC `if (!arg || arg == "") return 0;` —— 空参数单独处理
      arg == "" and move[:empty_arg] == :not_handled ->
        :not_handled

      arg_matches?(move[:arg], arg) ->
        opts =
          case move[:exclude_actor] do
            true -> [exclude_actor: true]
            _ -> []
          end

        conn
        |> maybe_vision(room_id, move[:before], opts)
        |> Helpers.move_to(move.target)
        |> maybe_vision(move.target, move[:after], opts)

      true ->
        otherwise(conn, move[:otherwise], room_id)
    end
  end

  defp arg_matches?(nil, _arg), do: true
  # LPC `if (! arg)` —— 参数必须为空
  defp arg_matches?(:none, arg), do: arg == ""
  defp arg_matches?(want, arg), do: want == arg

  defp maybe_vision(conn, _room_id, nil, _opts), do: conn

  defp maybe_vision(conn, room_id, text, opts) do
    Helpers.broadcast_vision(conn, room_id, text, opts)
  end

  # LPC `return 0`
  defp otherwise(_conn, :not_handled, _room_id), do: :not_handled
  defp otherwise(conn, {:write, text}, _room_id), do: Helpers.render_to_player(conn, text)

  defp otherwise(conn, {:vision, text}, room_id) do
    Helpers.broadcast_vision(conn, room_id, text)
  end
end
