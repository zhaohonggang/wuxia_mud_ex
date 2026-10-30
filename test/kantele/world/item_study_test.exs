defmodule Kantele.World.ItemStudyTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.{PlayerMeta, Stats, StudyCommand, Vitals}
  alias Kalevala.World.Item.Instance

  defp player(opts) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 200),
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
      combat_exp: 500_000,
      potential: 100,
      learned_points: 0,
      skills: Keyword.get(opts, :skills, %{"literate" => 50}),
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

  # 实例自带定义（不走 Items 缓存），id 即自定义 do_study 的派发键
  defp book(definition_id, name, aliases) do
    item = %Kalevala.World.Item{id: definition_id, name: name, meta: %{aliases: aliases}}

    %Instance{
      id: "inst-#{definition_id}",
      item_id: definition_id,
      created_at: DateTime.utc_now(),
      item: item,
      meta: %{}
    }
  end

  defp lyj_book, do: book("kunlun:items.lyj_book", "两仪剑心得", ["shu", "book"])

  defp iron_hand, do: book("lingxiao:items.book_iron", "铁手掌", ["iron hand", "hand", "shu"])

  defp current(conn), do: conn.private.update_character || conn.character

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "两仪剑心得（d/kunlun/obj/lyj-book.c）" do
    test "两仪剑法 100<lvl<=180：扣 40 精、技能 +1" do
      p = player(skills: %{"literate" => 50, "liangyi-jian" => 120}, inventory: [lyj_book()])
      conn = StudyCommand.run(build_conn(p), %{"parse" => "shu"})

      c = current(conn)
      assert c.meta.vitals.jing == 160
      assert Stats.skill(c.meta.stats, "liangyi-jian") == 121
    end

    test "两仪剑法 100 以下：无变化（LPC 静默 return 1）" do
      p = player(skills: %{"literate" => 50, "liangyi-jian" => 90}, inventory: [lyj_book()])
      conn = StudyCommand.run(build_conn(p), %{"parse" => "shu"})

      c = current(conn)
      assert c.meta.vitals.jing == 200
      assert Stats.skill(c.meta.stats, "liangyi-jian") == 90
    end

    test "精神不足 30：提示歇会" do
      p =
        player(
          jing: 20,
          skills: %{"literate" => 50, "liangyi-jian" => 120},
          inventory: [lyj_book()]
        )

      conn = StudyCommand.run(build_conn(p), %{"parse" => "shu"})
      assert output_text(conn) =~ "太累了"
      assert current(conn).meta.vitals.jing == 20
    end

    test "参数不是 shu/book/xinde：提示要学什么" do
      p = player(skills: %{"literate" => 50, "liangyi-jian" => 120}, inventory: [lyj_book()])
      conn = build_conn(p)

      assert {:done, out} = Kantele.World.ItemStudy.study(conn, lyj_book(), "xxx", p)
      assert output_text(out) =~ "你要学什么"
      assert current(out).meta.vitals.jing == 200
    end
  end

  describe "铁手掌（d/lingxiao/obj/book-iron.c）" do
    test "战斗中且 30<=parry<=100：扣 20 精、招架 +1（战斗中也能读）" do
      combat = %{Kantele.Character.Combat.new() | enemies: [%{id: "npc-1", pid: self()}]}

      p =
        player(
          skills: %{"literate" => 50, "parry" => 50},
          inventory: [iron_hand()],
          combat: combat
        )

      conn = StudyCommand.run(build_conn(p), %{"parse" => "iron hand"})

      c = current(conn)
      assert c.meta.vitals.jing == 180
      assert Stats.skill(c.meta.stats, "parry") == 51
      refute output_text(conn) =~ "无法在战斗中"
    end

    test "不在战斗中：不生效（LPC return 0）" do
      p = player(skills: %{"literate" => 50, "parry" => 50}, inventory: [iron_hand()])
      conn = StudyCommand.run(build_conn(p), %{"parse" => "iron hand"})

      assert current(conn).meta.vitals.jing == 200
      assert Stats.skill(current(conn).meta.stats, "parry") == 50
    end

    test "招架超出 100：不生效" do
      combat = %{Kantele.Character.Combat.new() | enemies: [%{id: "npc-1", pid: self()}]}
      p = player(skills: %{"literate" => 50, "parry" => 150}, inventory: [iron_hand()], combat: combat)
      conn = StudyCommand.run(build_conn(p), %{"parse" => "hand"})

      assert Stats.skill(current(conn).meta.stats, "parry") == 150
    end
  end
end
