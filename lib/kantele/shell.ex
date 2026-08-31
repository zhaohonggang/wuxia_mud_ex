defmodule Kantele.Shell do
  @moduledoc """
  巫师会话 shell 辅助（对应 `feature/shell.c`）

  shell.c 的核心（把表达式写临时 .c 文件交驱动编译执行）在 Elixir 侧无对应物，
  故仅移植两段**纯逻辑**：

  1. **变量存取**：`set_var/query_var/query_all_vars/query_var_count/delete_var`
     —— 就是个字符串键的值映射（`%{prop => value}`）。
  2. **`$...$` 插值解析**：`interpolate/2` 扫描 `$expr$` 对，逐个用 `eval_fun`
     求值替换（对应 shell.c parse_shell 的括号往复替换）。
  """

  @doc "取变量（缺省 nil）"
  def query_var(vars, prop) when is_map(vars), do: Map.get(vars, prop)

  @doc "设变量，返回新映射"
  def set_var(vars, prop, data) when is_map(vars), do: Map.put(vars, prop, data)

  @doc "删变量，返回 `{new_map, success?}`（shell.c delete_var 语义）"
  def delete_var(vars, prop) when is_map(vars), do: {Map.delete(vars, prop), true}
  def delete_var(_vars, _prop), do: {%{}, false}

  @doc "变量个数"
  def query_var_count(vars) when is_map(vars), do: map_size(vars)

  @doc "全部变量（修旧为新 map 兜底）"
  def query_all_vars(vars) when is_map(vars), do: vars
  def query_all_vars(_), do: %{}

  @doc """
  `$...$` 插值解析（对应 shell.c parse_shell/1）

  `eval_fun.(inner)` 返回求值结果（string 或可 `to_string` 的值），
  依次替换每个 `$inner$`。无 `$` 对则原样返回。
  """
  def interpolate(arg, eval_fun) when is_binary(arg) do
    Regex.replace(~r/\$([^$]+)\$/, arg, fn _, inner ->
      inner
      |> eval_fun.()
      |> to_string()
    end)
  end
end
