defmodule Kantele.World.InquiryHandlers.CitySmithBack do
  @moduledoc """
  中原铁匠「血海无边」问询（`kind = "city_smith_back"`），对应 LPC
  `d/city/npc/smith.c` 的 `ask_back()`——血刀弟子从西域密道回中原的入口。

  LPC 原文（逐段对齐，颜色宏 HIY/CYN/HIC/NOR 剥离）：

      me = this_player();
      if (me->query("family/family_name") != "血刀门")
      {
              message_vision("$N自顾自的干活，好象没有听见$n在说什么。\\n",
                             this_object(), me);
              return -1;
      }
      message_sort("\\n$N猛地抬起头来，瞪着双目上上下下打量了$n"
                   "好一会儿，微微点了点头。$N随即放下手中的活"
                   "计，低声道：“都等你好长时间了，快跟我来。”说罢便领"
                   "着$p朝后厅走去。\\n\\n", this_object(), me);
      me->move("/d/city/xdmidao4");
      tell_object(me, name() + "说道：就是这里，你一直走南就行了。\\n"
                    + name() + "说完便急急忙忙赶了回去。\\n");

  ## 端口映射

  - `message_vision` / `message_sort` 均交 `InquiryHandlers.MessageSort`：
    提问者看到「你」版，旁观者看到真实姓名版，`$p` 由 MessageSort 按
    `you` 的 `gender_self` / 姓名分别渲染（与 LPC 一致）。
  - `me->move()` → `Kantele.Character.Teleport.teleport/2`（目标房间由 UCL
    `target_room` 给出，缺省 `city:xdmidao4`）。
  - `tell_object` → 玩家侧私有 render（两段，顺序与 LPC 相同）。
  - LPC `return -1` 只表示「问询已消费」，无附加文案，ex 侧不输出。

  ## UCL 配置

      { key = "血海无边" value = { kind = "city_smith_back"
                                   target_room = "city:xdmidao4"
                                   family = "血刀门" } }
  """

  alias Kantele.Character.CommandView
  alias Kantele.Character.Teleport
  alias Kantele.World.InquiryHandlers.MessageSort
  alias Kantele.World.NpcActions.Helpers

  @default_family "血刀门"
  @default_target_room "city:xdmidao4"

  # LPC `message_vision` 拒绝文案
  @deny_vision "$N自顾自的干活，好象没有听见$n在说什么。\n"

  # LPC `message_sort` 长文案；$p 是 LPC gender_self/name 占位，由
  # MessageSort 按提问者/旁观者分别渲染。
  @success_vision "\n$N猛地抬起头来，瞪着双目上上下下打量了$n好一会儿，微微点了点头。$N随即放下手中的活计，低声道：“都等你好长时间了，快跟我来。”说罢便领着$p朝后厅走去。\n\n"

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    if Map.get(data, :asker_id) != character.id do
      conn
    else
      if Helpers.family_name(character) == family(config) do
        pass(conn, config, data)
      else
        sort(conn, data, @deny_vision)
      end
    end
  end

  def run(conn, _config, _data), do: conn

  defp pass(conn, config, data) do
    npc_name = Map.get(data, :npc_name) || "铁匠"

    conn
    |> sort(data, @success_vision)
    |> Teleport.teleport(target_room(config))
    |> tell("#{npc_name}说道：就是这里，你一直走南就行了。\n")
    |> tell("#{npc_name}说完便急急忙忙赶了回去。\n")
  end

  # 原样把 LPC 模板交给 MessageSort，不预替换 $N/$n/$p。
  defp sort(conn, data, template) do
    MessageSort.run(conn, %{"text" => template}, data)
  end

  defp tell(conn, text) do
    conn
    |> Kalevala.Character.Conn.render(CommandView, "text", %{text: text})
    |> Kalevala.Character.Conn.prompt(CommandView, "prompt", %{})
  end

  defp family(config), do: Map.get(config, "family") || @default_family

  defp target_room(config) do
    case Map.get(config, "target_room") do
      room when is_binary(room) and byte_size(room) > 0 -> room
      _ -> @default_target_room
    end
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
