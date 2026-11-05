defmodule Kantele.Character.TopRanking do
  @moduledoc """
  全服排行数据源：LPC `CACHE_D->get(arg)` 在本端口的等价物。

  `cmds/usr/top.c` 用 `CACHE_D` 缓存全服玩家的一组快照字段
  （`U_AGE/U_QI/U_JING/U_NEILI/U_JINGLI/U_EXP/U_KILL/U_DIE`），`top` 只负责
  把缓存按该字段排序渲染。本引擎没有这个 daemon，数据来源按字段性质分两路：

  - **已落盘的成长字段**（`combat_exp` / `max_neili` / `age`）：查
    `character_metadata` 关联 `characters`，这才是真正的「全服」快照；
  - **运行态气血/精力**（`qi/jing/neili/jingli`）：这些值只在
    `PlayerMeta.vitals` 里，不落盘，因此只能取 `Presence.characters()`
    的在线玩家（LPC `users()` 等价物）。排行榜会注明「在线」口径。
  - **`kill/die` 计数**：LPC 由 `CACHE_D` 单独累计，本端口的
    `ExVenture.Characters.Metadata` 没有这两列，也没有计数器模块，故返回
    `:unsupported`，由 `TopCommand` 给出明确的「本服未记录该数据」提示，
    而不是伪装成空榜。

  所有查询都包了 fail-safe：数据库未就绪 / ETS 未起时返回空榜，绝不把玩家
  进程带崩（与 `World.FingerD` 的约定一致）。

  单测可以从 `conn.private[:top_ranking]` 注入一个 `category -> result` 的函数，
  避免依赖数据库（`TopCommand` 负责读取该注入点）。
  """

  import Ecto.Query

  alias ExVenture.Characters.Character
  alias ExVenture.Characters.Metadata
  alias ExVenture.Repo
  alias Kantele.Character.Presence

  @limit 20

  # category -> {标题, 数据源, 字段}
  @specs %{
    "exp" => {"经验等级", :db, :combat_exp},
    "lv" => {"经验等级", :db, :combat_exp},
    "hp" => {"气 血 值", :online, :qi},
    "qi" => {"气 血 值", :online, :qi},
    "jing" => {"精 气 值", :online, :jing},
    "neili" => {"内 力 值", :online, :neili},
    "jingli" => {"精 力 值", :online, :jingli},
    "age" => {"游戏年龄", :db_env, "age"},
    "kill" => {"杀敌次数", :unsupported, nil},
    "die" => {"死亡次数", :unsupported, nil}
  }

  @type row :: %{name: String.t(), title: String.t(), value: non_neg_integer()}

  @doc "LPC `top.c` 的 `member_array(arg, ...)` 白名单（另加 `league` 由 TopCommand 自行处理）。"
  def supported?(category), do: Map.has_key?(@specs, category)

  @doc "类别对应的英雄榜标题（用于「本服未记录」提示）。"
  def title(category) do
    case Map.get(@specs, category) do
      {title, _source, _field} -> title
      _ -> nil
    end
  end

  @doc """
  取某个类别的榜单。

  返回 `%{title: 标题, rows: [row], online_only?: bool}`、
  `:unsupported`（本服未记录该指标）或 `:error`（数据源不可用）。
  """
  def ranking(category) do
    case Map.get(@specs, category) do
      nil ->
        :unsupported

      {_title, :unsupported, _} ->
        :unsupported

      {title, :db, field} ->
        {:ok, %{title: title, rows: db_rows(field), online_only?: false}}

      {title, :db_env, key} ->
        {:ok, %{title: title, rows: env_rows(key), online_only?: false}}

      {title, :online, field} ->
        {:ok, %{title: title, rows: online_rows(field), online_only?: true}}
    end
  rescue
    _ -> :error
  catch
    _, _ -> :error
  end

  # ---- 全服（落盘）榜 ----

  defp db_rows(field) do
    Repo.all(
      from m in Metadata,
        join: c in Character,
        on: m.character_id == c.id,
        order_by: [desc: field(m, ^field)],
        limit: ^@limit,
        select: %{
          name: c.name,
          title: m.title,
          value: field(m, ^field)
        }
    )
    |> normalize_rows()
  end

  # `env` 是 jsonb，值形如 %{"age" => 18}；为避免写死 SQL 片段，取回后在
  # Elixir 侧排序取整（全服玩家量级下成本可忽略，且对 map/jsonb 两种列型都成立）。
  defp env_rows(key) do
    Repo.all(
      from m in Metadata,
        join: c in Character,
        on: m.character_id == c.id,
        select: %{name: c.name, title: m.title, env: m.env}
    )
    |> Enum.map(fn row ->
      value = env_value(row.env, key)
      %{name: row.name || "", title: row.title || "", value: value}
    end)
    |> Enum.sort_by(&{-&1.value, &1.name})
    |> Enum.take(@limit)
  end

  defp env_value(env, key) when is_map(env) do
    to_non_neg_integer(Map.get(env, key))
  end

  defp env_value(_, _), do: 0

  defp to_non_neg_integer(value) when is_integer(value), do: max(0, value)
  defp to_non_neg_integer(value) when is_float(value), do: max(0, trunc(value))

  defp to_non_neg_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> max(0, int)
      _ -> 0
    end
  end

  defp to_non_neg_integer(_), do: 0

  # ---- 在线（运行态）榜 ----

  defp online_rows(field) do
    Presence.characters()
    |> Enum.map(fn character ->
      meta = character.meta || %{}
      vitals = Map.get(meta, :vitals) || %{}
      stats = Map.get(meta, :stats) || %{}

      value =
        case Map.get(vitals, field) do
          nil -> Map.get(stats, field) || 0
          value -> value
        end

      %{
        name: to_string(character.name || ""),
        title: to_string(Map.get(meta, :title) || ""),
        value: value || 0
      }
    end)
    |> Enum.sort_by(&{-&1.value, &1.name})
    |> Enum.take(@limit)
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  defp normalize_rows(rows) do
    rows
    |> Enum.map(fn row ->
      %{
        name: to_string(row.name || ""),
        title: to_string(row.title || ""),
        value: row.value || 0
      }
    end)
    |> Enum.sort_by(&{-&1.value, &1.name})
    |> Enum.take(@limit)
  end
end
