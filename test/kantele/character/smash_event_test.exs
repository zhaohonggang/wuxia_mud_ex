defmodule Kantele.Character.SmashEventTest do
  @moduledoc """
  B2 — smash 事件链测试：
  - `Kantele.Character.SmashEvent.smitten/2`：目标进程内死亡结算 + R24 兜底
  - `Kantele.World.Room.SmashStrikeEvent.call/2`：同房间找人 + 等级门控 + 转发
  """
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SmashEvent
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room.SmashStrikeEvent

  defp character(opts \\ []) do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    %Kalevala.Character{
      id: Keyword.get(opts, :id, "player:1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: Keyword.get(opts, :pid, self()),
      room_id: "test:room",
      attributes: Keyword.get(opts, :attributes, %{}),
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: %Stats{str: 20, dex: 20, con: 20, int: 20, skills: %{}},
        temp: %{},
        # 故意留 nil，验证 R24 ensure_death_state 兜底不崩
        combat: Keyword.get(opts, :combat, nil),
        damage: Keyword.get(opts, :damage, %{})
      }
    }
  end

  defp conn_with(character), do: %Conn{character: character}

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "SmashEvent.smitten/2" do
    test "死亡结算：qi/jing 置 1、进入幽灵态、移到地府、不崩" do
      conn = conn_with(character())

      new_conn =
        SmashEvent.smitten(conn, %{
          data: %{smiter_name: "大巫", die_reason: "被大巫用雷劈死了"}
        })

      updated = new_conn.private.update_character
      assert updated.meta.vitals.qi == 1
      assert updated.meta.vitals.jing == 1
      assert updated.meta.damage[:ghost] == true
      assert updated.room_id == "death:yanluodian"
      assert output_text(new_conn) =~ "大巫"
    end

    test "meta.combat 为 nil 时兜底不崩（R24 回归）" do
      conn = conn_with(character(combat: nil, damage: nil))

      new_conn = SmashEvent.smitten(conn, %{data: %{}})

      assert new_conn.private.update_character.meta.combat != nil
      refute is_nil(new_conn.private.update_character)
    end

    test "缺省 data 不崩" do
      conn = conn_with(character())
      new_conn = SmashEvent.smitten(conn, %{})
      refute is_nil(new_conn.private.update_character)
    end
  end

  describe "Room.SmashStrikeEvent.call/2" do
    defp context(characters) do
      %{
        characters: characters,
        events: [],
        output: [],
        item_instances: [],
        data: %{},
        assigns: %{}
      }
    end

    defp strike_event(from_pid, data) do
      %Event{from_pid: from_pid, topic: "smash/strike", data: data}
    end

    test "同房间找到目标 → 转发 character/smitten 给目标进程" do
      smiter = character(id: "player:arch", name: "大巫", attributes: %{"wiz_level" => 2})
      target = character(id: "player:2", name: "张三")

      ctx =
        context([smiter, target])
        |> SmashStrikeEvent.call(
          strike_event(smiter.pid, %{
            target_name: "张三",
            smiter_name: "大巫",
            smiter_level: 2,
            die_reason: "被大巫用雷劈死了"
          })
        )

      assert length(ctx.events) == 1
      {_to_pid, event} = hd(ctx.events)
      assert event.topic == "character/smitten"
      assert event.data.smiter_name == "大巫"
      assert event.data.die_reason == "被大巫用雷劈死了"
    end

    test "目标巫师等级更高 → 不转发（LPC 冒青烟无伤）" do
      smiter = character(id: "player:arch", name: "大巫", attributes: %{"wiz_level" => 2})
      target = character(id: "player:2", name: "张三", attributes: %{"wiz_level" => 3})

      ctx =
        context([smiter, target])
        |> SmashStrikeEvent.call(
          strike_event(smiter.pid, %{
            target_name: "张三",
            smiter_name: "大巫",
            smiter_level: 2
          })
        )

      assert ctx.events == []
    end

    test "目标不在房间 → 不转发" do
      smiter = character(id: "player:arch", name: "大巫", attributes: %{"wiz_level" => 2})

      ctx =
        context([smiter])
        |> SmashStrikeEvent.call(
          strike_event(smiter.pid, %{target_name: "李四", smiter_name: "大巫", smiter_level: 2})
        )

      assert ctx.events == []
    end

    test "名字前缀匹配（双语名）" do
      smiter = character(id: "player:arch", name: "大巫", attributes: %{"wiz_level" => 2})
      target = character(id: "player:2", name: "店小二 Xiaoer")

      ctx =
        context([smiter, target])
        |> SmashStrikeEvent.call(
          strike_event(smiter.pid, %{target_name: "店小二", smiter_name: "大巫", smiter_level: 2})
        )

      assert length(ctx.events) == 1
    end
  end
end
