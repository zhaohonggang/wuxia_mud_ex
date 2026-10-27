defmodule Kantele.World.BegRequestEventTest do
  @moduledoc """
  P5 乞讨房间事件（对应 LPC cmds/std/beg.c `compelete_beg` 判定）。

  覆盖：目标查找、victim 门派/战斗/无钱 拦截，以及成功判定（victim jing=0 →
  dp=0 → 必然成功）跨进程发 `beg/debit`（扣 victim）+ `beg/credit`（加 beggar）
  事件并广播 vision。

  `context.characters` 为房间内角色的纯 map 快照（与运行时一致：含 `:name`、
  `is_character`、`meta`、`attributes` 等键），`meta.combat`/`meta.stats` 须为真实
  结构体（`%Combat{}`/`%Stats{}`）。
  """
  use ExUnit.Case, async: true

  alias Kalevala.Event
  alias Kalevala.World.Room.Context
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.World.Room
  alias Kantele.World.Room.BegRequestEvent

  defp beggar() do
    %{
      id: "player-1",
      name: "小乞丐",
      pid: self(),
      room_id: "test:room",
      is_character: true,
      is_player: true,
      inventory: [],
      attributes: %{"jing" => 200},
      meta: %{
        family: %{name: "丐帮"},
        stats: %Stats{skills: %{}},
        combat: Combat.new(),
        coins: 0
      }
    }
  end

  defp victim(opts \\ []) do
    coins = Keyword.get(opts, :coins, 500)
    jing = Keyword.get(opts, :jing, 1)
    family = Keyword.get(opts, :family, %{name: "武当"})
    fighting = Keyword.get(opts, :fighting, false)

    combat =
      if fighting do
        %{Combat.new() | enemies: [%{id: "x", name: "y", room_id: "test:room"}]}
      else
        Combat.new()
      end

    %{
      id: "player-2",
      name: "大侠",
      pid: :victim,
      room_id: "test:room",
      is_character: true,
      is_player: true,
      inventory: [],
      attributes: %{"jing" => jing},
      meta: %{
        family: family,
        stats: %Stats{skills: %{}},
        combat: combat,
        coins: coins
      }
    }
  end

  defp context(chars) do
    %Context{
      data: %Room{id: "test:room"},
      characters: chars,
      item_instances: [],
      assigns: %{},
      events: [],
      output: []
    }
  end

  defp call(chars, data) do
    BegRequestEvent.call(context(chars), %Event{
      from_pid: self(),
      topic: "beg/attempt",
      data: data
    })
  end

  defp rendered_texts(ctx) do
    Enum.flat_map(ctx.output, fn
      {_pid, %Kalevala.Character.Conn.Text{data: data}} -> [IO.iodata_to_binary(data)]
      {_pid, text} when is_binary(text) -> [text]
      _ -> []
    end)
  end

  defp emitted(ctx, topic) do
    Enum.filter(ctx.events, fn {_to_pid, %Event{topic: t}} -> t == topic end)
  end

  describe "目标/门派/战斗/资金 闸门" do
    test "目标不存在 → 提示不在这里" do
      ctx = call([beggar()], %{coin: "cash", target: "不存在的人"})
      assert rendered_texts(ctx) == ["你想乞讨的对象不在这里。\n"]
    end

    test "victim 也是乞丐 → 乞讨不出东西" do
      ctx = call([beggar(), victim(family: %{name: "丐帮"})], %{coin: "cash", target: "大侠"})
      assert rendered_texts(ctx) == ["那家伙也是乞丐，乞讨不出什么。\n"]
    end

    test "victim 正在战斗 → 没空理你" do
      ctx = call([beggar(), victim(fighting: true)], %{coin: "cash", target: "大侠"})
      assert rendered_texts(ctx) == ["大侠正在打架，没空理你。\n"]
    end

    test "victim 身无分文 → 没油水" do
      ctx = call([beggar(), victim(coins: 0)], %{coin: "cash", target: "大侠"})
      assert rendered_texts(ctx) == ["看起来大侠身上没有什么让你感兴趣的东西。\n"]
    end
  end

  describe "成功判定（victim jing=0 → dp=0 → 必然成功）" do
    test "向 victim 发 beg/debit、向 beggar 发 beg/credit，并广播 vision" do
      ctx = call([beggar(), victim(coins: 500, jing: 0)], %{coin: "cash", target: "大侠"})

      debits = emitted(ctx, "beg/debit")
      credits = emitted(ctx, "beg/credit")

      assert length(debits) == 1
      assert length(credits) == 1

      {debit_to, %Event{data: debit_data}} = hd(debits)
      {credit_to, %Event{data: credit_data}} = hd(credits)

      # victim 被扣 100（500 的 1/5），beggar 拿到 100
      assert debit_to == :victim
      assert debit_data.amount == 100
      assert credit_to == self()
      assert credit_data.result == :success
      assert credit_data.amount == 100

      # vision：成功文案含「扔给」
      assert Enum.any?(rendered_texts(ctx), &(&1 =~ "扔给"))
    end
  end
end
