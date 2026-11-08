defmodule Kantele.Character.SpecialSkill do
  @moduledoc """
  特技 daemon 适配层（对应 LPC `SPECIAL_D(skill)`）。

  `Kantele.Character.SpecialSkills` 只负责「skill id → 模块」的注册表，
  本模块负责调用约定：把 LPC 的 `SPECIAL_D(skill)->name()` 与
  `SPECIAL_D(skill)->perform(me, skill, arg)` 映射到 Elixir。

  ## 契约（新模块实现）

      defmodule MySpecial do
        @behaviour Kantele.Character.SpecialSkill
        def name, do: "某某特技"
        def perform(conn, skill_id, arg), do: conn
      end

  ## 兼容形状

  注册表里已有的模块（`test/kantele/character/special_skills_test.exs` 的
  `DaemonDummy`）用的是 `title/0` + `perform/2(conn, opts)`，那批模块早于
  本契约存在，不能强改。故 `display_name/2` / `perform/4` 会按导出函数
  自动适配：

  - 显示名：`name/0` → `title/0` → `BornPlayer.display_name/1` → skill id
  - 执行：`perform/3` → `perform/2(conn, %{skill: id, arg: arg})` → `:not_handled`

  `perform/4` 返回 `:not_handled` 等价于 LPC daemon `return 0`（special.c
  在调用前没有 `notify_fail`，所以此时不输出任何文案，只回提示符）。
  """

  alias Kantele.Character.BornPlayer

  @callback name() :: String.t()
  @callback perform(conn :: term(), skill_id :: String.t(), arg :: String.t()) :: term()

  @doc "特技显示名；模块为 nil 时退回内建表 / id"
  def display_name(nil, skill_id), do: BornPlayer.display_name(skill_id)

  def display_name(module, skill_id) when is_atom(module) do
    cond do
      function_exported?(module, :name, 0) -> to_string(apply(module, :name, []))
      function_exported?(module, :title, 0) -> to_string(apply(module, :title, []))
      true -> BornPlayer.display_name(skill_id)
    end
  rescue
    _ -> skill_id
  end

  @doc "执行特技；无可用 perform 时返回 `:not_handled`"
  def perform(module, conn, skill_id, arg) when is_atom(module) do
    cond do
      function_exported?(module, :perform, 3) ->
        apply(module, :perform, [conn, skill_id, arg])

      function_exported?(module, :perform, 2) ->
        apply(module, :perform, [conn, %{skill: skill_id, arg: arg}])

      true ->
        :not_handled
    end
  end
end
