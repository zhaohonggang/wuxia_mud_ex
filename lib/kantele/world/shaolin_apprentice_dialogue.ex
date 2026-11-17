defmodule Kantele.World.ShaolinApprenticeDialogue do
  @moduledoc """
  少林各字辈 `attempt_apprentice` 的成功台词（Task #652）。

  LPC 源码里每条收徒路线都有自己的 `command("say ...")`，不是达摩式通用文案：
  - `qing.h`：generation==0 直收 / generation==师父+1 直收；
  - `dao.h` / `hui.h` / `cheng.h` / `xuan.h` / `du.h`：直收一句 + 越级拜师三句；
  - `da-mo.c`：`char 老衲又得一可塑之才...` + `say 从今以后你的法名叫做...`。

  ex 没有 NPC `char`/`say` 频道，统一由 `FamilyEvent` 以房间 vision 广播。本模块只负责
  按分支返回 `{channel, text}`，`channel` 为 `:char`（大笑道）或 `:say`（说道）。
  文案逐字照 LPC 保留，包括全角/半角叹号与「怎麽」字形。
  """

  @type channel :: :char | :say

  @doc """
  返回按 LPC 分支选中的台词列表。

  `student_generation` 是收徒前玩家 `meta.family.generation`；`new_name` 是改名后的法名。
  UCL 可用 `zero_generation_msg` / `direct_msg` / `promotion_msg_1..3` 覆写默认文案。
  """
  @spec lines(map(), String.t() | nil, String.t() | nil, String.t() | nil, integer() | nil) ::
          [{channel(), String.t()}]
  def lines(apprentice, master_name, _old_name, new_name, student_generation) do
    case branch(apprentice, student_generation) do
      {:damo, :promotion} ->
        [
          {:char, override(apprentice, :promotion_msg_1, "老衲又得一可塑之才，真是大畅老怀 !")},
          {:say, override(apprentice, :promotion_msg_2, "从今以后你的法名叫做%new_name%。")}
        ]

      {:qing, :zero} ->
        [
          {:say,
           override(apprentice, :zero_generation_msg, "阿弥陀佛！贫僧就收下你做我的弟子了。")}
        ]

      {:qing, :direct} ->
        [{:say, override(apprentice, :direct_msg, "%master%的徒弟怎麽跑到我这儿来了，哈哈哈！")}]

      {:dao, :direct} ->
        [{:say, override(apprentice, :direct_msg, "%master%的徒弟怎麽跑到我这儿来了，哈哈哈！")}]

      {:dao, :promotion} ->
        promotion_lines(apprentice, [
          "是%master%叫你来找我的吧，哈哈哈 !",
          "贫僧又得一可塑之才，真是可喜可贺 !",
          "从今以后你的法名叫做%new_name%，恭喜你荣升为少林派清字辈弟子 !"
        ])

      {:hui, :direct} ->
        [{:say, override(apprentice, :direct_msg, "%master%的徒弟怎麽跑到我这儿来了，哈哈哈！")}]

      {:hui, :promotion} ->
        promotion_lines(apprentice, [
          "是%master%叫你来找我的吧，哈哈哈 !",
          "贫僧又得一可塑之才，真是可喜可贺 !",
          "从今以后你的法名叫做%new_name%，恭喜你荣升为少林派道字辈弟子 !"
        ])

      {:cheng, :direct} ->
        [{:say, override(apprentice, :direct_msg, "%master%的徒弟怎麽跑到我这儿来了，哈哈哈 !")}]

      {:cheng, :promotion} ->
        promotion_lines(apprentice, [
          "是%master%叫你来找我的吧，哈哈哈 !",
          "贫僧又得一可塑之才，真是可喜可贺 !",
          "从今以后你的法名叫做%new_name%，恭喜你荣升为少林派慧字辈弟子 !"
        ])

      {:xuan, :direct} ->
        [{:say, override(apprentice, :direct_msg, "%master%的徒弟怎麽跑到我这儿来了，哈哈哈 !")}]

      {:xuan, :promotion} ->
        promotion_lines(apprentice, [
          "是%master%叫你来找我的吧，哈哈哈！",
          "贫僧又得一可塑之才，真是可喜可贺！",
          "从今以后你的法名叫做%new_name%，恭喜你荣升为少林派澄字辈弟子！"
        ])

      {:du, :direct} ->
        [{:say, override(apprentice, :direct_msg, "%master%的徒弟怎麽跑到我这儿来了，哈哈哈 !")}]

      {:du, :promotion} ->
        promotion_lines(apprentice, [
          "你能过金刚伏魔圈，哈哈哈！",
          "贫僧又得一可塑之才，可喜可贺！",
          "从今以后你的法名叫做%new_name%！"
        ])

      nil ->
        []
    end
    |> Enum.map(fn {channel, text} ->
      {channel,
       text
       |> String.replace("%master%", master_name || "")
       |> String.replace("%new_name%", new_name || "")}
    end)
  end

  defp promotion_lines(apprentice, defaults) do
    [:promotion_msg_1, :promotion_msg_2, :promotion_msg_3]
    |> Enum.zip(defaults)
    |> Enum.map(fn {key, default} -> {:say, override(apprentice, key, default)} end)
  end

  defp override(apprentice, key, default) do
    case Map.get(apprentice, key) do
      text when is_binary(text) and byte_size(text) > 0 -> text
      _ -> default
    end
  end

  defp branch(apprentice, student_generation) do
    prefix = string_value(Map.get(apprentice, :rename_prefix))
    master_generation = int_value(Map.get(apprentice, :master_generation))

    cond do
      # 达摩是 exact_generation=36 的独立路线，UCL 没有 master_generation。
      prefix == "渡" ->
        {:damo, :promotion}

      is_integer(student_generation) and student_generation == 0 and
          (Map.get(apprentice, :allow_zero_generation) == true or prefix == "清") ->
        # qing.h 与 dao.h 的 generation==0 文案相同。
        {:qing, :zero}

      is_integer(student_generation) and is_integer(master_generation) and
          student_generation == master_generation + 2 ->
        case prefix do
          "清" -> {:dao, :promotion}
          "道" -> {:hui, :promotion}
          "慧" -> {:cheng, :promotion}
          "澄" -> {:xuan, :promotion}
          "玄" -> {:du, :promotion}
          _ -> nil
        end

      is_integer(student_generation) and is_integer(master_generation) and
          student_generation == master_generation + 1 ->
        case master_generation do
          40 -> {:qing, :direct}
          39 -> {:dao, :direct}
          38 -> {:hui, :direct}
          37 -> {:cheng, :direct}
          36 -> {:xuan, :direct}
          35 -> {:du, :direct}
          _ -> nil
        end

      true ->
        nil
    end
  end

  defp string_value(value) when is_binary(value), do: value
  defp string_value(_), do: nil

  defp int_value(value) when is_integer(value), do: value
  defp int_value(value) when is_binary(value), do: String.to_integer(value)
  defp int_value(_), do: nil
end
