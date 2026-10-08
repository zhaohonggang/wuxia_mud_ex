#!/usr/bin/env elixir
# scripts/migration/batch_migrate.exs
# 批量迁移助手：展示待迁移技能、生成清单、创建迁移模板

defmodule Migration.BatchMigrate do
  @generated_root "tmp/skill_out"
  @impl_root "lib/kantele/combat/skills"

  def list_pending do
    # 列出已生成但未实现的技能
    generated = Path.wildcard(Path.join(@generated_root, "*.ex"))
    |> Enum.map(&Path.basename(&1, ".ex"))
    |> Enum.map(&String.replace(&1, "_", "-"))
    |> Enum.sort()

    implemented = Path.wildcard(Path.join(@impl_root, "*.ex"))
    |> Enum.map(&Path.basename(&1, ".ex"))
    |> Enum.reject(&(&1 == "skills"))
    |> Enum.map(&String.replace(&1, "_", "-"))
    |> Enum.sort()

    pending = generated -- implemented
    extra = implemented -- generated

    IO.puts("=== Pending Migration ===")
    IO.puts("Generated: #{length(generated)}")
    IO.puts("Implemented: #{length(implemented)}")
    IO.puts("Pending: #{length(pending)}")
    IO.puts("Extra (impl only): #{length(extra)}")

    IO.puts("\n--- Pending Skills ---")
    Enum.each(pending, &IO.puts/1)

    if extra != [] do
      IO.puts("\n--- Extra (Impl Only) ---")
      Enum.each(extra, &IO.puts/1)
    end

    pending
  end

  def list_by_priority do
    # 按优先级分类：门派核心技能、常用技能、其他
    priority_skills = %{
      "core" => [
        "huashan-jian", "liuxin-jian", "taiji-jian", "taiji-quan",
        "dugu-jiujian", "wudang-jian", "emei-jian", "songshan-jian",
        "taiji-shengong", "hunyuan-yiqi", "xiaowuxiang", "zixia-shengong",
        "bibo-shengong", "bahuang-gong", "changsheng-jue", "xuanming-shengong"
      ],
      "common" => [
        "huoyan-dao", "chousui-zhang", "jingang-zhi", "jidian-jian",
        "jimie-zhua", "qiufeng-chenfa", "sanwu-shou", "suxin-jian",
        "songshan-jian", "dugu-jiujian", "taiji-jian"
      ]
    }

    pending = list_pending()

    Enum.each(priority_skills, fn {category, skills} ->
      category_pending = Enum.filter(skills, &(&1 in pending))
      if category_pending != [] do
        IO.puts("\n=== #{String.capitalize(category)} Priority ===")
        Enum.each(category_pending, &IO.puts/1)
      end
    end)

    other = pending -- List.flatten(Map.values(priority_skills))
    IO.puts("\n=== Other ===")
    IO.puts("Count: #{length(other)}")
  end

  def create_template(skill_id) do
    # 从生成的骨架创建迁移模板
    gen_file = Path.join(@generated_root, skill_dir(skill_id) <> ".ex")
    impl_file = Path.join(@impl_root, skill_dir(skill_id) <> ".ex")

    if !File.exists?(gen_file) do
      IO.puts("❌ Generated file not found: #{gen_file}")
    else
      if File.exists?(impl_file) do
        IO.puts("⚠️  Already exists: #{impl_file}")
      else
        gen = File.read!(gen_file)

        # 移除 Generated 模块名，替换为实际模块名
        template = gen
        |> String.replace("Kantele.Combat.Skills.Generated.", "Kantele.Combat.Skills.")
        |> String.replace("武学骨架", "武学实装")
        |> String.replace("TODO(migrate)（人工校对后补完，完成后删除本段注释）", "TODO(migrate): 人工迁移中...")

        # 创建目录
        File.mkdir_p!(Path.dirname(impl_file))
        File.write!(impl_file, template)

        IO.puts("✅ Created template: #{impl_file}")
      end
    end
  end

  def create_batch_template(category \\ "core") do
    priority_skills = %{
      "core" => [
        "huashan-jian", "liuxin-jian", "taiji-jian", "taiji-quan",
        "dugu-jiujian", "wudang-jian", "emei-jian", "songshan-jian",
        "taiji-shengong", "hunyuan-yiqi", "xiaowuxiang", "zixia-shengong",
        "bibo-shengong", "bahuang-gong", "changsheng-jue", "xuanming-shengong"
      ],
      "common" => [
        "huoyan-dao", "chousui-zhang", "jingang-zhi", "jidian-jian",
        "jimie-zhua", "qiufeng-chenfa", "sanwu-shou", "suxin-jian",
        "songshan-jian", "dugu-jiujian", "taiji-jian"
      ]
    }

    skills = Map.get(priority_skills, category, [])

    Enum.each(skills, fn skill ->
      if File.exists?(Path.join(@generated_root, skill_dir(skill) <> ".ex")) do
        create_template(skill)
      end
    end)
  end

  defp skill_dir(skill_id) do
    String.replace(skill_id, "-", "_")
  end
end

# 运行示例
# Migration.BatchMigrate.list_pending()
# Migration.BatchMigrate.list_by_priority()
# Migration.BatchMigrate.create_batch_template("core")
# Migration.BatchMigrate.create_template("huashan-jian")