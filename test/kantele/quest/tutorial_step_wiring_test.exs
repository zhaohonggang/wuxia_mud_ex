defmodule Kantele.Quest.TutorialStepWiringTest do
  use ExUnit.Case, async: false

  alias Kantele.Quest
  alias Kantele.World.Loader

  # 周不通七步链前六步：步骤文件 → 发放 NPC 名片段 → 交付物品 id（与 liuxi.ucl 配置一致）
  @steps [
    {"_0_tutorial_datie", "Wang the Smith", "liuxi:tiekuai"},
    {"_0_tutorial_cunqian", "Qian the Banker", "liuxi:yinpiao"},
    {"_0_tutorial_baozi", "Aunt Bun", "liuxi:baozi"},
    {"_0_tutorial_guofu", "Steward of Guo", "liuxi:hupi"},
    {"_0_tutorial_baishi", "Zhang Qingya", "liuxi:shuxiu"},
    {"_0_tutorial_qifu", "Temple Keeper", "liuxi:xiang"}
  ]

  # world.characters 为解析后角色（goods/loot/turn_in.item 已解引用）
  defp char(world, fragment) do
    Enum.find(world.characters, &String.contains?(&1.name, fragment))
  end

  defp item_ids(world), do: MapSet.new(world.items, & &1.id)

  defp obtainable_ids(world) do
    from_goods = world.characters |> Enum.flat_map(&((&1.meta.goods || [])))
    from_loot = world.characters |> Enum.flat_map(&((&1.meta.loot || [])))
    MapSet.new(from_goods ++ from_loot)
  end

  # 交付完成：调 Quest 引擎标记已解 + 移出在办 + 连续计数 +1（与 quest_event.update_quests 一致）
  defp complete(state, %{file: file}) do
    {:ok, s} = Quest.set_solved(state, %{file: file})
    s |> Quest.del_todo(file) |> Quest.bump_quest_count()
  end

  describe "Q1-T4 新手六步发放方接线" do
    setup do
      %{world: Loader.load()}
    end

    test "六步发放 NPC 齐备：quest 链递进 + turn_in 物品在库", %{world: world} do
      @steps
      |> Enum.with_index()
      |> Enum.each(fn {{file, fragment, item}, idx} ->
        cfg = char(world, fragment)
        assert cfg, "missing issuer #{fragment}"

        quest = cfg.meta.quest
        assert quest.file == file
        assert quest.type == "chain"
        refute Quest.repeatable?(quest)
        assert quest.master_id == "liuxi:butong"

        # UCL 采用「紧邻前步」链（step N 只要 N-1 已解；逐级累积等价于全链解锁）
        expected_chain =
          case idx do
            0 -> []
            _ -> [elem(Enum.at(@steps, idx - 1), 0)]
          end

        assert quest.chain == expected_chain

        turn_in = cfg.meta.turn_in
        assert turn_in.quest == file
        assert turn_in.item == item
        assert item in item_ids(world), "turn_in item #{item} must be defined"
      end)
    end

    test "每步交付物品都有真实获取途径（商店在售或怪物掉落）", %{world: world} do
      obtainable = obtainable_ids(world)

      for {_file, _fragment, item} <- @steps do
        assert item in obtainable, "delivery item #{item} has no source"
      end
    end

    test "主线收官：黑虎掉落虎皮（郭府步）且周不通可接收", %{world: world} do
      heihu = char(world, "黑虎")
      assert "liuxi:hupi" in (heihu.meta.loot || [])

      butong = char(world, "Butong")
      assert butong.meta.turn_in.quest == "_0_tutorial_shimen5"
      assert "liuxi:xieshi" in item_ids(world)
    end

    test "七步链数据接线全通：逐步发放、链式解锁、末步周不通收官", %{world: world} do
      step_specs = Enum.map(@steps, fn {_file, fragment, _item} -> char(world, fragment).meta.quest end)
      butong_spec = char(world, "Butong").meta.quest

      result =
        Enum.reduce_while(step_specs, Quest.new(), fn spec, state ->
          if Quest.chain_open?(state, spec) do
            case Quest.set_todo(state, spec) do
              {:ok, next} -> {:cont, complete(next, spec)}
              {:error, reason} -> {:halt, {:error, reason, spec.file}}
            end
          else
            {:halt, {:chain_locked, spec.file}}
          end
        end)

      assert Quest.chain_open?(result, butong_spec), "6 步全解后周不通链应开放"
      assert {:ok, s} = Quest.set_todo(result, butong_spec)
      assert {:ok, s} = Quest.set_solved(s, %{file: butong_spec.file})

      expected = (Enum.map(step_specs, & &1.file) ++ [butong_spec.file]) |> Enum.sort()
      assert Quest.get_solved(s) |> Enum.sort() == expected
    end
  end
end