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

    case LPCConverter.convert_file(lpc_path, zone_id: zone_id) do
      {:ok, ucl} ->
        # Determine output filename
        base_name = Path.basename(lpc_path, ".c")
        zone_id = zone_id || infer_zone_id(lpc_path)
        output_file = Path.join(output_dir, "#{zone_id}.ucl")

        # Ensure directory exists
        File.mkdir_p!(output_dir)

        # Append or create
        if File.exists?(output_file) do
          existing = File.read!(output_file)
          # Check if already exists
          if String.contains?(existing, "rooms \"#{base_name}\"") or
             String.contains?(existing, "characters \"#{base_name}\"") or
             String.contains?(existing, "items \"#{base_name}\"") do
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

    Enum.each(files, fn file ->
      convert_file(file, zone_id, output_dir)
    end)

    Mix.shell().info("Done.")
  end

  defp infer_zone_id(lpc_path) do
    # Use parent directory name as zone_id
    lpc_path
    |> Path.dirname()
    |> Path.basename()
    |> String.replace("-", "_")
  end
end