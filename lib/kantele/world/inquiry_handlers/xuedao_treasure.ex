defmodule Kantele.World.InquiryHandlers.XuedaoTreasure do
  @moduledoc """
  血刀派 #793：血刀老祖「血刀/血刀经」问询（kind = "xuedao_dao"/"xuedao_book"）。

  LPC 源 `kungfu/class/xuedao/laozu.c:697-823`：

  ask_dao()（kind = "xuedao_dao"）：

    1. is_good() → message_vision 怒斥（本门/外人分支），return 1
    2. family != "血刀门" → return "血刀是我血刀门至宝，你打听它干什么？"
    3. master_id != query("id") → return "只有我的弟子才能用血刀，你还是自己下去练练吧。"
    4. shen > -50000 → return "你邪气不重，使用不了血刀。"
    5. holder → owner==me / :object / :character(同门/外人) / :npc(发放)
    6. 发放 clone_lib:xuedao + message_vision

  ask_book()（kind = "xuedao_book"）：

    1. family != "血刀门" → return "哪里来的野种，竟敢打我血刀门的主意？"
    2. master_id != query("id") → return "你又不是老夫的弟子，跟老夫啰嗦些什么？"
    3. shen > -50000 → return "你倒是学起假仁假义来了，让老夫如何能相信你？"
    4. combat_exp < 300000 → return "你现在经验太浅，这本血刀经你还看不懂。"
    5. query_skill("xuedao-dafa", 1) > 179 → return "...血刀经对你起不了什么作用。"
    6. holder → owner==me / :object / :character(同门/外人) / :npc(发放)
    7. 发放 clone_lib:xuedao_jing + message_vision

  持有者状态由 NPC 进程 `zhihuan_owner/3` 近似（同 xueshan_lun）：
    提问者背包 → 老祖背包 → 同房间角色背包 → 房间地面 → 老祖
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family
  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers

  # === 文案常量 ===

  # ask_dao is_good 怒斥（message_vision → 房间广播）
  @dao_angry_same "$N大怒，对$n道：“你身为我血刀门弟子，反而学起假仁假义来了，居然还有脸问我要本门之宝？”"
  @dao_angry_other "$N大怒，对$n喝道：“你是什么人？居然敢贪图本门至宝，你再问看我不宰了你！”"

  # ask_dao 私有返回（tell_object → 仅提问者可见）
  @dao_not_family "血刀是我血刀门至宝，你打听它干什么？"
  @dao_not_master "只有我的弟子才能用血刀，你还是自己下去练练吧。"
  @dao_shen_too_high "你邪气不重，使用不了血刀。"
  @dao_in_hand "他奶奶的，本门的血刀现在不是你拿着在用吗？"
  @dao_not_here "你来晚了一步，血刀现在不在我手中。"
  @dao_grant_vision "$N哈哈一笑，道：好，乖徒儿，这柄血刀你就拿去，多杀几个正派人士，扬扬咱们的威风！"

  # ask_book 私有返回（tell_object → 仅提问者可见）
  @book_not_family "哪里来的野种，竟敢打我血刀门的主意？"
  @book_not_master "你又不是老夫的弟子，跟老夫啰嗦些什么？"
  @book_shen_too_high "你倒是学起假仁假义来了，让老夫如何能相信你？"
  @book_exp_too_low "你现在经验太浅，这本血刀经你还看不懂。"
  @book_skill_too_high "你的血刀大法火候已经很深了，血刀经对你起不了什么作用。"
  @book_in_hand "我血刀门的宝经不就是你拿着在看吗？"
  @book_not_here "…嗯…血刀经现在不在我手里。"
  @book_grant_vision "$N点头道：这本血刀经你就拿去看吧，可要仔细阅读。"

  def run(conn, config, data) when is_map(config) and is_map(data) do
    case Map.get(data, :asker_id) do
      asker_id when asker_id == conn.character.id -> run_for(conn, config, data)
      _ -> conn
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, config, data) do
    character = current(conn)
    kind = Map.get(config, "kind")

    cond do
      # ask_dao 独有：is_good() 前门，message_vision 房间广播，return 1
      kind == "xuedao_dao" and is_good?(character) ->
        angry = if xuedao_men?(character), do: @dao_angry_same, else: @dao_angry_other
        broadcast_room(conn, data, angry)

      # 门派门
      not xuedao_men?(character) ->
        reply(conn, if(kind == "xuedao_dao", do: @dao_not_family, else: @book_not_family))

      # 师父门（master_id）
      master_denied?(character, data) ->
        reply(conn, if(kind == "xuedao_dao", do: @dao_not_master, else: @book_not_master))

      # 杀气门（shen > -50000 → 不够邪）
      shen_too_high?(character) ->
        reply(conn, if(kind == "xuedao_dao", do: @dao_shen_too_high, else: @book_shen_too_high))

      # ask_book 独有：经验门
      kind == "xuedao_book" and exp_too_low?(character) ->
        reply(conn, @book_exp_too_low)

      # ask_book 独有：血刀大法火候门
      kind == "xuedao_book" and skill_too_high?(character) ->
        reply(conn, @book_skill_too_high)

      true ->
        handle_owner(conn, config, data, kind)
    end
  end

  # 持有者状态分支（LPC owner 遍历近似，见 npc_shop_event.ex zhihuan_owner）
  defp handle_owner(conn, config, data, kind) do
    case Map.get(data, :owner) do
      %{kind: :asker} ->
        reply(conn, if(kind == "xuedao_dao", do: @dao_in_hand, else: @book_in_hand))

      %{kind: :object} ->
        reply(conn, if(kind == "xuedao_dao", do: @dao_not_here, else: @book_not_here))

      %{kind: :character} = owner ->
        text = owner_text(owner, kind)
        reply(conn, text)

      _ ->
        grant(conn, config, data, kind)
    end
  end

  defp owner_text(%{family: family} = owner, kind) do
    name = Map.get(owner, :name) || "某人"
    same_family = family == "血刀门"

    if kind == "xuedao_dao" do
      if same_family do
        "血刀现在暂时是你同门师兄#{name}在用，你要用就去找他吧。"
      else
        "本门的血刀现在落在#{name}手中，你去把他做了，把血刀抢回来！"
      end
    else
      if same_family do
        "血刀经现在暂时被你同门的#{name}取去看了，你要看就去找他吧。"
      else
        "我血刀门的宝经现在落在了#{name}手中，你去把它夺回来吧！"
      end
    end
  end

  defp owner_text(_owner, _kind), do: nil

  defp grant(conn, _config, data, kind) do
    item_id = case kind do
      "xuedao_dao" -> "clone_lib:xuedao"
      "xuedao_book" -> "clone_lib:xuedao_jing"
      _ -> nil
    end

    cond do
      not is_binary(item_id) ->
        conn

      true ->
        case Items.get(item_id) do
          {:ok, _item} ->
            conn
            |> Helpers.give_item(item_id)
            |> broadcast_grant(data, kind)

          _ ->
            conn
        end
    end
  end

  # === 门控 ===

  # LPC is_good() ≈ shen > 500（框架仅建模 shen）
  defp is_good?(%{meta: %{stats: stats}}) when not is_nil(stats),
    do: (Map.get(stats, :shen) || 0) > 500

  defp is_good?(_character), do: false

  # LPC shen > -50000（上界；不是 min_shen）
  defp shen_too_high?(%{meta: %{stats: stats}}) when not is_nil(stats),
    do: (Map.get(stats, :shen) || 0) > -50_000

  defp shen_too_high?(_character), do: false

  # ask_book：combat_exp < 300000 → 经验太浅
  defp exp_too_low?(%{meta: %{stats: stats}}) when not is_nil(stats),
    do: (Map.get(stats, :combat_exp) || 0) < 300_000

  defp exp_too_low?(_character), do: false

  # ask_book：query_skill("xuedao-dafa", 1) > 179 → 火候太深
  defp skill_too_high?(character) do
    skills = Map.get(character.meta.stats || %{}, :skills) || %{}
    (Map.get(skills, "xuedao-dafa", 0) || 0) > 179
  end

  defp skill_too_high?(_character), do: false

  defp xuedao_men?(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) -> Family.name(family) == "血刀门"
      _ -> false
    end
  end

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

  # === 渲染 ===

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  # message_vision("$N...$n...", this_object(), me)：$N=老祖、$n=提问者。
  # 预先实名替换（不依赖 VisionView 的 "$N→你" 归一化，因为此处行动者是 NPC 而非玩家）。
  defp broadcast_room(conn, data, template) do
    case Map.get(data, :npc_room_id) do
      room_id when is_binary(room_id) ->
        npc_name = Map.get(data, :npc_name) || "血刀老祖"
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

  defp broadcast_grant(conn, data, kind) do
    case Map.get(data, :npc_room_id) do
      room_id when is_binary(room_id) ->
        npc_name = Map.get(data, :npc_name) || "血刀老祖"
        asker_name = to_string(Map.get(data, :asker_name) || "")
        vision = if(kind == "xuedao_dao", do: @dao_grant_vision, else: @book_grant_vision)

        rendered =
          vision
          |> String.replace("$N", npc_name)
          |> String.replace("$n", asker_name)
          |> String.replace("{npc}", npc_name)
          |> String.replace("{name}", asker_name)

        Helpers.broadcast(conn, room_id, String.trim_trailing(rendered) <> "\n")

      _ ->
        conn
    end
  end
end
