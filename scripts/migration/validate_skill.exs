#!/usr/bin/env elixir
# scripts/migration/validate_skill.exs
# 验证技能实现的完整性

defmodule Migration.ValidateSkill do
  @impl_root "lib/kantele/combat/skills"

  @required_callbacks [
    {:id, 0},
    {:valid_enable, 1},
    {:valid_learn, 1},
    {:practice_cost, 0},
    {:query_action, 1},
    {:query_action, 2}
  ]

  def run(skill_id \\ nil) do
    skills = if skill_id do
      [skill_id]
    else
      Path.wildcard(Path.join(@impl_root, "*.ex"))
      |> Enum.map(&Path.basename(&1, ".ex"))
      |> Enum.map(&String.replace(&1, "_", "-"))
      |> Enum.sort()
    end

    results = Enum.map(skills, &validate_skill/1)

    passed = Enum.count(results, &(&1.passed))
    failed = Enum.count(results, &(!&1.passed))

    IO.puts("\n=== Validation Summary ===")
    IO.puts("Total: #{length(skills)}")
    IO.puts("Passed: #{passed}")
    IO.puts("Failed: #{failed}")

    results
    |> Enum.filter(fn r -> !r.passed end)
    |> Enum.each(fn %{skill: s, errors: e} ->
      IO.puts("\n❌ #{s}:")
      Enum.each(e, fn err -> IO.puts("  - #{err}") end)
    end)

    results
  end

  defp validate_skill(skill_id) do
    file = Path.join(@impl_root, skill_dir(skill_id) <> ".ex")

    if !File.exists?(file) do
      %{skill: skill_id, passed: false, errors: ["File not found: #{file}"]}
    else
      code = File.read!(file)
      errors = []

      # 1. 检查模块定义
      if !Regex.match?(~r/defmodule Kantele\.Combat\.Skills\.\w+ do/, code) do
        errors = ["Missing module definition" | errors]
      end

      # 2. 检查 use Kantele.Combat.Skill
      if !String.contains?(code, "use Kantele.Combat.Skill") do
        errors = ["Missing 'use Kantele.Combat.Skill'" | errors]
      end

      # 3. 检查必需回调
      for {callback, arity} <- @required_callbacks do
        callback_str = Atom.to_string(callback)
        if !Regex.match?(~r/def #{Regex.escape(callback_str)}/, code) do
          errors = ["Missing required callback: #{callback}/#{arity}" | errors]
        end
      end

      # 4. 检查 @actions 属性
      if !String.contains?(code, "@actions") do
        errors = ["Missing @actions attribute" | errors]
      end

      # 4. 检查 id() 函数
      if !Regex.match?(~r/def id\(\), do:/, code) do
        if !Regex.match?(~r/def id\(\), do: /, code) do
          errors = ["Missing or malformed id()/0" | errors]
        end
      end

      # 5. 检查 valid_enable 返回 boolean
      if String.contains?(code, "def valid_enable") &&
         !Regex.match?(~r/def valid_enable.*do: .*(true|false|usage (in|==|===))/, code) do
        errors = ["valid_enable may not return boolean" | errors]
      end

      # 6. 检查 perform_list/exert_list 如果有绝招/运功
      if String.contains?(code, "def perform_list") &&
         !Regex.match?(~r/%\{.*=>.*\}/, code) do
        errors = ["perform_list should return map" | errors]
      end

      if String.contains?(code, "def exert_list") &&
         !Regex.match?(~r/%\{.*=>.*\}/, code) do
        errors = ["exert_list should return map" | errors]
      end

      # 7. 检查 query_action 返回 map
      if String.contains?(code, "def query_action") &&
         !Regex.match?(~r/Kantele\.Combat\.Skill\.pick_action/, code) do
        errors = ["query_action should use pick_action" | errors]
      end

      passed = errors == []

      %{skill: skill_id, passed: passed, errors: Enum.reverse(errors)}
    end
  end

  defp skill_dir(skill_id) do
    String.replace(skill_id, "-", "_")
  end
end

Migration.ValidateSkill.run()