defmodule Kantele.Character.CallCommand do
  @moduledoc """
  召唤命令：`call <对象> <函数> [参数...]`

  对应 LPC `cmds/arch/call.c` 的对象函数调用。

  行为：
  - 先在 `W3ObjectEngine` 中按对象 ID 查找已注册对象，取其 `module` 调用；
  - 未命中则按引用名 / 路径解析为 Elixir 模块（或经 `ObjectClone` 验证对象存在）；
  - 调用 `Module.apply(module, func, args)`，返回结果或明确错误；
  - 已注册对象可标记 `owner`，非属主且非 admin 时拒绝调用。

  仅巫师可用。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Commands.WizArch
  alias Kantele.World.ObjectClone
  alias Kantele.World.W3ObjectEngine

  def run(conn, params) do
    WizArch.guard(conn, params, &handle/2)
  end

  defp handle(conn, %{"rest" => rest}) when rest != "" do
    character = conn.character
    parts = String.split(String.trim(rest), " ", trim: true)

    case parts do
      [obj_ref, func | args] ->
        do_call(conn, character, obj_ref, func, args)

      [_obj_ref] ->
        reply(conn, "用法：call <对象> <函数> [参数...]\n")

      [] ->
        reply(conn, "用法：call <对象> <函数> [参数...]\n")
    end
  end

  defp handle(conn, _params) do
    reply(conn, "用法：call <对象> <函数> [参数...]\n")
  end

  defp do_call(conn, character, obj_ref, func, args) do
    case W3ObjectEngine.lookup(obj_ref) do
      nil ->
        case resolve_module_fallback(obj_ref, character) do
          {:ok, module} -> call_func(conn, module, func, args)
          {:error, reason} -> reply_error(conn, obj_ref, reason)
        end

      entry ->
        if owner_allowed?(entry, character) do
          call_func(conn, entry.module, func, args)
        else
          reply(conn, "你没有权限调用该对象（属主不匹配）。\n")
        end
    end
  end

  defp owner_allowed?(entry, character) do
    owner = Map.get(entry, :owner)
    is_nil(owner) or owner == character.name or Access.adminp(character)
  end

  # 已注册表未命中时：先尝试把引用当模块名解析；再尝试按路径克隆验证对象存在。
  defp resolve_module_fallback(obj_ref, character) do
    case module_from_ref(obj_ref) do
      mod when not is_nil(mod) ->
        {:ok, mod}

      nil ->
        case ObjectClone.clone_by_path(obj_ref, 1, character) do
          {:ok, _result} -> {:error, :not_callable}
          {:error, _} -> {:error, :not_found}
        end
    end
  end

  defp module_from_ref(ref) when is_binary(ref) do
    try do
      mod = Module.concat(ref)

      case Code.ensure_loaded(mod) do
        {:module, ^mod} -> mod
        _ -> nil
      end
    rescue
      _ -> nil
    end
  end

  defp call_func(conn, module, func, args) do
    func_atom =
      try do
        String.to_existing_atom(func)
      rescue
        _ -> nil
      end

    case func_atom do
      nil ->
        reply(conn, "函数不存在：#{func}\n")

      func_atom ->
        try do
          result = apply(module, func_atom, args)
          reply(conn, "调用 #{func} 结果: #{inspect(result)}\n")
        rescue
          UndefinedFunctionError ->
            reply(conn, "函数不存在：#{func}\n")

          FunctionClauseError ->
            reply(conn, "参数不匹配：#{func}(#{inspect(args)})\n")

          e ->
            reply(conn, "调用出错：#{Exception.message(e)}\n")
        end
    end
  end

  defp reply_error(conn, obj_ref, reason) do
    text =
      case reason do
        :not_found -> "找不到对象：#{obj_ref}\n"
        :not_callable -> "对象 #{obj_ref} 已找到，但不是可调用的模块。\n"
        _ -> "无法调用对象：#{obj_ref}\n"
      end

    reply(conn, text)
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
