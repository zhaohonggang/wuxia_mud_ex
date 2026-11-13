defmodule Kantele.World.CorpseTest do
  @moduledoc """
  尸体/狩猎掉落物管线的回归测试。

  覆盖两件事：
  1. `Kantele.World.Corpse` 的纯函数与降级行为（世界服务未启动时不能崩）；
  2. UCL 数据的完整性 —— 每个 `drop_a` / `drop_b` / `drop_c` 引用都能找到物品定义，
     且按 LPC `clone/quarry/*.c` / `clone/beast/*.c` 补全的关键 NPC 配置齐全。

  用 `Elias.parse/1` 直接读 UCL，而不是 `Loader.load/1`：本测试只关心数据契约，
  不需要把整个世界实例化，跑得也快。
  """

  use ExUnit.Case, async: true

  alias Kantele.World.Corpse

  @world_files "data/world/*.ucl"

  defp npc(overrides \\ %{}) do
    Map.merge(
      %{
        id: "clone_lib:quarry_zhu2",
        name: "野猪",
        room_id: "test:no_such_room",
        meta: %{drop_a: "zhurou", drop_b: nil, drop_c: nil, power: 32}
      },
      overrides
    )
  end

  defp parsed(path), do: path |> File.read!() |> Elias.parse()

  defp drop_ref(value) do
    case value do
      %{id: id} when is_binary(id) -> id
      _ -> nil
    end
  end

  # ---- 纯函数 ----

  describe "drop_item_ids/1" do
    test "收集 drop_a/drop_b/drop_c，丢弃 nil 并去重" do
      character =
        npc(%{
          meta: %{drop_a: "xiongrou", drop_b: "xiongpi", drop_c: "xiongdan"}
        })

      assert Corpse.drop_item_ids(character) == ["xiongrou", "xiongpi", "xiongdan"]
    end

    test "重复引用去重，nil / 缺失键忽略" do
      character = npc(%{meta: %{drop_a: "zhurou", drop_b: "zhurou", drop_c: nil}})
      assert Corpse.drop_item_ids(character) == ["zhurou"]

      assert Corpse.drop_item_ids(npc(%{meta: %{}})) == []
    end
  end

  describe "corpse_instance/1" do
    test "item_id 是带区前缀的完整缓存 key，避免 get all 抛 Could not find key" do
      instance = Corpse.corpse_instance(npc())

      assert is_binary(instance.item_id)
      assert String.ends_with?(instance.item_id, "corpse")
      assert String.contains?(instance.item_id, ":")
      refute instance.item_id == "corpse"
    end

    test "尸体带角色名、属主与掉落物 meta（字符串键，供运行期读取）" do
      instance = Corpse.corpse_instance(npc())

      assert instance.item.name == "野猪的尸体"
      assert instance.meta["is_corpse"] == true
      assert instance.meta["owner_id"] == "clone_lib:quarry_zhu2"
      assert instance.meta["drop_items"] == ["zhurou"]
      assert instance.item.meta["character_name"] == "野猪"
      assert instance.item.meta["drop_items"] == ["zhurou"]
    end
  end

  describe "spawn/1" do
    test "玩家死亡生成尸体（与 LPC chard.c 一致，不再因 player id 跳过）" do
      assert Corpse.spawn(npc(%{id: "player:42"})) in [:ok, :error]
    end

    test "结构不完整时跳过" do
      assert Corpse.spawn(%{}) == :skip
      assert Corpse.spawn(%{id: "x", room_id: nil}) == :skip
    end

    test "房间进程/物品缓存未就绪时静默降级，不抛异常" do
      assert Corpse.spawn(npc()) in [:ok, :error]
    end
  end

  # ---- UCL 数据契约 ----

  describe "UCL 掉落物数据" do
    test "所有 UCL 文件语法可解析" do
      files = Path.wildcard(@world_files)
      assert length(files) > 50

      Enum.each(files, fn path ->
        assert is_map(parsed(path)), "#{path} 解析失败"
      end)
    end

    test "每个 drop_a/drop_b/drop_c 引用都能解析到物品定义" do
      parsed_files = Enum.map(Path.wildcard(@world_files), &parsed/1)

      item_keys =
        parsed_files
        |> Enum.flat_map(fn data ->
          data |> Map.get(:items, %{}) |> Map.keys() |> Enum.map(&to_string/1)
        end)
        |> MapSet.new()

      refs =
        parsed_files
        |> Enum.flat_map(fn data -> Map.values(Map.get(data, :characters, %{})) end)
        |> Enum.filter(&is_map/1)
        |> Enum.flat_map(fn character ->
          [:drop_a, :drop_b, :drop_c]
          |> Enum.map(&drop_ref(Map.get(character, &1)))
          |> Enum.reject(&is_nil/1)
        end)

      assert length(refs) >= 80
      assert Enum.all?(refs, &MapSet.member?(item_keys, &1)),
             "存在无法解析的掉落物引用：#{inspect(refs -- MapSet.to_list(item_keys))}"
    end

    test "按 LPC 补齐的 20 个狩猎物品定义存在且数值来自 LPC" do
      items = Map.get(parsed("data/world/clone_lib.ucl"), :items, %{})

      expected = %{
        diaorou: {"貂肉", 60, "块", 300},
        diaopi: {"貂皮", 10_000, "张", 300},
        eyurou: {"鳄鱼肉", 100, "块", 300},
        eyupi: {"鳄鱼皮", 10_000, "张", 800},
        baorou: {"豹肉", 100, "块", 300},
        zhangrou: {"獐子肉", 40, "块", 300},
        yingrou: {"鹰肉", 60, "块", 300},
        xiangrou: {"象肉", 500, "块", 300},
        xiangya: {"象牙", 50_000, "根", 1000},
        paorou: {"狍子肉", 40, "块", 300},
        langrou: {"狼肉", 20, "块", 300},
        langpi: {"狼皮", 600, "张", 300},
        langpi2: {"银狼皮", 12_000, "张", 300},
        jizirou: {"麂子肉", 60, "块", 300},
        jirou: {"山鸡肉", 20, "块", 300},
        lirou: {"狸肉", 50, "块", 300},
        lipi: {"狐狸皮", 2000, "张", 300},
        lipi2: {"白狐皮", 10_000, "张", 300},
        sherou: {"蛇肉", 60, "块", 300},
        shepi: {"蛇皮", 4000, "张", 600}
      }

      Enum.each(expected, fn {key, {name, value, unit, weight}} ->
        item = Map.get(items, key)
        assert item != nil, "缺少 items \"#{key}\""
        assert item.name == name
        assert item.meta.value == value
        assert item.meta.unit == unit
        assert item.meta.weight == weight
      end)
    end

    test "12 个已存在的 quarry NPC 按 LPC 配置了 drop 与 power" do
      characters = Map.get(parsed("data/world/clone_lib.ucl"), :characters, %{})

      expected = %{
        quarry_diao: {7, ["diaorou", "diaopi"]},
        quarry_eyu: {50, ["eyurou", "eyupi"]},
        quarry_gou2: {13, ["gourou", "goupi"]},
        quarry_gou3: {22, ["gourou", "goupi"]},
        quarry_gui: {5, ["guijia"]},
        quarry_lang: {25, ["langrou", "langpi"]},
        quarry_lang2: {30, ["langrou", "langpi"]},
        quarry_laohu2: {50, ["hurou", "hupi"]},
        quarry_yang2: {7, ["yangrou", "yangpi"]},
        quarry_yang3: {7, ["yangrou", "yangpi"]},
        quarry_ying: {32, ["yingrou"]},
        quarry_zhu: {28, ["zhurou"]}
      }

      Enum.each(expected, fn {key, {power, drops}} ->
        character = Map.get(characters, key)
        assert character != nil, "缺少 characters \"#{key}\""
        assert character.power == power, "#{key} 的 power 与 LPC 不符"

        actual =
          [:drop_a, :drop_b, :drop_c]
          |> Enum.map(&drop_ref(Map.get(character, &1)))
          |> Enum.reject(&is_nil/1)

        assert actual == drops, "#{key} 的掉落配置与 LPC 不符"
      end)
    end

    test "灰熊的稀有掉落 drop_c（LPC item3 = 熊胆）已配置" do
      characters = Map.get(parsed("data/world/clone_lib.ucl"), :characters, %{})
      xiong = Map.get(characters, :quarry_xiong)

      assert [
               drop_ref(xiong.drop_a),
               drop_ref(xiong.drop_b),
               drop_ref(xiong.drop_c)
             ] == ["xiongrou", "xiongpi", "xiongdan"]
    end

    test "蛇类 NPC 按 LPC inherit SNAKE die() 配置了蛇肉/蛇胆" do
      baituo = Map.get(parsed("data/world/baituo.ucl"), :characters, %{})

      Enum.each(
        [:caihuashe, :dushe, :fushe, :jinshe, :qingshe, :wangshe, :wubushe, :yanjingshe],
        fn key ->
          character = Map.get(baituo, key)
          assert character != nil, "缺少 characters \"#{key}\""
          assert drop_ref(character.drop_a) == "sherou"
          assert drop_ref(character.drop_b) == "shedan"
        end
      )

      # 蟒蛇的 item2 是蛇皮而非蛇胆（LPC clone/beast/mangshe.c）
      mangshe = Map.get(baituo, :mangshe)
      assert drop_ref(mangshe.drop_a) == "sherou"
      assert drop_ref(mangshe.drop_b) == "shepi"
    end

    test "玄冰莽蛇的 item3 碧魄血精（clone_lib:blood）已配置" do
      lingxiao = Map.get(parsed("data/world/lingxiao.ucl"), :characters, %{})
      xuanmang = Map.get(lingxiao, :xuanmang)

      assert drop_ref(xuanmang.drop_a) == "sherou"
      assert drop_ref(xuanmang.drop_b) == "shedan"
      assert drop_ref(xuanmang.drop_c) == "blood"
    end
  end
end
