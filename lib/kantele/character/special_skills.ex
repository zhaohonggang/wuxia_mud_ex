defmodule Kantele.Character.SpecialSkills do
  @moduledoc """
  特技注册表（对应 F2：转世特技系统 SpecialSkills）

  职责**止于注册表**，不改写任何既有读取点——`poison.ex`/`conditions.ex`/
  `feature_damage.ex`/`attributes.ex`/`room.ex` 各自维持现状。
  本模块提供：
    - 静态内建表（转世特技起步 3-5 个）
    - `persistent_term` 运行时热增/热删（转世授予时 `register/2`，无需重启）
    - `daemon/1` 解析 `special <name>` 命令要调用的特技模块
    - `known?/1` / `all/0` 供 `special` 命令查列

  ⚠️ 存储形状决策（用户拍板）：**保持原样**，只增加注册表 + `special` 命令；
  测试通过注入 `attributes["special_skills"]`（字符串 map：`%{"piyi" => true, ...}`，
  与 `poison.ex`/`room.ex` 已用的宿主形状一致）验证。
  """

  @skills %{}
  # 静态表从空起步：目前全库没有任何授予路径（见 F2 决策"只写注册表 + 测试注入"）。
  # 特技由 `register/2` 在运行时热增（转世/成就/师父授予时调用，也可以
  # 通过 `persistent_term` 预热度），加载真实技能模块经 `Kantele.Character.SpecialSkills`。

  @table "kantele_special_skills"

  @doc "读取注册表（静态表 ∪ persistent_term 热增）"
  def all do
    Map.merge(@skills, table())
  end

  @doc "按特技 id 解析模块，`{:ok, mod}` | `:error`"
  def daemon(skill_id) do
    case Map.get(all(), skill_id) do
      nil -> :error
      mod -> {:ok, mod}
    end
  end

  @doc "特技是否已注册"
  def registered?(skill_id), do: Map.has_key?(all(), skill_id)

  @doc """
  运行时热增（转世/成就授予调用）：写入 `persistent_term`，不重启进程。
  覆盖同 id 已有模块。
  """
  def register(skill_id, module) do
    table()
    |> Map.put(skill_id, module)
    |> put_table()
    :ok
  end

  @doc "运行时热删"
  def unregister(skill_id) do
    table()
    |> Map.delete(skill_id)
    |> put_table()
    :ok
  end

  defp table do
    :persistent_term.get(@table, %{})
  end

  defp put_table(map) do
    :persistent_term.put(@table, map)
    map
  end
end
