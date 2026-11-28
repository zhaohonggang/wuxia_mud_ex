defmodule Kantele.World.BitmapFont do
  @moduledoc """
  点阵字库原语（A-5-c C3），镜像 LPC `bitmap_font(str, 16)`。

  对应 LPC `mudcore/system/kernel/simul_efun/bitmap_font.c:26-102`
  （康熙殿试 `write(bitmap_font(word, 16) + "\\n")` 的谜面渲染）。

  ## UTF-8 索引（用户 2026-11-28 指定）

  ex 侧字符串全程 UTF-8，**运行时不做任何 GBK 偏移换算**。构建期由
  `scripts/build_hzk16_utf8_pack.py`（一次性，有权威 `gbk` codec）把 GBK
  排布的 HZK16×9 字库转成按 Unicode 码点索引的 pack：
  `priv/fonts/hzk16.pack` = `码点 → 32 字节点阵`。点阵字节与 LPC
  `read_buffer(HZK16?, offset, 32)` 读到的完全同源——只是把「GBK 码 →
  偏移」的运行时算术换成构建期直查表。

  ASC16（ASCII 16 点阵）为字节索引，ASCII 在 UTF-8 中同值，原样拷贝到
  `priv/fonts/asc16`。

  ## 渲染语义（与 LPC 逐条对齐）

  - 16 号：汉字 32 字节、`scale = 32/16 = 2`（两字节一行，共 16 行 16 列）；
    ASCII 16 字节 `scale = 1`（16 行 8 列）；
  - 前景 `fill = "8"`、背景 `bg = "-"`（LPC 默认值）；
  - 位掩码 `0x80..0x01` 逐位展开；
  - 16 号字体随机变体 `HZK16{C,F,H,K,L,S,V,X,Y}`（LPC `element_of`）；
    ex 侧等价随机选变体，可用 `font:` 选项固定（测试用）；
  - 字库读不到对应字形时返回 LPC 同款错误串
    `"Can't read bytes from character lib.\\n"`。
  """

  @font_variants ["C", "F", "H", "K", "L", "S", "V", "X", "Y"]
  @fill "8"
  @bg "-"
  @masks [0x80, 0x40, 0x20, 0x10, 0x8, 0x4, 0x2, 0x1]
  @size 16
  @fontsize 32
  @read_error "Can't read bytes from character lib.\n"

  @doc """
  渲染 `word` 为 `size` 行点阵文本（不带尾换行；LPC 侧由调用方补 `+ "\\n"`）。

  选项：
  - `font:` 固定字体变体 `"C".."Y"`（缺省随机，对齐 LPC `element_of`）。
  """
  def render(word, size \\ @size, opts \\ []) when is_binary(word) do
    size = normalize_size(size)

    case load_pack() do
      {font_maps, asc} ->
        font = case Keyword.get(opts, :font) do
          nil -> Enum.random(@font_variants)
          f -> f
        end
        font_map = Map.get(font_maps, font) || Map.get(font_maps, "C")
        do_render(word, size, font_map, asc)

      :error ->
        @read_error
    end
  end

  @doc "可用字体变体（16 号随机池，对齐 LPC）。"
  def font_variants, do: @font_variants

  # ---- 渲染 ----

  defp do_render(word, size, font_map, asc) do
    rows = List.duplicate("", size)

    word
    |> String.graphemes()
    |> Enum.reduce_while(rows, fn ch, out ->
      case glyph_rows(ch, size, font_map, asc, out) do
        {:ok, out} -> {:cont, out}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      :error -> @read_error
      rows -> Enum.join(rows, "\n")
    end
  end

  defp glyph_rows(ch, size, font_map, asc, out) do
    cp = String.to_charlist(ch) |> hd()

    {bmp, scale} =
      if cp < 128 do
        start = cp * size

        if start + size <= byte_size(asc) do
          {binary_part(asc, start, size), 1}
        else
          {nil, 1}
        end
      else
        case Map.get(font_map, cp) do
          bmp when is_binary(bmp) and byte_size(bmp) == @fontsize ->
            {bmp, div(@fontsize, size)}

          _ ->
            {nil, div(@fontsize, size)}
        end
      end

    case bmp do
      # LPC：读不到字形 → 整体返回错误串（kangxi 词池字符均在库内，
      # 实际不可达，仅保持同语义）。
      nil ->
        :error

      bmp ->
        rows =
          bmp
          |> :binary.bin_to_list()
          |> Enum.with_index()
          |> Enum.reduce(out, fn {byte, i}, acc ->
            row_i = div(i, scale)
            cells = expand_bits(byte)
            List.update_at(acc, row_i, &(&1 <> cells))
          end)

        {:ok, rows}
    end
  end

  defp expand_bits(byte) do
    @masks
    |> Enum.map(fn mask -> if Bitwise.band(mask, byte) != 0, do: @fill, else: @bg end)
    |> Enum.join()
  end

  # ---- pack 加载 ----

  defp normalize_size(s) when s in [12, 14, 16], do: s
  defp normalize_size(_), do: @size

  defp load_pack do
    case :persistent_term.get({__MODULE__, :pack}, :missing) do
      :missing ->
        case read_pack() do
          {:ok, pack} ->
            :persistent_term.put({__MODULE__, :pack}, pack)
            pack

          :error ->
            :error
        end

      pack ->
        pack
    end
  end

  defp read_pack do
    path = Application.app_dir(:ex_venture, "priv/fonts/hzk16.pack")

    with {:ok, bin} <- File.read(path),
         {font_maps, asc} <- parse_pack(bin) do
      {:ok, {font_maps, asc}}
    else
      _ -> :error
    end
  rescue
    _ -> :error
  end

  # pack: "HZK16PACK" + version u8 + font_count u8
  #   每 font: tag 1B + count u16le + count × { codepoint u32le + bitmap 32B }
  defp parse_pack(
         <<"HZK16PACK", 1, font_count, rest::binary>> = bin
       ) do
    # asc16 与 pack 同目录
    asc_path = Application.app_dir(:ex_venture, "priv/fonts/asc16")

    with {:ok, asc} <- File.read(asc_path) do
      parse_fonts(rest, font_count, %{}, bin)
      |> case do
        {maps, ""} -> {maps, asc}
        _ -> :error
      end
    end
  end

  defp parse_pack(_), do: :error

  defp parse_fonts(rest, 0, acc, _bin), do: {acc, rest}

  defp parse_fonts(<<tag::8, count::16-little, entries::binary>>, n, acc, bin)
       when n > 0 do
    entry_size = count * 36

    case entries do
      <<entries_bin::binary-size(entry_size), rest::binary>> ->
        map = parse_entries(entries_bin, %{})
        tag = <<tag::8>>
        parse_fonts(rest, n - 1, Map.put(acc, tag, map), bin)

      _ ->
        :error
    end
  end

  defp parse_fonts(_, _, _, _), do: :error

  defp parse_entries(<<>>, acc), do: acc

  defp parse_entries(<<cp::32-little, bmp::32-bytes, rest::binary>>, acc) do
    parse_entries(rest, Map.put(acc, cp, bmp))
  end

  defp parse_entries(_, _), do: :error
end
