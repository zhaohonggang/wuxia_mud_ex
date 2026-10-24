defmodule Kantele.World.InquiryHandlers.GiveItem do
  @moduledoc """
  LPC `ask_me_1` / `ask_me_2` 类「问一句、发一件」问询（`kind = "give_item"`）。

  UCL 配置（`inquiries` 的 map 值）：

      value = {
        kind = "give_item"
        item = "shaolin:huwan"        # 发放的 item_id（LPC new("/d/shaolin/obj/"+name)）
        match = "huwan"               # present(name, me) 匹配词；缺省取 item_id 尾段
        count = "huju_count"          # 共享库存键（LPC set("huju_count", N)）；缺省无限
        unique = true                 # LPC ask_me_1 的 present(name, me) 检查；false 跳过
        family = "少林派"             # 限门派；缺省不限
        vision_name = "道相"          # message_vision 里的 NPC 短名；缺省用角色名
        success = "拿去吧。..."        # LPC 返回值（发给玩家）
        already = "你现在身上..."      # 已有时的返回值（自动加敬称）
        family_deny = "与本派..."      # 非本门时的返回值（自动加敬称）
        exhausted = "抱歉...发完了。"  # 库存耗尽时的返回值
        max_shen = -10000             # 杀气上限（LPC `shen > -10000` 即拒）
        min_combat_exp = 100000       # 经验下限
        max_skill_levels = { poison = 119 }  # 技能上限（LPC `query_skill("poison") > 119` 即拒）
        min_skill_levels = { bagua_dao = 150 }  # 技能下限（LPC `query_skill(...) < 150` 即拒）
        min_gongxian = 2200           # 门派贡献下限（LPC `query("gongxian") < 2200` 即拒）
        max_neili = 3200              # 内力上限下限（LPC `query("max_neili") < 3200` 即拒）
        master_id = true              # 仅本门师父亲传弟子（family/master_id == npc id）
        perform_id = "bagua-dao/tian" # 发放同时习得绝招（LPC set can_perform/...=1）
        cost_gongxian = 2200          # 发放后扣除贡献（LPC add("gongxian", -2200)）
        max_shen_deny = "..."         # 杀气过高时的返回值
        min_exp_deny = "..."          # 经验不足时的返回值
        max_skill_deny = "..."        # 技能过高时的返回值
        min_skill_deny = "..."        # 技能不足时的返回值
        min_gongxian_deny = "..."     # 贡献不足时的返回值
        max_neili_deny = "..."        # 内力不足时的返回值
        master_deny = "..."           # 非本师弟子时的返回值
        maxed = "..."                 # perform_id 已习得时的返回值
      }

  ## 与 LPC 的差异

  - `RANK_D->query_respect` 用 `NpcActions.Helpers.respect/1`（暂统一「大侠」）。
  - `message_vision` 用 `Helpers.broadcast/3`（`$N` → `{npc}`，行动者看到「你」）。
  - 库存扣减不在 NPC 进程直接做：玩家侧确认发出后回发 `npc/inquiry_consume`，
    由 NPC 进程自减（`inquiry_state`），避免「回执丢失仍扣库存」。

  ## 并发说明（@todo）

  NPC 侧读到 `remaining` 后才在玩家侧发放，跨进程回执存在极窄的竞态：同一 tick
  内两人同时问会都看到旧库存。LPC 在 NPC 线程内同步扣减无此问题。后续可改为
  NPC 侧预留（先减，玩家侧失败时回补）。
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4, put_character: 2]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.World.Item
  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "item")) -> conn
      Map.get(data, :asker_id) != character.id -> conn
      true -> run_for(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, character, config, data) do
    cond do
      already_known?(character, config) ->
        reply(conn, Helpers.respect(character) <> maxed_text(config))

      family_denied?(character, config) ->
        reply(conn, Helpers.respect(character) <> family_deny_text(config))

      gate = gate_denial(character, config) ->
        reply(conn, gate)

      master_denied?(character, config, data) ->
        reply(conn, Helpers.respect(character) <> master_deny_text(config))

      unique?(config) and carries?(character, config) ->
        reply(conn, Helpers.respect(character) <> already_text(config))

      exhausted?(data) ->
        reply(conn, Map.get(config, "exhausted") || "抱歉，你来得不是时候，已经发完了。")

      true ->
        give(conn, config, data)
    end
  end

  defp give(conn, config, data) do
    item_id = config["item"]

    case Items.get(item_id) do
      {:ok, item} ->
        conn = Helpers.give_item(conn, item_id)
        conn = give_perform(conn, config)
        conn = deduct_cost(conn, config)
        conn = reply(conn, Map.get(config, "success") || "拿去吧。")
        conn = broadcast(conn, data, config, item, item_id)
        consume(data, config)
        conn

      _ ->
        conn
    end
  end

  # LPC set("can_perform/<perform_id>", 1)：发放同时习得绝招（如 商剑鸣「天刀八势」）。
  defp give_perform(conn, %{"perform_id" => perform_id})
       when is_binary(perform_id) do
    character = current(conn)

    case character.meta.stats do
      %Stats{} = stats ->
        updated = Stats.learn_perform(stats, perform_id)
        character = %{character | meta: %{character.meta | stats: updated}}
        conn = put_character(conn, character)
        Records.save(character)
        conn

      _ ->
        conn
    end
  end

  defp give_perform(conn, _config), do: conn

  # LPC add("gongxian", -N)：发放后扣除门派贡献。
  defp deduct_cost(conn, %{"cost_gongxian" => cost})
       when is_integer(cost) and cost > 0 do
    character = current(conn)

    case character.meta.stats do
      %Stats{} = stats ->
        updated = %{stats | gongxian: max((stats.gongxian || 0) - cost, 0)}
        character = %{character | meta: %{character.meta | stats: updated}}
        conn = put_character(conn, character)
        Records.save(character)
        conn

      _ ->
        conn
    end
  end

  defp deduct_cost(conn, _config), do: conn

  defp broadcast(conn, data, config, item, item_id) do
    case Map.get(data, :npc_room_id) do
      room_id when is_binary(room_id) ->
        npc_name = Map.get(config, "vision_name") || Map.get(data, :npc_name) || "对方"
        item_name = item.name || item_id
        Helpers.broadcast(conn, room_id, "#{npc_name}给$N一件#{item_name}。\n")

      _ ->
        conn
    end
  end

  defp consume(%{npc_pid: pid}, %{"count" => count_key})
       when is_pid(pid) and is_binary(count_key) do
    send(pid, %Kalevala.Event{
      from_pid: self(),
      topic: "npc/inquiry_consume",
      data: %{count_key: count_key}
    })
  end

  defp consume(_data, _config), do: :ok

  defp exhausted?(%{remaining: remaining}) when is_integer(remaining), do: remaining <= 0
  defp exhausted?(_data), do: false

  defp unique?(config) do
    case Map.get(config, "unique", true) do
      false -> false
      "false" -> false
      _ -> true
    end
  end

  defp carries?(character, config) do
    item_id = config["item"]
    match = Map.get(config, "match") || item_id_suffix(item_id)

    Enum.any?(character.inventory || [], fn instance ->
      instance.item_id == item_id or
        item_id_suffix(instance.item_id) == match or
        Item.matches?(Item.instance_item(instance), match)
    end)
  end

  defp item_id_suffix(item_id) when is_binary(item_id) do
    item_id |> String.split(":") |> List.last()
  end

  defp item_id_suffix(_item_id), do: nil

  defp family_denied?(character, config) do
    case Map.get(config, "family") do
      family when is_binary(family) and family != "" -> family_name(character) != family
      _ -> false
    end
  end

  defp family_name(%{meta: %{family: family}}) when is_map(family), do: Family.name(family)
  defp family_name(_character), do: nil

  # LPC ask_me 的额外门槛：杀气上限 / 经验下限 / 技能上限（kungfu/class/wudu/qiyunao.c ask_me）。
  defp gate_denial(character, config) do
    stats = stats_of(character)

    cond do
      exceeds_max_shen?(stats, config) ->
        Map.get(config, "max_shen_deny") || "像你这样心慈手软，这东西给了你也干不了大事。"

      below_min_exp?(stats, config) ->
        Map.get(config, "min_exp_deny") || "你现在经验太浅，不用忙着来要这个。"

      exceeds_max_skill?(stats, config) ->
        Map.get(config, "max_skill_deny") || "你这方面的造诣已经不浅了，这个不看也罢。"

      below_min_skill?(stats, config) ->
        Map.get(config, "min_skill_deny") || "你这门功夫还练得不到家，自己下去练练再来吧！"

      below_min_gongxian?(stats, config) ->
        Map.get(config, "min_gongxian_deny") || "你在我这里碌碌无为，这东西暂时还不能给你。"

      below_max_neili?(character, config) ->
        Map.get(config, "max_neili_deny") || "你的内力修为不足，施展不出这招。"

      true ->
        nil
    end
  end

  defp stats_of(%{meta: %{stats: stats}}) when not is_nil(stats), do: stats
  defp stats_of(_character), do: %{}

  defp stat(stats, key), do: Map.get(stats, key, 0) || 0

  defp exceeds_max_shen?(stats, config) do
    case Map.get(config, "max_shen") do
      max when is_integer(max) -> stat(stats, :shen) > max
      _ -> false
    end
  end

  defp below_min_exp?(stats, config) do
    case Map.get(config, "min_combat_exp") do
      min when is_integer(min) -> stat(stats, :combat_exp) < min
      _ -> false
    end
  end

  defp exceeds_max_skill?(stats, config) do
    case Map.get(config, "max_skill_levels") do
      levels when is_map(levels) ->
        skills = Map.get(stats, :skills) || %{}
        Enum.any?(levels, fn {skill, max} -> Map.get(skills, skill, 0) > max end)

      _ ->
        false
    end
  end

  # LPC `query_skill("<skill>", 1) < N`：任一技能未达下限即拒。
  defp below_min_skill?(stats, config) do
    case Map.get(config, "min_skill_levels") do
      levels when is_map(levels) ->
        skills = Map.get(stats, :skills) || %{}
        Enum.any?(levels, fn {skill, min} -> Map.get(skills, skill, 0) < min end)

      _ ->
        false
    end
  end

  # LPC `query("gongxian") < N`。
  defp below_min_gongxian?(stats, config) do
    case Map.get(config, "min_gongxian") do
      min when is_integer(min) -> stat(stats, :gongxian) < min
      _ -> false
    end
  end

  # LPC `query("max_neili") < N`：内力上限存于 meta.vitals.max_neili。
  defp below_max_neili?(character, config) do
    case Map.get(config, "max_neili") do
      min when is_integer(min) -> max_neili_of(character) < min
      _ -> false
    end
  end

  defp max_neili_of(%{meta: %{vitals: %{max_neili: n}}}) when is_integer(n), do: n
  defp max_neili_of(_character), do: 0

  defp family_deny_text(config),
    do: Map.get(config, "family_deny") || "与本派素无来往，不知此话从何谈起？"

  defp already_text(config),
    do: Map.get(config, "already") || "你现在身上已经有这样东西了。"

  # LPC `can_perform/<perform_id>` 已习得：发放前先确认（如 商剑鸣「你不是已经会了吗？」）。
  defp already_known?(%{meta: %{stats: %Stats{} = stats}}, config) do
    case Map.get(config, "perform_id") do
      perform_id when is_binary(perform_id) -> Stats.perform_known?(stats, perform_id)
      _ -> false
    end
  end

  defp already_known?(_character, _config), do: false

  defp maxed_text(config),
    do: Map.get(config, "maxed") || "这招我已经教过你了，自己下去练吧。"

  # LPC `query("family/master_id") != query("id")`：仅本师亲传弟子可取。
  # UCL 解析器把 `master_id = true` 读为字符串 "true"；仅显式 true/"true" 开启门控，
  # 未配置（nil）时不拦。
  defp master_denied?(character, config, data) do
    case Map.get(config, "master_id") do
      true -> not own_disciple?(character, Map.get(data, :npc_id))
      "true" -> not own_disciple?(character, Map.get(data, :npc_id))
      _ -> false
    end
  end

  defp own_disciple?(%{meta: %{family: family}}, npc_id) when is_map(family) do
    master_id = Map.get(family, :master_id) || Map.get(family, "master_id")
    is_binary(master_id) and master_id == npc_id
  end

  defp own_disciple?(_character, _npc_id), do: false

  defp master_deny_text(config),
    do:
      Map.get(config, "master_deny") ||
        "只有我的弟子才配用这个，你别拿去丢脸。"

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
