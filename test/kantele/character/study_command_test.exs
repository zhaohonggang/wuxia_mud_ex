defmodule Kantele.Character.StudyCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.{PlayerMeta, Stats, StudyCommand, Vitals}
  alias Kantele.World.Items
  alias Kalevala.World.Item
  alias Kantele.World.Item.Meta.Book

  @book_id "test:book-liuxin-jian"

  setup_all do
    Items.put(@book_id, %Kalevala.World.Item{
      id: @book_id,
      name: "柳心剑法",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    Items.put("test:paper", %Kalevala.World.Item{
      id: "test:paper",
      name: "纸",
      verbs: [],
      callback_module: Kantele.World.Item,
      meta: %{}
    })

    :ok
  end

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
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
      int: Keyword.get(opts, :int, 20),
      combat_exp: Keyword.get(opts, :combat_exp, 5000),
      potential: Keyword.get(opts, :potential, 100),
      learned_points: Keyword.get(opts, :learned_points, 0),
      skills: Keyword.get(opts, :skills, %{"unarmed" => 60, "sword" => 60, "dodge" => 60, "parry" => 60, "force" => 20, "literate" => 10}),
      mapped: %{},
      performs: MapSet.new(),
      score: 0,
      weiwang: 0,
      gongxian: 0,
      shen: 0
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
        combat: Keyword.get(opts, :combat, Kantele.Character.Combat.new()),
        temp: %{}
      }
    }
  end

  defp book_instance(book_id, book_meta, opts \\ []) do
    %Kalevala.World.Item.Instance{
      id: Keyword.get(opts, :id, "book-inst"),
      item_id: book_id,
      created_at: DateTime.utc_now(),
      meta: %{book: book_meta}
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

  describe "study 前置条件" do
    test "战斗中拒绝研读" do
      combat = %{Kantele.Character.Combat.new() | enemies: [%{id: "npc-1", pid: self()}]}
      p = player(combat: combat)
      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法"})
      assert output_text(conn) =~ "战斗"
    end

    test "busy 状态下拒绝" do
      combat = %{Kantele.Character.Combat.new() | busy: 1}
      p = player(combat: combat)
      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法"})
      assert output_text(conn) =~ "正忙着"
    end

    test "无参数提示格式" do
      p = player()
      conn = StudyCommand.run(build_conn(p), %{"parse" => ""})
      assert output_text(conn) =~ "格式"
    end
  end

  describe "study 读书条件" do
    test "身上没有这本书" do
      p = player()
      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法"})
      assert output_text(conn) =~ "没有"
    end

    test "物品没有书籍 meta" do
      not_book = %Kalevala.World.Item.Instance{
        id: "inst-not-book",
        item_id: "test:paper",
        created_at: DateTime.utc_now(),
        meta: %{}
      }

      p = player(inventory: [not_book])
      conn = StudyCommand.run(build_conn(p), %{"parse" => "纸"})
      assert output_text(conn) =~ "无法从这样东西学到"
    end

    test "读书次数超限" do
      book_meta = %Book{skill: "liuxin-jian", min_skill: 0, max_skill: 100, exp_required: 0, jing_cost: 5, difficulty: 10}
      p = player(inventory: [book_instance(@book_id, book_meta)])
      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法 x200"})
      assert output_text(conn) =~ "最多"
    end
  end

  describe "study 文盲检查" do
    test "无 literate 技能" do
      book_meta = %Book{skill: "liuxin-jian", min_skill: 0, max_skill: 100, exp_required: 0, jing_cost: 5, difficulty: 10}
      p = player(inventory: [book_instance(@book_id, book_meta)], skills: %{"force" => 20})
      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法"})
      assert output_text(conn) =~ "文盲"
    end
  end

  describe "study 技能等级检查" do
    test "实战经验不足" do
      book_meta = %Book{skill: "liuxin-jian", min_skill: 0, max_skill: 100, exp_required: 5000, jing_cost: 5, difficulty: 10}
      p = player(inventory: [book_instance(@book_id, book_meta)], combat_exp: 100)
      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法"})
      assert output_text(conn) =~ "实战经验不足"
    end

    test "技能已超过书籍上限" do
      book_meta = %Book{skill: "liuxin-jian", min_skill: 0, max_skill: 80, exp_required: 0, jing_cost: 5, difficulty: 10}
      p = player(inventory: [book_instance(@book_id, book_meta)], skills: %{"literate" => 10, "liuxin-jian" => 90})
      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法"})
      assert output_text(conn) =~ "太浅"
    end

    test "技能低于书籍下限" do
      book_meta = %Book{skill: "liuxin-jian", min_skill: 30, max_skill: 100, exp_required: 0, jing_cost: 5, difficulty: 10}
      p = player(inventory: [book_instance(@book_id, book_meta)], skills: %{"literate" => 10, "liuxin-jian" => 10})
      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法"})
      assert output_text(conn) =~ "理解还太浅"
    end
  end

  describe "study 研读成功" do
    test "成功研读并提升技能" do
      book_meta = %Book{skill: "liuxin-jian", min_skill: 0, max_skill: 100, exp_required: 0, jing_cost: 50, difficulty: 10}
      p = player(
        inventory: [book_instance(@book_id, book_meta)],
        skills: %{"literate" => 10, "liuxin-jian" => 0, "force" => 20},
        jing: 2000,
        potential: 50
      )

      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法"})
      text = output_text(conn)
      assert text =~ "研读"
      assert text =~ "柳心剑法"

      updated = conn.private.update_character || conn.character
      skill_level = updated.meta.stats.skills["liuxin-jian"] || 0
      assert skill_level >= 1
    end

    test "精气不足时中途停止" do
      # jing_cost=5000 → jing_cost_effective = max((5000*20+10-20)/20,10) = 4999 > jing(3000) → 0 iterations
      book_meta = %Book{skill: "liuxin-jian", min_skill: 0, max_skill: 100, exp_required: 0, jing_cost: 5000, difficulty: 10}
      p = player(
        inventory: [book_instance(@book_id, book_meta)],
        skills: %{"literate" => 10, "liuxin-jian" => 0, "force" => 20},
        jing: 3000,
        potential: 100
      )

      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法 x3"})
      text = output_text(conn)
      assert text =~ "一行也没有看下去"
    end

    test "指定次数 x3 格式" do
      book_meta = %Book{skill: "liuxin-jian", min_skill: 0, max_skill: 100, exp_required: 0, jing_cost: 1000, difficulty: 10}
      p = player(
        inventory: [book_instance(@book_id, book_meta)],
        skills: %{"literate" => 10, "liuxin-jian" => 0, "force" => 20},
        jing: 3000,
        potential: 50
      )

      conn = StudyCommand.run(build_conn(p), %{"parse" => "柳心剑法 x3"})

      updated = conn.private.update_character || conn.character
      skill_level = updated.meta.stats.skills["liuxin-jian"] || 0
      assert skill_level == 3
    end
  end

  describe "study Book 结构（原有测试保留）" do
    test "Book 结构包含必要字段" do
      book = %Book{
        skill: "liuxin-jian",
        min_skill: 0,
        max_skill: 100,
        exp_required: 1000,
        jing_cost: 5,
        difficulty: 10
      }

      assert book.skill == "liuxin-jian"
      assert book.min_skill == 0
      assert book.max_skill == 100
      assert book.exp_required == 1000
      assert book.jing_cost == 5
      assert book.difficulty == 10
    end
  end
end