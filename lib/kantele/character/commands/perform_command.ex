defmodule Kantele.Character.PerformCommand do
  @moduledoc """
  绝招命令：`perform <技能>.<招式>`

  两种写法等价：

  - `perform liuxin-jian.liu`（技能 id）
  - `perform sword.liu`（map_skill 的用法，映射到柳心剑法）
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  def run(conn, %{"action" => action}) do
    case String.split(String.trim(action), ".") do
      [key, move] ->
        resolve(conn, String.trim(key), String.trim(move))

      _ ->
        conn
        |> render(CommandView, "text", %{text: "用法：perform <武功>.<招式>\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp resolve(conn, key, move) do
    stats = conn.character.meta.stats

    skill_id =
      cond do
        Skills.known?(key) -> key
        true -> Stats.mapped(stats, key)
      end

    module = skill_id && Skills.get(skill_id)

    cond do
      is_nil(module) ->
        render_error(conn, "你并没有使用这项武功。\n")

      true ->
        case Map.get(module.perform_list(), move) do
          nil ->
            render_error(conn, "这项武功中没有这一招。\n")

          perform_module ->
            # D4: T5 需要 prepare_skill 预备，检查 prepared 状态
            case check_prepared(conn, perform_module) do
              {:ok, _} -> perform_module.run(conn)
              {:error, reason} -> render_error(conn, reason)
            end
        end
    end
  end

  defp check_prepared(conn, perform_module) do
    # 检查该绝招是否需要 prepare_skill 预备（查看 spec 的 gates）
    spec =
      if Code.ensure_loaded?(perform_module) and function_exported?(perform_module, :spec, 0) do
        perform_module.spec()
      else
        %{}
      end

    gates = Map.get(spec, :gates, [])

    case Enum.find(gates, fn gate -> elem(gate, 0) == :prepared end) do
      nil ->
        # 不需要 prepare，直接通过
        {:ok, :no_prepare_required}

      {_, usage, _message} ->
        # 需要该用法的预备
        perform_id = perform_id_of(perform_module)

        case Stats.prepared_perform(conn.character.meta.stats, usage) do
          nil ->
            {:error, "你尚未预备该招式用法（#{usage}），请先使用 prepare 命令预备。\n"}

          ^perform_id ->
            {:ok, :prepared}

          _ ->
            {:error, "预备的绝招与当前招式不符。\n"}
        end
    end
  end

  defp perform_id_of(perform_module) do
    case perform_module.__info__(:attributes)[:perform_id] do
      [id] when is_binary(id) ->
        id

      _ ->
        if Code.ensure_loaded?(perform_module) and function_exported?(perform_module, :spec, 0) do
          s = perform_module.spec()
          s.id
        end
    end
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
