defmodule Scripts.TranslateSkill do
  @moduledoc """
  武学元数据提取器（F4 移植管线，`scripts/translate_skill.exs`）

  扫描 `kungfu/skill/<skill>.c` 顶层文件，抽取可自动化的静态事实并产出
  武学骨架：

    * `mapping *action` 中**全字面量**的招式（八字段，`dmage`/`name`
      等源拼写差异自动归一）；
    * `valid_enable` 的用法集合；
    * `practice_skill` 的 qi/neili 消耗；
    * 动态招式数量与源码钩子/条件（`hit_ob`/`valid_damage`/`valid_learn`/
      `valid_combine`/`difficult_level` 等）清单，供人工校对。

  动态招式（值含 `this_player()`/`query_skill()`/`random()` 等表达式）不
  入 `@actions`，只在 `TODO(migrate)` 中计数量并说明。

  用法（跑在仓库根）：

      RUN_SKILL_EXTRACTOR=1 mix run scripts/translate_skill.exs
      RUN_SKILL_EXTRACTOR=1 KUNGFU_SRC=/path/to/mud/kungfu/skill mix run scripts/translate_skill.exs
      RUN_SKILL_EXTRACTOR=1 KUNGFU_OUT=/tmp/out mix run scripts/translate_skill.exs

  默认输出到 `tmp/skill_out`（不进编译路径，人工评审后再挑入
  `lib/kantele/combat/skills/`）。不设置 `RUN_SKILL_EXTRACTOR=1` 时
  （如被测试 `Code.require_file` 引入）不执行主流程。

  LPC 源码经核验全部是合法 UTF-8，故无需转码/清洗。
  """

  @action_table_re ~r/mapping\s+\*?\s*action\s*=\s*\(\{(.*?)\}\);/us
  @entry_re ~r/\(\[(.*?)\]\)/us
  @string_re ~r/"([a-z_]+)"\s*:\s*"([^"]*)"/u
  @int_re ~r/"([a-z_]+)"\s*:\s*(-?\d+)(?=\s*[,\n])/u
  @dyn_re ~r/"\w+"\s*:\s*[^"\n]*(?:query_skill|query_temp|query_skill_mapped|random|this_player|combat_level)\s*\(/
  @enable_re ~r/usage\s*==\s*"([a-z0-9-]+)"/
  @practice_sig ~r/int\s+practice_skill\s*\(/
  @close_brace_re ~r/^\}/m
  @qi_re ~r/receive_damage\(\s*"qi"\s*,\s*(\d+)/
  @neili_re ~r/\badd\(\s*"neili"\s*,\s*-?(\d+)/

  @action_keys ["action", "force", "attack", "parry", "dodge", "damage", "lvl", "damage_type", "skill_name"]

  @hooks ~w(
    valid_learn valid_combine valid_force valid_damage hit_ob valid_effect
    difficult_level query_effect_parry query_effect_dodge skill_improved
    practice_skill perform_action_file exert_function_file
  )

  @types ~w(int void string mapping mixed object float)

  @doc "抽取单个顶层武学文件的事实数据（`skill` 为文件名去掉 `.c`）"
  def extract(src) do
    text = File.read!(src)
    {statics, dynamics} = text |> parse_actions() |> Enum.split_with(& &1.static)

    %{
      skill: Path.basename(src, ".c"),
      actions: Enum.map(statics, & &1.action),
      dynamic_actions: length(dynamics),
      valid_enable: parse_valid_enable(text),
      practice_cost: parse_practice_cost(text),
      flags: flags(text)
    }
  end

  @doc "解析 `mapping *action` 表；返回 `[%{static: boolean, action: map}]`"
  def parse_actions(text) do
    text
    |> action_table_body()
    |> action_entries()
    |> Enum.map(&parse_action/1)
  end

  @doc "渲染单个武学骨架文本（测试/人工复刻参照）"
  def render_skeleton(data) do
    mod = "Kantele.Combat.Skills.Generated." <> camel(data.skill)

    actions =
      case data.actions do
        [] ->
          "  @actions []"

        list ->
          "  @actions [\n" <> Enum.map_join(list, ",\n", &render_action/1) <> "\n  ]"
      end

    named? = Enum.any?(data.actions, &Map.has_key?(&1, "skill_name"))

    """
    defmodule #{mod} do
      @moduledoc \"""
      武学骨架「#{data.skill}」（源 #{data.skill}.c，由 translate_skill.exs 生成）

      已自动化：静态招式 #{length(data.actions)} 式、valid_enable、practice_cost。
      TODO(migrate)（人工校对后补完，完成后删除本段注释）：
      - 动态招式 #{data.dynamic_actions} 式（值含 this_player/query_skill/random，
        需在拿到出招属性后用公式复现，参照 lib/kantele/combat/skills/huashan_jian.ex）。
      - 源码钩子/条件：#{format_flags(data.flags)}
      - perform/exert 路由骨架见 tmp/perf_out/#{skill_dir(data.skill)}/
      \"""

      use Kantele.Combat.Skill

    #{actions}

      @impl true
      def id(), do: #{inspect(data.skill)}

    #{render_enable(data.valid_enable)}#{render_practice(data.practice_cost)}
      @impl true
      def query_action(level, rng \\\\ &:rand.uniform/1) do
        Kantele.Combat.Skill.pick_action(@actions, level, rng)
      end

      @doc "招式名 -> 招式数据（供 score/look 展示）"
      def actions(), do: @actions
    #{render_query_skill_name(named?)}end
    """
  end

  @doc "渲染全部顶层武学骨架到输出根；返回 `%{written: [...], count: n}`"
  def run(src_root, out_root) do
    datas =
      src_root
      |> Path.join("*.c")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(&extract/1)

    written =
      datas
      |> Enum.map(&write_skeleton(out_root, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()

    write_summary(out_root, datas)

    %{written: written, count: length(datas)}
  end

  @doc "技能 id → 输出文件名（huashan-jian → huashan_jian.ex）"
  def skill_dir(skill), do: String.replace(skill, "-", "_")

  @doc "技能 id → Elixir 模块名后缀（huashan-jian → HuashanJian）"
  def camel(id) do
    id
    |> String.split(["-", "_"])
    |> Enum.map_join("", &String.capitalize/1)
  end

  # -- 解析 ---------------------------------------------------------------

  defp action_table_body(text) do
    case Regex.run(@action_table_re, text) do
      [_, body] -> body
      _ -> ""
    end
  end

  defp action_entries(""), do: []

  defp action_entries(body) do
    @entry_re
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.map(&List.first/1)
  end

  defp parse_action(entry) do
    strings = pairs(Regex.scan(@string_re, entry, capture: :all_but_first))
    ints = pairs(Regex.scan(@int_re, entry, capture: :all_but_first), &String.to_integer/1)
    dynamic = Regex.match?(@dyn_re, entry)
    name = strings["skill_name"] || strings["name"]

    action =
      %{
        "action" => strings["action"] || "",
        "force" => ints["force"] || 0,
        "attack" => ints["attack"] || 0,
        "parry" => ints["parry"] || 0,
        "dodge" => ints["dodge"] || 0,
        "damage" => ints["damage"] || ints["dmage"] || 0,
        "lvl" => ints["lvl"] || 0,
        "damage_type" => strings["damage_type"] || "瘀伤"
      }

    action = if name, do: Map.put(action, "skill_name", name), else: action
    %{static: not dynamic, action: action}
  end

  defp pairs(list, transform \\ & &1) do
    Map.new(list, fn [k, v] -> {k, transform.(v)} end)
  end

  @doc "解析 `valid_enable` 的用法集合（排序去重）"
  def parse_valid_enable(text) do
    @enable_re
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "解析 `practice_skill` 的 qi/neili 消耗；未识别返回 `nil`"
  def parse_practice_cost(text) do
    body = func_body(text, @practice_sig)
    qi = capture_int(body, @qi_re)
    neili = capture_int(body, @neili_re)

    if qi || neili, do: %{qi: qi || 0, neili: neili || 0}, else: nil
  end

  @doc "源码中出现的钩子/条件函数名（排序）"
  def flags(text) do
    @hooks
    |> Enum.filter(&fun?(text, &1))
    |> Enum.sort()
  end

  defp fun?(text, name) do
    Regex.match?(~r/^\s*(?:#{Enum.join(@types, "|")})\s+#{Regex.escape(name)}\s*\(/m, text)
  end

  defp func_body(text, sig) do
    case Regex.run(sig, text, return: :index) do
      [{start, _len}] ->
        rest = binary_part(text, start, byte_size(text) - start)

        case Regex.run(@close_brace_re, rest, return: :index) do
          [{stop, _}] -> binary_part(rest, 0, stop)
          _ -> rest
        end

      _ ->
        ""
    end
  end

  defp capture_int(text, re) do
    case Regex.run(re, text, capture: :all_but_first) do
      [n] -> String.to_integer(n)
      _ -> nil
    end
  end

  # -- 渲染 ---------------------------------------------------------------

  defp render_action(action) do
    keys = Enum.filter(@action_keys, &Map.has_key?(action, &1))

    lines =
      Enum.map_join(keys, ",\n", fn key ->
        "      #{inspect(key)} => #{inspect(Map.fetch!(action, key))}"
      end)

    "    %{\n" <> lines <> "\n    }"
  end

  defp render_enable([]) do
    "  # TODO(migrate) valid_enable 未识别（源可能用变量/组合判断）\n" <>
      "  @impl true\n  def valid_enable(_usage), do: false\n"
  end

  defp render_enable(usages) do
    "  @impl true\n  def valid_enable(usage), do: usage in #{inspect(usages)}\n"
  end

  defp render_practice(nil), do: ""

  defp render_practice(%{qi: qi, neili: neili}) do
    "\n  @impl true\n  def practice_cost(), do: %{qi: #{qi}, neili: #{neili}}\n"
  end

  defp render_query_skill_name(false), do: ""

  defp render_query_skill_name(true) do
    """
      @doc "当前等级对应的最高招式名（query_skill_name）"
      def query_skill_name(level) do
        @actions
        |> Enum.reverse()
        |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
        |> case do
          nil -> nil
          action -> Map.get(action, "skill_name")
        end
      end

    """
  end

  defp format_flags([]), do: "（无）"
  defp format_flags(flags), do: Enum.join(flags, ", ")

  defp write_skeleton(out_root, data) do
    File.mkdir_p!(out_root)
    file = Path.join(out_root, skill_dir(data.skill) <> ".ex")
    rendered = render_skeleton(data)

    if File.read(file) == {:ok, rendered} do
      nil
    else
      File.write!(file, rendered)
      Path.relative_to(file, out_root)
    end
  end

  defp write_summary(out_root, datas) do
    File.mkdir_p!(out_root)

    body =
      datas
      |> Enum.map_join("\n", fn d ->
        "| #{d.skill} | #{length(d.actions)} | #{d.dynamic_actions} | " <>
          "#{Enum.join(d.valid_enable, ",")} | #{Enum.join(d.flags, ",")} |"
      end)

    rendered =
      """
      # F4 武学元数据提取摘要（translate_skill.exs）

      | skill | 静态招式 | 动态招式 | valid_enable | 钩子/条件 |
      | --- | --- | --- | --- | --- |
      #{body}
      """

    file = Path.join(out_root, "_summary.md")

    if File.read(file) != {:ok, rendered} do
      File.write!(file, rendered)
    end
  end
end

if System.get_env("RUN_SKILL_EXTRACTOR") in ["1", "true"] do
  src = System.get_env("KUNGFU_SRC") || Path.join([__DIR__, "fixtures", "kungfu", "skill"])
  out = System.get_env("KUNGFU_OUT") || Path.join([__DIR__, "..", "tmp", "skill_out"])
  Scripts.TranslateSkill.run(src, out) |> IO.inspect(label: "translate_skill")
end
