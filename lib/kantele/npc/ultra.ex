defmodule Kantele.NPC.Ultra do
  @moduledoc """
  大宗师评价子系统（对应 `kungfu/class/ultra/*.c` + `ultra.h`）。

  四位大宗师各自只评一个类别（`meta.ultra.category`）：
    独孤求败 weapon / 黄裳 unarmed / 霍山 force / 葵花太监 dodge。

  流程与 LPC 逐条对齐：
    1. `ask 评价` → 门控（exp<200000 / 已宗师 / 战斗中 / 评价中 / 催促次数）→ 记 `want_opinion/<key>`。
    2. `fight` → `Kantele.Npc.EngageRule.decide/4` 调 `engage_decide/3`：
       无意图/状态不佳/内力不足分别拒绝；通过则清玩家内力、NPC temp 记 `opinion`，
       NPC 侧起 2 拍 `check_opinion`（`Kantele.Character.UltraEvent`）。
    3. `calc_level` 按大师类别分别计算（weapon/unarmed 读招式表；force 看 4000 内力；dodge 恒 +20）。
    4. `check_opinion` 按 `opinions_rank`（200..520）评级，写 `meta.env["opinion/<类别>"]`；
       四类全宗师 → `opinion/ultra=1` + 祝贺 + 江湖传闻。
    5. 绝招 quest（dugubook / zhenjing1+2）由 `Kantele.World.UltraAccept` 处理。

  LPC 的收徒函数全部注释禁用，故不注册 apprentice/teach 教学块。
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Communication
  alias Kalevala.Event

  # ultra.h opinions_rank，升序；LPC `check_opinion` 的 ks = sort_array(keys(...), 1)。
  @opinion_ranks [
    {200, "已有小成"},
    {240, "身手不凡"},
    {280, "出类拔萃"},
    {320, "非同凡响"},
    {360, "已有大成"},
    {400, "炉火纯青"},
    {430, "臻至化境"},
    {460, "超凡脱俗"},
    {490, "登峰造极"},
    {520, "宗师"}
  ]

  @categories ["unarmed", "weapon", "force", "dodge"]

  @impl true
  def ask_specs do
    %{
      "评价" => opinion_spec(),
      "opinion" => opinion_spec(),
      "摄心大法" => skill_spec()
    }
  end

  @impl true
  def check(asker, npc, keyword) do
    case spec_call(:check, asker, npc, keyword) do
      {:error, text} -> {:error, decorate(text, npc, asker)}
      other -> other
    end
  end

  @impl true
  def execute(asker, npc, keyword) do
    case spec_call(:execute, asker, npc, keyword) do
      {:ok, text, asker} -> {:ok, decorate(text, npc, asker), asker}
      {:ok, text} -> {:ok, decorate(text, npc, asker)}
      other -> other
    end
  end

  @impl true
  def effects(_asker, _npc, keyword) when keyword in ["评价", "opinion", "摄心大法"], do: []
  def effects(_asker, _npc, _keyword), do: []

  defp spec_call(fun, asker, npc, keyword) do
    case ask_specs()[keyword] do
      %{^fun => fun_impl} -> fun_impl.(asker, npc)
      nil when fun == :check -> static_inquiry(npc, keyword)
      nil -> :ok
      _ -> {:error, "他没有回答。"}
    end
  end

  # 四位大宗师还有大量静态 inquiry（独孤九剑/剑意/武学修养…），ask_handler
  # 接管全部 ask 关键词后必须自己回这些静态文案，否则会全部掉进「无此问询」。
  defp static_inquiry(npc, keyword) do
    case Map.get((npc.meta.inquiries || %{}), keyword) do
      text when is_binary(text) -> {:error, decorate(text, npc, nil)}
      _ -> {:error, "他没有回答。"}
    end
  end

  # ---- ask 评价 ----

  defp opinion_spec do
    %{
      check: &check_ask_opinion/2,
      execute: &execute_ask_opinion/2
    }
  end

  defp check_ask_opinion(asker, npc) do
    cfg = ultra_config(npc)
    category = Map.get(cfg, :category, "")

    cond do
      cfg == nil -> {:error, "他不懂评价。"}
      asker.meta.stats.combat_exp < 200_000 -> {:error, msg(cfg, :ask_low_exp)}
      opinion_of(asker, category) == "宗师" -> {:error, msg(cfg, :ask_already)}
      fighting_with?(npc, asker) -> {:error, msg(cfg, :ask_fighting_npc)}
      fighting?(asker) -> {:error, msg(cfg, :ask_fighting_player)}
      busy_with_other?(npc, asker) -> {:error, msg(cfg, :ask_busy_other)}
      busy_with_self?(npc, asker) -> {:error, msg(cfg, :ask_busy_self)}
      want_count(asker, cfg) >= 3 -> {:error, msg(cfg, :ask_shut_up)}
      true -> :ok
    end
  end

  defp execute_ask_opinion(asker, npc) do
    cfg = ultra_config(npc)
    count = want_count(asker, cfg)
    prompt_key =
      case count do
        0 -> :ask_prompt_a
        1 -> :ask_prompt_b
        _ -> :ask_prompt_c
      end

    prompt = msg(cfg, prompt_key)
    key = want_key(cfg)
    meta = PlayerMeta.add_temp(asker.meta, "want_opinion/#{key}")
    {:ok, prompt, %{asker | meta: meta}}
  end

  # ---- ask 摄心大法（黄裳专属）----

  defp skill_spec do
    %{
      check: &check_ask_skill/2,
      execute: &execute_ask_skill/2
    }
  end

  defp check_ask_skill(asker, npc) do
    cfg = ultra_config(npc)

    cond do
      Map.get(cfg, :category) != "unarmed" -> {:error, "他不懂摄心大法。"}
      env_get(asker, "can_perform/jiuyin-shengong/xin") -> {:error, msg(cfg, :skill_already)}
      not env_get(asker, "can_learn/jiuyin-shengong/xin") -> {:error, msg(cfg, :skill_need_books)}
      Stats.skill(asker.meta.stats, "jiuyin-shengong") < 240 -> {:error, msg(cfg, :skill_force_low)}
      Stats.skill(asker.meta.stats, "martial-cognize") < 240 -> {:error, msg(cfg, :skill_cognize_low)}
      not all_performs?(asker, ["shou", "zhi", "zhua", "zhang"]) -> {:error, msg(cfg, :skill_other_performs)}
      true -> :ok
    end
  end

  defp execute_ask_skill(asker, npc) do
    cfg = ultra_config(npc)
    stats = asker.meta.stats

    stats = %{
      stats
      | skills: bump(stats.skills, ["force", "jiuyin-shengong", "martial-cognize"], 1_500_000)
    }

    asker = %{asker | meta: PlayerMeta.put_temp(asker.meta, "ultrap/skill_granted", true)}
    env = Map.put(asker.meta.env || %{}, "can_perform/jiuyin-shengong/xin", true)
    asker = put_in(asker.meta.env, env)
    {:ok, msg(cfg, :skill_granted) <> "你学会了「摄心大法」！\n", %{asker | meta: %{asker.meta | stats: stats}}}
  end

  # ---- fight 动态门控（EngageRule.decide/4）----

  @doc """
  LPC `accept_fight` 的 ex 对应。返回 `{:deny, msg}` 表示「一招试招」结束、
  不开真正战斗（LPC `notify_fail` 语义）；`:allow` 才进入普通战斗。
  """
  def engage_decide(npc, attacker, type) do
    cfg = ultra_config(npc)

    cond do
      cfg == nil or type != "fight" -> :allow
      opinion_of(attacker, Map.get(cfg, :category, "")) == "宗师" ->
        notify(npc, attacker, decorate(msg(cfg, :fight_already), npc, attacker))
        :allow

      want_count(attacker, cfg) == 0 -> deny_msg(cfg, :fight_no_intent, npc, attacker)

      Map.get(cfg, :weapon_required) and not armed?(attacker) ->
        deny_msg(cfg, :fight_need_weapon, npc, attacker)

      not Map.get(cfg, :weapon_required) and armed?(attacker) ->
        deny_msg(cfg, :fight_need_empty_hand, npc, attacker)

      low_vitals?(attacker) and Map.has_key?(cfg.msgs, "fight_low_vitals") ->
        deny_msg(cfg, :fight_low_vitals, npc, attacker)

      Map.has_key?(cfg.msgs, "fight_neili_low") and attacker.meta.vitals.neili < 3000 ->
        deny_msg(cfg, :fight_neili_low, npc, attacker)

      true ->
        start_opinion_fight(npc, attacker, cfg)
        deny_msg(cfg, :fight_ok, npc, attacker)
    end
  end

  defp start_opinion_fight(npc, attacker, cfg) do
    # NPC temp 记「正在给谁评价」（LPC set_temp("opinion", me)）。
    npc_pid = Map.get(npc, :pid)

    if is_pid(npc_pid) do
      send(
        npc_pid,
        %Event{
          from_pid: self(),
          topic: "ultra/accept-fight",
          data: %{player: attacker, ultra: cfg}
        }
      )
    end

    # LPC `call_out("check_opinion", 2, me)` 在 NPC 侧起拍，见 UltraEvent.accept_fight/2。
    :ok
  end

  # ---- 评级（ultra.h check_opinion / check_ultra）----

  @doc "按 ultra.h 计算单项等级；`cfg` 来自 NPC 的 `meta.ultra`。"
  def calc_level(asker, skill, cfg) do
    stats = asker.meta.stats
    base = div(Stats.skill(stats, skill), 2)

    case mapped_skill(stats, skill) do
      nil ->
        base

      sp ->
        lvl = base + Stats.skill(stats, sp)
        action_bonus(asker, cfg, sp) + mode_bonus(asker, cfg) + lvl
    end
  end

  @doc """
  `ultra.h check_opinion`：按现有 rank 找下一档；逐项 calc_level 取最高，
  `-1` 表示无进步；到 520 即宗师并触发 `check_ultra`。
  返回 `{updated_asker, message}`。
  """
  def check_opinion(asker, npc, cfg) do
    category = Map.get(cfg, :category, "")
    rank = opinion_of(asker, category)
    next_lvl = next_threshold(rank)

    best =
      cfg.opinions
      |> Enum.map(&calc_level(asker, &1, cfg))
      |> Enum.max(fn -> -1 end)

    cond do
      best < next_lvl and next_lvl == 200 ->
        {asker, decorate(msg(cfg, :rank_first_fail), npc, asker)}

      best < next_lvl ->
        {asker, decorate(msg(cfg, :rank_no_progress), npc, asker)}

      true ->
        {threshold, rank_name} = rank_for(best)
        asker = put_opinion(asker, category, rank_name)

        if threshold == 520 do
          asker = %{asker | meta: PlayerMeta.put_temp(asker.meta, "opinions/master", true)}
          {asker, ultra_text} = check_ultra(asker, cfg)
          text = decorate(msg(cfg, :rank_master), npc, asker) <> ultra_text
          {asker, text}
        else
          text = decorate(msg(cfg, :rank_up), npc, asker) |> replace("{rank}", rank_name)
          {asker, text}
        end
    end
  end

  @doc "四类全宗师 → opinion/ultra=1 + 祝贺 + 江湖传闻（ultra.h check_ultra）。"
  def check_ultra(asker, cfg) do
    if Enum.all?(@categories, &(opinion_of(asker, &1) == "宗师")) do
      env = Map.put(asker.meta.env || %{}, "opinion/ultra", 1)
      asker = put_in(asker.meta.env, env)
      rumor = "听说#{asker.name}成为武学大宗师。"
      Communication.announce("rumor", rumor)
      {asker, replace(msg(cfg, :congrat), "{name}", asker.name) <> rumor}
    else
      {asker, ""}
    end
  end

  # ---- 纯工具 ----

  @doc "opinions_rank 阈值表（升序），供测试与评级共用。"
  def opinion_ranks, do: @opinion_ranks

  def ultra_config(npc) when is_map(npc) do
    case Map.get(Map.get(npc, :meta, %{}), :ultra) do
      cfg when is_map(cfg) -> cfg
      _ -> nil
    end
  end

  def ultra_config(_), do: nil

  def opinion_of(asker, category) do
    env_get(asker, "opinion/#{category}")
  end

  def put_opinion(asker, category, rank) do
    env = Map.put(asker.meta.env || %{}, "opinion/#{category}", rank)
    put_in(asker.meta.env, env)
  end

  defp next_threshold(rank) do
    case Enum.find_index(@opinion_ranks, fn {_lvl, name} -> name == rank end) do
      nil -> 200
      idx ->
        case Enum.at(@opinion_ranks, idx + 1) do
          {lvl, _} -> lvl
          nil -> 520
        end
    end
  end

  defp rank_for(lvl) do
    @opinion_ranks
    |> Enum.reverse()
    |> Enum.find(fn {threshold, _} -> lvl >= threshold end) ||
      hd(@opinion_ranks)
  end

  defp action_bonus(asker, cfg, sp) do
    type =
      case Map.get(cfg, :category) do
        "weapon" -> "weapon"
        "unarmed" -> "unarmed"
        _ -> nil
      end

    if is_nil(type) do
      0
    else
      action =
        Kantele.Combat.Skills.query_action(type, Stats.skill(asker.meta.stats, sp), fn _ -> 1 end)

      get = fn key -> Map.get(action, key, 0) end

      case type do
        "weapon" -> div(get.("force") + get.("parry") + get.("dodge") - 250, 10)
        _ -> div(get.("force") + get.("attack") + get.("parry") + get.("dodge") - 150, 15)
      end
    end
  end

  defp mode_bonus(asker, cfg) do
    case Map.get(cfg, :calc_mode) do
      "max_neili_4000" ->
        if asker.meta.vitals.max_neili > 4000, do: 20, else: 0

      "flat_20" ->
        20

      _ ->
        0
    end
  end

  defp mapped_skill(stats, skill) do
    case Stats.mapped(stats, skill) do
      nil -> nil
      value when is_atom(value) -> to_string(value) |> String.replace("_", "-")
      value when is_binary(value) -> String.replace(value, "_", "-")
      _ -> nil
    end
  end

  defp bump(skills, names, delta) when is_map(skills) do
    Enum.reduce(names, skills, fn name, acc ->
      Map.put(acc, name, Map.get(acc, name, 0) + delta)
    end)
  end

  defp want_key(cfg), do: Map.get(cfg, :want_key, Map.get(cfg, :category, ""))

  defp want_count(asker, cfg) do
    PlayerMeta.get_temp(asker.meta, "want_opinion/#{want_key(cfg)}", 0) || 0
  end

  defp env_get(asker, key) do
    env = asker.meta.env || %{}
    Map.get(env, key) || Map.get(env, String.to_atom(key)) || false
  end

  defp fighting?(asker), do: (asker.meta.combat.enemies || []) != []

  defp fighting_with?(npc, asker) do
    id = asker.id

    (npc.meta.combat.enemies || [])
    |> Enum.any?(fn enemy -> Map.get(enemy, :id) == id or Map.get(enemy, "id") == id end)
  end

  defp busy_with_self?(npc, asker), do: busy_with?(npc, asker.id)

  defp busy_with_other?(npc, asker), do: busy_with?(npc) and not busy_with?(npc, asker.id)

  defp busy_with?(npc), do: Map.get(npc.meta.temp || %{}, "opinion") != nil

  defp busy_with?(npc, id) do
    case Map.get(npc.meta.temp || %{}, "opinion") do
      ^id -> true
      _ -> false
    end
  end

  defp armed?(asker) do
    case Map.get(asker.meta.combat, :equipped, %{}) do
      %{weapon: weapon} -> weapon != nil
      %{"weapon" => weapon} -> weapon != nil
      _ -> false
    end
  end

  defp low_vitals?(asker) do
    vitals = asker.meta.vitals
    qi_pct = div(vitals.qi * 100, max(vitals.max_qi, 1))
    jing_pct = div(vitals.jing * 100, max(vitals.max_jing, 1))
    qi_pct < 80 or jing_pct < 80
  end

  defp all_performs?(asker, ids) do
    Enum.all?(ids, fn perform -> env_get(asker, "can_perform/jiuyin-shengong/#{perform}") end)
  end

  defp msg(cfg, key) do
    msgs = (cfg && Map.get(cfg, :msgs)) || %{}
    Map.get(msgs, to_string(key)) || Map.get(msgs, key) || ""
  end

  defp deny_msg(cfg, key, npc, asker), do: {:deny, decorate(msg(cfg, key), npc, asker)}

  # LPC message_vision 的 $N/$n 在 UCL 里写成 {npc}/{name}（$ 会被校验器拒绝）。
  defp decorate(text, npc, asker) when is_binary(text) do
    text
    |> replace("{npc}", (npc && Map.get(npc, :name)) || "")
    |> replace("{name}", (asker && Map.get(asker, :name)) || "")
  end

  defp decorate(_, _, _), do: ""

  defp replace(text, placeholder, value) when is_binary(text), do: String.replace(text, placeholder, value)
  defp replace(_, _, _), do: ""

  defp notify(npc, attacker, text) when is_binary(text) and text != "" do
    if pid = attacker.pid, do: send(pid, {:room_message, "#{npc.name}#{text}"})
  end

  defp notify(_, _, _), do: :ok
end
