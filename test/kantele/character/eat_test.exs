defmodule Kantele.Character.EatTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kalevala.World.Item
  alias Kantele.Character.EatCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  @eat_verb %Kalevala.Verb{
    key: :eat,
    icon: "eat",
    text: "吃",
    send: "eat ${id}",
    conditions: %Kalevala.Verb.Conditions{location: ["inventory/self"]}
  }

  @wield_verb %Kalevala.Verb{
    key: :wield,
    icon: "sword",
    text: "装备",
    send: "wield ${id}",
    conditions: %Kalevala.Verb.Conditions{location: ["inventory/self"]}
  }

  # 应用在测试环境已启动（kickoff 关闭），Items 缓存进程可用，直接播种测试物品
  setup do
    Items.put("liuxi:baozi", %Item{
      id: "liuxi:baozi",
      name: "包子 Baozi",
      verbs: [@eat_verb],
      callback_module: Kantele.World.Item,
      meta: %Meta{food: 20}
    })

    Items.put("liuxi:dan", %Item{
      id: "liuxi:dan",
      name: "培元丹 Peiyuan Dan",
      verbs: [@eat_verb],
      callback_module: Kantele.World.Item,
      meta: %Meta{medicine: %{qi: 50, stats: %{str: 1}}}
    })

    Items.put("liuxi:sword", %Item{
      id: "liuxi:sword",
      name: "长剑 Changjian",
      verbs: [@wield_verb],
      callback_module: Kantele.World.Item,
      meta: %Meta{damage: 22}
    })

    :ok
  end

  defp character(inventory_ids, opts \\ []) do
    inventory =
      Enum.map(inventory_ids, fn item_id ->
        %Kalevala.World.Item.Instance{
          id: "instance-#{item_id}",
          item_id: item_id,
          created_at: DateTime.utc_now()
        }
      end)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: inventory,
      meta: %PlayerMeta{
        vitals: struct(Vitals.new(), Keyword.get(opts, :vitals, [])),
        stats: struct(Stats.new(), Keyword.get(opts, :stats, [])),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp run(conn, name), do: EatCommand.run(conn, %{"item_name" => name})

  defp current_character(conn), do: conn.private.update_character || conn.character

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  test "吃食物：文案提示且消耗实例" do
    conn = run(build_conn(character(["liuxi:baozi"])), "包子")

    assert output_text(conn) =~ "吃下"
    assert current_character(conn).inventory == []
  end

  test "吃丹药：气血回复 + 臂力永久+1" do
    character = character(["liuxi:dan"], vitals: [qi: 100], stats: [str: 20])

    conn = run(build_conn(character), "培元丹")

    updated = current_character(conn)
    assert output_text(conn) =~ "臂力+1"
    assert updated.meta.vitals.qi == 150
    assert updated.meta.stats.str == 21
    assert updated.inventory == []
  end

  test "回复钳到上限" do
    character = character(["liuxi:dan"], vitals: [qi: 149])

    conn = run(build_conn(character), "培元丹")

    assert current_character(conn).meta.vitals.qi == 150
  end

  test "四维到软上限后拒绝消耗（重复吃到上限被拒）" do
    character = character(["liuxi:dan"], stats: [str: 30])

    conn = run(build_conn(character), "培元丹")

    assert output_text(conn) =~ "再难精进"
    assert current_character(conn).inventory != []
    assert current_character(conn).meta.stats.str == 30
  end

  test "不可食用的物品被拒" do
    conn = run(build_conn(character(["liuxi:sword"])), "长剑")

    assert output_text(conn) =~ "不能这么往嘴里塞"
  end

  test "没有该物品提示" do
    conn = run(build_conn(character([])), "包子")

    assert output_text(conn) =~ "没有这样东西"
  end

  @tag :skip_persistence
  test "save 落盘失败不影响游戏进程" do
    # Records.save 在沙盒外自行 rescue，此处仅保证调用路径不抛
    conn = run(build_conn(character(["liuxi:baozi"])), "包子")
    assert Records.save(current_character(conn)) in [:ok, :error]
  end
end