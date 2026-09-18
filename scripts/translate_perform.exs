defmodule Scripts.TranslatePerform do
  @moduledoc """
  kungfu 招式/运功提取器（F4 移植管线，`scripts/translate_perform.exs`）

  扫描 `kungfu/skill/<skill>/<move>.c`，按 `int perform(` / `int exert(`
  顶层签名分类（F_SSERVER / F_CLEAN_UP 继承标注一并记录），抽取门槛、
  资源消耗、文案等事实数据，产出骨架（与样板实装同模板，语义未自动化处
  标 `TODO(migrate)`，由人工校对清单补完）。

  用法（跑在仓库根）：

      mix run scripts/translate_perform.exs
      KUNGFU_SRC=/path/to/mud/kungfu/skill mix run scripts/translate_perform.exs
      KUNGFU_OUT=/tmp/out mix run scripts/translate_perform.exs

  默认输出到 `tmp/perf_out`（不进编译路径，人工评审后再挑入
  `lib/kantele/combat/skills/performs/`）。不设置 `RUN_EXTRACTOR=1` 时
  （如被测试 `Code.require_file` 引入）不执行主流程。

  LPC 源码经核验全部是合法 UTF-8，故无需转码/清洗。
  """

  @perform_re ~r/^\s*int\s+perform\s*\(/m
  @exert_re ~r/^\s*int\s+exert\s*\(/m
  @inherit_re ~r/\binherit\s+(F_\w+)\b/
  @sense_re ~r/#define\s+\w+\s*"「"\s*\w*\s*"([^"「」]+)/
  @level_gate_re ~r/query_skill\("([a-z0-9-]+)"[^)]*\)+\s*<\s*(\d+)/
  @assign_re ~r/(\w+)\s*=\s*[^;\n]*?query_skill\("([a-z0-9-]+)"/
  @var_gate_re ~r/\b(\w+)\s*<\s*(\d+)/
  @map_gate_re ~r/query_skill_mapped\("(\w+)"\)\s*!=\s*"([a-z0-9-]+)"/
  @prepared_gate_re ~r/query_skill_prepared\("(\w+)"\)\s*!=\s*"([a-z0-9-]+)"/
  @resource_gate_re ~r/query\("(\w+)"[^)]*\)+\s*<\s*(\d+)/
  @add_re ~r/\badd\("(\w+)",\s*(-?\d+)\)/
  @set_re ~r/\bset\("(\w+)",\s*(\d+)\)/
  @set_temp_re ~r/\bset_temp\("(\w+)"/
  @add_temp_re ~r/\badd_temp\("apply\/(\w+)"/
  @affect_re ~r/\baffect_by\("([a-z_]+)"/
  @damage_re ~r/\bdo_damage\(/
  @busy_re ~r/^\s*(?:\/\/)?\s*.*\b(?:start_busy|is_busy)\(/
  @notify_re ~r/notify_fail\(\s*"([^"\n]+)/m

  @doc "按顶层 perform/exert 签名分类：`:perform` | `:exert` | `:skip`"
  def classify(src) do
    text = File.read!(src)

    kind =
      cond do
        Regex.match?(@perform_re, text) -> :perform
        Regex.match?(@exert_re, text) -> :exert
        true -> :skip
      end

    {kind, Regex.match?(@inherit_re, text) && Regex.run(@inherit_re, text) |> List.last()}
  end

  @doc "抽取事实数据；`nil` 表示非招式/运功文件"
  def extract(src) do
    {kind, inherit} = classify(src)

    if kind == :skip do
      nil
    else
      text = File.read!(src)
      skill = src |> Path.dirname() |> Path.basename()
      move = src |> Path.basename(".c")

      %{
        skill: skill,
        move: move,
        kind: kind,
        inherit: inherit,
        title: title_of(text, move),
        level_gates: pairs(Regex.scan(@level_gate_re, text, capture: :all_but_first)),
        assign_refs: pairs(Regex.scan(@assign_re, text, capture: :all_but_first)),
        var_gates: pairs(Regex.scan(@var_gate_re, text, capture: :all_but_first)),
        map_gates: pairs(Regex.scan(@map_gate_re, text, capture: :all_but_first)),
        prepared_gates: pairs(Regex.scan(@prepared_gate_re, text, capture: :all_but_first)),
        resource_gates: pairs(Regex.scan(@resource_gate_re, text, capture: :all_but_first)),
        add_costs: pairs(dedup(Regex.scan(@add_re, text, capture: :all_but_first))),
        set_flags: pairs(dedup(Regex.scan(@set_re, text, capture: :all_but_first))),
        temp_set: dedup(List.flatten(Regex.scan(@set_temp_re, text, capture: :all_but_first))),
        apply_adds:
          dedup(List.flatten(Regex.scan(@add_temp_re, text, capture: :all_but_first))),
        affect_by: dedup(List.flatten(Regex.scan(@affect_re, text, capture: :all_but_first))),
        remote_damage: Regex.run(@damage_re, text) != nil,
        busy_lines: busy_lines(text),
        first_fail: first_fail(text)
      }
    end
  end

  @doc "渲染骨架到输出根；返回 `%{written: [...], skipped: [...]}`"
  def run(src_root, out_root) do
    {written, skipped} =
      src_root
      |> skill_dirs()
      |> Enum.reduce({[], []}, &reduce_skill_dir(&1, &2, out_root))

    %{written: Enum.sort(written), skipped: Enum.sort(skipped)}
  end

  defp reduce_skill_dir(skill_dir, acc, out_root) do
    skill_dir
    |> Path.join("*.c")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.reduce(acc, &reduce_c_file(&1, &2, out_root))
  end

  defp reduce_c_file(c_file, {written, skipped}, out_root) do
    case extract(c_file) do
      nil ->
        {written, [Path.relative_to(c_file, System.get_env("KUNGFU_SRC") || Path.join([__DIR__, "fixtures", "kungfu", "skill"])) | skipped]}

      data when is_map(data) ->
        case write_skeleton(out_root, skill_from_path(c_file), data) do
          nil -> {written, skipped}
          out -> {[out | written], skipped}
        end
    end
  end

  defp skill_from_path(c_file) do
    c_file
    |> Path.dirname()
    |> Path.basename()
  end

  @doc "渲染单个骨架文本（测试/人工复刻参照）"
  def render_skeleton(data) do
    mod = module_name(data.skill, data.move)

    gates =
      inspect(
        %{
          level_gates: data.level_gates,
          assign_refs: data.assign_refs,
          var_gates: data.var_gates,
          map_gates: data.map_gates,
          prepared_gates: data.prepared_gates,
          resource_gates: data.resource_gates
        },
        pretty: true,
        width: 80
      )
      |> comment_block()

    effects =
      inspect(
        %{
          add_costs: data.add_costs,
          set_flags: data.set_flags,
          temp_set: data.temp_set,
          apply_adds: data.apply_adds,
          affect_by: data.affect_by,
          remote_damage: data.remote_damage,
          busy_lines: data.busy_lines
        },
        pretty: true,
        width: 80
      )
      |> comment_block()

    stanzas =
      data.busy_lines
      |> Enum.map(&"      #   - #{&1}")
      |> Enum.join("\n")

    """
    defmodule #{mod} do
      @moduledoc \"""
      #{data.kind}「#{data.title}」（source #{data.skill}/#{data.move}.c，由 translate_perform.exs 骨架生成，inherit #{data.inherit || "?"}）

      TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
      以上注释行（TODO(migrate)）校对完成后删除。
      \"""

      import Kalevala.Character.Conn

      alias Kantele.Combat.Broadcast
      alias Kantele.Character.CommandView

      @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
      def run(conn) do
        character = conn.character

        with :ok <- check_gates(character) do
          apply_effect(conn, character)
        else
          {:error, message} ->
            conn
            |> render(CommandView, "text", %{text: message})
            |> assign(:prompt, false)
        end
      end

      # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
    #{gates}
      defp check_gates(_character), do: :ok

      defp apply_effect(conn, character) do
        # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
    #{effects}
    #{stanzas}
        conn
        |> Broadcast.publish("-= TODO(migrate) 未移植文案。\\n", n1: character.name)
        |> put_character(character)
        |> assign(:prompt, false)
      end
    end
    """
  end

  # 任意多行文本逐行加注释前缀，保证嵌入 heredoc 后每行都是注释
  defp comment_block(text, indent \\ "      #   ") do
    text
    |> String.split("\n")
    |> Enum.map_join("\n", &(indent <> &1))
  end

  defp write_skeleton(out_root, skill, data) do
    dir = Path.join(out_root, skill_dir(skill))
    File.mkdir_p!(dir)
    file = Path.join(dir, data.move <> ".ex")
    rendered = render_skeleton(data)

    if File.read(file) == {:ok, rendered} do
      nil
    else
      File.write!(file, rendered)
      Path.relative_to(file, out_root)
    end
  end

  @doc "技能 id → 输出目录名（与模块文件路径一致，huashan-jian → huashan_jian）"
  def skill_dir(skill), do: String.replace(skill, "-", "_")

  defp skill_dirs(src_root) do
    src_root
    |> File.ls!()
    |> Enum.map(&Path.join(src_root, &1))
    |> Enum.filter(&File.dir?/1)
    |> Enum.sort()
  end

  defp title_of(text, move) do
    case Regex.run(@sense_re, text) do
      [_, sense] -> sense |> String.trim()
      nil -> move
    end
  end

  defp first_fail(text) do
    case Regex.run(@notify_re, text) do
      [_, msg] -> msg
      nil -> nil
    end
  end

  defp busy_lines(text) do
    text
    |> String.split("\n")
    |> Enum.filter(&Regex.match?(@busy_re, &1))
    |> Enum.map(&String.trim/1)
  end

  defp dedup(list), do: list |> Enum.uniq() |> Enum.sort()

  defp pairs(list), do: list |> Enum.map(&List.to_tuple/1) |> Enum.sort()

  @doc "技能/招式 id → Elixir 模块名（如 huashan-jian/jie → Kantele.Combat.Skills.Performs.HuashanJian.Jie）"
  def module_name(skill, move) do
    "Kantele.Combat.Skills.Performs." <> camel(skill) <> "." <> camel(move)
  end

  defp camel(id) do
    id
    |> String.split("-")
    |> Enum.map_join("", &String.capitalize/1)
  end
end

if System.get_env("RUN_EXTRACTOR") in ["1", "true"] do
  src = System.get_env("KUNGFU_SRC") || Path.join([__DIR__, "fixtures", "kungfu", "skill"])
  out = System.get_env("KUNGFU_OUT") || Path.join([__DIR__, "..", "tmp", "perf_out"])
  Scripts.TranslatePerform.run(src, out) |> IO.inspect(label: "translate_perform")
end
