defmodule Kantele.Character.CommandVerbs do
  @moduledoc """
  全局命令动词表（编译期固化）。

  `Kantele.Character.Commands` 用 `Kalevala.Character.Command.Router` 的
  `parse/4` 宏注册命令；`RouterMacros.parse/4` 把主命令写进 `@parse_functions`
  （只有函数名 `parse_<verb>_<fun>`，无法可靠还原中文动词），把 `aliases:`
  选项写进 `@aliases`。因此运行时拿不到「全部已注册动词」的干净列表。

  本模块在**编译期**读 `commands.ex` 源文件，按行首 `parse("verb", ...)`
  抽取动词并固化成 `MapSet`，运行时只读内存：

  - `all/0` 供 `CommandsCommand` 列出全部命令；
  - `global?/1` 供交互提示判断某个对象动词是否会被全局命令表接住
    （例如 NPC `add_actions` 里的 `list` / `buy` 虽无专属 handler，
    但确实由全局命令执行，不能当成死动词过滤掉）。

  `@external_resource` 让 Mix 在 `commands.ex` 变动时重新编译本模块，
  避免增量编译下动词表变陈旧。
  """

  @commands_path Path.join(__DIR__, "commands.ex")
  @external_resource @commands_path

  @verbs (
    @commands_path
    |> File.read!()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      # 只认行首的 parse("...")，避免把注释/文档里的 parse( 文字当成命令
      case Regex.run(~r/^\s*parse\(\s*"([^"]+)"/, line) do
        [_, verb] -> [verb]
        _ -> []
      end
    end)
    |> MapSet.new()
  )

  @doc "全部已注册的全局命令动词（排序后的列表）"
  def all, do: @verbs |> MapSet.to_list() |> Enum.sort()

  @doc "该动词是否是全局命令表里的命令"
  def global?(verb) when is_binary(verb), do: MapSet.member?(@verbs, verb)
  def global?(_verb), do: false
end
