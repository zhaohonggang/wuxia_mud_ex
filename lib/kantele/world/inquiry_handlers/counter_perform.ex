defmodule Kantele.World.InquiryHandlers.CounterPerform do
  @moduledoc """
  计数器式渐进授绝招（`kind = "counter_perform"`），镜像
  `kungfu/class/wudang/zhang.c` 的 `ask_skill6`（武当张三丰「太极图」）。

  与 `SectMaster.inquiry_grant` 的「一次问对即学会」不同，LPC 这里把
  `can_perform/<perform_id>` 当**计数器**用：每次询问过门就 +1，攒到
  `max_count`（10）才真正学会绝招；中途还要扣 `learned_points`（潜能）。
  目前全库仅此一处 inquiry 使用该模式（其余 `add("can_perform/...")`
  计数器都在读书/练技能链，不走 inquiry），故独立成 kind 而不污染
  `inquiry_grant` 的布尔语义。

  ## UCL 配置（`inquiries` 的 map 值）

      value = {
        kind = "counter_perform"
        perform_id = "taiji-quan/tu"          # 第 max_count 次时 learn_perform
        skill = "taiji-quan"                  # 必修技能（< 1 即拒）
        counter_key = "can_perform/taiji-quan/tu"  # 计数器落点（meta.marks）
        max_count = 10                        # 计数器上限
        family = "武当派"                     # 限门派；缺省不限
        min_gongxian = 3000                   # 贡献下限
        min_shen = 250000                     # 杀气下限
        max_jingli = 1000                     # 精力门槛（meta.vitals.max_jingli 下限）
        potential_cost = 100                  # 每次扣 learned_points（潜能）
        min_levels = { taiji_quan = 250, taiji_shengong = 300, taoism = 300 }
        level_deny = {                        # 每技能单独拒绝文案（键同 min_levels）
          taiji_quan = "你的太极拳法还不到家，要多练练！"
          taiji_shengong = "你的太极神功还不到家，好好修行吧！"
          taoism = "你的道学心法研究的还不够明白，要下功夫苦学才是！"
        }
        improve_skills = {                    # 完成时各技能提升次数（见下方差异说明）
          taiji_shengong = 3, force = 3, unarmed = 3, taiji_quan = 3,
          taoism = 3, martial_cognize = 1
        }
        cost_gongxian = 3000                  # 完成时扣除的贡献
        maxed = "该学的你都已经学了，以后要善加利用！"
        family_deny = "不是我们武当派的人，何出此言？"     # 自动加敬称
        skill_deny = "你连太极拳都没学，还谈什么绝招可言？"
        gongxian_deny = "你为我武当派效力还不够，这招我不忙传你。"
        shen_deny = "你行侠仗义的事情做得还不够多，我不能放心传你绝招！"
        jingli_deny = "你的精力不济，就算传给你太极图你也难以运用。"
        potential_deny = "你看了半天，没有研究出什么新的东西，看来是潜能还不够！"
        insight = "你对太极图有了一点领悟。"              # 未满 max_count 时私发
        learned = "你学会了道家密技「太极图」。"            # 满 max_count 时私发
        npc_say = "你看懂了多少？"                        # NPC 房间发言
        vision = "点点头，双手轻轻划了一个圈子，地上土雾无端吸起，又渐渐落下。"
      }

  ## 门控顺序（严格按 LPC ask_skill6）

  计数器封顶 → 门派 → 必修技能 `< 1` → 贡献 → 杀气 → 各技能等级 →
  精力 →（房间广播 + NPC 发言）→ 潜能 → 计数 +1。

  注意贡献/杀气在技能等级**之前**判定，与 `inquiry_grant` 的顺序不同，
  故不共用那段 cond。

  ## 与 LPC 的差异

  - 计数器存 `meta.marks[counter_key]`（`Records.save` 持久化，语义同 LPC
    `set("can_perform/...")`），不用 `stats.performs`（MapSet 无数值语义）。
  - `improve_skill(skill, 1500000)` 的「大幅提升」在引擎无对应物：
    `Stats.improve_skill/2` 每次只 +1，此处按配置的**次数**调用
    （LPC 每个技能 3 次 → +3 级），量级不还原，记为 fidelity 缺口。
  - `can_improve_skill` 前置检查（LPC 每个 improve 前都查）引擎无对应，
    直接提升。
  """

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActions.Helpers

  @doc "处理一次「询问绝招」：门控 → 广播 → 计数 →（满次）学会"
  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "perform_id")) -> conn
      Map.get(data, :asker_id) != character.id -> conn
      true -> run_for(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  # ---- 门控链（顺序 = LPC ask_skill6） ----

  defp run_for(conn, character, config, data) do
    cond do
      denial = gate_denial(character, config) ->
        reply(conn, denial)

      true ->
        teach(conn, character, config, data)
    end
  end

  defp gate_denial(character, config) do
    counter = counter_of(character, config)

    cond do
      counter >= max_count(config) ->
        text(config, "maxed", "该学的你都已经学了，以后要善加利用！")

      family_denied?(character, config) ->
        Helpers.respect(character) <> text(config, "family_deny", "不是我们武当派的人，何出此言？")

      skill_unlearned?(character, config) ->
        text(config, "skill_deny", "你连太极拳都没学，还谈什么绝招可言？")

      stat(stats_of(character), :gongxian) < min_gongxian(config) ->
        text(config, "gongxian_deny", "你为我武当派效力还不够，这招我不忙传你。")

      stat(stats_of(character), :shen) < min_shen(config) ->
        text(config, "shen_deny", "你行侠仗义的事情做得还不够多，我不能放心传你绝招！")

      denial = level_gate_denial(character, config) ->
        denial

      max_jingli_of(character) < max_jingli(config) ->
        text(config, "jingli_deny", "你的精力不济，就算传给你太极图你也难以运用。")

      true ->
        nil
    end
  end

  # ---- 授业：广播 + NPC 发言 + 潜能 + 计数 ----

  defp teach(conn, character, config, data) do
    stats = stats_of(character)
    room_id = Map.get(data, :npc_room_id)
    npc_name = Map.get(data, :npc_name) || "对方"

    conn =
      if is_binary(room_id) do
        vision = text(config, "vision", "点点头，双手轻轻划了一个圈子，地上土雾无端吸起，又渐渐落下。")

        conn
        |> Helpers.broadcast(room_id, "#{npc_name}#{vision}\n")
        |> Helpers.say(room_id, npc_name, text(config, "npc_say", "你看懂了多少？"))
      else
        conn
      end

    # 潜能门槛：potential < learned_points + cost（LPC 在广播之后才判）
    cost = potential_cost(config)

    if potential(stats) < learned_points(stats) + cost do
      reply(conn, text(config, "potential_deny", "你看了半天，没有研究出什么新的东西，看来是潜能还不够！"))
    else
      advance(conn, character, config, data, cost)
    end
  end

  defp advance(conn, character, config, data, cost) do
    stats = stats_of(character)
    key = Map.fetch!(config, "counter_key")
    max = max_count(config)
    counter = counter_of(character, config) + 1

    # 计数器 + learned_points 一并落 meta（marks 持久化，stats 随 Records.save 落盘）
    stats = Map.put(stats, :learned_points, learned_points(stats) + cost)

    meta =
      character.meta
      |> PlayerMeta.put_mark(key, counter)
      |> Map.put(:stats, stats)

    character = %{character | meta: meta}

    if counter < max do
      # 未满：一点领悟（房间广播 + 私发）
      conn =
        case Map.get(data, :npc_room_id) do
          room_id when is_binary(room_id) ->
            Helpers.broadcast(conn, room_id, "{npc}迷迷茫茫的点了点头，深思良久。\n")

          _ ->
            conn
        end

      persist(conn, character, text(config, "insight", "你对太极图有了一点领悟。"))
    else
      complete(conn, character, config, data, counter)
    end
  end

  defp complete(conn, character, config, data, _counter) do
    stats = stats_of(character)
    perform_id = Map.fetch!(config, "perform_id")
    npc_name = Map.get(data, :npc_name) || "对方"

    stats =
      stats
      |> Stats.learn_perform(perform_id)
      |> improve_skills(Map.get(config, "improve_skills") || %{})
      |> deduct_gongxian(cost_gongxian(config))

    character = %{character | meta: %{character.meta | stats: stats}}

    conn =
      case Map.get(data, :npc_room_id) do
        room_id when is_binary(room_id) ->
          Helpers.broadcast(
            conn,
            room_id,
            "{npc}脸露笑容，喜道：我已经明白了，所谓真与幻象其实并无分别啊！" <>
              "#{npc_name}哈哈大笑：明白就好，明白就好，以后勿得轻易使用，你去吧。\n"
          )

        _ ->
          conn
      end

    persist(conn, character, text(config, "learned", "你学会了道家密技「太极图」。"))
  end

  defp persist(conn, character, text) do
    Kantele.Character.Records.save(character)

    conn
    |> put_character(character)
    |> reply(text)
  end

  # LPC `improve_skill(skill, 1500000)` ×N：引擎 improve_skill/2 每次只 +1，
  # 按配置次数调用（量级不还原，见 @moduledoc 差异说明）。
  defp improve_skills(stats, improves) when is_map(improves) do
    Enum.reduce(improves, stats, fn {skill, times}, acc ->
      skill = to_string(skill)
      times = int(times, 0)

      if times > 0 do
        Enum.reduce(1..times, acc, fn _i, s ->
          {s, _ok?} = Stats.improve_skill(s, skill)
          s
        end)
      else
        acc
      end
    end)
  end

  defp improve_skills(stats, _improves), do: stats

  defp deduct_gongxian(%Stats{} = stats, cost) when is_integer(cost) and cost > 0 do
    %{stats | gongxian: max((stats.gongxian || 0) - cost, 0)}
  end

  defp deduct_gongxian(stats, _cost), do: stats

  # ---- 配置读取（容错：UCL 数字可能以字符串落库） ----

  defp counter_of(character, config) do
    case Map.get(config, "counter_key") do
      key when is_binary(key) -> PlayerMeta.mark(character.meta, key) || 0
      _ -> 0
    end
  end

  defp max_count(config), do: int(Map.get(config, "max_count"), 10)
  defp min_gongxian(config), do: int(Map.get(config, "min_gongxian"), 0)
  defp min_shen(config), do: int(Map.get(config, "min_shen"), 0)
  defp max_jingli(config), do: int(Map.get(config, "max_jingli"), 0)
  defp potential_cost(config), do: int(Map.get(config, "potential_cost"), 0)
  defp cost_gongxian(config), do: int(Map.get(config, "cost_gongxian"), 0)

  defp int(value, default) when is_integer(value), do: value

  defp int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> n
      :error -> default
    end
  end

  defp int(_value, default), do: default

  defp text(config, key, default), do: Map.get(config, key) || default

  # ---- 门控细节 ----

  defp family_denied?(character, config) do
    case Map.get(config, "family") do
      family when is_binary(family) and family != "" -> family_name(character) != family
      _ -> false
    end
  end

  defp family_name(%{meta: %{family: family}}) when is_map(family), do: Family.name(family)
  defp family_name(_character), do: nil

  defp skill_unlearned?(character, config) do
    case Map.get(config, "skill") do
      skill when is_binary(skill) -> skill_level(stats_of(character), skill) < 1
      _ -> false
    end
  end

  # LPC 每个技能一条独立拒绝文案；键与 min_levels 同形（loader 已 `_`→`-`）
  defp level_gate_denial(character, config) do
    stats = stats_of(character)

    Enum.find_value(min_levels(config), fn {skill, level} ->
      if skill_level(stats, skill) < level do
        deny = level_deny(config, skill)
        deny || "你的修为还不够，练高了再来吧。"
      end
    end)
  end

  defp min_levels(config) do
    case Map.get(config, "min_levels") do
      levels when is_map(levels) -> levels
      _ -> %{}
    end
  end

  defp level_deny(config, skill) do
    denies = Map.get(config, "level_deny") || %{}

    Enum.find_value([skill, String.replace(skill, "-", "_"), String.to_atom(skill)], fn key ->
      case Map.get(denies, key) do
        text when is_binary(text) and text != "" -> text
        _ -> nil
      end
    end)
  rescue
    # String.to_atom 对非 ASCII 安全，但非法输入仍兜底
    ArgumentError -> nil
  end

  # ---- 角色取数 ----

  defp stats_of(%{meta: %{stats: stats}}) when not is_nil(stats), do: stats
  defp stats_of(_character), do: %{}

  defp stat(stats, key), do: Map.get(stats, key, 0) || 0

  defp skill_level(stats, skill), do: Map.get(Map.get(stats, :skills) || %{}, skill, 0)

  defp potential(stats), do: stat(stats, :potential)
  defp learned_points(stats), do: stat(stats, :learned_points)

  defp max_jingli_of(%{meta: %{vitals: vitals}}) when is_map(vitals),
    do: Map.get(vitals, :max_jingli, 0) || 0

  defp max_jingli_of(_character), do: 0

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn
end
