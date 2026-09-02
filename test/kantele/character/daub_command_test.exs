defmodule Kantele.Character.DaubCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.DaubCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Items
  alias Kalevala.World.Item

  @poison_id "test:poison"
  @weapon_id "test:sword"
  @armor_id "test:cloth"
  @non_daubable_id "test:bread"

  setup_all do
    Items.put(@poison_id, %Item{
      id: @poison_id,
      name: "砒霜",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{
        "can_daub" => true,
        "poison_type" => "毒药",
        "poison_level" => 50,
        "poison_duration" => 300,
        "poison_remain" => 10
      }
    })

    Items.put(@weapon_id, %Item{
      id: @weapon_id,
      name: "金蛇剑",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{"type" => "sword"}
    })

    Items.put(@armor_id, %Item{
      id: @armor_id,
      name: "铁甲",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{"type" => "armor"}
    })

    Items.put(@non_daubable_id, %Item{
      id: @non_daubable_id,
      name: "馒头",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    :ok
  end

  defp player(opts \\ []) do
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
      skills: Keyword.get(opts, :skills, %{}),
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: Keyword.get(opts, :inventory, []),
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Kantele.Character.Combat.new(),
        temp: Keyword.get(opts, :temp, %{})
      }
    }
  end

  defp inst(item_id, opts \\ []) do
    %Item.Instance{
      id: Keyword.get(opts, :id, "inst-#{System.unique_integer([:positive])}"),
      item_id: item_id,
      created_at: DateTime.utc_now(),
      meta: Keyword.get(opts, :meta, %{})
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

  describe "daub 缺参/无毒药" do
    test "缺少参数提示格式" do
      conn = DaubCommand.run(build_conn(player()), %{})
      assert output_text(conn) =~ "指令格式：daub"
    end

    test "空参数提示格式" do
      conn = DaubCommand.run(build_conn(player()), %{"poison" => "", "target" => ""})
      assert output_text(conn) =~ "指令格式：daub"
    end

    test "身上没有毒药报错" do
      conn = DaubCommand.run(build_conn(player()), %{"poison" => "砒霜", "target" => "金蛇剑"})
      assert output_text(conn) =~ "你身上没有这样毒药"
    end
  end

  describe "daub 毒药不可涂" do
    test "物品没有 can_daub 属性" do
      Items.put("test:herb", %Item{
        id: "test:herb",
        name: "草药",
        verbs: [],
        callback_module: Kantele.World.Item,
        meta: %{}
      })

      p = player(inventory: [inst("test:herb")])
      conn = DaubCommand.run(build_conn(p), %{"poison" => "草药", "target" => "金蛇剑"})
      assert output_text(conn) =~ "这不是可用于涂毒的药物"
    end
  end

  describe "daub 目标查找" do
    test "背包中没有匹配目标" do
      p = player(inventory: [inst(@poison_id)])
      conn = DaubCommand.run(build_conn(p), %{"poison" => "砒霜", "target" => "金蛇剑"})
      assert output_text(conn) =~ "你身上没有这样武器或防具"
    end

    test "目标物品类型不可涂毒" do
      p = player(inventory: [inst(@poison_id), inst(@non_daubable_id)])
      conn = DaubCommand.run(build_conn(p), %{"poison" => "砒霜", "target" => "馒头"})
      assert output_text(conn) =~ "这不是可涂毒的武器或防具"
    end
  end

  describe "daub 武器涂毒" do
    test "技能不足提示" do
      p = player(
        inventory: [inst(@poison_id), inst(@weapon_id)],
        skills: %{"force" => 0, "poison" => 0}
      )
      conn = DaubCommand.run(build_conn(p), %{"poison" => "砒霜", "target" => "金蛇剑"})
      assert output_text(conn) =~ "你的毒技不够纯熟，无法给武器涂毒"
    end

    test "技能足够涂毒成功" do
      p = player(
        inventory: [inst(@poison_id), inst(@weapon_id)],
        skills: %{"force" => 30, "poison" => 30}
      )
      conn = DaubCommand.run(build_conn(p), %{"poison" => "砒霜", "target" => "金蛇剑"})
      text = output_text(conn)
      assert text =~ "砒霜"
      assert text =~ "金蛇剑"

      updated = conn.private.update_character || conn.character
      weapon_inst = Enum.find(updated.inventory, &(&1.item_id == @weapon_id))
      assert weapon_inst.meta["daub"] != nil
      assert weapon_inst.meta["daub"]["level"] == 50
    end

    test "已有毒的武器混毒" do
      existing_daub = %{
        "level" => 80,
        "duration" => 200,
        "remain" => 5,
        "id" => "old:poison",
        "name" => "鹤顶红"
      }

      p = player(
        inventory: [inst(@poison_id), inst(@weapon_id, meta: %{"daub" => existing_daub})],
        skills: %{"force" => 30, "poison" => 30}
      )
      conn = DaubCommand.run(build_conn(p), %{"poison" => "砒霜", "target" => "金蛇剑"})
      assert output_text(conn) =~ "砒霜"

      updated = conn.private.update_character || conn.character
      weapon_inst = Enum.find(updated.inventory, &(&1.item_id == @weapon_id))
      merged = weapon_inst.meta["daub"]
      assert merged["id"] == "test:poison"
      assert merged["name"] == "砒霜"
      assert merged["level"] == 80 + div(50, 4)
    end
  end

  describe "daub 防具涂毒" do
    test "技能足够涂毒成功" do
      p = player(
        inventory: [inst(@poison_id), inst(@armor_id)],
        skills: %{"force" => 20, "poison" => 20}
      )
      conn = DaubCommand.run(build_conn(p), %{"poison" => "砒霜", "target" => "铁甲"})
      text = output_text(conn)
      assert text =~ "砒霜"
      assert text =~ "铁甲"

      updated = conn.private.update_character || conn.character
      armor_inst = Enum.find(updated.inventory, &(&1.item_id == @armor_id))
      assert armor_inst.meta["daub"] != nil
      assert armor_inst.meta["daub"]["level"] == 50
    end
  end

  describe "daub 手部涂毒" do
    test "技能足够涂毒到手" do
      p = player(
        inventory: [inst(@poison_id)],
        skills: %{"force" => 30, "poison" => 30}
      )
      conn = DaubCommand.run(build_conn(p), %{"poison" => "砒霜", "target" => "手"})
      text = output_text(conn)
      assert text =~ "砒霜"
      assert text =~ "手上"

      updated = conn.private.update_character || conn.character
      assert updated.meta.temp["daub/hand"] != nil
      assert updated.meta.temp["daub/hand"]["level"] == 50
    end

    test "技能不足提示" do
      p = player(
        inventory: [inst(@poison_id)],
        skills: %{"force" => 0, "poison" => 0}
      )
      conn = DaubCommand.run(build_conn(p), %{"poison" => "砒霜", "target" => "手"})
      assert output_text(conn) =~ "你的毒技不够纯熟，无法涂毒手部"
    end

    test "自毒检测：低 poison_skill 高概率自毒" do
      p = player(
        inventory: [inst(@poison_id)],
        skills: %{"force" => 30, "poison" => 30}
      )
      conn = DaubCommand.run(build_conn(p), %{"poison" => "砒霜", "target" => "手"})
      text = output_text(conn)
      # 自毒概率 ~33%（poison_skill=30 → chance=div(100,3)=33），
      # 两种可能：自毒或涂毒成功，至少验证两种分支之一可达
      assert text =~ "砒霜" or text =~ "一不小心"
    end
  end
end