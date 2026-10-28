defmodule Kantele.Character.ZhuneiliCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.ZhuneiliCommand
  alias Kantele.World.Forging

  @owner_id "player-zhun-1"
  @owner_name "赵六"

  setup do
    Forging.ensure_table()
    Forging.delete(@owner_id)
    :ok
  end

  defp player(vital_overrides \\ []) do
    vitals =
      struct(
        %Vitals{qi: 400, max_qi: 400, jing: 200, max_jing: 200, neili: 900, max_neili: 1100},
        vital_overrides
      )

    # force 基本 50 级、无 map → 有效等级 = div(50, 2) = 25（LPC 基本技能折半）
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

  # 从频道变更队列里取出 vision 广播文本（Helpers.broadcast_vision 的产物）
  defp vision_text(conn) do
    conn.private.channel_changes
    |> Enum.flat_map(fn
      {:publish, _channel, %Kalevala.Event{topic: Kalevala.Event.Message, data: data}, _opts, _fun} ->
        [data.text]

      _ ->
        []
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

  describe "合法注内力（LPC do_help 成功分支）" do
    test "扣气精内力最大内力、提升 point、can_help 置 false、房间 vision" do
      p = player()
      Forging.put(@owner_id, session())

      conn = ZhuneiliCommand.run(build_conn(p), %{})
      v = updated_char(conn).meta.vitals

      # 扣费：jing 200-180, qi 400-300, neili 900-200, max_neili 1100-200
      assert v.jing == 20
      assert v.qi == 100
      assert v.neili == 700
      assert v.max_neili == 900

      # force 有效等级 25（50 折半）→ point = 100 + div(100*25, 800) = 103
      s = Forging.get(@owner_id)
      assert s.can_help == false
      assert s.point == 103

      # 成功文案是 message_vision（房间广播），不是私人 tell
      assert vision_text(conn) =~ "长啸一声，双手搭上炉边。刹那间炉火沸腾，一道白光直冲霄汉。"
      # `$N` 由 broadcast_vision 归一为 `{npc}`，交给 VisionView 按接收者渲染
      assert vision_text(conn) =~ "{npc}"
    end
  end

  describe "会话门控（LPC 原文文案）" do
    test "无活跃会话 → 没你什么业务" do
      Forging.delete(@owner_id)
      conn = ZhuneiliCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "没你什么业务。"
      assert Forging.get(@owner_id) == nil
    end

    test "status 不在 waiting/inputing → 没你什么业务" do
      Forging.put(@owner_id, session(%{status: "handoff"}))
      conn = ZhuneiliCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "没你什么业务。"

      s = Forging.get(@owner_id)
      assert s.status == "handoff"
      assert s.can_help == true
    end

    test "status = waiting 也放行（LPC 用的是 waiting）" do
      Forging.put(@owner_id, session(%{status: "waiting"}))
      conn = ZhuneiliCommand.run(build_conn(player()), %{})
      assert Forging.get(@owner_id).can_help == false
      assert vision_text(conn) =~ "白光直冲霄汉"
    end

    test "can_help == false → 现在不是你帮忙的时候" do
      Forging.put(@owner_id, session(%{can_help: false}))
      conn = ZhuneiliCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "现在不是你帮忙的时候！"
      assert Forging.get(@owner_id).can_help == false
    end
  end

  describe "体力链失败（LPC 逐项扣、逐项判，失败要付代价）" do
    test "jing < 180 → jing 归零 + 「精力衰竭」，不扣其它" do
      p = player(jing: 100)
      Forging.put(@owner_id, session())

      conn = ZhuneiliCommand.run(build_conn(p), %{})
      v = updated_char(conn).meta.vitals

      assert v.jing == 0
      assert v.qi == 400
      assert v.neili == 900

      assert output_text(conn) =~ "你感到精力衰竭。"
      assert vision_text(conn) =~ "突然眼前一黑"

      # 未成功：会话不变
      s = Forging.get(@owner_id)
      assert s.can_help == true
      assert s.point == 100
    end

    test "qi < 300 → jing 先被扣 180，qi 归零 + 「心虚气短」" do
      p = player(qi: 200)
      Forging.put(@owner_id, session())

      conn = ZhuneiliCommand.run(build_conn(p), %{})
      v = updated_char(conn).meta.vitals

      assert v.jing == 20, "LPC 先 receive_damage(jing,180) 再判 qi，jing 已损失"
      assert v.qi == 0
      assert v.neili == 900

      assert output_text(conn) =~ "你感到心虚气短。"
      assert Forging.get(@owner_id).point == 100
    end

    test "neili < 800 → jing、qi 已扣，neili 归零 + 「内力枯竭」" do
      p = player(neili: 500)
      Forging.put(@owner_id, session())

      conn = ZhuneiliCommand.run(build_conn(p), %{})
      v = updated_char(conn).meta.vitals

      assert v.jing == 20
      assert v.qi == 100
      assert v.neili == 0

      assert output_text(conn) =~ "你感到内力枯竭。"
      assert Forging.get(@owner_id).can_help == true
    end

    test "max_neili < 1000（neili 自身达标）→ 同样 neili 归零" do
      p = player(max_neili: 600)
      Forging.put(@owner_id, session())

      conn = ZhuneiliCommand.run(build_conn(p), %{})
      v = updated_char(conn).meta.vitals

      assert v.jing == 20
      assert v.qi == 100
      assert v.neili == 0

      assert output_text(conn) =~ "你感到内力枯竭。"
    end
  end

  describe "query_skill 语义（基本技能折半 + 特技全值 + apply）" do
    test "map 了特技时 point 加成按「force/2 + 特技」算" do
      stats =
        struct(Stats.new(),
          skills: %{"force" => 50, "taiji-shengong" => 40},
          mapped: %{"force" => "taiji-shengong"}
        )

      p = %Character{player() | meta: %PlayerMeta{vitals: player().meta.vitals, stats: stats}}
      Forging.put(@owner_id, session())

      ZhuneiliCommand.run(build_conn(p), %{})

      # 有效 force = div(50,2) + 40 = 65 → point = 100 + div(100*65, 800) = 100 + 8
      assert Forging.get(@owner_id).point == 108
    end
  end
end
