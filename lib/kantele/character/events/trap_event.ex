defmodule Kantele.Character.TrapEvent do
  @moduledoc """
  执行出口陷阱的副作用（房间进程判定，角色进程执行）

  房间侧 `Kantele.World.Room` 的 `check_traps/3` 纯算出要做什么，然后
  `send(pid, %Kalevala.Event{topic: "trap/effect", data: %{effects: effects}})`。
  本模块负责真正落地：

    * `{:set_temp, key, value}`  -> LPC `set_temp/3`
    * `{:delete_temp, key}`      -> LPC `delete_temp("bagua/count")`（删单个键）
    * `{:delete_prefix, prefix}` -> LPC `delete_temp("wuxing")`（删整棵子树）
    * `{:force_move, room_id}`   -> LPC `me->move(...)`
    * `{:add, field, delta}`     -> LPC `me->add("neili", -50)` 之类
    * `{:damage, type, amount}`  -> LPC `me->receive_damage("jing", 50)`
    * `{:wound, type, amount}`   -> LPC `me->receive_wound("qi", 50)`
    * `{:faint}`                 -> LPC `me->unconcious()`

  为什么必须由角色进程执行：meta 只有它能安全地改并落盘
  （`Kantele.Character.Records.save/1`）。房间进程只发事件。

  **顺序很重要**：LPC 里 `delete_temp` / `set_temp` / `move` 的先后是有意义的
  （五行迷宫脱困时先 `delete_temp("wuxing")` 再 `move(andao2)`），
  所以这里严格按收到的顺序执行。
  """

  require Logger

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Teleport

  # 真正的模块名是 `Kantele.Feature.Damage`（文件 lib/kantele/feature_damage.ex）。
  # 之前按文件名臆测成 `Kantele.FeatureDamage`，于是八卦阵第一次扣血就把
  # **角色进程**炸了（UndefinedFunctionError / module not available）。
  alias Kantele.Feature.Damage

  @doc "topic: trap/effect -> run/2"
  def run(conn, %{data: %{effects: effects}}) do
    {conn, texts} = apply_effects(conn, effects)

    character = current(conn)
    Records.save(character)

    conn
    |> put_character(character)
    |> render_all(texts)
  end

  # **`put_character/2` 只是把角色暂存进 private.update_character，并不改
  # conn.character**（见 Kalevala.Character.Conn）。所以连续施加多个副作用时，
  # 每次都必须读「暂存后的那个」，否则后一条会拿到旧角色、覆盖掉前面几条
  # 的成果 —— 五行迷宫脱困那三步（set_temp -> delete_prefix -> force_move）
  # 就会只剩最后一步生效。Teleport.teleport/2 也是这么读的。
  defp current(conn), do: conn.private.update_character || conn.character

  # 统一用 put_character（暂存语义），别直接改 conn.character
  defp stage(conn, character), do: put_character(conn, character)

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
    meta = PlayerMeta.put_temp(current(conn).meta, key, value)
    {stage(conn, %{current(conn) | meta: meta}), texts}
  end

  defp apply_effect(conn, {:delete_temp, key}, texts) do
    # LPC delete_temp("bagua/count") —— 只删这一个键。
    # 与下面的 delete_prefix（delete_temp("bagua")，删整棵子树）是两回事。
    meta = current(conn).meta
    {stage(conn, %{current(conn) | meta: PlayerMeta.delete_temp(meta, key)}), texts}
  end

  defp apply_effect(conn, {:delete_prefix, prefix}, texts) do
    # LPC delete_temp("wuxing") 删的是整棵子树，不是单个键。
    # PlayerMeta.delete_temp/2 只删精确键，所以这里自己按前缀过滤。
    meta = current(conn).meta

    kept =
      meta.temp
      |> Enum.reject(fn {k, _} -> String.starts_with?(k, prefix) end)
      |> Map.new()

    # 注意暂存的是**角色**（current(conn)），不是 meta ——
    # put_character/2 的第二个参数是角色本身。
    {stage(conn, %{current(conn) | meta: %{meta | temp: kept}}), texts}
  end

  defp apply_effect(conn, {:add, field, delta}, texts) do
    # LPC me->add("neili", -50) / add("combat_exp", -50)
    meta = current(conn).meta

    new_meta =
      case field do
        :neili ->
          v = Map.get(meta.vitals, :neili, 0)
          %{meta | vitals: %{meta.vitals | neili: max(0, v + delta)}}

        :combat_exp ->
          s = meta.stats
          %{meta | stats: %{s | combat_exp: max(0, Map.get(s, :combat_exp, 0) + delta)}}

        other ->
          Logger.warning("陷阱副作用未知的 add 字段：#{inspect(other)}")
          meta
      end

    {stage(conn, %{current(conn) | meta: new_meta}), texts}
  end

  defp apply_effect(conn, {:damage, type, amount}, texts) do
    # LPC me->receive_damage("jing", 50)
    # 注意返回的是 {:ok, character} | {:error, reason}，不是裸角色 ——
    # 直接把返回值当角色暂存会把元组塞进 put_character/2。
    {apply_feature(conn, &Damage.receive_damage(&1, type, amount), :receive_damage), texts}
  end

  defp apply_effect(conn, {:wound, type, amount}, texts) do
    # LPC me->receive_wound("qi", 50)
    {apply_feature(conn, &Damage.receive_wound(&1, type, amount), :receive_wound), texts}
  end

  defp apply_effect(conn, {:faint}, texts) do
    # LPC me->unconcious()
    {apply_feature(conn, &Damage.unconcious/1, :unconcious), texts}
  end

  # Kantele.Feature.Damage 的函数统一返回 {:ok, character} | {:error, reason}。
  # 这里解开：成功就暂存新角色，失败就**保持原状并记日志** ——
  # 陷阱不该因为扣血失败就把玩家进程搞崩。
  defp apply_feature(conn, fun, name) do
    case fun.(current(conn)) do
      {:ok, character} ->
        stage(conn, character)

      {:error, reason} ->
        Logger.warning("陷阱副作用 #{name} 失败：#{inspect(reason)}")
        conn

      other ->
        Logger.warning("陷阱副作用 #{name} 返回了预期外的值：#{inspect(other)}")
        conn
    end
  end

  defp apply_effect(conn, {:force_move, room_id}, texts) do
    # LPC me->move(__DIR__"andao2")
    #
    # 不能只改 conn.character.room_id —— 那样只是「改了状态」而不是「移动」：
    # 房间频道订阅还在旧房间、没发 leave/enter、客户端不重新 look，
    # 于是玩家看到的是「提示说掉进僧监、人还在原地」。
    # Teleport.teleport/2 复用了 MoveEvent.commit 的两段 Movement 事件机制。
    {Teleport.teleport(conn, room_id), texts}
  end

  defp apply_effect(conn, {:text, text}, texts) do
    {conn, texts ++ [text]}
  end

  defp apply_effect(conn, effect, texts) do
    Logger.warning("未知的陷阱副作用：#{inspect(effect)}")
    {conn, texts}
  end
end