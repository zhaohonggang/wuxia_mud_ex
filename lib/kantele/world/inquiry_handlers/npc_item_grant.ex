defmodule Kantele.World.InquiryHandlers.NpcItemGrant do
  @moduledoc """
  NPC 持有独特物品发放问询处理器（`kind = "npc_item_grant"`），对应 LPC
  `kungfu/class/kunlun/hetaichong.c` 的 `ask_jian()`/`ask_jing()` 和
  `kungfu/class/kunlun/hezudao.c` 的 `ask_jian()`/`accept_object()`。

  UCL 配置（`inquiries` 的 map 值）：

      value = {
        kind = "npc_item_grant"
        item = "clone_lib:tieqin"        # 发放的 item_id；NPC 持有时发放此物
        npc_carry_key = "clone_lib:tieqin"  # NPC 应持有的 item_id（匹配 meta.carry / inquiry_state）
        match = "tieqin jian"            # present(name, npc) 匹配词；缺省取 item_id 尾段
        replacement_item = "clone_lib:changjian"  # NPC 不持有时的替代物品（如 长剑）
        family = "昆仑派"                # 限门派；缺省不限
        master_id = true                 # 仅本师亲传弟子（family/master_id == npc id）
        allowed_master_ids = ["he zudao", "ban shuxian", "he taichong"]  # 师父白名单
        min_skill_levels = { kunlun_jian = 150, tanqin_jifa = 100 }  # AND：全部达标
        min_skill_levels_or = { qiankun_jian = 150 }  # OR：任一达标（琴≥120 或 棋≥120）
        max_skill_levels = { xunlei_jian = 120 }  # 技能上限（超过即拒）
        count = "tieqin_count"           # 共享库存键（LPC set("tieqin_count", N)）；缺省无限
        success = "..."                  # 发放成功文案
        already = "..."                  # 玩家已有时的文案（自动加敬称）
        family_deny = "..."              # 非本门文案
        master_deny = "..."              # 非嫡传文案
        skill_deny = "..."               # 技能不足文案
        max_skill_deny = "..."           # 技能过高文案
        no_item = "..."                  # NPC 未持有且无替代物品时的文案
        accept_object = true             # NPC 会接受玩家归还此物品（对应 accept_object()）

        # #805/#806 逍遥派扩展
        fallback_items = ["clone_lib:strike_book", "clone_lib:hand_book"]  # 非嫡传的随机回退物品
        fallback_count = "book_count"    # 回退物品独立库存键
        fallback_vision_msg = "..."      # 回退路径独立广播文案
        fallback_success = "..."         # 回退路径独立回话
        fallback_no_item = "..."         # 回退库存耗尽文案
      }

  工作流（玩家侧，由 NpcScriptEvent.inquiry_result/2 调用）：

    1. 门控：family / master_id / allowed_master_ids /
       min_skill_levels (AND 全部达标) /
       min_skill_levels_or (OR 任一达标) /
       max_skill_levels (上限)
    2. 已有时检查：玩家背包中若已有 item，回 already 文案
    3. NPC 持有检查：data.remaining > 0 表示 NPC 尚持有该物品
       - 持有 → 发放 item 给玩家；如配置 replacement_item，NPC 装备替代物品
       - 不持有 → 若有 replacement_item → 发放 replacement_item；否则拒绝
    4. 广播 vision 消息；扣减库存（npc/inquiry_consume，如配置 count）

  新 kind 仅需在 `Kantele.World.InquiryHandlers` 的 `@handlers` 注册，
  无需改动 `NpcAskEvent`。
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4, put_character: 2]

  alias Kantele.Character.CommandView
  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "item")) ->
        conn

      Map.get(data, :asker_id) != character.id ->
        conn

      true ->
        run_for(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, character, config, data) do
    cond do
      # 已有时：玩家背包中已有该物品
      already_has?(character, config) ->
        reply(conn, already_text(config))

      # 门派门控
      family_denied?(character, config) ->
        reply(conn, family_deny_text(config))

      # 师父门控；#806 荀读对同门非嫡传走「盗来的旧书」回退路径，不在此硬拒。
      master_denied?(character, config, data) and not fallback_configured?(config) ->
        reply(conn, master_deny_text(config))

      # 技能上限门（超过即拒，文案独立）
      exceeds_max_skill?(character, config) ->
        reply(conn, max_skill_deny_text(config))

      # min_skill_levels AND 门（任一未达标即拒；支持 per-skill 文案）
      failing_skill = below_min_skill_and_skill(character, config) ->
        reply(conn, min_skill_deny_text(config, failing_skill))

      # min_skill_levels_or OR 门（全部未达标才拒）
      below_min_skill_or?(character, config) ->
        reply(conn, min_skill_or_deny_text(config))

      true ->
        grant_item(conn, character, config, data)
    end
  end

  defp grant_item(conn, character, config, data) do
    # #806 苟读：同门非嫡传走「从少林盗来的旧书」随机回退，不硬拒。
    if fallback_configured?(config) and master_denied?(character, config, data) do
      grant_fallback(conn, config, data)
    else
      item_id = config["item"]
      remaining = Map.get(data, :remaining, :infinity)

      npc_has_item? =
        case remaining do
          :infinity -> true
          n when is_integer(n) -> n > 0
          _ -> true
        end

      if npc_has_item? do
        # NPC 持有独特物品：发放 item 给玩家
        conn =
          give_item(conn, config, data, item_id, Map.get(config, "success") || "拿去吧。")
          |> consume(data, Map.get(config, "count"))
          |> broadcast(config, data, item_id, Map.get(config, "vision_msg"))

        # LPC: ob = new("clone/weapon/changjian"); ob->move(this_object()); ob->wield()
        # NPC 把替代物品（长剑）装备到自己身上——通过 inquiry_equip 事件回发 NPC 进程。
        equip_replacement(conn, config, data)
      else
        # NPC 不再持有：LPC 的 find_object/load_object/environment 持有者遍历分支。
        # 这里以 inquiry_state 计数近似：计数耗尽即「不在我这里」。
        reply(conn, no_item_text(config))
      end
    end
  end

  # LPC goudu.c:125-140：book_count>0 → 随机 strike_book / hand_book + 独立广播。
  defp grant_fallback(conn, config, data) do
    items = config["fallback_items"]
    remaining = Map.get(data, :fallback_remaining, :infinity)

    cond do
      not is_list(items) or items == [] ->
        reply(conn, fallback_no_item_text(config))

      is_integer(remaining) and remaining <= 0 ->
        reply(conn, fallback_no_item_text(config))

      true ->
        item_id = Enum.random(items)

        give_item(conn, config, data, item_id, fallback_success_text(config))
        |> consume(data, Map.get(config, "fallback_count"))
        |> broadcast(config, data, item_id, Map.get(config, "fallback_vision_msg"))
    end
  end

  defp fallback_configured?(config) do
    case Map.get(config, "fallback_items") do
      items when is_list(items) and items != [] -> true
      _ -> false
    end
  end

  # 通知 NPC 进程装备替代物品（对应 LPC 的 replacement->move(me); replacement->wield()）。
  defp equip_replacement(conn, config, data) do
    case {Map.get(config, "replacement_item"), Map.get(data, :npc_pid)} do
      {replacement, pid} when is_binary(replacement) and is_pid(pid) ->
        send(pid, %Kalevala.Event{
          from_pid: self(),
          topic: "npc/inquiry_equip",
          data: %{item_id: replacement}
        })

      _ ->
        conn
    end

    conn
  end

  defp give_item(conn, _config, _data, item_id, success_text) do
    case Items.get(item_id) do
      {:ok, _item} ->
        conn
        |> Helpers.give_item(item_id)
        |> reply(success_text)

      _ ->
        conn
    end
  end

  defp consume(conn, %{npc_pid: pid}, count_key) when is_pid(pid) and is_binary(count_key) do
    send(pid, %Kalevala.Event{
      from_pid: self(),
      topic: "npc/inquiry_consume",
      data: %{count_key: count_key}
    })
    conn
  end

  defp consume(conn, _data, _count_key), do: conn

  defp broadcast(conn, _config, data, item_id, vision_msg) do
    case Map.get(data, :npc_room_id) do
      room_id when is_binary(room_id) ->
        npc_name = Map.get(data, :npc_name) || "对方"
        item_name = item_id_name(item_id)

        template =
          case vision_msg do
            text when is_binary(text) and text != "" -> text
            _ -> "$N给$n一件#{item_name}。"
          end

        # 与 SectMasterGrant.render_msg1 同源：$n=提问者、$N=NPC，
        # 同时归一化 {npc}/{name}；预先替换成实名再广播（clone_lib 逐字归档
        # 允许裸 $n/$N，见 validate_ucl.py 的 object_only 豁免）。
        rendered =
          template
          |> String.replace("$n", to_string(Map.get(data, :asker_name) || ""))
          |> String.replace("$N", npc_name)
          |> String.replace("{npc}", npc_name)
          |> String.replace("{name}", to_string(Map.get(data, :asker_name) || ""))

        Helpers.broadcast(conn, room_id, String.trim_trailing(rendered) <> "\n")

      _ ->
        conn
    end
  end

  defp item_id_name(item_id) when is_binary(item_id) do
    case Items.get(item_id) do
      {:ok, item} -> item.name || item_id
      _ -> item_id |> String.split(":") |> List.last()
    end
  end

  defp item_id_name(_item_id), do: nil

  # === 门控 ===

  defp already_has?(character, config) do
    item_id = config["item"]
    match = Map.get(config, "match") || item_id_suffix(item_id)

    Enum.any?(character.inventory || [], fn instance ->
      instance.item_id == item_id or
        item_id_suffix(instance.item_id) == match or
        Kantele.World.Item.matches?(Kantele.World.Item.instance_item(instance), match)
    end)
  end

  defp item_id_suffix(item_id) when is_binary(item_id) do
    item_id |> String.split(":") |> List.last()
  end

  defp item_id_suffix(_item_id), do: nil

  defp family_denied?(character, config) do
    case {Map.get(config, "allowed_families"), Map.get(config, "family")} do
      {families, _} when is_list(families) and families != [] ->
        not Enum.any?(families, &(&1 == Helpers.family_name(character)))

      {_, family} when is_binary(family) and family != "" ->
        Helpers.family_name(character) != family

      _ ->
        false
    end
  end

  defp master_denied?(character, config, data) do
    case {Map.get(config, "allowed_master_ids"), Map.get(config, "master_id")} do
      {ids, _} when is_list(ids) and ids != [] ->
        not Enum.any?(ids, &own_disciple?(character, &1))

      {_, true} ->
        not own_disciple?(character, Map.get(data, :npc_id))

      {_, "true"} ->
        not own_disciple?(character, Map.get(data, :npc_id))

      _ ->
        false
    end
  end

  defp own_disciple?(%{meta: %{family: family}}, npc_id) when is_map(family) do
    master_id = Map.get(family, :master_id) || Map.get(family, "master_id")
    is_binary(master_id) and master_id == npc_id
  end

  defp own_disciple?(_character, _npc_id), do: false

  defp stats_of(%{meta: %{stats: stats}}) when not is_nil(stats), do: stats
  defp stats_of(_character), do: %{}

  defp skills_of(character), do: Map.get(stats_of(character), :skills) || %{}

  defp skill_level(skills, skill) do
    level = Map.get(skills, skill, 0) || 0
    level =
      if level == 0 and is_binary(skill),
        do: Map.get(skills, String.replace(skill, "_", "-"), 0) || 0,
        else: level
    level
  end

  defp exceeds_max_skill?(character, config) do
    skills = skills_of(character)

    case Map.get(config, "max_skill_levels") do
      levels when is_map(levels) ->
        Enum.any?(levels, fn {skill, max} -> skill_level(skills, skill) > max end)
      _ -> false
    end
  end

  # 返回第一个未达标的 skill（用于 per-skill 文案），达标则 nil。
  defp below_min_skill_and_skill(character, config) do
    skills = skills_of(character)

    case Map.get(config, "min_skill_levels") do
      levels when is_map(levels) ->
        Enum.find_value(levels, fn {skill, min} ->
          if skill_level(skills, skill) < min, do: skill, else: nil
        end)

      _ ->
        nil
    end
  end

  defp below_min_skill_or?(character, config) do
    skills = skills_of(character)

    case Map.get(config, "min_skill_levels_or") do
      levels when is_map(levels) and map_size(levels) > 0 ->
        # OR：任一达标即放行；全部未达标才拒
        not Enum.any?(levels, fn {skill, min} -> skill_level(skills, skill) >= min end)
      _ -> false
    end
  end

  # === 文案 ===

  defp family_deny_text(config),
    do: Map.get(config, "family_deny") || "与本派素无来往，不知此话从何谈起？"

  defp master_deny_text(config),
    do:
      Map.get(config, "master_deny") ||
        "只有我的弟子才配用这个，你别拿去丢脸。"

  # per-skill 文案表 min_skill_denies = { skill = "..." } 优先（LPC 逐 skill 分支不同文案）；
  # 再退通用 min_skill_deny / skill_deny；Skill 键同时兼容下划线/连字符。
  defp min_skill_deny_text(config, failing_skill) do
    per_skill = Map.get(config, "min_skill_denies")

    per_skill_text =
      case {per_skill, failing_skill} do
        {denies, skill} when is_map(denies) and is_binary(skill) ->
          Map.get(denies, skill) ||
            (String.contains?(skill, "_") && Map.get(denies, String.replace(skill, "_", "-"))) ||
            (String.contains?(skill, "-") && Map.get(denies, String.replace(skill, "-", "_")))

        _ ->
          nil
      end

    per_skill_text || Map.get(config, "min_skill_deny") || Map.get(config, "skill_deny") ||
      "你这门功夫还练得不到家，自己下去练练再来吧！"
  end

  defp min_skill_or_deny_text(config),
    do: Map.get(config, "min_skill_or_deny") || Map.get(config, "skill_deny") ||
      "你这门功夫还练得不到家，自己下去练练再来吧！"

  defp max_skill_deny_text(config),
    do: Map.get(config, "max_skill_deny") || "你这方面的造诣已经不浅了，这个不看也罢。"

  defp already_text(config),
    do: Map.get(config, "already") || "你现在身上已经有这样东西了。"

  defp no_item_text(config),
    do: Map.get(config, "no_item") || "抱歉，这件东西我不随身携带，你改日再来吧。"

  defp fallback_success_text(config),
    do: Map.get(config, "fallback_success") || Map.get(config, "success") || "拿去吧。"

  defp fallback_no_item_text(config),
    do: Map.get(config, "fallback_no_item") || "我现在手头没有什么书了。"

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end