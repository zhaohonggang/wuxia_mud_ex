defmodule Kantele.World.InquiryHandlers.SmithJobTest do
  @moduledoc """
  P5-9：铁匠派活问询（kind = "smith_job"），镜像 LPC
  `/inherit/char/smith.c` `ask_me()`。

  覆盖：asker 守门 / 打工次数上限 / 气血不足 / 三个进行中活计的追问 /
  random(3) 派活写 temp。
  """

  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers.SmithJob

  defp conn(opts \\ []) do
    meta = %PlayerMeta{
      marks: Keyword.get(opts, :marks, %{}),
      temp: Keyword.get(opts, :temp, %{}),
      vitals: Keyword.get(opts, :vitals, %Vitals{qi: 100})
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "玩家",
        room_id: "xiangyang:tiejiangpu",
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp data(overrides \\ %{}) do
    Map.merge(
      %{
        kind: "smith_job",
        config: %{},
        npc_name: "铁匠",
        npc_room_id: "xiangyang:tiejiangpu",
        asker_id: "player:test"
      },
      overrides
    )
  end

  # prompt 渲染条目的 data 不是 iodata（是 prompt 结构体），只取 Conn.Text
  # （counter_perform 测试同款helper）。
  defp out_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp character(conn), do: conn.private.update_character || conn.character

  describe "run/3 守门" do
    test "kind 已注册（InquiryHandlers.lookup）" do
      assert Kantele.World.InquiryHandlers.lookup("smith_job") == SmithJob
    end

    test "asker 不匹配 → 静默（无输出）" do
      conn2 = SmithJob.run(conn(), %{}, data(%{asker_id: "player:other"}))

      assert out_text(conn2) == ""
    end

    test "mark/job_smith > 10000 → 「不会真想做一辈子」" do
      conn2 = SmithJob.run(conn(marks: %{"mark/job_smith" => 10_001}), %{}, data())

      assert out_text(conn2) =~ "您老不会真想做一辈子的铁匠吧？"
    end

    test "mark/job_smith == 10000 → 不触发（LPC 为严格大于）" do
      conn2 = SmithJob.run(conn(marks: %{"mark/job_smith" => 10_000}), %{}, data())

      refute out_text(conn2) =~ "不会真想做一辈子"
    end

    test "qi < 50 → 「还是歇会儿吧」" do
      conn2 = SmithJob.run(conn(vitals: %Vitals{qi: 49}), %{}, data())

      assert out_text(conn2) =~ "你还是歇会儿吧！要是出了人命我可承担不起。"
    end
  end

  describe "进行中活计的追问（不重复派活）" do
    test "smith/gu → 「你怎么还磨蹭？」" do
      conn2 = SmithJob.run(conn(temp: %{"smith/gu" => 1}), %{}, data())

      assert out_text(conn2) =~ "让你去鼓(gu)一会儿风箱，你怎么还磨蹭？"
      assert character(conn2).meta.temp["smith/gu"] == 1
    end

    test "smith/dapi → 「你打了没有？」" do
      conn2 = SmithJob.run(conn(temp: %{"smith/dapi" => 1}), %{}, data())

      assert out_text(conn2) =~ "叫你打的坯(dapi)你打了没有？"
    end

    test "smith/cuihuo → 「快给我淬火去！」" do
      conn2 = SmithJob.run(conn(temp: %{"smith/cuihuo" => 1}), %{}, data())

      assert out_text(conn2) =~ "干活怎么尽偷懒？快给我淬火(cuihuo)去！"
    end

    test "temp 为 0 → 按未领处理（LPC 0 为假）→ 派新活" do
      conn2 = SmithJob.run(conn(temp: %{"smith/gu" => 0}), %{}, data())

      refute out_text(conn2) =~ "怎么还磨蹭"
      assert assigned_one_job?(character(conn2).meta.temp)
    end
  end

  describe "random(3) 派活" do
    test "恰好写一个 smith/* temp，文案与派活对应" do
      conn2 = SmithJob.run(conn(), %{}, data())
      temp = character(conn2).meta.temp
      text = out_text(conn2)

      assert assigned_one_job?(temp)

      cond do
        temp["smith/gu"] == 1 -> assert text =~ "好！你帮我鼓(gu)一会儿风箱。"
        temp["smith/dapi"] == 1 -> assert text =~ "这样吧，你帮我打(dapi)一下坯吧！"
        temp["smith/cuihuo"] == 1 -> assert text =~ "去帮我把这些刚出炉的淬(cuihuo)一下火。"
      end
    end

    test "data 缺 asker_id → 不改 conn（不崩）" do
      conn2 = SmithJob.run(conn(), %{}, %{kind: "smith_job"})

      assert out_text(conn2) == ""
    end
  end

  # LPC 真值语义：0/false/nil/"" 均为假（query_temp 未设置返回 0）。
  # 注意 Elixir 里 0 是 truthy，必须显式排除——旧值 smith/gu=0 会在派新活后
  # 残留（LPC set_temp 也只写新键，行为一致）。
  defp assigned_one_job?(temp) do
    Enum.count(["smith/gu", "smith/dapi", "smith/cuihuo"], fn key ->
      case Map.get(temp, key) do
        nil -> false
        false -> false
        0 -> false
        "" -> false
        _ -> true
      end
    end) == 1
  end
end
