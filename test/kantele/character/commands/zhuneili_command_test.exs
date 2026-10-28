defmodule Kantele.Character.ZhuneiliCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Forging
  alias Kantele.Character.ZhuneiliCommand

  @owner_id "player-zhun-1"
  @owner_name "赵六"

  setup do
    Forging.ensure_table()
    Forging.delete(@owner_id)
    :ok
  end

  defp player() do
    vitals =
      %Vitals{
        qi: 400,
        max_qi: 400,
        jing: 200,
        max_jing: 200,
        neili: 900,
        max_neili: 1100
      }

    stats = struct(Stats.new(), skills: %{"force" => 50})

    %Character{
      id: @owner_id,
      name: @owner_name,
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{vitals: vitals, stats: stats}
    }
  end

  defp session(extra \\ %{}) do
    %{
      status: "inputing",
      can_help: true,
      point: 100,
      owner_id: @owner_id,
      owner_name: @owner_name
    }
    |> Map.merge(Map.new(extra))
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

  describe "路由解析" do
    test "注内力 落在 ZhuneiliCommand，params 不含 rest" do
      {:ok, parsed} = Kantele.Character.Commands.parse("注内力")
      assert parsed.module == ZhuneiliCommand
      assert parsed.params["command"] == "注内力"
      refute Map.has_key?(parsed.params, "rest")
    end
  end

  describe "合法注内力" do
    test "扣气精内力最大内力、提升 point、can_help 置 false" do
      p = player()
      Forging.put(@owner_id, session())

      conn = ZhuneiliCommand.run(build_conn(p), %{})

      c = updated_char(conn)
      v = c.meta.vitals

      # 扣费：jing 200-180, qi 400-300, neili 900-200, max_neili 1100-200
      assert v.jing == 20
      assert v.qi == 100
      assert v.neili == 700
      assert v.max_neili == 900

      # 会话：point = 100 + div(100 * 50, 800) = 100 + 6 = 106；can_help -> false
      s = Forging.get(@owner_id)
      assert s.can_help == false
      assert s.point == 106

      assert output_text(conn) =~ "炉火骤然炽盛"
      assert output_text(conn) =~ "106"
      assert output_text(conn) =~ "无法再注入内力"
    end
  end

  describe "会话门控" do
    test "无活跃会话 → 提示并不改动" do
      Forging.delete(@owner_id)
      conn = ZhuneiliCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "没有进行中的锻造会话"
      assert Forging.get(@owner_id) == nil
    end

    test "status != inputing → 拒绝" do
      Forging.put(@owner_id, session(%{status: "handoff"}))
      conn = ZhuneiliCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "炉火尚未备好"
      s = Forging.get(@owner_id)
      assert s.status == "handoff"
      assert s.can_help == true
    end

    test "can_help == false → 拒绝（单次限制）" do
      Forging.put(@owner_id, session(%{can_help: false}))
      conn = ZhuneiliCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "无法再注入内力"
      s = Forging.get(@owner_id)
      assert s.can_help == false
    end
  end

  describe "体力门槛" do
    test "jing < 180 → 拒绝" do
      p =
        %Character{
          player()
          |
          meta: %{
            player().meta
            | vitals: %Vitals{player().meta.vitals | jing: 100}
          }
        }
      Forging.put(@owner_id, session())
      conn = ZhuneiliCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "你的精不足"
    end

    test "qi < 300 → 拒绝" do
      p =
        %Character{
          player()
          |
          meta: %{
            player().meta
            | vitals: %Vitals{player().meta.vitals | qi: 200}
          }
        }
      Forging.put(@owner_id, session())
      conn = ZhuneiliCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "你的气不足"
    end

    test "neili < 800 → 拒绝" do
      vitals = %Vitals{qi: 400, max_qi: 400, jing: 200, max_jing: 200, neili: 500, max_neili: 1100}
      stats = struct(Stats.new(), skills: %{"force" => 50})
      p = %Character{id: @owner_id, name: @owner_name, pid: self(), room_id: "test:room",
        inventory: [], attributes: %{}, meta: %PlayerMeta{vitals: vitals, stats: stats}}
      Forging.put(@owner_id, session())
      conn = ZhuneiliCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "你的内力不足"
    end

    test "max_neili < 1000 → 拒绝（neili 自身已达标）" do
      vitals = %Vitals{qi: 400, max_qi: 400, jing: 200, max_jing: 200, neili: 900, max_neili: 600}
      stats = struct(Stats.new(), skills: %{"force" => 50})
      p = %Character{id: @owner_id, name: @owner_name, pid: self(), room_id: "test:room",
        inventory: [], attributes: %{}, meta: %PlayerMeta{vitals: vitals, stats: stats}}
      Forging.put(@owner_id, session())
      conn = ZhuneiliCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "你的最大内力不足"
    end
  end
end
