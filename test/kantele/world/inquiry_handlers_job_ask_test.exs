defmodule Kantele.World.InquiryHandlers.JobAskTest do
  @moduledoc """
  A-5-b：`job_ask` 问询处理器（平一指/书童/厨娘）与 11 个 UCL 占位回填的定向测试。

  LPC 源：
  - `d/city/npc/ping.c:113-145` ask_job()
  - `d/city/npc/shutong.c:45-83` ask_job()
  - `d/chengdu/npc/chuniang.c:67-105` ask_job()
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.InquiryHandlers
  alias Kantele.World.InquiryHandlers.JobAsk
  alias Kantele.World.Loader

  @ping_config %{"kind" => "job_ask", "profile" => "city_ping"}
  @shutong_config %{"kind" => "job_ask", "profile" => "city_shutong"}
  @chuniang_config %{"kind" => "job_ask", "profile" => "chengdu_chuniang"}

  defp conn(opts \\ []) do
    stats = %Stats{
      combat_exp: Keyword.get(opts, :exp, 2000),
      int: Keyword.get(opts, :int, 25),
      skills: Keyword.get(opts, :skills, %{}),
      mapped: Keyword.get(opts, :mapped, %{}),
      tattoo: %{},
      reborn: %{}
    }

    vitals = %Vitals{
      qi: Keyword.get(opts, :qi, 100),
      jing: Keyword.get(opts, :jing, 100)
    }

    meta = %PlayerMeta{
      stats: stats,
      vitals: vitals,
      temp: Keyword.get(opts, :temp, %{}),
      marks: Keyword.get(opts, :marks, %{}),
      env: %{gender: Keyword.get(opts, :gender, "男性")}
    }

    private = %Conn.Private{channel_changes: []}

    private =
      case Keyword.get(opts, :occupants) do
        nil -> private
        occupants -> %{private | room: %{characters: occupants}}
      end

    %Conn{
      character: %Character{
        id: "player:test",
        name: "李四",
        room_id: Keyword.get(opts, :room_id, "chengdu:chufang"),
        meta: meta
      },
      private: private,
      output: []
    }
  end

  defp data(overrides \\ %{}) do
    Map.merge(
      %{
        asker_id: "player:test",
        asker_name: "李四",
        npc_name: "NPC",
        npc_room_id: "chengdu:chufang"
      },
      overrides
    )
  end

  defp out_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated(conn) do
    conn.private.update_character || conn.character
  end

  test "job_ask 已注册；非问询者本人完全沉默" do
    assert InquiryHandlers.lookup("job_ask") == JobAsk

    result = JobAsk.run(conn(), @ping_config, data(%{asker_id: "player:other"}))
    assert out_text(result) == ""
  end

  describe "city_ping profile" do
    test "复用 CityPing 门序：经验不足拒绝" do
      result = JobAsk.run(conn(exp: 1000), @ping_config, data())
      assert out_text(result) =~ "端不起来"
      refute Map.has_key?(updated(result).meta.temp, "job/peiyao")
    end

    test "成功写 job/peiyao temp 并回原文" do
      result = JobAsk.run(conn(exp: 6000, qi: 50), @ping_config, data())
      assert out_text(result) =~ "好，你就帮我配药(peiyao)吧！喏，就这几味。"
      assert updated(result).meta.temp["job/peiyao"] == 1
    end
  end

  describe "city_shutong profile" do
    test "已领活 / 经验上下界 / 气血 / 精神 / 悟性门按 LPC 原序拒绝" do
      cases = [
        {[temp: %{"job/copy" => 1}], "让你抄的书你抄完了？", false},
        {[exp: 1000], "你经验太差", true},
        {[exp: 9000], "大侠你还是别抄书了", true},
        {[exp: 2000, qi: 10], "我看你脸色不行啊", true},
        {[exp: 2000, jing: 5], "我看你精神不行啊", true},
        {[exp: 2000, int: 10, skills: %{"literate" => 10}], "不太聪明", true}
      ]

      for {opts, expected, assert_no_temp} <- cases do
        result = JobAsk.run(conn(opts), @shutong_config, data())
        assert out_text(result) =~ expected

        if assert_no_temp do
          refute Map.has_key?(updated(result).meta.temp, "job/copy")
        end
      end
    end

    test "同房间已有他人在抄书 → 报出占用者姓名" do
      occupants = [
        %{id: "player:other", name: "张三", meta: %{temp: %{"job/copy" => 1}}}
      ]

      result = JobAsk.run(conn(occupants: occupants), @shutong_config, data())
      assert out_text(result) =~ "我这已经有张三在干活了，你等等吧。"
      refute Map.has_key?(updated(result).meta.temp, "job/copy")
    end

    test "成功写 job/copy temp 并回原文" do
      result = JobAsk.run(conn(), @shutong_config, data())
      assert out_text(result) =~ "好，你就帮我抄书(copy)吧！笔墨纸砚在这儿。"
      assert updated(result).meta.temp["job/copy"] == 1
    end
  end

  describe "chengdu_chuniang profile" do
    test "性别 / 经验 / 精神 / 老手 / 烹饪等级 / 映射门按 LPC 原序拒绝" do
      cases = [
        {[gender: "男性", exp: 1000], "你一个大老爷们"},
        {[gender: "女性", exp: 5000], "端得动盘子么"},
        {[gender: "女性", exp: 20_000, jing: 50], "你还是休息会儿吧"},
        {[gender: "女性", exp: 250_000, marks: %{"job_cook" => 2000}], "折杀小的"},
        {[gender: "女性", exp: 20_000, skills: %{"cooking" => 50}], "你的炒菜手艺那么差"},
        {[
           gender: "女性",
           exp: 20_000,
           skills: %{"cooking" => 80},
           mapped: %{"cooking" => "other-cooking"}
         ], "亮出你川菜的活儿"}
      ]

      for {opts, expected} <- cases do
        result = JobAsk.run(conn(opts), @chuniang_config, data())
        assert out_text(result) =~ expected
        refute Map.has_key?(updated(result).meta.temp, "job/cook")
      end
    end

    test "成功写 job/cook temp 并回原文" do
      result =
        JobAsk.run(
          conn(
            gender: "女性",
            exp: 20_000,
            skills: %{"cooking" => 80},
            mapped: %{"cooking" => "chuancai-jiyi"}
          ),
          @chuniang_config,
          data()
        )

      assert out_text(result) =~ "好吧，你就帮我炒菜(cook)吧！菜在这儿，灶台在那边。"
      assert updated(result).meta.temp["job/cook"] == 1
    end
  end

  test "UCL 11 个占位全部替换为 job_ask config，平一指两份块均挂 ask_handler" do
    # city:ping 与 clone_lib:city_ping 是两份数据；loader 以 clone_lib 为准，
    # 故两份 UCL 源都要检查，不能只看加载后的单一副本。
    city_ucl = File.read!("data/world/city.ucl")
    clone_ucl = File.read!("data/world/clone_lib.ucl")

    for ucl <- [city_ucl, clone_ucl] do
      assert ucl =~ ~s(ask_handler = "Kantele.NPC.CityPing")
      assert String.contains?(ucl, ~s(profile = "city_ping"))

      refute String.contains?(
               ucl,
               ~s[{ key = "job" value = " inquire about job (unimplemented)" }]
             )
    end

    world = Loader.load()

    ping = Enum.find(world.characters, &(&1.name == "平一指" and &1.meta.zone_id == "clone_lib"))
    assert ping
    assert Map.get(ping.meta, :ask_handler) == "Kantele.NPC.CityPing"

    for key <- ["job", "工作", "配药"] do
      config = Map.get(ping.meta.inquiries, key)
      assert is_map(config)
      assert (config["kind"] || config[:kind]) == "job_ask"
      assert (config["profile"] || config[:profile]) == "city_ping"
    end

    # city:shutong 在当前世界里没有被房间引用，loader 不会实例化它；
    # 但该原型块仍属 11 个占位之一，必须按 UCL 源检查。
    assert length(Regex.scan(~r/profile = "city_shutong"/, city_ucl)) == 3

    chuniang = Enum.find(world.characters, &(&1.name == "厨娘" and &1.meta.zone_id == "chengdu"))
    assert chuniang

    for key <- ["job", "工作"] do
      config = Map.get(chuniang.meta.inquiries, key)
      assert (config["kind"] || config[:kind]) == "job_ask"
      assert (config["profile"] || config[:profile]) == "chengdu_chuniang"
    end
  end
end
