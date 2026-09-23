defmodule Kantele.Character.GiveCommandTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kantele.Character.GiveCommand
  alias Kantele.Character.GiveEvent
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items

  setup do
    Items.put("test:baozi", %Item{
      id: "test:baozi",
      name: "包子 Baozi",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %Kantele.World.Item.Meta{}
    })

    :ok
  end

  defp player(id \\ "player-1", name \\ "张三", inventory \\ []) do
    %Kalevala.Character{
      id: id,
      name: name,
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp instance(item_id \\ "test:baozi") do
    %Item.Instance{id: "inst-1", item_id: item_id, created_at: DateTime.utc_now()}
  end

  defp npc_with_accept(rules) do
    %Kalevala.Character{
      id: "test:xiaoer",
      name: "店小二",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %Kantele.Character.NonPlayerMeta{
        zone_id: "test",
        accept: rules,
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp money_instance(amount) do
    Items.put("money/coin", %Item{
      id: "money/coin",
      name: "铜钱 coin",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{"is_money" => true, "amount" => amount}
    })

    %Item.Instance{id: "coin-#{amount}", item_id: "money/coin", created_at: DateTime.utc_now()}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "路由解析" do
    test "give 物品 to 人" do
      {:ok, parsed} = Kantele.Character.Commands.parse("give 包子 to 张三")
      assert parsed.function == :run
      assert parsed.params["rest"] == "包子 to 张三"
    end

    test "give 人 物品" do
      {:ok, parsed} = Kantele.Character.Commands.parse("give 张三 包子")
      assert parsed.function == :run
    end

    test "中文别名 给" do
      {:ok, parsed} = Kantele.Character.Commands.parse("给 张三 包子")
      assert parsed.function == :run
    end
  end

  describe "命令发布 room/give" do
    test "物品在背包时发 room/give" do
      conn =
        GiveCommand.run(build_conn(player("player-1", "张三", [instance()])), %{"rest" => "张三 包子"})

      assert [%Event{topic: "room/give", data: data}] = conn.events
      assert data.target == "张三"
      assert data.item_instance.item_id == "test:baozi"
      assert data.from_id == "player-1"
    end

    test "物品不在背包时提示" do
      conn = GiveCommand.run(build_conn(player()), %{"rest" => "张三 长剑"})

      assert output_text(conn) =~ "没有这样东西"
    end

    test "已装备物品不能赠送" do
      equipped = %{weapon: %{name: "包子 Baozi", damage: 10}}

      char = %{
        player("player-1", "张三", [instance()])
        | meta: %{player().meta | combat: %{player().meta.combat | equipped: equipped}}
      }

      conn = GiveCommand.run(build_conn(char), %{"rest" => "张三 包子"})

      assert output_text(conn) =~ "取下装备"
    end

    test "空参数提示" do
      conn = GiveCommand.run(build_conn(player()), %{"rest" => ""})

      assert output_text(conn) =~ "给谁什么东西"
    end
  end

  describe "收受端 GiveEvent.receive" do
    test "收到物品入背包并回执" do
      conn =
        GiveEvent.receive(build_conn(player("player-2", "李四")), %Event{
          topic: "characters/give",
          data: %{
            item_instance: instance(),
            item_name: "包子 Baozi",
            from_name: "张三",
            from_id: "player-1",
            reply_to: self()
          }
        })

updated = conn.private.update_character || conn.character
      assert [%Item.Instance{item_id: "test:baozi"}] = updated.inventory
      assert output_text(conn) =~ "张三给你包子"

      assert_receive %Event{topic: "give/result", data: %{ok: true, instance_id: "inst-1"}}
    end
  end

  describe "收受端 GiveEvent.receive（accept_object 规则分发）" do
    setup do
      Items.put("test:yupai", %Item{
        id: "test:yupai",
        name: "玉牌 Yupai",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %Kantele.World.Item.Meta{}
      })

      :ok
    end

    test "收钱：达到下限接受" do
      _conn =
        GiveEvent.receive(
          build_conn(npc_with_accept([%{kind: "money", min: 1000, accept: true}])),
          %Event{
            topic: "characters/give",
            data: %{
              item_instance: money_instance(2000),
              item_name: "铜钱",
              from_name: "张三",
              from_id: "player-1",
              reply_to: self()
            }
          }
        )

      assert_receive %Event{topic: "give/result", data: %{ok: true}}
    end

    test "收钱：低于下限拒绝" do
      _conn =
        GiveEvent.receive(
          build_conn(npc_with_accept([%{kind: "money", min: 1000, accept: true}])),
          %Event{
            topic: "characters/give",
            data: %{
              item_instance: money_instance(50),
              item_name: "铜钱",
              from_name: "张三",
              from_id: "player-1",
              reply_to: self()
            }
          }
        )

      assert_receive %Event{topic: "give/result", data: %{ok: false}}
    end

    test "收指定物品 id" do
      _conn =
        GiveEvent.receive(
          build_conn(npc_with_accept([%{kind: "item_id", id: "test:yupai", accept: true}])),
          %Event{
            topic: "characters/give",
            data: %{
              item_instance: %Item.Instance{id: "inst-yu", item_id: "test:yupai", created_at: DateTime.utc_now()},
              item_name: "玉牌",
              from_name: "张三",
              from_id: "player-1",
              reply_to: self()
            }
          }
        )

      assert_receive %Event{topic: "give/result", data: %{ok: true}}
    end

    test "收指定名字物品" do
      _conn =
        GiveEvent.receive(
          build_conn(npc_with_accept([%{kind: "item_name", name: "玉牌", accept: true}])),
          %Event{
            topic: "characters/give",
            data: %{
              item_instance: %Item.Instance{id: "inst-yu", item_id: "test:yupai", created_at: DateTime.utc_now()},
              item_name: "玉牌",
              from_name: "张三",
              from_id: "player-1",
              reply_to: self()
            }
          }
        )

      assert_receive %Event{topic: "give/result", data: %{ok: true}}
    end

    test "无匹配规则且无 any：拒绝" do
      _conn =
        GiveEvent.receive(
          build_conn(npc_with_accept([%{kind: "item_id", id: "test:yupai", accept: true}])),
          %Event{
            topic: "characters/give",
            data: %{
              item_instance: instance(),
              item_name: "包子",
              from_name: "张三",
              from_id: "player-1",
              reply_to: self()
            }
          }
        )

      assert_receive %Event{topic: "give/result", data: %{ok: false}}
    end

    test "any 规则接受多余物品" do
      _conn =
        GiveEvent.receive(
          build_conn(npc_with_accept([%{kind: "item_id", id: "test:yupai", accept: true}, %{kind: "any", accept: true}])),
          %Event{
            topic: "characters/give",
            data: %{
              item_instance: instance(),
              item_name: "包子",
              from_name: "张三",
              from_id: "player-1",
              reply_to: self()
            }
          }
        )

      assert_receive %Event{topic: "give/result", data: %{ok: true}}
    end

    test "any 拒绝规则：一律不收" do
      _conn =
        GiveEvent.receive(
          build_conn(npc_with_accept([%{kind: "any", accept: false}])),
          %Event{
            topic: "characters/give",
            data: %{
              item_instance: instance(),
              item_name: "包子",
              from_name: "张三",
              from_id: "player-1",
              reply_to: self()
            }
          }
        )

      assert_receive %Event{topic: "give/result", data: %{ok: false}}
    end
  end

  describe "赠与端 GiveEvent.result" do
    test "确认后从背包移除物品" do
      char = player("player-1", "张三", [instance()])

      conn =
        GiveEvent.result(build_conn(char), %Event{
          topic: "give/result",
          data: %{ok: true, instance_id: "inst-1", from_id: "player-1"}
        })

      updated = conn.private.update_character || conn.character
      assert updated.inventory == []
      assert output_text(conn) =~ "交给了对方"
    end

    test "不是自己的回执不处理" do
      char = player("player-1", "张三", [instance()])

      conn =
        GiveEvent.result(build_conn(char), %Event{
          topic: "give/result",
          data: %{ok: true, instance_id: "inst-1", from_id: "someone-else"}
        })

      assert conn.private.update_character == nil
    end
  end
end
