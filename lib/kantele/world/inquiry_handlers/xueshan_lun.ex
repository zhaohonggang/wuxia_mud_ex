defmodule Kantele.World.InquiryHandlers.XueshanLun do
  @moduledoc """
  日月金轮问询（`kind = "xueshan_lun"`）—— 金轮法王「日月金轮」。

  LPC 源 `kungfu/class/xueshan/fawang.c:774-834` `ask_lun/0`（逐条忠实，不简化）：

      me = this_player();
      if (me->is_good()) {
        if (family == "大轮寺")
          message_vision("$N大怒，对$n道：“你身为我大轮寺弟子，反而学起"
                         "假仁假义来了，给我滚吧！”", this_object(), me);
        else
          message_vision("$N大怒，对$n喝道：“你是什么人？居然敢贪图我的"
                         "随身利器，活得不耐烦了？”", this_object(), me);
        return 1;
      }
      if (family != "大轮寺")
        return "日月金轮是我的随身兵器，你打听它干什么？";
      if (family/master_id != query("id"))
        return "只有我的弟子才配使用金轮，你还是自己下去练练吧。";
      if (shen > -50000)
        return "哼！你既然如此侠义，还是别用金轮的好。";

      ob = find_object(JINLUN); if (!ob) ob = load_object(JINLUN);
      owner = environment(ob);
      while (owner) { if (owner->is_character() || !environment(owner)) break;
                      owner = environment(owner); }
      if (owner == me)           return "怎么？日月金轮不就是你拿着在用吗？";
      if (objectp(owner) && owner != this_object()) {
        if (!owner->is_character()) return "你来晚了一步，日月金轮现在不在我手中。";
        if (owner->family == "大轮寺")
          return "金轮现在暂时是你同门师兄" + name + "在用，你要用就去找他吧。";
        else
          return "我的日月金轮现在落在" + name + "手中，你去把他做了，把金轮抢回来！";
      }
      ob->move(this_object());
      message_vision("$N微微笑道：念在你平时刻苦努力，我这柄金轮你就拿去用吧。",
                     this_object(), me);
      command("give riyue jinlun to " + me->query("id"));
      return 1;

  门序（严格按 LPC）：

  1. `is_good()` = `shen > 500 || shen_type == 1`（框架仅建模 shen，见下），
     命中后只播 `message_vision`（`$N`=法王、`$n`=提问者），不返回文字。
  2. 非大轮寺 → 「日月金轮是我的随身兵器…」
  3. 非法王嫡传（`family/master_id != npc id`）→ 「只有我的弟子才配…」
  4. `shen > -50000` → 「哼！你既然如此侠义…」
  5. 持有者遍历（NPC 进程 `zhihuan_owner` 同款，见 `npc_shop_event.ex`）：
     - `owner == asker` → 「怎么？日月金轮不就是你拿着在用吗？」
     - `owner` 非角色 → 「你来晚了一步…」
     - `owner` 同门 → 「金轮现在暂时是你同门师兄{name}在用…」
     - `owner` 外人 → 「我的日月金轮现在落在{name}手中，你去把他做了…」
  6. 法王手中（缺省）→ give `clone_lib:jinlun` + 微笑 `message_vision`。

  ## 端口映射 / 近似（均已登记进度文档）

  - `is_good()` 的 `shen_type == 1` 分量：框架仅建模 `shen`（同 performs 的
    既有约定，见 `lingshe_zhangfa/wanshi.ex`），故取 `shen > 500`。
  - `find_object/load_object/environment` 全局持有者链：同 #807 无崖子神仙环，
    ex 无全局对象环境链，由 NPC 进程按「提问者背包 → 法王背包 → 同房间角色
    背包 → 房间地面 → 法王」顺序近似（纯增量 `data.owner`）。
  - `ob->move(this_object())` + `command("give ...")`：give_item 直接发到玩家背包。
  - `$N`=法王（NPC）、`$n`=提问者（玩家）：与 #807 `broadcast_ring_vision`
    同源，预先实名替换后广播。

  ## UCL 配置（金轮法王 inquiries）

      { key = "日月金轮" value = {
        kind = "xueshan_lun"
        item = "clone_lib:jinlun"
      } }
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers

  @angry_same "金轮法王大怒，对{name}道：“你身为我大轮寺弟子，反而学起假仁假义来了，给我滚吧！”"
  @angry_other "金轮法王大怒，对{name}喝道：“你是什么人？居然敢贪图我的随身利器，活得不耐烦了？”"
  @grant_vision "金轮法王微微笑道：念在你平时刻苦努力，我这柄金轮你就拿去用吧。"

  def run(conn, config, data) when is_map(config) and is_map(data) do
    case Map.get(data, :asker_id) do
      asker_id when asker_id == conn.character.id -> run_for(conn, config, data)
      _ -> conn
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, config, data) do
    character = current(conn)

    cond do
      is_good?(character) ->
        angry_text = if dailun?(character), do: @angry_same, else: @angry_other
        broadcast_room(conn, data, angry_text)

      not dailun?(character) ->
        reply(conn, "日月金轮是我的随身兵器，你打听它干什么？")

      master_denied?(character, data) ->
        reply(conn, "只有我的弟子才配使用金轮，你还是自己下去练练吧。")

      shen_too_high?(character) ->
        reply(conn, "哼！你既然如此侠义，还是别用金轮的好。")

      true ->
        handle_owner(conn, config, data)
    end
  end

  # 持有者链（NPC 进程产出，见 npc_shop_event.ex zhihuan_owner）：
  #   :asker     提问者正拿着 → 已在手中
  #   :object    非角色对象持有（地上/容器） → 不在法王手中
  #   :character 其他角色持有 → 同门借用 / 敌人抢夺
  #   :npc / nil 法王持有（缺省） → 发放
  defp handle_owner(conn, config, data) do
    case Map.get(data, :owner) do
      %{kind: :asker} ->
        reply(conn, "怎么？日月金轮不就是你拿着在用吗？")

      %{kind: :object} ->
        reply(conn, "你来晚了一步，日月金轮现在不在我手中。")

      %{kind: :character} = owner ->
        name = Map.get(owner, :name) || "某人"

        text =
          if dailun_owner?(owner) do
            "金轮现在暂时是你同门师兄#{name}在用，你要用就去找他吧。"
          else
            "我的日月金轮现在落在#{name}手中，你去把他做了，把金轮抢回来！"
          end

        reply(conn, text)

      _ ->
        grant(conn, config, data)
    end
  end

  defp grant(conn, config, data) do
    item_id = Map.get(config, "item") || "clone_lib:jinlun"

    case Items.get(item_id) do
      {:ok, _item} ->
        conn
        |> Helpers.give_item(item_id)
        |> broadcast_room(data, @grant_vision)

      _ ->
        conn
    end
  end

  # === 门控 ===

  # LPC is_good() = query("shen") > 500 || query("shen_type") == 1；
  # 框架仅建模 shen（同 performs 既有约定），取 shen > 500。
  defp is_good?(%{meta: %{stats: stats}}) when not is_nil(stats),
    do: (Map.get(stats, :shen) || 0) > 500

  defp is_good?(_character), do: false

  # LPC shen > -50000（上界；不是 min_shen）。shen 存 meta.stats.shen。
  defp shen_too_high?(%{meta: %{stats: stats}}) when not is_nil(stats),
    do: (Map.get(stats, :shen) || 0) > -50_000

  defp shen_too_high?(_character), do: false

  defp dailun?(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) -> Kantele.Character.Family.name(family) == "大轮寺"
      _ -> false
    end
  end

  # LPC family/master_id != query("id")：仅法王亲传弟子。
  defp master_denied?(character, data) do
    master_id =
      case Map.get(character.meta || %{}, :family) do
        family when is_map(family) ->
          Map.get(family, :master_id) || Map.get(family, "master_id")

        _ ->
          nil
      end

    case Map.get(data, :npc_id) do
      npc_id when is_binary(npc_id) -> not (is_binary(master_id) and master_id == npc_id)
      _ -> true
    end
  end

  defp dailun_owner?(%{family: family}) when is_binary(family), do: family == "大轮寺"
  defp dailun_owner?(_owner), do: false

  # === 渲染 ===

  # message_vision("$N...$n...", this_object(), me)：$N=法王、$n=提问者。
  # 与 #807 broadcast_ring_vision 同源：预先实名替换（不依赖 VisionView 的
  # "$N→你" 归一化，因为此处行动者是 NPC 而非玩家）。
  defp broadcast_room(conn, data, template) do
    case Map.get(data, :npc_room_id) do
      room_id when is_binary(room_id) ->
        npc_name = Map.get(data, :npc_name) || "金轮法王"
        asker_name = to_string(Map.get(data, :asker_name) || "")

        rendered =
          template
          |> String.replace("$N", npc_name)
          |> String.replace("$n", asker_name)
          |> String.replace("{npc}", npc_name)
          |> String.replace("{name}", asker_name)

        Helpers.broadcast(conn, room_id, String.trim_trailing(rendered) <> "\n")

      _ ->
        conn
    end
  end

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
