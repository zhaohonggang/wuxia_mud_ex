defmodule Kantele.Character.TrapEvent do
  @moduledoc """
  执行出口陷阱的副作用（房间进程判定，角色进程执行）

  房间侧 `Kantele.World.Room` 的 `check_traps/3` 纯算出要做什么，然后
  `send(pid, %Event{topic: "trap/effect", data: %{effects: effects}})`。
  本模块负责真正落地：

    * `{:set_temp, key, value}`     -> `PlayerMeta.put_temp/3`
    * `{:delete_prefix, prefix}`    -> LPC `delete_temp("wuxing")`（删整棵子树）
    * `{:force_move, room_id}`      -> LPC `me->move(...)`，改 room_id 并广播离/进
    * `{:damage, type, amount}`     -> `Kantele.FeatureDamage.receive_damage/4`
    * `{:wound, type, amount}`      -> `Kantele.FeatureDamage.receive_wound/4`
    * `{:add, field, delta}`        -> LPC `me->add("neili", -50)` 之类
    * `{:faint}`                    -> LPC `me->unconcious()`

  为什么必须由角色进程执行：meta 只有它能安全地改并落盘
  （`Kantele.Character.Records.save/1`）。房间进程只发事件，不碰 meta。

  **顺序很重要**：LPC 里 `delete_temp` / `set_temp` / `move` 的先后是有意义的
  （例如五行迷宫脱困时先 `delete_temp("wuxing")` 再 `move(andao2)`），
  所以这里严格按收到的顺序执行。
  """

  use Kalevala.Character.Event

  require Logger

  import Kalevala.Character.Conn

  alias Kantele.Character.Records
  alias Kantele.Character.CommandView
  alias Kantele.FeatureDamage

  @impl true
  def handle("trap/effect", conn, %{data: %{effects: effects}}) do
    {conn, texts} = apply_effects(conn, effects)

    conn
    |> persist()
    |> render_all(texts)
  end

  defp persist(conn) do
    Records.save(conn.character)
    put_character(conn, conn.character)
  end

  defp render_all(conn, texts) do
    Enum.reduce(texts, conn, fn text, acc ->
      render(acc, CommandView, "text", %{text: text})
    end)
  end

  # ---- 逐条执行，返回 {conn, 累积的提示文本} ----

  defp apply_effects(conn, effects) do
    Enum.reduce(effects, {conn, []}, fn effect, {conn, texts} ->
      apply_effect(conn, effect, texts)
    end)
  end

  defp apply_effect(conn, {:set_temp, key, value}, texts) do
    # LPC set_temp/3
    character = Kantele.Character.PlayerMeta.put_temp(conn.character.meta, key, value)
    {put_character(conn, character), texts}
  end

  defp apply_effect(conn, {:delete_prefix, prefix}, texts) do
    # LPC delete_temp("wuxing") 删的是整棵子树，不是单个键。
    # PlayerMeta.delete_temp/2 只删精确键，所以这里自己按前缀过滤。
    meta = conn.character.meta
    kept = meta.temp |> Map.to_list() |> Enum.reject(fn {k, _} -> String.starts_with?(k, prefix) end)
    character = %{meta | temp: Map.new(kept)}
    {put_character(conn, character), texts}
  end

  defp apply_effect(conn, {:add, field, delta}, texts) do
    # LPC me->add("neili", -50) / add("combat_exp", -50)
    character =
      case field do
        :neili ->
          v = Map.get(conn.character.meta.vitals, :neili, 0)
          %{conn.character | meta: %{conn.character.meta | vitals: %{conn.character.meta.vitals | neili: max(0, v + delta)}}}

        :combat_exp ->
          s = conn.character.meta.stats
          %{conn.character | meta: %{conn.character.meta | stats: %{s | combat_exp: max(0, Map.get(s, :combat_exp, 0) + delta)}}}

        other ->
          Logger.warning("陷阱副作用未知的 add 字段：#{inspect(other)}")
          conn.character
      end

    {put_character(conn, character), texts}
  end

  defp apply_effect(conn, {:damage, type, amount}, texts) do
    # LPC me->receive_damage("jing", 50)
    character = FeatureDamage.receive_damage(conn.character, type, amount)
    {put_character(conn, character), texts}
  end

  defp apply_effect(conn, {:wound, type, amount}, texts) do
    # LPC me->receive_wound("qi", 50)
    character = FeatureDamage.receive_wound(conn.character, type, amount)
    {put_character(conn, character), texts}
  end

  defp apply_effect(conn, {:faint}, texts) do
    # LPC me->unconcious()
    character = FeatureDamage.unconcious(conn.character)
    {put_character(conn, character), texts}
  end

  defp apply_effect(conn, {:force_move, room_id}, texts) do
    # LPC me->move(__DIR__"andao2")
    character = %{conn.character | room_id: room_id}
    {put_character(conn, character), texts}
  end

  defp apply_effect(conn, {:text, text}, texts) do
    {conn, texts ++ [text]}
  end

  defp apply_effect(conn, effect, texts) do
    Logger.warning("未知的陷阱副作用：#{inspect(effect)}")
    {conn, texts}
  end
end