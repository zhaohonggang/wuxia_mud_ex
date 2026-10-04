defmodule ExVenture.Repo.Migrations.DropFixtureZoneItems do
  use Ecto.Migration

  @moduledoc """
  清掉背包/装备/行囊里指向 `test:` / `global:` 两个夹具区的物品引用。

  背景：`data/world/{test,global}.ucl` 是 `lpc_converter.py` 的转换测试产物
  （源为 `test_minimal_world_v2_modified/`），从未接入真实世界，已搬到
  `test/fixtures/world/` 并从 `Loader.load/1` 的默认路径里摘掉
  （见 `Kantele.World.Loader.load_fixture_world/1`）。

  但**物品实例是持久化在数据库里的** —— 角色身上早就存下了
  `global:potion` / `test:staff` / `test:bottle` 这类 id。定义一没，
  `Items.get!/1` 就 raise，登录时 `inventory/list` 直接把 Foreman GenServer 带走：

      ** (RuntimeError) Could not find key global:potion in cache Elixir.Kantele.World.Items
          (ex_venture 0.1.0) lib/kantele/character/events/inventory_event.ex:10

  这些物品本来就查不到定义（存下来的是 `ItemNotLoaded` 空壳），留着只会让人物
  无法登录，所以直接从三列里剔除。

  ## 三列的类型不一样，所以三条语句分开写

      inventory   jsonb[]   原生数组，元素是 {"item_id": "..."} 对象
      equipment   jsonb     对象，值是 item_id 字符串
      bag         jsonb     对象（当前都是 {}）

  之前试过用一条 `CASE jsonb_typeof(...)` 统一处理，`inventory` 上直接报
  `No function matches the given name and argument types` —— `jsonb_typeof`
  根本不接受数组。类型既然固定，就别在一个分支里硬凑三种形状。

  匹配一律按文本 `%global:%` / `%test:%`：全部 zone id 里只有夹具那两区含
  global/test 字样，不会误伤。jsonb 元素的 `::text` 里 `global:` 是连续的
  （转义反斜杠落在引号那一侧），所以匹配得到。

  幂等：跑完再跑一次匹配不到任何行。
  """

  def up do
    execute(fn -> flush_inventory() end)
    execute(fn -> flush_object_column(:equipment) end)
    execute(fn -> flush_object_column(:bag) end)
  end

  def down do
    # 物品实例本体没被删，只是从三列里摘掉了条目；没有任何办法还原。
    raise "irreversible: 夹具区物品实例已丢失，无法还原"
  end

  # inventory 是 jsonb[]，逐元素判断后重建数组
  defp flush_inventory do
    %Postgrex.Result{num_rows: n} =
      repo().query!(
        """
        UPDATE character_metadata AS m
        SET inventory = ARRAY(
          SELECT e
          FROM unnest(m.inventory) AS e
          WHERE e::text NOT LIKE '%global:%'
            AND e::text NOT LIKE '%test:%'
        )
        WHERE EXISTS (
          SELECT 1
          FROM unnest(m.inventory) AS e
          WHERE e::text LIKE '%global:%' OR e::text LIKE '%test:%'
        )
        """,
        []
      )

    if n > 0, do: IO.puts("  inventory: 清掉 #{n} 行")
  end

  # equipment / bag 是 jsonb 对象，值是 item_id 字符串
  defp flush_object_column(column) do
    %Postgrex.Result{num_rows: n} =
      repo().query!(
        """
        UPDATE character_metadata AS m
        SET #{column} = COALESCE((
          SELECT jsonb_object_agg(kv.key, kv.value)
          FROM jsonb_each(m.#{column}) AS kv
          WHERE kv.value::text NOT LIKE '%global:%'
            AND kv.value::text NOT LIKE '%test:%'
        ), '{}'::jsonb)
        WHERE m.#{column}::text LIKE '%global:%'
           OR m.#{column}::text LIKE '%test:%'
        """,
        []
      )

    if n > 0, do: IO.puts("  #{column}: 清掉 #{n} 行")
  end
end
