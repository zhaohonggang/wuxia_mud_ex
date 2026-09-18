Code.require_file("translate_perform.exs", __DIR__)

defmodule Scripts.F4Checklist do
  @moduledoc """
  F4 步骤 3「人工校对清单」生成器。

  复用 `Scripts.TranslatePerform.extract/1` 的事实抽取，把全量 perform/exert
  骨架按待移植复杂度分档，输出 markdown 勾选清单。

  用法（跑在仓库根）：

      KUNGFU_SRC=/tmp/kungfu_skill RUN_CHECKLIST=1 mix run scripts/f4_checklist.exs

  输出默认写到 `docs/kungfu-f4-migration-checklist.zh-CN.md`。
  """

  alias Scripts.TranslatePerform

  @tier_order ["T1", "T2", "T3", "T4", "T5"]

  @tier_titles %{
    "T1" => "T1 自我增益 exert（无目标、无条件）",
    "T2" => "T2 无目标 perform（自我/治疗/位移等）",
    "T3" => "T3 攻击型 perform（do_damage，走目标侧结算）",
    "T4" => "T4 状态/毒型（affect_by 非空，需条件宿主）",
    "T5" => "T5 需 prepare_skill（当前被 prepare 门槛阻塞）"
  }

  def build(src_root) do
    src_root
    |> Path.join("*/*.c")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&TranslatePerform.extract/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&row/1)
    |> Enum.group_by(& &1.tier)
  end

  def render(groups) do
    total = groups |> Map.values() |> List.flatten() |> length()

    header = """
    # Kantele F4 招式/内功迁移校对清单（自动生成）

    > 生成器：`scripts/f4_checklist.exs`（`KUNGFU_SRC=/tmp/kungfu_skill RUN_CHECKLIST=1 mix run scripts/f4_checklist.exs`）
    > 数据源：LPC `kungfu/skill/*/*.c`，经 `Scripts.TranslatePerform.extract/1` 抽取事实。
    > 用法：逐条校对 `TODO(migrate)` 门槛/效果，实装后勾选并把该文件自 `tmp/perf_out` 挑入
    > `lib/kantele/combat/skills/performs/` + 注册 `Skills.@static`。

    共 #{total} 个骨架。

    """

    summary =
      @tier_order
      |> Enum.map(fn t ->
        n = groups |> Map.get(t, []) |> length()
        "| #{t} | #{@tier_titles[t]} | #{n} |"
      end)
      |> Enum.join("\n")

    summary_block = """
    | 档 | 含义 | 数量 |
    |---|---|---|
    #{summary}

    """

    sections =
      @tier_order
      |> Enum.map(fn t ->
        rows = groups |> Map.get(t, []) |> Enum.sort_by(&{&1.skill, &1.move})

        body =
          rows
          |> Enum.map_join("\n", fn r ->
            "- [ ] `#{r.skill}/#{r.move}` #{r.kind}「#{r.title}」" <>
              " 门槛: #{r.gates} | 效果: #{r.effects} | 依赖: #{r.blocked}"
          end)

        "## #{@tier_titles[t]}\n\n#{body}\n"
      end)
      |> Enum.join("\n")

    header <> summary_block <> sections
  end

  defp row(d) do
    %{
      tier: tier(d),
      skill: d.skill,
      move: d.move,
      kind: d.kind,
      title: d.title,
      gates: gates(d),
      effects: effects(d),
      blocked: blocked(d)
    }
  end

  defp tier(d) do
    cond do
      d.prepared_gates != [] -> "T5"
      d.affect_by != [] -> "T4"
      d.remote_damage -> "T3"
      d.kind == :exert -> "T1"
      true -> "T2"
    end
  end

  defp blocked(d) do
    []
    |> maybe(d.prepared_gates != [], "prepare_skill 未实现")
    |> maybe(d.remote_damage, "target-side 结算（通道已就绪）")
    |> maybe(d.affect_by != [], "condition 宿主（已就绪）")
    |> case do
      [] -> "无"
      list -> Enum.join(list, "; ")
    end
  end

  defp maybe(list, false, _), do: list
  defp maybe(list, true, tag), do: list ++ [tag]

  defp gates(d) do
    []
    |> add_pairs("level:", d.level_gates, ">=")
    |> add_pairs("assign:", d.assign_refs, "=")
    |> add_pairs("var:", d.var_gates, "<")
    |> add_pairs("map:", d.map_gates, "=")
    |> add_pairs("prepared:", d.prepared_gates, "=")
    |> add_pairs("res:", d.resource_gates, ">=")
    |> join_or_none()
  end

  defp effects(d) do
    []
    |> add_pairs("add:", d.add_costs, " ")
    |> add_pairs("set:", d.set_flags, "=")
    |> add_list("temp:", d.temp_set)
    |> add_list("apply+:", d.apply_adds)
    |> add_list("affect:", d.affect_by)
    |> add_flag("remote_damage", d.remote_damage)
    |> add_flag("busy", d.busy_lines != [])
    |> join_or_none()
  end

  defp add_pairs(acc, _label, [], _op), do: acc
  defp add_pairs(acc, label, pairs, op) do
    acc ++ [label <> Enum.map_join(pairs, ",", fn {a, b} -> "#{a}#{op}#{b}" end)]
  end

  defp add_list(acc, _label, []), do: acc
  defp add_list(acc, label, list), do: acc ++ [label <> Enum.join(list, ",")]

  defp add_flag(acc, _label, false), do: acc
  defp add_flag(acc, label, true), do: acc ++ [label]

  defp join_or_none([]), do: "—"
  defp join_or_none(list), do: Enum.join(list, "; ")
end

if System.get_env("RUN_CHECKLIST") in ["1", "true"] do
  src = System.get_env("KUNGFU_SRC") || Path.join([__DIR__, "fixtures", "kungfu", "skill"])

  out =
    System.get_env("KUNGFU_CHECKLIST_OUT") ||
      Path.join([__DIR__, "..", "docs", "kungfu-f4-migration-checklist.zh-CN.md"])

  groups = Scripts.F4Checklist.build(src)
  File.write!(out, Scripts.F4Checklist.render(groups))

  counts =
    groups
    |> Enum.map(fn {t, rows} -> {t, length(rows)} end)
    |> Enum.sort()

  IO.inspect(counts, label: "checklist")
  IO.puts("written: #{out}")
end
