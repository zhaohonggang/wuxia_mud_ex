defmodule Kantele.Character.AskCommandCityPingTest do
  @moduledoc """
  `ask 平一指 <关键词>` 端到端接线测试。

  上一批（第 55 批）只交付了 `Kantele.NPC.CityPing` + UCL `ask_handler` + Handler 定向测试，
  回归清单误记为「AskCommand 未接线」。本文件验证真实运行时路径：

      AskCommand.run/2 → npc.meta.ask_handler → Code.ensure_loaded/1
        → CityPing.check/3 → CityPing.execute/3 → put_character + render

  与 LPC `d/city/npc/ping.c` 的 `ask_job()` 行为逐字对齐（interactive 门除外）。
  """

  use ExVenture.DataCase, async: false
  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.AskCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    %Character{
      id: "ask-city-ping-player",
      name: "张三",
      pid: self(),
      room_id: "kaifeng:yaopu",
      meta: %PlayerMeta{
        stats: %Stats{combat_exp: Keyword.get(opts, :combat_exp, 10_000)},
        vitals: %Vitals{qi: Keyword.get(opts, :qi, 100), max_qi: 100},
        temp: Keyword.get(opts, :temp, %{}),
        marks: Keyword.get(opts, :marks, %{})
      }
    }
  end

  defp ping_npc do
    %{
      id: "city_ping",
      name: "平一指",
      pid: self(),
      room_id: "kaifeng:yaopu",
      meta: %{
        aliases: ["ping yi zhi"],
        ask_handler: "Kantele.NPC.CityPing"
      }
    }
  end

  defp conn_with_ping(player) do
    conn = build_conn(player)
    private = %{conn.private | room: %{private: %{characters: [ping_npc()]}}}
    %{conn | private: private}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated_char(conn), do: conn.private.update_character || conn.character

  test "ask 平一指 配药：分发到 CityPing 并落 temp job/peiyao" do
    result = AskCommand.run(conn_with_ping(player()), %{"name" => "平一指", "keyword" => "配药"})

    assert updated_char(result).meta.temp["job/peiyao"] == 1
    # 领活阶段不结算经验/潜能/mark
    assert updated_char(result).meta.stats.combat_exp == 10_000
    assert updated_char(result).meta.marks == %{}

    text = output_text(result)
    assert text =~ "好，你就帮我配药(peiyao)吧！喏，就这几味。"
    assert text =~ "你向平一指请教配药。"
  end

  test "ask 平一指 about job：strip_about 后英文关键字同样命中" do
    result =
      AskCommand.run(conn_with_ping(player()), %{"name" => "ping yi zhi", "keyword" => "about job"})

    assert updated_char(result).meta.temp["job/peiyao"] == 1
    assert output_text(result) =~ "帮我配药(peiyao)吧"
  end

  test "ask 平一指 工作：中文别名关键字命中" do
    result = AskCommand.run(conn_with_ping(player()), %{"name" => "平一指", "keyword" => "工作"})

    assert updated_char(result).meta.temp["job/peiyao"] == 1
    assert output_text(result) =~ "帮我配药(peiyao)吧"
  end

  test "已领活再 ask：check 拒绝，消息不追加「请教」且状态不变" do
    result =
      AskCommand.run(
        conn_with_ping(player(temp: %{"job/peiyao" => 1})),
        %{"name" => "平一指", "keyword" => "配药"}
      )

    assert updated_char(result).meta.temp["job/peiyao"] == 1
    text = output_text(result)
    assert text =~ "让你干的活你干完了么？"
    refute text =~ "你向平一指请教"
  end

  test "弱角色 ask：check 拒绝且不落 job/peiyao" do
    result =
      AskCommand.run(
        conn_with_ping(player(combat_exp: 4_999)),
        %{"name" => "平一指", "keyword" => "配药"}
      )

    assert is_nil(updated_char(result).meta.temp["job/peiyao"])
    assert output_text(result) =~ "就凭你就这点能力"
  end
end
