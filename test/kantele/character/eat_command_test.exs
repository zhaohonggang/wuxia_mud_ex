defmodule Kantele.Character.EatCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Verb
  alias Kantele.Character.EatCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items
  alias Kalevala.World.Item

  @food_id "test:baozi"
  @inedible_id "test:rock"
  @pill_id "test:yangjingdan"
  @pill_self_id "test:heiyugao"

  setup_all do
    Items.put(@food_id, %Item{
      id: @food_id,
      name: "肉包子",
      verbs: [%Verb{key: :eat, conditions: %Verb.Conditions{location: ["inventory/self"]}}],
      callback_module: Kantele.World.Item,
      meta: %{food: 50}
    })

    Items.put(@inedible_id, %Item{
      id: @inedible_id,
      name: "石头",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    # P5-5 丹药：带 heal + cooldown + full-check + busy + vision
    Items.put(@pill_id, %Item{
      id: @pill_id,
      name: "养精丹",
      verbs: [%Verb{key: :eat, conditions: %Verb.Conditions{location: ["inventory/self"]}}],
      callback_module: Kantele.World.Item,
      meta: %{
        medicine: %{jing: 100},
        effect: %{
          kind: "pill",
          cooldown: 5,
          cooldown_key: "last_eat/dan(A)",
          cooldown_text: "药力尚未化开，暂不能再服。",
          full_vital: "jing",
          full_text: "你现在精神状态很好，无需服用养精丹。",
          vision_text: "{npc}吃下一粒养精丹，感到灵台处一片清净。",
          busy: 1,
          stack: true
        }
      }
    })

    # P5-5 自述型丹药（LPC tell_object）：只有本人看到，无房间广播
    Items.put(@pill_self_id, %Item{
      id: @pill_self_id,
      name: "黑玉断续膏",
      verbs: [%Verb{key: :eat, conditions: %Verb.Conditions{location: ["inventory/self"]}}],
      callback_module: Kantele.World.Item,
      meta: %{
        medicine: %{jing: 1000, qi: 2000},
        effect: %{
          kind: "pill",
          self_text: "你只觉一股热流在七经八脉中循环了一个周天，立刻神采奕奕了！"
        }
      }
    })

    :ok
  end

  defp player() do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_food(qi \\ 4900) do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: qi,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    food_instance = %Kalevala.World.Item.Instance{
      id: "包子",
      item_id: @food_id,
      created_at: DateTime.utc_now()
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [food_instance],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_capped_stats do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 30,
      dex: 30,
      con: 30,
      int: 30,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    med_instance = %Kalevala.World.Item.Instance{
      id: "test:medicine",
      item_id: "test:medicine",
      created_at: DateTime.utc_now()
    }

    Items.put("test:medicine", %Item{
      id: "test:medicine",
      name: "大还丹",
      verbs: [%Verb{key: :eat, conditions: %Verb.Conditions{location: ["inventory/self"]}}],
      callback_module: Kantele.World.Item,
      meta: %{medicine: %{str: 1, dex: 1, con: 1, int: 1}}
    })

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [med_instance],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_inedible do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    rock_instance = %Kalevala.World.Item.Instance{
      id: @inedible_id,
      item_id: @inedible_id,
      created_at: DateTime.utc_now()
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [rock_instance],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_pill(jing \\ 100, count \\ 1) do
    vitals = %Vitals{
      jing: jing,
      max_jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      qi: 1000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    instances =
      Enum.map(1..count, fn i ->
        %Kalevala.World.Item.Instance{
          id: "pill-#{i}",
          item_id: @pill_id,
          created_at: DateTime.utc_now()
        }
      end)

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: instances,
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_with_self_pill do
    vitals = %Vitals{
      jing: 100,
      max_jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      qi: 1000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    inst = %Kalevala.World.Item.Instance{
      id: "self-pill",
      item_id: @pill_self_id,
      created_at: DateTime.utc_now()
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [inst],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
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

  describe "eat 命令" do
    test "身上没有食物报错" do
      p = player()
      conn = EatCommand.run(build_conn(p), %{"item_name" => "包子"})
      text = output_text(conn)

      assert text =~ "你身上没有这样东西"
    end

    test "eat 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("eat 包子")
      assert parsed.module == EatCommand
    end

    test "吃 别名路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("吃 包子")
      assert parsed.module == EatCommand
    end

    test "吃食物成功，饱食度恢复" do
      p = player_with_food(4900)
      conn = EatCommand.run(build_conn(p), %{"item_name" => "包子"})
      text = output_text(conn)

      assert text =~ "吃下"
      assert text =~ "肉包子"
      assert text =~ "气血"
      updated = conn.private.update_character || conn.character
      assert updated.inventory == []
    end

    test "不可食用的物品报错" do
      p = player_with_inedible()
      conn = EatCommand.run(build_conn(p), %{"item_name" => "石头"})
      text = output_text(conn)

      assert text =~ "可不能这么往嘴里塞"
    end
  end

  describe "eat 丹药 (pill / do_effect 数据驱动路径)" do
    test "服用后回精、消耗实例、盖章冷却、本人看到 {npc}→你" do
      p = player_with_pill(100)
      conn = EatCommand.run(build_conn(p), %{"item_name" => "养精丹"})
      text = output_text(conn)

      assert text =~ "你吃下一粒养精丹"
      updated = conn.private.update_character || conn.character
      assert updated.inventory == []
      assert updated.meta.vitals.jing == 200
      # 冷却时间戳已写入
      assert is_integer(Map.get(updated.meta.pill_cooldowns, "last_eat/dan(A)"))
    end

    test "满状态拒绝服用，实例保留" do
      p = player_with_pill(2000)
      conn = EatCommand.run(build_conn(p), %{"item_name" => "养精丹"})
      text = output_text(conn)

      assert text =~ "精神状态很好"
      updated = conn.private.update_character || conn.character
      assert length(updated.inventory) == 1
      assert updated.meta.vitals.jing == 2000
    end

    test "冷却中第二次服用被拒" do
      p1 = player_with_pill(100)
      conn1 = EatCommand.run(build_conn(p1), %{"item_name" => "养精丹"})
      updated = conn1.private.update_character || conn1.character

      p2 = %{updated | inventory: [%Kalevala.World.Item.Instance{id: "pill-2", item_id: @pill_id, created_at: DateTime.utc_now()}]}
      conn2 = EatCommand.run(build_conn(p2), %{"item_name" => "养精丹"})
      text2 = output_text(conn2)

      assert text2 =~ "药力尚未化开"
      updated2 = conn2.private.update_character || conn2.character
      assert length(updated2.inventory) == 1
    end

    test "tell_object 自述型丹药只给本人看到，无房间广播占位" do
      p = player_with_self_pill()
      conn = EatCommand.run(build_conn(p), %{"item_name" => "黑玉断续膏"})
      text = output_text(conn)

      assert text =~ "你只觉一股热流在七经八脉中循环了一个周天"
      assert text =~ "立刻神采奕奕"
      # 不应出现 {npc} 占位符泄漏
      refute text =~ "{npc}"
      updated = conn.private.update_character || conn.character
      assert updated.inventory == []
      assert updated.meta.vitals.jing == 1100
    end
  end
end
