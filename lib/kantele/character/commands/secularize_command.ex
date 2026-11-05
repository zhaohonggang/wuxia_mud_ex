defmodule Kantele.Character.SecularizeCommand do
  @moduledoc """
  还俗命令：`secularize` / `huansu`

  对应 LPC `cmds/std/secularize.c`。放弃出家生活，返回俗人身份。

  ## 移植范围（LPC 门控逐条落地）

  1. `query("class") != "bonze"` → 非出家人，静默不处理（LPC return 0）；
  2. `family/family_name` 在 少林派/峨嵋派/大轮寺/血刀门 → 出家门派，不能擅自还俗；
  3. `query_temp("pending/secularize")` 已设 → 执行还俗：删除 class、广播 rumor、提示完成；
  4. 否则 → 设 `pending/secularize`，提示「再输入一次这个命令」等待确认。

  ## 与 LPC 的差异（引擎模型所限）

  - Ex 无 `query("class")` 顶层字段，class 存于 `meta.family.class`（见
    `FamilyEvent.put_class/2`）；未入门派（family 为 nil）视为非出家人，静默不处理。
  - LPC `CHANNEL_D->do_channel(..., "rumor", ...)` 映射为
    `Kantele.Communication.announce("rumor", text)`；该函数吞掉异常，调用方不受影响。
  - LPC `set_name()` / `purename` 姓名重设机制在 Ex 中未建模，该步骤省略，
    已在本 moduledoc 记录差异。
  - `query_temp("pending/secularize")` 映射为 `meta.temp[:pending_secularize]`。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Communication

  @monastic_families ["少林派", "峨嵋派", "大轮寺", "血刀门"]

  def run(conn, %{}) do
    character = conn.character
    family = Map.get(character.meta || %{}, :family)

    cond do
      # 非出家人（无门派或 class 非 bonze）：LPC return 0，静默不处理
      not bonze?(family) ->
        conn

      # 出家门派弟子，不可擅自还俗
      monastic?(family) ->
        render_error(conn, "你身在出家门派，不能擅自还俗！\n")

      # 已确认还俗（pending 标志已设）
      pending?(character) ->
        execute(conn, character)

      # 首次输入：设置 pending 标志，等待再次确认
      true ->
        set_pending(conn, character)
    end
  end

  def run(conn, %{"rest" => _rest}) do
    # LPC secularize 忽略参数，与裸命令同处理
    run(conn, %{})
  end

  # ---- 内部 ----

  defp bonze?(nil), do: false
  defp bonze?(family), do: Map.get(family, :class) == "bonze"

  defp monastic?(nil), do: false
  defp monastic?(family), do: Map.get(family, :name) in @monastic_families

  defp pending?(character) do
    temp = Map.get(character.meta || %{}, :temp) || %{}
    Map.get(temp, :pending_secularize) == true
  end

  defp set_pending(conn, character) do
    temp = Map.get(character.meta, :temp) || %{}
    meta = Map.put(character.meta, :temp, Map.put(temp, :pending_secularize, true))
    character = %{character | meta: meta}
    conn = put_character(conn, character)

    render_error(
      conn,
      "你决定要还俗吗？这可是大事，如果你下了决心，那就再输入一次这个命令。\n"
    )
  end

  defp execute(conn, character) do
    # 删除 class（LPC delete("class") → meta.family.class 设为 nil）
    family = Map.get(character.meta, :family) || %{}
    family = Map.delete(family, :class)

    meta =
      character.meta
      |> Map.put(:family, family)
      |> Map.update!(:temp, fn temp -> Map.delete(temp, :pending_secularize) end)

    character = %{character | meta: meta}
    conn = put_character(conn, character)

    # 广播 rumor（LPC CHANNEL_D->do_channel(this_object(), "rumor", ...））
    broadcast_rumor(character)

    render_error(conn, "你摸了摸脑袋，叹了口气，决定回尘世好好享受享受。\n")
  end

  defp broadcast_rumor(character) do
    text = "听说#{character.name}厌倦了清贫枯燥的出家生活，决定还俗。\n"

    case Communication.announce("rumor", text) do
      :ok -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
