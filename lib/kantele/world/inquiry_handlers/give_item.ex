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
        plain_already = true          # #854 静风师太：已有文案不加 RANK_D 敬称前缀
        exhausted_before_already = true  # #854 静风 ask_jian：库存门先于已持有门
        require_wounded = true        # #854 静风 ask_yao：qi >= max_qi 即拒；缺省关闭
        wound_deny = "你未曾受伤，讨这药膏做什么？"
        family = "少林派"             # 限门派；缺省不限
        vision_name = "道相"          # message_vision 里的 NPC 短名；缺省用角色名
        npc_say = "这本脉经你就拿去看吧"  # #844 LPC command("say ...") 房间广播；缺省不播
        silent_success = true         # #844 LPC 只 say 不私发返回值；缺省 false 零回归
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
        # #820 LPC masterd.c:474-509 give_item 持有者遍历（技能门后、贡献门前）
        owner_check = true            # 启用 owner 遍历（NPC 侧 npc_shop_event 取快照）
        owner_item_label = "那支鹤形笔"  # {item} 占位符（LPC obj->query("unit") + obj->name()）
        owner_self_deny = "{item}不就是你拿着在用么，怎么反倒找我了？"
        owner_lost_deny = "{item}我已经借出去了，你还是隔段时间再来吧。"
        owner_sect_deny = "{item}现在是我派的{name}在用，你若需要就去找他吧。"
        owner_ally_deny = "{item}现在是你派的{name}在用，你自己去问他要吧。"
        owner_outsider_deny = "{item}现在落在了{name}手中，你去把它取回来吧。"
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
    # #1188/#844：master_before_gates 只改变「师父门」的位置，不得关闭整条 gate 链。
    # LPC 红花会 ask_* / 段正明 ask_maijing1/2 都是师父门先于 shen/技能门，
    # 其余门仍按原顺序执行；老配置（master_first?=false）的条件顺序完全不变。
    gate = gate_denial(conn, character, config, data)

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

      # #814 LPC ding.c：家族后、技能门前，NPC is_busy/is_fighting 即拒绝。
      npc_busy_or_fighting?(data, config) ->
        reply(conn, Helpers.respect(character) <> npc_busy_text(config))

      gate ->
        reply(conn, gate)

      not master_first? and master_denied?(character, config, data) ->
        reply(conn, Helpers.respect(character) <> master_deny_text(config))

      # #814 玩家 cooldown_temp 180 秒内已领取，再次求取即拒。
      cooldown_denied?(conn, character, config) ->
        reply(conn, Helpers.respect(character) <> cooldown_deny_text(config))

      exhausted_before_already?(config) and exhausted?(data) ->
        reply(conn, Map.get(config, "exhausted") || "抱歉，你来得不是时候，已经发完了。")

      unique?(config) and carries?(character, config) ->
        text =
          if plain_already?(config),
            do: already_text(config),
            else: Helpers.respect(character) <> already_text(config)

        reply(conn, text)

      not exhausted_before_already?(config) and exhausted?(data) ->
        reply(conn, Map.get(config, "exhausted") || "抱歉，你来得不是时候，已经发完了。")

      true ->
        give(conn, config, data)
    end
  end

  defp give(conn, config, data) do
    item_id = config["item"]

    case Items.get(item_id) do
      {:ok, item} ->
        amount = give_amount(config)
        # LPC ask_maijing1/2：ob->move(this_object()) → command("say ...") → command("give ...")。
        # npc_say 只在显式配置时广播，老配置零影响。
        conn = maybe_npc_say(conn, data, config)
        conn = Helpers.give_items(conn, item_id, amount)
        conn = give_perform(conn, config)
        conn = deduct_cost(conn, config)
        conn = maybe_success_reply(conn, config)
        conn = broadcast(conn, data, config, item, item_id)
        conn = record_cooldown(conn, config)
        consume(data, config)
        mark_npc_busy(data, config)
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

  # #844 LPC `command("say ...")` 后 return 1，没有额外私发返回值；
  # silent_success 只抑制 give_item 的缺省私聊，老配置仍走原 reply。
  defp maybe_success_reply(conn, config) do
    case Map.get(config, "silent_success") do
      flag when flag in [true, "true"] -> conn
      _ -> reply(conn, Map.get(config, "success") || "拿去吧。")
    end
  end

  # #844 段正明 ask_maijing1/2 的 `command("say 这本脉经你就拿去看吧，可要认真研读。")`。
  # 与随后的 give 广播是两句不同的 LPC 输出，故分开保留；未配置 npc_say 时零影响。
  defp maybe_npc_say(conn, data, %{"npc_say" => text} = config) when is_binary(text) do
    case Map.get(data, :npc_room_id) do
      room_id when is_binary(room_id) ->
        npc_name =
          Map.get(config, "vision_name") || Map.get(data, :npc_name) || "对方"

        Helpers.say(conn, room_id, npc_name, text)

      _ ->
        conn
    end
  end

  defp maybe_npc_say(conn, _data, _config), do: conn

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

  # #814 LPC ding.c ask_xiangliao：发放 random(50)+100 份香料，即
  # amount_base + random(amount_random) ∈ [amount_base, amount_base + amount_random - 1]。
  defp give_amount(config) do
    base = Map.get(config, "amount_base") || 1
    random = Map.get(config, "amount_random")

    case random do
      n when is_integer(n) and n > 0 -> base + :rand.uniform(n) - 1
      _ -> base
    end
  end

  # #814 玩家领取冷却：把 System.system_time(:second) 写入 meta.temp[cooldown_temp]，
  # 下次求取时 cooldown_denied?/3 再比较「当前秒 - 上次领取秒 < cooldown_seconds」。
  defp record_cooldown(conn, %{"cooldown_temp" => temp_key})
       when is_binary(temp_key) do
    Helpers.put_temp(conn, temp_key, System.system_time(:second))
  end

  defp record_cooldown(conn, _config), do: conn

  # #814 NPC start_busy(2)：发放成功后回执 npc/inquiry_busy 给 NPC 进程，由
  # NpcAskEvent.inquiry_busy/2 写 meta.combat.busy，战斗 tick 逐轮递减。
  defp mark_npc_busy(%{npc_pid: pid}, %{"npc_start_busy" => rounds})
       when is_pid(pid) and is_integer(rounds) and rounds > 0 do
    send(pid, %Kalevala.Event{
      from_pid: self(),
      topic: "npc/inquiry_busy",
      data: %{rounds: rounds}
    })
  end

  defp mark_npc_busy(_data, _config), do: :ok

  # #814 NPC 自身忙碌/战斗快照（npc_ask_event.ex 已在 npc/inquiry 事件里带回 boolean）。
  defp npc_busy_or_fighting?(data, _config) do
    Map.get(data, :npc_busy) == true or Map.get(data, :npc_fighting) == true
  end

  defp cooldown_denied?(conn, _character, %{
         "cooldown_temp" => temp_key,
         "cooldown_seconds" => seconds
       })
       when is_binary(temp_key) and is_integer(seconds) and seconds > 0 do
    case Helpers.temp(conn, temp_key) do
      last when is_integer(last) -> System.system_time(:second) - last < seconds
      _ -> false
    end
  end

  defp cooldown_denied?(_conn, _character, _config), do: false

  defp npc_busy_text(config),
    do: Map.get(config, "npc_busy_deny") || "等会儿，没看我这正忙着呢么？"

  defp cooldown_deny_text(config),
    do: Map.get(config, "cooldown_deny") || "刚才不是给了你吗？不会这么快就用完了吧？"

  defp exhausted?(%{remaining: remaining}) when is_integer(remaining), do: remaining <= 0
  defp exhausted?(_data), do: false

  # #854 静风师太的「已带药/已带武器」LPC 原文不带 RANK_D 敬称；
  # 其它老配置保持自动加敬称。
  defp plain_already?(config), do: Map.get(config, "plain_already") in [true, "true"]

  # #854 静风 ask_jian 的 LPC 原序是「库存 < 1 → present(ruanjian)」，与 ask_yao
  # 「已持有 → 库存」相反；旧配置不设此键时仍走 exhausted 在 already 之后。
  defp exhausted_before_already?(config),
    do: Map.get(config, "exhausted_before_already") in [true, "true"]

  # #854 静风 ask_yao：`this_player()->query("qi") >= query("max_qi")`。
  # LPC 玩家必有 vitals；此处缺字段时不拦，避免把数据缺失误判成「未受伤」。
  defp wounded_denied?(character, config) do
    case Map.get(config, "require_wounded") do
      flag when flag in [true, "true"] ->
        vitals = Map.get(character.meta || %{}, :vitals) || %{}
        qi = Map.get(vitals, :qi) || Map.get(vitals, "qi")
        max_qi = Map.get(vitals, :max_qi) || Map.get(vitals, "max_qi")

        is_integer(qi) and is_integer(max_qi) and qi >= max_qi

      _ ->
        false
    end
  end

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
  defp gate_denial(conn, character, config, data) do
    stats = stats_of(character)

    skill_first? = skill_before_shen?(config)

    cond do
      # #854 静风 ask_yao：`query("qi") >= query("max_qi")` → 未受伤拒，门序在
      # 「已持有」与「库存」之前；其它 give_item 未配置 require_wounded 时零影响。
      wounded_denied?(character, config) ->
        Map.get(config, "wound_deny") || "你未曾受伤，讨这药膏做什么？"

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

      # #820 LPC masterd.c:474-509：sk1..sk3 之后、gongxian 之前遍历持有者。
      denial = owner_denial(character, config, data) ->
        denial

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

  # #820 LPC masterd.c:474-509 的 owner 遍历五分支。owner 快照由 NPC 侧
  # `npc_shop_event.zhihuan_owner/3` 产出（:asker/:object/:character/:npc）：
  #   owner == who       → "不就是你拿着在用么…"
  #   !is_character      → "我已经借出去了…"
  #   owner.family == NPC.family → "现在是我派的 X 在用…"
  #   owner.family == who.family → "现在是你派的 X 在用…"
  #   其余               → "现在落在了 X 手中…"
  # :npc（缺省，物品在 NPC 身上）与未开启 owner_check 时返回 nil 继续发放。
  defp owner_denial(character, config, data) do
    if Map.get(config, "owner_check") in [true, "true"] do
      label = Map.get(config, "owner_item_label") || item_id_suffix(config["item"])

      case Map.get(data, :owner) do
        %{kind: :asker} ->
          owner_text(config, "owner_self_deny", label, nil)

        %{kind: :object} ->
          owner_text(config, "owner_lost_deny", label, nil)

        %{kind: :character} = owner ->
          name = Map.get(owner, :name) || "某人"
          owner_family = Map.get(owner, :family)

          cond do
            is_binary(owner_family) and owner_family == Map.get(config, "family") ->
              owner_text(config, "owner_sect_deny", label, name)

            is_binary(owner_family) and owner_family == family_name(character) ->
              owner_text(config, "owner_ally_deny", label, name)

            true ->
              owner_text(config, "owner_outsider_deny", label, name)
          end

        _ ->
          nil
      end
    else
      nil
    end
  end

  defp owner_text(config, key, label, name) do
    template =
      Map.get(config, key) ||
        case key do
          "owner_self_deny" -> "{item}不就是你拿着在用么，怎么反倒找我了？"
          "owner_lost_deny" -> "{item}我已经借出去了，你还是隔段时间再来吧。"
          "owner_sect_deny" -> "{item}现在是我派的{name}在用，你若需要就去找他吧。"
          "owner_ally_deny" -> "{item}现在是你派的{name}在用，你自己去问他要吧。"
          "owner_outsider_deny" -> "{item}现在落在了{name}手中，你去把它取回来吧。"
          _ -> nil
        end

    if is_binary(template) do
      template
      |> String.replace("{item}", to_string(label || ""))
      |> String.replace("{name}", to_string(name || ""))
    else
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
