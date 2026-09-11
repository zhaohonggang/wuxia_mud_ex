defmodule Kantele.Character.PlayerMiscCommandsTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.World.Item
  alias Kantele.Character.Combat
  alias Kantele.Character.FeedCommand
  alias Kantele.Character.FemoteCommand
  alias Kantele.Character.HideCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.RidetoCommand
  alias Kantele.Character.SetCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.SummonCommand
  alias Kantele.Character.TouxiCommand
  alias Kantele.Character.UnsetCommand
  alias Kantele.Character.Vitals
  alias Kantele.Character.WizlistCommand
  alias Kantele.World.Items

  defp player(attrs \\ %{}) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "start:room",
      attributes: Map.get(attrs, :attributes, %{}),
      inventory: Map.get(attrs, :inventory, []),
      meta: %PlayerMeta{
        vitals: Map.get(attrs, :vitals, Vitals.new()),
        stats: Stats.new(),
        combat: Map.get(attrs, :combat, Combat.new()),
        riding: Map.get(attrs, :riding),
        env: Map.get(attrs, :env, %{})
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated(conn), do: conn.private.update_character || conn.character

  defp event_topics(conn) do
    Enum.map(conn.events, fn event -> {:topic, event.topic, :data, event.data} end)
  end

  setup do
    Items.put("pmisctest:sword", %Item{id: "pmisctest:sword", name: "青云剑"})
    :ok
  end

  describe "set/unset 环境变量" do
    test "set 设定变量并保存到 update_character" do
      conn = SetCommand.run(build_conn(player()), %{"rest" => "time = busy"})

      assert output_text(conn) =~ "time 设定为 busy"
      assert updated(conn).meta.env["time"] == "busy"
    end

    test "set 空格分隔形式" do
      conn = SetCommand.run(build_conn(player()), %{"rest" => "brief room"})

      assert updated(conn).meta.env["brief"] == "room"
    end

    test "set 查询未设定变量" do
      conn = SetCommand.run(build_conn(player()), %{"rest" => "time"})

      assert output_text(conn) =~ "time 并没有设定"
    end

    test "set 查询已设定变量" do
      conn = SetCommand.run(build_conn(player(%{env: %{"time" => "busy"}})), %{"rest" => "time"})

      assert output_text(conn) =~ "time = busy"
    end

    test "set 无参数列出（未设定时提示）" do
      conn = SetCommand.run(build_conn(player()), %{})

      assert output_text(conn) =~ "你目前没有设定任何环境变数"
    end

    test "unset 删除变量" do
      conn = UnsetCommand.run(build_conn(player(%{env: %{"time" => "busy"}})), %{"key" => "time"})

      assert output_text(conn) =~ "Ok."
      assert updated(conn).meta.env == %{}
    end

    test "unset 无参数给出帮助" do
      conn = UnsetCommand.run(build_conn(player()), %{})

      assert output_text(conn) =~ "unset <变数>"
    end

    test "unset 空 key 给出帮助" do
      conn = UnsetCommand.run(build_conn(player()), %{"key" => "  "})

      assert output_text(conn) =~ "unset <变数>"
    end
  end

  describe "hide 遁物" do
    test "无参数" do
      conn = HideCommand.run(build_conn(player()), %{})

      assert output_text(conn) =~ "你要隐藏什么物品"
    end

    test "幽灵状态" do
      conn = HideCommand.run(build_conn(player(%{attributes: %{"ghost" => true}})), %{
        "item" => "青云剑"
      })

      assert output_text(conn) =~ "等你还了阳再说吧"
    end

    test "未登记 can_summon" do
      conn = HideCommand.run(build_conn(player()), %{"item" => "青云剑"})

      assert output_text(conn) =~ "你不知道如何隐藏这个物品"
    end

    test "精力不足" do
      attrs =
        player(%{
          attributes: %{"can_summon" => %{"青云剑" => "pmisctest:sword"}},
          vitals: %{Vitals.new() | jing: 50}
        })

      conn = HideCommand.run(build_conn(attrs), %{"item" => "青云剑"})

      assert output_text(conn) =~ "精力不济"
    end

    test "身上没有这样东西" do
      attrs = player(%{attributes: %{"can_summon" => %{"青云剑" => "pmisctest:sword"}}})
      conn = HideCommand.run(build_conn(attrs), %{"item" => "青云剑"})

      assert output_text(conn) =~ "你身上没有这样东西"
    end

    test "成功：扣减精力并派发 item/hide 事件" do
      instance = %Item.Instance{id: "inst-1", item_id: "pmisctest:sword"}

      attrs =
        player(%{
          attributes: %{"can_summon" => %{"青云剑" => "pmisctest:sword"}},
          inventory: [instance]
        })

      conn = HideCommand.run(build_conn(attrs), %{"item" => "青云剑"})

      assert Enum.any?(conn.events, fn
        %Kalevala.Event{topic: "item/hide", data: %{item_instance: ^instance}} -> true
        _ -> false
      end)

      assert updated(conn).meta.vitals.jing == 20
    end
  end

  describe "summon 召唤" do
    test "未登记 can_summon" do
      conn = SummonCommand.run(build_conn(player()), %{"item" => "青云剑"})

      assert output_text(conn) =~ "你不知道如何召唤这个物品"
    end

    test "精力不济" do
      attrs = player(%{attributes: %{"can_summon" => %{"青云剑" => "pmisctest:sword"}}})
      conn = SummonCommand.run(build_conn(attrs), %{"item" => "青云剑"})

      assert output_text(conn) =~ "精力不济"
    end

    test "成功：扣减精力并输出召唤信息" do
      attrs =
        player(%{
          attributes: %{"can_summon" => %{"青云剑" => "pmisctest:sword"}},
          vitals: %{Vitals.new() | jingli: 300}
        })

      conn = SummonCommand.run(build_conn(attrs), %{"item" => "青云剑"})

      assert output_text(conn) =~ "破空而来"
      assert updated(conn).meta.vitals.jingli == 100
    end

    test "无参数列出可召唤物品" do
      conn = SummonCommand.run(build_conn(player()), %{})

      assert output_text(conn) =~ "你现在可以召唤的物品有"
    end
  end

  describe "rideto 骑马传送" do
    test "无参数列出地点" do
      conn = RidetoCommand.run(build_conn(player()), %{})

      assert output_text(conn) =~ "利用坐骑到达某个地点"
    end

    test "负荷过重" do
      conn = RidetoCommand.run(build_conn(player(%{attributes: %{"carry_weight" => 101}})), %{
        "place" => "shaolin"
      })

      assert output_text(conn) =~ "你的负荷过重"
    end

    test "忙碌" do
      mobile = player(%{combat: %{Combat.new() | busy: 2}})
      conn = RidetoCommand.run(build_conn(mobile), %{"place" => "shaolin"})

      assert output_text(conn) =~ "动作还没有完成"
    end

    test "战斗中" do
      mobile = player(%{combat: %{Combat.new() | enemies: [%{id: "enemy-1"}]}})
      conn = RidetoCommand.run(build_conn(mobile), %{"place" => "shaolin"})

      assert output_text(conn) =~ "正在战斗"
    end

    test "幽灵状态" do
      conn = RidetoCommand.run(build_conn(player(%{attributes: %{"ghost" => true}})), %{
        "place" => "shaolin"
      })

      assert output_text(conn) =~ "等你还了阳再说吧"
    end

    test "没有坐骑" do
      conn = RidetoCommand.run(build_conn(player()), %{"place" => "shaolin"})

      assert output_text(conn) =~ "你还没有坐骑"
    end

    test "未知地点" do
      mobile = player(%{riding: %{instance_id: "m-1", item_id: "test:horse", name: "马"}})
      conn = RidetoCommand.run(build_conn(mobile), %{"place" => "nowhere"})

      assert output_text(conn) =~ "这个地方无法乘坐骑去"
    end

    test "成功传送到目标房间" do
      mobile = player(%{riding: %{instance_id: "m-1", item_id: "test:horse", name: "马"}})
      conn = RidetoCommand.run(build_conn(mobile), %{"place" => "shaolin"})

      assert updated(conn).room_id == "shaolin:shanmen"
    end
  end

  describe "touxi 偷袭" do
    test "无参数" do
      conn = TouxiCommand.run(build_conn(player()), %{})

      assert output_text(conn) =~ "你想偷袭谁"
    end

    test "空名字" do
      conn = TouxiCommand.run(build_conn(player()), %{"name" => ""})

      assert output_text(conn) =~ "你想偷袭谁"
    end

    test "幽灵状态" do
      conn = TouxiCommand.run(build_conn(player(%{attributes: %{"ghost" => true}})), %{
        "name" => "阿飞"
      })

      assert output_text(conn) =~ "你这个样子有什么好偷袭的"
    end

    test "忙碌" do
      mobile = player(%{combat: %{Combat.new() | busy: 2}})
      conn = TouxiCommand.run(build_conn(mobile), %{"name" => "阿飞"})

      assert output_text(conn) =~ "不能偷袭"
    end

    test "战斗中" do
      mobile = player(%{combat: %{Combat.new() | enemies: [%{id: "enemy-1"}]}})
      conn = TouxiCommand.run(build_conn(mobile), %{"name" => "阿飞"})

      assert output_text(conn) =~ "还想偷袭"
    end

    test "成功派发 combat/touxi 事件" do
      conn = TouxiCommand.run(build_conn(player()), %{"name" => "阿飞"})

      assert {:topic, "combat/touxi", :data, %{name: "阿飞"}} in event_topics(conn)
    end
  end

  describe "feed 喂养" do
    test "无参数" do
      conn = FeedCommand.run(build_conn(player()), %{})

      assert output_text(conn) =~ "你要喂养谁"
    end

    test "幽灵状态" do
      conn = FeedCommand.run(build_conn(player(%{attributes: %{"ghost" => true}})), %{
        "name" => "小狗"
      })

      assert output_text(conn) =~ "先照顾好自己"
    end

    test "成功派发 room/feed 事件" do
      conn = FeedCommand.run(build_conn(player()), %{"name" => "小狗"})

      assert {:topic, "room/feed", :data, %{name: "小狗"}} in event_topics(conn)
    end
  end

  describe "femote 表情查询" do
    test "无参数给出帮助" do
      conn = FemoteCommand.run(build_conn(player()), %{})

      assert output_text(conn) =~ "指令格式"
    end

    test "命中关键字" do
      conn = FemoteCommand.run(build_conn(player()), %{"keyword" => "微微"})

      assert output_text(conn) =~ "微微一笑"
      assert output_text(conn) =~ "共有 1 个"
    end

    test "未命中关键字" do
      conn = FemoteCommand.run(build_conn(player()), %{"keyword" => "完全不存在的词"})

      assert output_text(conn) =~ "没有找到"
    end
  end

  describe "路由解析" do
    test "set 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("set")
      assert parsed.module == SetCommand

      {:ok, parsed} = Kantele.Character.Commands.parse("set time=busy")
      assert parsed.module == SetCommand
      assert parsed.params["rest"] == "time=busy"
    end

    test "unset 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("unset time")
      assert parsed.module == UnsetCommand
      assert parsed.params["key"] == "time"
    end

    test "hide 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("hide 青云剑")
      assert parsed.module == HideCommand
      assert parsed.params["item"] == "青云剑"
    end

    test "summon 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("summon 青云剑")
      assert parsed.module == SummonCommand
      assert parsed.params["item"] == "青云剑"
    end

    test "rideto 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("rideto shaolin")
      assert parsed.module == RidetoCommand
      assert parsed.params["place"] == "shaolin"
    end

    test "touxi 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("touxi 阿飞")
      assert parsed.module == TouxiCommand
      assert parsed.params["name"] == "阿飞"
    end

    test "feed 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("feed 小狗")
      assert parsed.module == FeedCommand
      assert parsed.params["name"] == "小狗"
    end

    test "femote 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("femote 微微一笑")
      assert parsed.module == FemoteCommand
      assert parsed.params["keyword"] == "微微一笑"
    end

    test "wizlist 解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("wizlist")
      assert parsed.module == WizlistCommand
    end
  end
end