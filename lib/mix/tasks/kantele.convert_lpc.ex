defmodule Mix.Tasks.Kantele.ConvertLpc do
  @moduledoc """
  Mix task to convert LPC files to UCL format.

  ## Usage

      mix kantele.convert_lpc PATH [--zone ZONE_ID] [--output DIR]

  ## Options

    - `--zone` - Zone ID for output (default: inferred from path)
    - `--output` - Output directory (default: data/world)
    - `--single` - Convert single file (default: true)
    - `--recursive` - Convert all .c files in directory recursively

  ## Examples

      # Convert single file
      mix kantele.convert_lpc lpc_example/room/room_qiyuan2.c --zone liuxi

      # Convert directory recursively
      mix kantele.convert_lpc lpc_example/room --recursive --zone liuxi
  """

  use Mix.Task

  @shortdoc "Convert LPC files to UCL format"

  alias Kantele.World.LPCConverter

  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, switches: zone_switches())

    case positional do
      [] ->
        Mix.shell().error("Usage: mix kantele.convert_lpc PATH [options]")
        Mix.shell().error("Run 'mix help kantele.convert_lpc' for more info")
        {:error, :invalid_args}

      [path | _] ->
        zone_id = Keyword.get(opts, :zone, nil)
        output_dir = Keyword.get(opts, :output, "data/world")
        recursive = Keyword.get(opts, :recursive, false)

        convert_path(path, zone_id, output_dir, recursive)
    end
  end

  defp zone_switches do
    [
      zone: :string,
      output: :string,
      recursive: :boolean,
      single: :boolean,
      help: :boolean
    ]
  end

  defp convert_path(path, zone_id, output_dir, recursive) do
    if File.dir?(path) do
      if recursive do
        convert_directory(path, zone_id, output_dir)
      else
        Mix.shell().error("Path is a directory. Use --recursive to convert all .c files.")
        {:error, :is_directory}
      end
    else
      convert_file(path, zone_id, output_dir)
    end
  end

  defp convert_file(lpc_path, zone_id, output_dir) do
    Mix.shell().info("Converting #{lpc_path}...")

    case LPCConverter.convert_file(lpc_path, zone_id: zone_id, include_comments: true) do
      {:ok, {ucl, comments}} ->
        # Determine output filename
        base_name = Path.basename(lpc_path, ".c")
        # 输出侧 ID 统一做 "-" → "_" 规范化（见 lpc_converter.ex 的 npc_id/room_id/item_id），
        # 去重检查必须用规范化名，否则连字符文件名（如 worker-liu.c）每次运行都会重复追加
        ucl_name = String.replace(base_name, "-", "_")
        zone_id = zone_id || infer_zone_id(lpc_path)
        output_file = Path.join(output_dir, "#{zone_id}.ucl")
        comments_file = Path.join(output_dir, "#{zone_id}.comments.txt")

        # Ensure directory exists
        File.mkdir_p!(output_file |> Path.dirname())

        # Append or create UCL file
        if File.exists?(output_file) do
          existing = File.read!(output_file)
          # Check if already exists
          if String.contains?(existing, "# Generated from #{lpc_path} by LPCConverter") or
             String.contains?(existing, "rooms \"#{ucl_name}\"") or
             String.contains?(existing, "characters \"#{ucl_name}\"") or
             String.contains?(existing, "items \"#{ucl_name}\"") do
            Mix.shell().info("#{base_name} already exists in #{output_file}, skipping append")
          else
            File.write!(output_file, String.trim_trailing(existing) <> "\n\n" <> String.trim_trailing(ucl) <> "\n")
            Mix.shell().info("Appended to #{output_file}")
          end
        else
          zone_header = """
          zones "#{zone_id}" {
            name = "#{zone_id}"
          }

          """
          File.write!(output_file, zone_header <> String.trim_trailing(ucl) <> "\n")
          Mix.shell().info("Created #{output_file}")
        end

        # Write comments to separate .txt file
        comments_file = Path.join(output_dir, "#{zone_id}.comments.txt")
        File.write!(comments_file, comments <> "\n")
        Mix.shell().info("Wrote comments to #{comments_file}")

        {:ok, output_file}

      {:error, reason} ->
        Mix.shell().error("Conversion failed: #{reason}")
        {:error, reason}
    end
  end

  defp convert_directory(dir, zone_id, output_dir) do
    files =
      Path.wildcard(Path.join(dir, "**/*.c"))
      |> Enum.filter(&String.ends_with?(&1, ".c"))

    Mix.shell().info("Found #{length(files)} LPC files in #{dir}")

    zone_id = zone_id || infer_zone_id(dir)

    {entries, failures} =
      Enum.reduce(files, {[], []}, fn file, {entries, failures} ->
        Mix.shell().info("Converting #{file}...")

        case LPCConverter.convert_file(file, zone_id: zone_id, include_comments: true) do
          {:ok, {ucl, comments}} ->
            ucl_name = file |> Path.basename(".c") |> String.replace("-", "_")
            {[{ucl_name, ucl, comments} | entries], failures}

          {:error, reason} ->
            Mix.shell().error("Conversion failed: #{reason}")
            {entries, [{file, reason} | failures]}
        end
      end)

    # 内存累积后一次性整体写出，避免逐文件反复读写同一大文件时被宿主文件
    # 系统 / 杀毒扫描触发 EINVAL；整体覆盖也天然消除跨运行重复追加
    # entries 已是逆序，先 reverse 恢复 wildcard 顺序，再去重保留首次出现
    entries_in_order = Enum.reverse(entries)
    deduped =
      entries_in_order
      |> Enum.reduce({[], MapSet.new()}, fn {ucl_name, ucl, comments}, {acc, seen} ->
        if MapSet.member?(seen, ucl_name) do
          Mix.shell().info("#{ucl_name} already converted, skipping duplicate")
          {acc, seen}
        else
          Mix.shell().info("Appended #{ucl_name}")
          {[{ucl_name, ucl, comments} | acc], MapSet.put(seen, ucl_name)}
        end
      end)
      |> elem(0)
      |> Enum.reverse()

    output_file = Path.join(output_dir, "#{zone_id}.ucl")
    comments_file = Path.join(output_dir, "#{zone_id}.comments.txt")
    File.mkdir_p!(Path.dirname(output_file))

    zone_header = ~s(zones "#{zone_id}" {\n  name = "#{zone_id}"\n}\n\n)
    # generic 文件不产生 UCL 段，其整块注释只进 comments.txt
    body =
      deduped
      |> Enum.filter(fn {_ucl_name, ucl, _comments} -> String.trim(ucl) != "" end)
      |> Enum.map_join("\n\n", fn {_ucl_name, ucl, _comments} -> String.trim_trailing(ucl) end)
    body = sanitize_ucl_body(body)
    if body == "" do
      File.write!(output_file, zone_header)
    else
      File.write!(output_file, zone_header <> body <> "\n")
    end

    # Fix UCL file to avoid elias parser issues
    fix_ucl_file(output_file)

    # Write comments to separate .txt file
    comments_body = Enum.map_join(deduped, "\n\n", fn {_ucl_name, _ucl, comments} -> String.trim_trailing(comments) end)
    File.write!(comments_file, comments_body <> "\n")

    Mix.shell().info("Wrote #{length(deduped)} objects to #{output_file}")
    Mix.shell().info("Wrote comments to #{comments_file}")
    if failures != [], do: Mix.shell().error("Failed on #{length(failures)} files: #{inspect(failures)}")
    Mix.shell().info("Done.")

    # Post-process the generated UCL file to fix elias parser issues
    fix_ucl_file(output_file)
  end

  defp sanitize_ucl_body(body) do
    body
    |> String.replace("\\\"", "'")
    |> String.replace("\\\\\"", "'")
    |> String.replace("\\n\"", " ")
    |> String.replace("\\t\"", " ")
    |> String.replace("\\r\"", " ")
  end

  defp fix_ucl_file(path) do
    content = File.read!(path)
    # Fix problematic escape sequences that confuse elias parser
    fixed =
      content
      |> String.replace("\\n\"", "\\n'")
      |> String.replace("\\\"", "'")
      |> String.replace("\\\\\"", "'")
      # Fix trailing backslash-space at end of lines
      |> String.replace("\\\\ \n", "\n")
      |> String.replace("\\ \n", "\n")
      # Fix multiline string values that break UCL parsing
      |> String.replace("\\\\\n", "\\n")
      |> String.replace("\\\n", "\\n")
    File.write!(path, fixed)
  end

  defp infer_zone_id(lpc_path) do
    # Use parent directory name as zone_id
    lpc_path
    |> Path.dirname()
    |> Path.basename()
    |> String.replace("-", "_")
  end
end