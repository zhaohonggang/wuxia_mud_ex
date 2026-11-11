defmodule Kantele.World.SnowRegionEventTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.Character.Conn
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.SnowRegionEvent

  defp player(qi: qi) do
    vitals = %Vitals{
      qi: qi,
      max_qi: 200,
      jing: 100,
      max_jing: 200,
      jingli: 2000,
      max_jingli: 2000,
      neili: 1000,
      max_neili: 1000,
      food: 100,
      water: 100
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 0,
      score: 0,
      potential: 0,
      weiwang: 0
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{},
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Combat.new()
      }
    }
  end

  defp cold_conn(qi, conditions \\ nil) do
    build_conn(player(qi: qi), %{"conditions" => conditions || %{}})
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join()
  end

  describe "cold/2 —— 雪原寒冷事件处理（snow/cold）" do
    test "damage > 0：渲染文案并扣气" do
      conn = cold_conn(100)
      event = %Event{
        topic: "snow/cold",
        data: %{damage: 20, msg: "天气非常的冷！\n"}
      }

      result = SnowRegionEvent.cold(conn, event)

      assert output_text(result) =~ "天气非常的冷"
      assert result.private.update_character.meta.vitals.qi == 80  # 100 - 20
    end

    test "damage = 0：渲染文案但不扣气" do
      conn = cold_conn(100)
      event = %Event{
        topic: "snow/cold",
        data: %{damage: 0, msg: "挺暖和的。\n"}
      }

      result = SnowRegionEvent.cold(conn, event)

      assert output_text(result) =~ "挺暖和"
      assert result.character.meta.vitals.qi == 100
    end

    test "damage > 10 且 qi < 50（扣气后）：落 ill_dongshang 条件" do
      # qi=30，damage=20 -> 扣气后 qi=10 < 50，落冻伤
      # duration = 0 + 5 + div(20, 3) = 5 + 6 = 11
      conn = cold_conn(30)
      event = %Event{
        topic: "snow/cold",
        data: %{damage: 20, msg: "天气非常的冷！\n"}
      }

      result = SnowRegionEvent.cold(conn, event)

      conditions = Conn.get_session(result, "conditions")
      assert %{"duration" => duration} = conditions["ill_dongshang"]
      assert duration == 11
    end

    test "damage > 10 但 qi >= 50（扣气后）：不落 ill_dongshang" do
      # qi=100，damage=20 -> 扣气后 qi=80 >= 50，不落冻伤
      conn = cold_conn(100)
      event = %Event{
        topic: "snow/cold",
        data: %{damage: 20, msg: "天气非常的冷！\n"}
      }

      result = SnowRegionEvent.cold(conn, event)

      conditions = Conn.get_session(result, "conditions")
      refute Map.get(conditions, "ill_dongshang")
    end

    test "damage <= 10：不落 ill_dongshang 即使 qi < 50" do
      # qi=30，damage=5 -> 扣气后 qi=25 < 50，但 damage <= 10，不落冻伤
      conn = cold_conn(30)
      event = %Event{
        topic: "snow/cold",
        data: %{damage: 5, msg: "有点冷！\n"}
      }

      result = SnowRegionEvent.cold(conn, event)

      conditions = Conn.get_session(result, "conditions")
      refute Map.get(conditions, "ill_dongshang")
    end

    test "已有 ill_dongshang 时持续时间累加" do
      # qi=30，damage=20 -> 扣气后 qi=10 < 50，落冻伤
      # existing=10，duration = 10 + 5 + div(20, 3) = 10 + 5 + 6 = 21
      conn = cold_conn(30, %{"ill_dongshang" => %{"duration" => 10}})
      event = %Event{
        topic: "snow/cold",
        data: %{damage: 20, msg: "天气非常的冷！\n"}
      }

      result = SnowRegionEvent.cold(conn, event)

      conditions = Conn.get_session(result, "conditions")
      assert %{"duration" => duration} = conditions["ill_dongshang"]
      assert duration == 21
    end

    test "缺失 damage 键：返回 conn 不变（匹配失败走兜底条款）" do
      conn = cold_conn(100)
      event = %Event{topic: "snow/cold", data: %{msg: "只有文案"}}
      before = inspect(conn)

      result = SnowRegionEvent.cold(conn, event)

      assert inspect(result) == before
    end

    test "非 snow/cold 主题且 data 缺损：返回 conn 不变（兜底条款）" do
      conn = cold_conn(100)
      event = %Event{
        topic: "other/event",
        data: %{foo: "bar"}
      }
      before = inspect(conn)

      result = SnowRegionEvent.cold(conn, event)

      assert inspect(result) == before
    end
  end
end
