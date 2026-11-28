defmodule Kantele.Character.Party do
  @moduledoc """
  LPC `party/*` 角色属性的端口表示（对应 `query("party/party_name")` /
  `set("party", mapping)` / `delete("party")` / `delete("rank")` / `delete("level")`）。

  引擎没有独立帮会系统，`meta.env` 即 LPC 的 `query/set/delete` 属性仓库。
  本模块只承载「帮会身份」这一组键，供天地会退会（#831）及后续 party 类缺口复用：

      "party/party_name" / "party/rank" / "party/level"   # 扁平键
      "party"                                              # 兼容整体 mapping

  注意：party 与 `meta.family`（师门）是**两套独立身份**。LPC 天地会
  `ask_tuihui` 只读 `party/party_name`，绝不能回落到门派名。
  """

  @flat_keys ["party/party_name", "party/rank", "party/level"]
  @legacy_keys ["party", "rank", "level"]

  @doc """
  对应 LPC `ob->query("party/party_name")`；未入会返回 nil。
  """
  def name(character) when is_map(character) do
    env = env_of(character)

    Map.get(env, "party/party_name") || Map.get(env, :party_name) ||
      case Map.get(env, "party") || Map.get(env, :party) do
        %{"party_name" => name} -> name
        %{party_name: name} -> name
        _ -> nil
      end
  end

  def name(_character), do: nil

  @doc """
  写入帮会身份（供 wizard / 未来活的入会链使用；天地会 `do_join` 本身是死代码）。

  同时写扁平键与整体 mapping，使 `name/1` 与 LPC 风格查询均可命中。
  """
  def set(character, party_name, rank \\ nil, level \\ nil)
      when is_map(character) and is_binary(party_name) do
    env =
      env_of(character)
      |> Map.put("party/party_name", party_name)
      |> Map.put("party/rank", rank)
      |> Map.put("party/level", level)
      |> Map.put("party", %{"party_name" => party_name, "rank" => rank, "level" => level})

    put_env(character, env)
  end

  @doc """
  对应 LPC `ob->delete("party"); ob->delete("rank"); ob->delete("level");`。

  删除扁平键与兼容 mapping；其它 `meta.env` 键（detach/betrayer/剧情标记等）原样保留。
  """
  def quit(character) when is_map(character) do
    env =
      (@flat_keys ++ @legacy_keys)
      |> Enum.reduce(env_of(character), fn key, acc ->
        acc |> Map.delete(key) |> Map.delete(String.to_atom(key))
      end)

    put_env(character, env)
  end

  def quit(character), do: character

  @doc "退会时需要清掉的键（供测试与文档核对）。"
  def quit_keys, do: @flat_keys ++ @legacy_keys

  defp env_of(character) do
    case Map.get(character, :meta) do
      %{env: env} when is_map(env) -> env
      meta when is_map(meta) -> Map.get(meta, :env) || Map.get(meta, "env") || %{}
      _ -> %{}
    end
  end

  defp put_env(character, env) do
    meta = Map.get(character, :meta) || %{}
    %{character | meta: Map.put(meta, :env, env)}
  end
end
