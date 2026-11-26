defmodule Kantele.World.InquiryHandlers.XuedaoTonsure do
  @moduledoc """
  血刀派 #794：善勇「剃度/出家」问询（kind = "xuedao_tonsure"）。

  LPC 源 `kungfu/class/xuedao/shanyong.c:112-129` `ask_for_join/0`（逐条忠实，不简化）：

      me = this_player();
      if ((string)me->query("class") == "bonze")
              return "阿弥陀佛！你我同是出家人，何故跟贫僧开这等玩笑？\n";
      if ((string)me->query("gender") == "女性")
              return "施主若真心向佛，真是可喜可贺，可惜本寺不收女徒。\n";
      if ((string)me->query("gender") != "男性")
              return "公公别开玩笑了，还是赶快回宫去伺候皇上吧。\n";
      me->set_temp("pending/join_bonze", 1);
      return "阿弥陀佛！善哉！善哉！施主若真心皈依我佛，请跪下(kneel)受戒。\n";

  门序（严格按 LPC）：

  1. class == "bonze" → 出家人玩笑
  2. gender == "女性" → 不收女徒
  3. gender != "男性" → 公公别开玩笑
  4. 通过 → 设 pending/join_bonze，提示跪下(kneel)受戒

  ## 端口映射

  - `query("class")` → `meta.family[:class]`
  - `query("gender")` → `meta.env[:gender]`
  - `set_temp("pending/join_bonze", 1)` → `meta.temp[:pending_join_bonze] = true`
  - `return <text>` → 玩家侧 text 渲染

  ## UCL 配置（善勇 inquiries）

      inquiries = [
        { key = "出家" value = { kind = "xuedao_tonsure" } },
        { key = "剃度" value = { kind = "xuedao_tonsure" } }
      ]
  """

  alias Kantele.Character.CommandView

  def run(conn, _config, data) when is_map(data) do
    character = conn.character

    cond do
      bonze?(character) ->
        tell(conn, "阿弥陀佛！你我同是出家人，何故跟贫僧开这等玩笑？\n")

      gender(character) == "女性" ->
        tell(conn, "施主若真心向佛，真是可喜可贺，可惜本寺不收女徒。\n")

      gender(character) != "男性" ->
        tell(conn, "公公别开玩笑了，还是赶快回宫去伺候皇上吧。\n")

      true ->
        set_pending_and_tell(conn, character)
    end
  end

  def run(conn, _config, _data), do: conn

  # LPC query("class")=="bonze"：class 存于 meta.family.class
  defp bonze?(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) -> Map.get(family, :class) == "bonze"
      _ -> false
    end
  end

  defp gender(character) do
    env = Map.get(character.meta || %{}, :env) || %{}
    Map.get(env, :gender) || Map.get(env, "gender") || "男性"
  end

  defp set_pending_and_tell(conn, character) do
    temp = Map.get(character.meta, :temp) || %{}
    meta = Map.put(character.meta, :temp, Map.put(temp, :pending_join_bonze, true))
    character = %{character | meta: meta}
    conn = Kalevala.Character.Conn.put_character(conn, character)

    tell(conn, "阿弥陀佛！善哉！善哉！施主若真心皈依我佛，请跪下(kneel)受戒。\n")
  end

  defp tell(conn, text) do
    conn
    |> Kalevala.Character.Conn.render(CommandView, "text", %{text: text})
    |> Kalevala.Character.Conn.prompt(CommandView, "prompt", %{})
  end
end
