defmodule Kantele.World.Trap.Bagua do
  @moduledoc """
  少林八卦阵（`d/shaolin/bagua.h` 的 `check_dirs/2`，被 bagua0~bagua7 的
  `valid_leave` 调用）

  ## LPC 原文的结构

      int check_dirs(object me, string dir)
      {
          if (member_array(dir, dirs) != -1)      // dirs = 乾坤离震巽坎艮兑
          {
              bc = query_temp("bagua/count");
              switch (dir) { ...每个方向允许不同的 bc，不符就 delete_temp("bagua/count")... }

              if (dir == "坤") delete_temp("bagua");            // 坤：整个 bagua 清空
              else {
                  count = query_temp("bagua/" + dir); count++;
                  set_temp("bagua/" + dir, count);
                  if (count > 13) { delete_temp("bagua"); move(jianyu); return 1; }
              }
          }
          return 0;
      }

  ## 两个必须注意的点

  **① 出口是拼音，temp 的键是汉字。** 转换器把出口恢复成了拼音
  （`qian/kun/zhen/xun/kan/li/gen/dui`），而 LPC 的 `switch(dir)` 和
  `"bagua/" + dir` 用的都是汉字。所以这里要先做拼音 -> 汉字的映射，
  temp 键仍然用汉字（`bagua/坎`），与 LPC 一致。

  **② 出口名用汉字，指令拼音也认。** 八个 `room_exits` 的方向名已改回汉字
  （LPC 原样，`look` 显示 `Exits: 乾 坤 震 巽 坎 离 艮 兑`），而指令层面
  `乾` 和 `qian` 都能走（见 `commands.ex` 的 `parse("乾", :qian, aliases: ["qian"])`），
  所以 `evaluate/2` 入口要把汉字归一成拼音再查表。

  **③ 汉字容易认错。** 下面表里的汉字都标了码点：艮是 U+826E、巽是 U+5DFD
  —— 两者曾被弄反过（控制台吞字），行为完全不同（艮扣 combat_exp、
  巽受 qi 伤），所以每条都写明码点。

  ## 语义

  `bagua/count` 是一个 0..17 的进度：走对一步 +1，走错一步直接清零。
  走错时按方向不同会受到惩罚：

  | 拼音 | 汉字 | 码点 | 允许的 count | 走错/走对的惩罚 |
  |---|---|---|---|---|
  | `kan` | 坎 | U+574E | 0, 13, 17 | `receive_damage("jing", 50)` |
  | `kun` | 坤 | U+5764 | —（总是清零） | 无惩罚，但清空整个 `bagua` |
  | `li` | 离 | U+79BB | 1, 12 | `add("neili", -50)` |
  | `qian` | 乾 | U+4E7E | 8 | `receive_damage("qi", 50)` |
  | `gen` | 艮 | U+826E | 3, 4, 15 | `add("combat_exp", -50)` |
  | `zhen` | 震 | U+9707 | 2, 7, 9 | `unconcious()`（昏厥） |
  | `xun` | 巽 | U+5DFD | 6, 11 | `receive_wound("qi", 50)` |
  | `dui` | 兑 | U+5151 | 5, 10, 14, 16 | `receive_wound("jing", 50)` |

  注意「惩罚」是**无论走对走错都会吃**的 —— LPC 里 `receive_damage` 等写在
  `if (bc 匹配)` 的 then 分支里，但那个分支同时做了 `count+1`，也就是说
  **只有走对这一步才扣血**；走错只清零、不受罚。这点很容易读反。

  脱困：同一个方向连走 14 次（`bagua/<汉字>` 计数 > 13）就会被丢进僧监
  （`shaolin:jianyu`），并清空所有 `bagua` 计数。
  """

  # 出口方向名改回汉字（LPC 原样）之后，同一个方向就可能以汉字进来；
  # 但拼音指令仍然保留（commands.ex 里 parse("乾", :qian, aliases: ["qian"])），
  # 所以这里两种写法都要认。
  @han_to_pinyin %{
    "乾" => "qian",
    "坤" => "kun",
    "坎" => "kan",
    "离" => "li",
    "艮" => "gen",
    "震" => "zhen",
    "巽" => "xun",
    "兑" => "dui"
  }

  # 拼音 -> {汉字, 码点, 允许的 count, 走对时的惩罚}
  @steps %{
    "kan" => {"坎", 0x574E, [0, 13, 17], {:damage, :jing, 50}},
    "kun" => {"坤", 0x5764, [], nil},
    "li" => {"离", 0x79BB, [1, 12], {:add, :neili, -50}},
    "qian" => {"乾", 0x4E7E, [8], {:damage, :qi, 50}},
    "gen" => {"艮", 0x826E, [3, 4, 15], {:add, :combat_exp, -50}},
    "zhen" => {"震", 0x9707, [2, 7, 9], {:faint}},
    "xun" => {"巽", 0x5DFD, [6, 11], {:wound, :qi, 50}},
    "dui" => {"兑", 0x5151, [5, 10, 14, 16], {:wound, :jing, 50}}
  }

  @escape_count 13
  @escape_msg "你踩动了机关，掉进僧监。"

  @doc "拼音或汉字 -> 汉字（LPC 的 temp 键用汉字）"
  def han(dir) do
    dir = normalize_dir(dir)
    elem(Map.get(@steps, dir, {nil}), 0)
  end

  @doc "汉字/拼音都归一到拼音（内部查表用）"
  def normalize_dir(dir), do: Map.get(@han_to_pinyin, dir, dir)

  @doc "该方向在给定 count 下走是否「踩对」（汉字与拼音都接受）"
  def correct?(dir, count) do
    case Map.get(@steps, normalize_dir(dir)) do
      # 坤（kun）永远清零，不存在「踩对」
      nil -> false
      {_han, _cp, allowed, _penalty} -> count in allowed
    end
  end

  @doc """
  `temp` + 方向 -> `{:allow, effects}` | `{:block, msg, effects}`

  方向不在八卦阵的八个方向里（`down` / `up`）时原样放行，
  对应 LPC 的 `member_array(dir, dirs) != -1`。
  """
  def evaluate(temp, dir) do
    # 出口名现在是汉字，但拼音写法（历史数据 / 测试 / 外部调用）也要认
    dir = normalize_dir(dir)

    case Map.get(@steps, dir) do
      nil ->
        {:allow, []}

      {han, _cp, allowed, penalty} ->
        count = temp_count(temp, "bagua/count")
        correct? = count in allowed

        effects =
          if correct? do
            # 走对：count + 1，并吃该方向的惩罚
            [{:set_temp, "bagua/count", count + 1}] ++ List.wrap(penalty)
          else
            # 走错（或坤）：只清零，不受罚
            [{:delete_temp, "bagua/count"}]
          end

        # ---- 坤：清空整个 bagua，不累加方向计数 ----
        if han == "坤" do
          {:allow, effects ++ [{:delete_prefix, "bagua/"}]}
        else
          # ---- 其余方向：累加该方向计数，可能脱困 ----
          dir_key = "bagua/#{han}"
          dir_count = temp_count(temp, dir_key) + 1

          effects = effects ++ [{:set_temp, dir_key, dir_count}]

          if dir_count > @escape_count do
            {:block, @escape_msg,
             effects ++
               [
                 {:delete_prefix, "bagua/"},
                 {:force_move, "shaolin:jianyu"}
               ]}
          else
            {:allow, effects}
          end
        end
    end
  end

  @doc "脱困提示语（UCL valid_leave 里配的原文）"
  def escape_message, do: @escape_msg

  # LPC query_temp 对缺失键返回 0
  defp temp_count(temp, key) do
    case Map.get(temp, key, 0) do
      n when is_integer(n) -> n
      _ -> 0
    end
  end
end