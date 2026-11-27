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
        min_shen = 30000              # 侠义下限（LPC `0 < shen < N` 即拒，如紫霞秘籍）
        min_combat_exp = 100000       # 经验下限
        max_skill_levels = { poison = 119 }  # 技能上限（LPC `query_skill("poison") > 119` 即拒）
        min_skill_levels = { bagua_dao = 150 }  # 技能下限（LPC `query_skill(...) < 150` 即拒）
        min_gongxian = 2200           # 门派贡献下限（LPC `query("gongxian") < 2200` 即拒）
        max_neili = 3200              # 内力上限下限（LPC `query("max_neili") < 3200` 即拒）
        hostile_shen = -100000        # 杀气低于此值直接翻脸开打（LPC `shen < -100000` → kill_ob）
        hostile_emote = "哼了一声"   # 开打前 NPC 动作（LPC command("heng")，缺省不播）
        hostile_say = "..."           # 开打前 NPC 室内说（LPC command("say ...")，缺省不播）
        min_weiwang = 100000          # 威望下限（LPC `query("weiwang") < 100000` 即拒）
        min_weiwang_deny = "..."      # 威望不足时的返回值
        master_id = true              # 仅本门师父亲传弟子（family/master_id == npc id）
        allowed_master_ids = ["chen jialuo", "wuchen daozhang"]  # 多师父白名单（红花会 #1010）
        master_before_gates = true    # 师父门移到 shen/技能门之前（红花会 ask_jian/ask_bi）
        allowed_families = ["红花会", "武当派"]  # 多门派白名单（陆菲青 #1010）
        family_denies = { 武当派 = "专属拒绝文案" }  # 按门派给出不同拒绝（LPC 分支）
        perform_id = "bagua-dao/tian" # 发放同时习得绝招（LPC set can_perform/...=1）
        cost_gongxian = 2200          # 发放后扣除贡献（LPC add("gongxian", -2200)）
        max_shen_deny = "..."         # 杀气过高时的返回值
        min_shen_deny = "..."         # 侠义不足时的返回值
        min_exp_deny = "..."          # 经验不足时的返回值
        max_skill_deny = "..."        # 技能过高时的返回值
        min_skill_deny = "..."        # 技能不足时的返回值
        min_gongxian_deny = "..."     # 贡献不足时的返回值
        max_neili_deny = "..."        # 内力不足时的返回值
        master_deny = "..."           # 非本师弟子时的返回值
        maxed = "..."                 # perform_id 已习得时的返回值
        # #1045 少林道象/清乐：条件/属性/辈分门控
        bonze_drug = true             # 启用 query_condition("bonze_drug") > 0 门控（dao-xiang2 金创药）
        bonze_drug_deny = "..."       # bonze_drug 过剩时的返回值
        guilty_deny = "..."           # query("guilty") > 0 时的返回值（qing-le 手谕）
        min_int = 30                  # query_int() 下限（qing-le 手谕）
        min_int_deny = "..."          # 智力不足时的返回值
        generation_skill_levels = { buddhism = 150, dodge = 100, ... }  # 动态门槛 (41-generation)*20+30 的技能名表（qing-le 达摩令）
        generation_skill_deny = "..." # 达摩令技能不足时的返回值，文案可含 {skill}
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

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4, put_character: 2, get_session: 2]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Conditions
  alias Kantele.Character.Family
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.World.Item
  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers
  alias Kantele.World.NpcActions.NpcAttack

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
    master_first? = master_before_gates?(config)
    gate = if master_first?, do: nil, else: gate_denial(conn, character, config)

    cond do
      # LPC zhangsan2.c give_ling 首项：shen < -100000 → heng + say + kill_ob，return 1（不私发文本）。
      hostile_shen?(conn, character, config, data) ->
        hostile_shen_attack(conn, character, config, data)

      already_known?(character, config) ->
        reply(conn, Helpers.respect(character) <> maxed_text(config))

      denial = family_denial(character, config) ->
        reply(conn, Helpers.respect(character) <> denial)

      master_first? and master_denied?(character, config, data) ->
        reply(conn, Helpers.respect(character) <> master_deny_text(config))

      gate ->
        reply(conn, gate)

      not master_first? and master_denied?(character, config, data) ->
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

  # #1010 红花会：先查逐门派专属拒绝，再走通用单门派/多门派白名单。
  defp family_denial(character, config) do
    case family_specific_denial(character, config) do
      text when is_binary(text) and byte_size(text) > 0 ->
        text

      _ ->
        if family_denied?(character, config), do: family_deny_text(config), else: nil
    end
  end

  # UCL `family_denies = { 武当派 = "..." }`：LPC `if (family == "武当派") return "...";`。
  defp family_specific_denial(character, config) do
    case Map.get(config, "family_denies") do
      denies when is_map(denies) ->
        Map.get(denies, family_name(character))

      _ ->
        nil
    end
  end

  defp family_denied?(character, config) do
    case {Map.get(config, "allowed_families"), Map.get(config, "family")} do
      {families, _} when is_list(families) and families != [] ->
        not Enum.any?(families, &(&1 == family_name(character)))

      {_, family} when is_binary(family) and family != "" ->
        family_name(character) != family

      _ ->
        false
    end
  end

  defp family_name(%{meta: %{family: family}}) when is_map(family), do: Family.name(family)
  defp family_name(_character), do: nil

  # LPC ask_me 的额外门槛：杀气上限 / 经验下限 / 技能上限（kungfu/class/wudu/qiyunao.c ask_me）。
  # #1045 新增：bonze_drug 条件 / guilty 戒律 / min_int 资质 / generation_skill 辈分动态门槛。
  defp gate_denial(conn, character, config) do
    stats = stats_of(character)

    skill_first? = skill_before_shen?(config)

    cond do
      # #1045 少林道象：query_condition("bonze_drug") > 0 → 拒（LPC dao-xiang2.c ask_me_1）
      bonze_drug_denied?(conn, config) ->
        Map.get(config, "bonze_drug_deny") || "你是不是刚吃过药，怎麽又来要了？ 灵药多吃有害无宜，过段时间再来吧。"

      # #1045 少林清乐：query("guilty") > 0 → 拒（LPC qing-le.c ask_me_1）
      guilty_gt_zero?(character, config) ->
        Map.get(config, "guilty_deny") || "你累犯数戒，身带重罪，我如何能给你这手谕！"

      # #1045 少林清乐：query_int() < N → 拒（LPC qing-le.c ask_me_1）
      below_min_int?(character, config) ->
        Map.get(config, "min_int_deny") || "资质不够，不能进入藏经楼。"

      exceeds_max_shen?(stats, config) ->
        Map.get(config, "max_shen_deny") || "像你这样心慈手软，这东西给了你也干不了大事。"

      skill_first? and below_min_skill?(stats, config) ->
        Map.get(config, "min_skill_deny") || "你这门功夫还练得不到家，自己下去练练再来吧！"

      below_min_shen?(stats, config) ->
        Map.get(config, "min_shen_deny") || "你目前所做的侠义正事不够，这东西暂时还不能交给你。"

      below_min_exp?(stats, config) ->
        Map.get(config, "min_exp_deny") || "你现在经验太浅，不用忙着来要这个。"

      exceeds_max_skill?(stats, config) ->
        Map.get(config, "max_skill_deny") || "你这方面的造诣已经不浅了，这个不看也罢。"

      not skill_first? and below_min_skill?(stats, config) ->
        Map.get(config, "min_skill_deny") || "你这门功夫还练得不到家，自己下去练练再来吧！"

      below_min_weiwang?(stats, config) ->
        Map.get(config, "min_weiwang_deny") || "你在我这里碌碌无为，这东西暂时还不能给你。"

      below_min_gongxian?(stats, config) ->
        Map.get(config, "min_gongxian_deny") || "你在我这里碌碌无为，这东西暂时还不能给你。"

      below_max_neili?(character, config) ->
        Map.get(config, "max_neili_deny") || "你的内力修为不足，施展不出这招。"

      # #1045 少林清乐：辈分动态技能门槛 lvl=(41-generation)*20+30 → 拒（LPC qing-le.c ask_me_2 达摩令）
      below_generation_skill?(character, config) ->
        Map.get(config, "generation_skill_deny") || "你{skill}的功力不够，不能领取达摩令。"

      require_fumoquan?(config) and not valid_in_fumoquan?(character) ->
        Map.get(config, "fumoquan_deny") || "你尚未在金刚伏魔圈中，无法领取此物。"

      true ->
        nil
    end
  end

  # LPC zhangsan2.c give_ling：shen < -100000 时翻脸开打。
  # 顺序：emote（heng）→ say（室内广播）→ kill_ob，不私发 tell_object（对应 return 1）。
  defp hostile_shen?(conn, character, config, data) do
    case Map.get(config, "hostile_shen") do
      threshold when is_integer(threshold) ->
        stat(stats_of(character), :shen) < threshold

      _ ->
        false
    end
  end

  defp hostile_shen_attack(conn, character, config, data) do
    room_id = Map.get(data, :npc_room_id)
    npc_name = Map.get(data, :npc_name) || "对方"

    conn =
      case {Map.get(config, "hostile_emote"), room_id} do
        {emote, room_id} when is_binary(emote) and is_binary(room_id) ->
          Helpers.broadcast(conn, room_id, "#{npc_name}#{emote}。\n")

        _ ->
          conn
      end

    conn =
      case {Map.get(config, "hostile_say"), room_id} do
        {say, room_id} when is_binary(say) and is_binary(room_id) ->
          message = String.replace(say, "{name}", character.name || "你")
          Helpers.say(conn, room_id, npc_name, message)

        _ ->
          conn
      end

    npc = %{
      id: Map.get(data, :npc_id),
      pid: Map.get(data, :npc_pid),
      name: Map.get(data, :npc_name),
      room_id: room_id
    }

    player = %{
      id: character.id,
      pid: self(),
      name: character.name,
      room_id: character.room_id
    }

    NpcAttack.kill_ob(npc, player)

    conn
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

  # LPC masterd.c give_item `shen > 0 && who->query("shen") < shen`：
  # 华山岳不群「紫霞秘籍」要求 shen >= 30000。
  defp below_min_shen?(stats, config) do
    case Map.get(config, "min_shen") do
      min when is_integer(min) -> stat(stats, :shen) < min
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
  # min_skill_levels 的 UCL 键保留下划线（loader 不归一），但 Stats.skills
  # 用连字符 skill id，故这里双查，否则紫霞秘籍的 huashan_xinfa 永不命中。
  defp below_min_skill?(stats, config) do
    case Map.get(config, "min_skill_levels") do
      levels when is_map(levels) ->
        skills = Map.get(stats, :skills) || %{}

        Enum.any?(levels, fn {skill, min} ->
          level = Map.get(skills, skill, 0) || 0

          level =
            if level == 0 and is_binary(skill),
              do: Map.get(skills, String.replace(skill, "_", "-"), 0) || 0,
              else: level

          level < min
        end)

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

  # LPC `query("weiwang") < N`：侠客岛赏善使者要求 weiwang >= 100000。
  defp below_min_weiwang?(stats, config) do
    case Map.get(config, "min_weiwang") do
      min when is_integer(min) -> stat(stats, :weiwang) < min
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

  # LPC `query_temp("valid_in_fumoquan")`：仅在金刚伏魔圈内且少林辈分<=36 时置位。
  defp require_fumoquan?(config), do: Map.get(config, "require_fumoquan") in [true, "true"]

  defp valid_in_fumoquan?(%{meta: %{temp: temp}}) when is_map(temp),
    do: Map.get(temp, "valid_in_fumoquan") == 1 or Map.get(temp, :valid_in_fumoquan) == 1

  defp valid_in_fumoquan?(_character), do: false

  # #1045 少林道象：query_condition("bonze_drug") > 0 → 吃药冷却中，拒发金创药。
  # conditions 存于 session（见 ConditionEvent），需经 get_session(conn, "conditions") 取出。
  defp bonze_drug_denied?(conn, config) do
    case Map.get(config, "bonze_drug") do
      true ->
        check_bonze_drug(conn)

      "true" ->
        check_bonze_drug(conn)

      _ ->
        false
    end
  end

  defp check_bonze_drug(conn) do
    conditions = get_session(conn, "conditions") || %{}

    case Conditions.query_condition(%{conditions: conditions}, "bonze_drug") do
      n when is_integer(n) and n > 0 -> true
      _ -> false
    end
  end

  # #1045 少林清乐：query("guilty") > 0 → 累犯戒律，拒发手谕。
  defp guilty_gt_zero?(character, config) do
    case Map.get(config, "guilty_deny") do
      nil ->
        false

      "" ->
        false

      _ ->
        meta = character.meta || %{}
        guilty = Map.get(meta, :guilty) || Map.get(meta, "guilty") || 0
        is_integer(guilty) and guilty > 0
    end
  end

  # #1045 少林清乐：query_int() < N → 资质不足，拒发手谕。
  defp below_min_int?(character, config) do
    case Map.get(config, "min_int") do
      min when is_integer(min) ->
        stats =
          case character.meta do
            %{stats: stats} -> stats
            _ -> %{}
          end

        Stats.int(stats) < min

      _ ->
        false
    end
  end

  # #1045 少林清乐：辈分动态技能门槛 lvl = (41 - generation) * 20 + 30。
  # 检查 generation_skill_levels 里列出的每门技能，任一不达标即拒。
  defp below_generation_skill?(character, config) do
    case Map.get(config, "generation_skill_levels") do
      levels when is_map(levels) and map_size(levels) > 0 ->
        generation =
          case character.meta do
            %{family: family} when is_map(family) ->
              Map.get(family, :generation) || Map.get(family, "generation") || 0

            _ ->
              0
          end

        threshold = (41 - generation) * 20 + 30
        stats = stats_of(character)
        skills = Map.get(stats, :skills) || %{}

        Enum.any?(levels, fn {skill, _min} ->
          level = Map.get(skills, skill, 0) || 0

          level =
            if level == 0 and is_binary(skill),
              do: Map.get(skills, String.replace(skill, "_", "-"), 0) || 0,
              else: level

          level < threshold
        end)

      _ ->
        false
    end
  end

  defp family_deny_text(config),
    do: Map.get(config, "family_deny") || "与本派素无来往，不知此话从何谈起？"

  defp already_text(config),
    do: Map.get(config, "already") || "你现在身上已经有这样东西了。"

  defp min_weiwang_deny_text(config),
    do: Map.get(config, "min_weiwang_deny") || "你在我这里碌碌无为，这东西暂时还不能给你。"

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
  # #1010 红花会物品可由多位当家发放（如白龙剑：陈家洛/无尘/赵半山），
  # `allowed_master_ids = [...]` 用 LPC 原样 id 列表；旧 `master_id` 行为完全不变。
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

  # #1010 红花会 ask_* 的师父门在 is_bad/family/shen/技能门之前；
  # 布尔值经 UCL 解析器可能是字符串 "true"，两种写法都接受。
  defp master_before_gates?(config),
    do: Map.get(config, "master_before_gates") in [true, "true"]

  # #1010 赵半山 ask_bi：LPC 是「技能等级 → shen」，与 give_item 缺省
  # 「shen → 技能等级」相反；显式开启后只影响配置了该键的物品。
  defp skill_before_shen?(config),
    do: Map.get(config, "skill_before_shen") in [true, "true"]

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
