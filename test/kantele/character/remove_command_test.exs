defmodule Kantele.Character.RemoveCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.RemoveCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @cloth_snap %{name: "铁甲", armor: 5, prop: %{defense: 2}, consistence: 100}
  @head_snap %{name: "斗笠", armor: 2, prop: %{}, consistence: 100}
  @weapon_snap %{
    name: "长剑",
    skill_type: "sword",
    damage: 20,
    prop: %{attack: 1},
    flag: 1
  }

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
      skills: %{},
      combat_exp: 0,
      score: 0,
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
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp armored_combat do
    Combat.new()
    |> Combat.equip(:weapon, @weapon_snap)
    |> Combat.equip(:cloth, @cloth_snap)
    |> Combat.equip(:head, @head_snap)
  end

  defp weapon_only_combat do
    Combat.new() |> Combat.equip(:weapon, @weapon_snap)
  end

  # `conn.private` 是结构体、未实现 Access；注入测试 seam 用 Map.put/3。
  defp build(p, private \\ %{}) do
    conn = build_conn(p)

    private =
      Enum.reduce(private, conn.private, fn {key, value}, acc -> Map.put(acc, key, value) end)

    %{conn | private: private}
  end

  # put_character/2 只写 conn.private.update_character。
  defp updated_character(conn), do: conn.private.update_character || conn.character

  defp present(value), do: fn _character, _arg -> value end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "main()：参数分派" do
    test "无参数提示你要脱掉什么" do
      conn = RemoveCommand.run(build(player()), %{})
      assert output_text(conn) =~ "你要脱掉什么"
    end

    test "空白参数同样按无参数处理" do
      conn = RemoveCommand.run(build(player()), %{"item_name" => "   "})
      assert output_text(conn) =~ "你要脱掉什么"
    end

    test "不再输出占位桩文案" do
      texts =
        [
          RemoveCommand.run(build(player()), %{}),
          RemoveCommand.run(build(player()), %{"item_name" => "铁甲"}),
          RemoveCommand.run(build(player()), %{"item_name" => "all"})
        ]
        |> Enum.map(&output_text/1)

      refute Enum.any?(texts, &String.contains?(&1, "暂未开放"))
    end
  end

  describe "main()：单件脱卸的 LPC 双门" do
    test "present() 不过 → 你身上没有这样东西" do
      conn =
        RemoveCommand.run(
          build(player(combat: armored_combat()), %{remove_present: present(false)}),
          %{"item_name" => "铁甲"}
        )

      assert output_text(conn) =~ "你身上没有这样东西"
      assert Map.has_key?(updated_character(conn).meta.combat.equipped, :cloth)
    end

    test "present() 过但没有已穿戴护具 → 你并没有装备这样东西" do
      conn =
        RemoveCommand.run(
          build(player(), %{remove_present: present(true)}),
          %{"item_name" => "铁甲"}
        )

      assert output_text(conn) =~ "你并没有装备这样东西"
    end

    test "武器槽位不属于 remove（应走 unwield）" do
      conn =
        RemoveCommand.run(
          build(player(combat: weapon_only_combat()), %{remove_present: present(true)}),
          %{"item_name" => "长剑"}
        )

      assert output_text(conn) =~ "你并没有装备这样东西"
    end

    test "present() + 已穿戴 → 真正卸下并清空对应槽位" do
      conn =
        RemoveCommand.run(
          build(player(combat: armored_combat()), %{remove_present: present(true)}),
          %{"item_name" => "铁甲"}
        )

      assert output_text(conn) =~ "你卸下了铁甲"

      equipped = updated_character(conn).meta.combat.equipped
      refute Map.has_key?(equipped, :cloth)
      assert Map.has_key?(equipped, :head)
      assert Map.has_key?(equipped, :weapon)
    end
  end

  describe "main()：remove all" do
    test "一件护具都没有 → 你什么都没有脱下来" do
      conn = RemoveCommand.run(build(player(combat: weapon_only_combat())), %{"item_name" => "all"})
      assert output_text(conn) =~ "你什么都没有脱下来"
      refute output_text(conn) =~ "你脱完了"
    end

    test "卸下全部护具并保留武器槽位" do
      conn = RemoveCommand.run(build(player(combat: armored_combat())), %{"item_name" => "all"})

      text = output_text(conn)
      assert text =~ "你卸下了铁甲"
      assert text =~ "你卸下了斗笠"
      assert text =~ "你脱完了"

      equipped = updated_character(conn).meta.combat.equipped
      refute Map.has_key?(equipped, :cloth)
      refute Map.has_key?(equipped, :head)
      assert Map.has_key?(equipped, :weapon)
    end
  end

  describe "路由" do
    test "裸 remove / 带参 / all / 中文别名 统一归 RemoveCommand" do
      {:ok, bare} = Kantele.Character.Commands.parse("remove")
      assert bare.module == RemoveCommand
      assert bare.function == :run
      refute Map.has_key?(bare.params, "item_name")

      for {text, expected} <- [
            {"remove 铁甲", "铁甲"},
            {"remove all", "all"},
            {"remove 玄铁 护甲", "玄铁 护甲"},
            {"脱 铁甲", "铁甲"}
          ] do
        {:ok, parsed} = Kantele.Character.Commands.parse(text)
        assert parsed.module == RemoveCommand, "#{text} 应路由到 RemoveCommand"
        assert parsed.function == :run
        assert parsed.params["item_name"] == expected
      end
    end

    test "WieldCommand 不再持有重复的 remove/脱 路由" do
      assert match_remove_to_wield("remove 铁甲") == :error
      assert match_remove_to_wield("脱 铁甲") == :error
    end
  end

  defp match_remove_to_wield(text) do
    case Kantele.Character.Commands.parse(text) do
      {:ok, %{module: Kantele.Character.WieldCommand, function: :remove}} -> {:ok, :wield}
      _ -> :error
    end
  end
end
