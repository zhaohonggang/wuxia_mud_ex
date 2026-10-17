defmodule Kantele.Character.VisionEventTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.VisionEvent
  alias Kantele.Character.VisionView

  defp other_pid do
    spawn(fn -> :timer.sleep(:infinity) end)
  end

  defp character(id, name) do
    %Kalevala.Character{
      id: id,
      name: name,
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{vitals: Vitals.new(), stats: Stats.new(), combat: Combat.new()}
    }
  end

  defp message_event(attrs) do
    struct!(%Event.Message{
      channel_name: "rooms:test:room",
      type: "vision",
      text: "{npc}抖出一柄长剑握在手中。",
      character: character("player-1", "张三"),
      id: "msg-1"
    }, attrs)
  end

  describe "interested?/1" do
    test "rooms: 频道上的 vision 类型命中" do
      assert VisionEvent.interested?(%Event{data: message_event(%{})})
    end

    test "speech 类型不命中（留给 SayEvent）" do
      refute VisionEvent.interested?(%Event{data: message_event(%{type: "speech"})})
    end

    test "非 rooms: 频道不命中" do
      refute VisionEvent.interested?(%Event{data: message_event(%{channel_name: "general"})})
    end
  end

  describe "echo/2" do
    test "行动者自己收到：{npc} → 你" do
      character = character("player-1", "张三")

      conn =
        VisionEvent.echo(build_conn(character), %Event{
          from_pid: self(),
          topic: Event.Message,
          data: message_event(%{})
        })

      # echo 末尾带 prompt，消息文本本身无换行（EventText.text）
      assert output_text(conn) =~ "你抖出一柄长剑握在手中。"
    end

    test "房间内其他人收到：{npc} → 行动者姓名" do
      character = character("player-2", "李四")

      conn =
        VisionEvent.echo(build_conn(character), %Event{
          from_pid: other_pid(),
          topic: Event.Message,
          data: message_event(%{})
        })

      assert output_text(conn) =~ "张三抖出一柄长剑握在手中。"
    end
  end

  describe "VisionView.render/2" do
    test "echo/listen 只替换 {npc}，{name} 留给发布方预替换" do
      echo =
        VisionView.render("echo", %{text: "{npc}把一样放了下来。"})
        |> Map.get(:text)
        |> IO.iodata_to_binary()

      assert echo == "你把一样放了下来。"

      listen =
        VisionView.render("listen", %{
          text: "{npc}把一样{name}放了下来。",
          character: %Kalevala.Character{name: "王五"}
        })
        |> Map.get(:text)
        |> IO.iodata_to_binary()

      assert listen == "王五把一样{name}放了下来。"
    end
  end

  # conn.output 混合两种条目：纯字符串渲染 → %Conn.Text{}，EventText 渲染
  # → %EventText{}（kalevala Conn.push/3 两个子句，见 conn.ex L139/L150）。
  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      %Kalevala.Character.Conn.EventText{text: %Kalevala.Character.Conn.Text{data: data}} ->
        [IO.iodata_to_binary(data)]

      _ ->
        []
    end)
    |> Enum.join("")
  end
end
