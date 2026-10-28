defmodule Kantele.World.ForgeTemplatesTest do
  @moduledoc """
  S3 后续：自定义锻造物品模板的落盘 / 启动恢复。

  背景：`handle_finish/3` 原先用 `Jason.encode!(%Kalevala.World.Item{})` 落盘，
  而该 struct 的 `Jason.Encoder` 走 `Kalevala.Meta.Trim`，`Kantele.World.Item.Meta`
  的 trim 只保留 `:damage` / `:armor`。结果落盘文件里没有 `item_make` / `owner_id` /
  `messages` —— 重启后 `discard` 退款失效、自定义文案丢失。这里锁死「落盘必须完整」。
  """
  use ExUnit.Case, async: false

  alias Kalevala.World.Item, as: ItemDef
  alias Kantele.World.ForgeTemplates
  alias Kantele.World.Item, as: ItemCallbacks
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  setup do
    dir =
      Path.join(
        System.tmp_dir!(),
        "forge_templates_test_#{System.unique_integer([:positive])}"
      )

    previous = Application.get_env(:ex_venture, :forge_dir)
    Application.put_env(:ex_venture, :forge_dir, dir)

    on_exit(fn ->
      File.rm_rf(dir)

      if previous do
        Application.put_env(:ex_venture, :forge_dir, previous)
      else
        Application.delete_env(:ex_venture, :forge_dir)
      end
    end)

    {:ok, dir: dir}
  end

  defp template(overrides \\ %{}) do
    base = %ItemDef{
      id: "forge:test-owner-abc",
      name: "玄铁剑",
      description: "一把由玄铁炼制的利剑。",
      callback_module: ItemCallbacks,
      verbs: [],
      meta: %Meta{
        skill_type: "sword",
        unit: "柄",
        weight: 750,
        material: "steel",
        material_name: "玄铁",
        damage: 100,
        armor: nil,
        value: 5000,
        item_make: true,
        owner: "孙七",
        owner_id: "test-owner",
        messages: %{wield: "你腰间悬起了玄铁剑。", unwield: "你将玄铁剑收回鞘中。"}
      }
    }

    Map.merge(base, overrides)
  end

  describe "encode/decode 往返" do
    test "保留 item_make / owner_id / 属性 / 文案（不能退化成 Meta.Trim 的 damage+armor）" do
      original = template()

      # 模拟落盘：encode -> JSON 字符串 -> 解析回 map -> decode
      map = original |> ForgeTemplates.encode() |> Jason.encode!() |> Jason.decode!()
      assert {:ok, restored} = ForgeTemplates.decode(map)

      assert restored.id == original.id
      assert restored.name == "玄铁剑"
      assert restored.description == "一把由玄铁炼制的利剑。"
      assert restored.callback_module == ItemCallbacks
      assert restored.verbs == []

      meta = restored.meta
      assert %Meta{} = meta
      assert meta.item_make == true
      assert meta.owner_id == "test-owner"
      assert meta.owner == "孙七"
      assert meta.skill_type == "sword"
      assert meta.unit == "柄"
      assert meta.weight == 750
      assert meta.material == "steel"
      assert meta.material_name == "玄铁"
      assert meta.damage == 100
      assert meta.value == 5000
    end

    test "messages 的键还原成 atom（消费端用 Map.get(messages, :wield)）" do
      map =
        template()
        |> ForgeTemplates.encode()
        |> Jason.encode!()
        |> Jason.decode!()

      assert {:ok, restored} = ForgeTemplates.decode(map)

      assert Map.get(restored.meta.messages, :wield) == "你腰间悬起了玄铁剑。"
      assert Map.get(restored.meta.messages, :unwield) == "你将玄铁剑收回鞘中。"
    end

    test "缺 id 或非 map → error" do
      assert {:error, _} = ForgeTemplates.decode(%{"name" => "无 id"})
      assert {:error, _} = ForgeTemplates.decode("nope")
    end

    test "未知 meta 键被忽略，不炸" do
      map =
        template()
        |> ForgeTemplates.encode()
        |> Map.update!("meta", &Map.put(&1, "future_field_xyz", 1))

      assert {:ok, restored} = ForgeTemplates.decode(map)
      assert restored.id == "forge:test-owner-abc"
    end
  end

  describe "save/load_all" do
    test "save 写盘 + load_all 重新注册进 Items", %{dir: dir} do
      item = template()

      assert {:ok, path} = ForgeTemplates.save(item)
      assert path == Path.join(dir, ForgeTemplates.file_name(item.id))
      assert File.regular?(path)
      # Windows 上 `:` 是非法文件名字符，落盘名不能带它
      refute String.contains?(Path.basename(path), ":")

      Items.delete(item.id)
      assert Items.get(item.id) == {:error, :not_found}

      assert ForgeTemplates.load_all() == 1

      assert {:ok, restored} = Items.get(item.id)
      assert restored.name == "玄铁剑"
      assert restored.meta.item_make == true
      assert restored.meta.owner_id == "test-owner"
      assert Map.get(restored.meta.messages, :wield) == "你腰间悬起了玄铁剑。"

      Items.delete(item.id)
    end

    test "坏文件只跳过，不影响其他模板", %{dir: dir} do
      assert {:ok, _} = ForgeTemplates.save(template())
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "broken.json"), "{not json")
      File.write!(Path.join(dir, "no-id.json"), ~s({"name":"无 id"}))

      assert ForgeTemplates.load_all() == 1
      assert {:ok, item} = Items.get("forge:test-owner-abc")
      assert item.name == "玄铁剑"

      Items.delete("forge:test-owner-abc")
    end

    test "目录不存在 → 0，不抛异常", %{dir: dir} do
      assert ForgeTemplates.load_all() == 0
      refute File.dir?(dir)
    end
  end

  describe "启动钩子" do
    test "Kantele.World.Items.initialize/1 会灌入 forge_dir 下的模板" do
      assert {:ok, _} = ForgeTemplates.save(template())
      Items.delete("forge:test-owner-abc")
      assert Items.get("forge:test-owner-abc") == {:error, :not_found}

      # Kalevala.Cache 建表后回调 initialize/1（{:continue, :initialize}）
      assert :ok = Items.initialize(%Kalevala.Cache{})

      assert {:ok, item} = Items.get("forge:test-owner-abc")
      assert item.meta.item_make == true
      assert item.meta.owner_id == "test-owner"

      Items.delete("forge:test-owner-abc")
    end

    test "落盘目录不可用时 initialize/1 仍然返回 :ok（不能让物品缓存起不来）" do
      Application.put_env(:ex_venture, :forge_dir, "/proc/definitely-not-a-dir")

      assert :ok = Items.initialize(%Kalevala.Cache{})
    end
  end
end
