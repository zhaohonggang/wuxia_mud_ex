defmodule Kantele.Combat.RouyunStepsTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.PerformCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.RouyunSteps
  alias Kantele.Combat.Skills.Performs.RouyunSteps.Zong

  @vitals %{Vitals.new() | neili: 200, max_neili: 200}
  @room "city:wumiao"
  @destinations ["city/wumiao", "city/kedian", "mudren/workroom"]

  defp build_character(opts) do
    stats = struct(Stats.new(), Keyword.take(opts, [:skills, :mapped, :performs]))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @room,
      meta: %Kantele.Character.PlayerMeta{
        vitals: Keyword.get(opts, :vitals, @vitals),
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp perform(opts) do
    opts = Keyword.put_new(opts, :performs, MapSet.new(["rouyun-steps/zong"]))
    PerformCommand.run(build_conn(build_character(opts)), %{"action" => "rouyun-steps.zong"})
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp published_text(conn) do
    conn.private.channel_changes
    |> Enum.flat_map(fn
      {:publish, _channel, %Kalevala.Event{topic: Kalevala.Event.Message, data: data}, _, _} ->
        [data.text]

      _ ->
        []
    end)
    |> Enum.join("")
  end

  describe "柔云步（技能表）" do
    test "已注册且可 enable dodge/move" do
      assert Skills.known?("rouyun-steps")
      assert Skills.get("rouyun-steps") == RouyunSteps
      assert RouyunSteps.valid_enable("dodge")
      assert RouyunSteps.valid_enable("move")
      refute RouyunSteps.valid_enable("sword")
    end

    test "perform_list 含柔云纵" do
      assert RouyunSteps.perform_list() == %{"zong" => Zong}
    end
  end

  describe "柔云纵（门槛）" do
    test "未学会被拒" do
      conn = perform([skills: %{"rouyun-steps" => 50}, performs: MapSet.new()])
      assert output_text(conn) =~ "外功中没有这种功能"
    end

    test "等级不足被拒" do
      conn = perform([skills: %{"rouyun-steps" => 49}])
      assert output_text(conn) =~ "柔云步法不够熟练"
    end

    test "成功：扣无内力、广播起身文案并随机传送" do
      conn = perform([skills: %{"rouyun-steps" => 60}])

      updated = conn.private.update_character
      assert updated.room_id in @destinations
      assert updated.meta.vitals.neili == @vitals.neili
      assert pub_text = published_text(conn)
      assert pub_text =~ "身形陡然纵起"
      assert pub_text =~ "乘云而去了"
    end
  end
end