defmodule Kantele.World.NpcActions.Gongxian do
  @moduledoc """
  长安群玉楼二楼「浮云」（门贡商人）的 `list` / `duihuan`
  （对照 `d/changan/npc/fuyun.c` 的 `do_list` / `do_duihuan`）。

  LPC 里 `init()` 把两个动词都挂在本 NPC 上：

      add_action("do_duihuan", "duihuan");
      add_action("do_list", "list");

  UCL 侧 `data/world/changan.ucl` 的 `characters "fuyun"` 已带
  `init.add_actions = ["duihuan", "list"]`，本模块补齐 handler 并注册到
  `changan:qunyulou2`（`NpcActionHandlers`），两个动词从此在该房间生效。

  ## 为什么这里要管乾坤石

  乾坤石（`/clone/fam/item/qiankun_stone`）在 LPC 里有三个来源：

  1. **本商人**：`duihuan 7 <数量>`，1500 门贡/块（`fuyun.c` L21）—— 唯一的
     可重复来源；
  2. 铁匠任务「打铁还需自身硬」10000 次（`adm/daemons/quest/_0_smith.c`
     L155，一次性）；
  3. 任务系统 1000 次里程碑奖励（`adm/daemons/questd.c` L237 的 `ob13_list`）。

  2、3 依赖本仓尚未移植的任务发放链（`mark/job_smith` 只有计数、没有交任务
  环节；`questd` 的里程碑表整块未移植），故先落 1 —— 让乾坤石真正能被玩家
  拿到，莫邪的「如意乾坤袋」分支才不是死路。

  ## 兑换表（`fuyun.c` L14-31 的 `convert_list`）

  LPC 每项是 `({物品路径, 门贡单价, 0})`，第三项恒为 0（预留字段，不参与
  结算）。表按编号 1..16 顺序排列，编号即玩家输入的第一个数字。

  单价原样照抄：1000 ×6、1500（乾坤石）、3000、5000、6666、8888 ×2、9999、
  99999 ×2、999999。

  ## 与 LPC 的差异（都是「照抄会出事」的地方，逐条说明）

  - **编号/数量越界**：LPC 只判 `n > sizeof(convert_list)`，`n <= 0` 会去
    `convert_list[0]`（= 0）再 `new(0)`，直接抛错；`count <= 0` 时 `gx <= 0`，
    `add("gongxian", -gx)` 反而**给**玩家加贡献（负数量刷贡献的漏洞）。本模块
    统一把 `n ∉ 1..16` 或 `count < 1` 归到「看清编号再来吧」，不复现这两个
    缺陷。
  - **物品定义缺失**：LPC `new(path)` 时文件一定存在；本仓世界数据只收了
    `qiankun_stone` / `tiancs` / `tianjing` 三种，其余 13 种
    （`clone/fam/gift/*`、`clone/fam/max/*`、`clone/fam/item/yanluo|lihuo|
    bless_water`、`d/death/obj/qise`）转换时没有落库。`new()` 失败在 LPC 里
    是崩溃，本模块改为「没货」提示且**不扣门贡**（与
    `NpcActions.Exchange` 处理缺失定义的做法一致），世界数据补齐后自动可用。
  - **文案颜色**：LPC 的 `HIY`/`CYN` 等 ANSI 宏已剥离，只留文字。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Stats
  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers

  @room_id "changan:qunyulou2"
  @npc_name "浮云"

  # `fuyun.c` L14-31 convert_list：{物品 id, 显示名, 门贡单价}
  #
  # 显示名取 LPC 各物品 `set_name()` 的中文部分（去色）：LPC `do_list` 打印的是
  # `ob->name()`，而本仓多数物品定义缺失，只能把名字钉在这张表里。
  @convert_list [
    {"clone_lib:str3", "蚩尤诛元仙丹", 1000},
    {"clone_lib:int3", "神恩通慧仙丹", 1000},
    {"clone_lib:con3", "洗髓再造仙丹", 1000},
    {"clone_lib:dex3", "破阳无极仙丹", 1000},
    {"clone_lib:yanluo", "阎罗绸", 1000},
    {"clone_lib:lihuo", "离火玄冰玉", 1000},
    {"signature:qiankun_stone", "乾坤石", 1500},
    {"clone_lib:tianshu2", "「无字天书」", 3000},
    {"clone_lib:tianshu1", "「忘情天书」", 5000},
    {"clone_lib:guo", "许愿无花果", 6666},
    {"clone_lib:longjia", "子午龙甲丹", 8888},
    {"clone_lib:xuanhuang", "玄黄紫箐丹", 8888},
    {"clone_lib:bless_water", "乾坤圣水", 9999},
    {"item:tiancs", "冰蚕丝", 99_999},
    {"death:qise", "七色璎珞", 99_999},
    {"death:tianjing", "寰宇天晶", 999_999}
  ]

  @impl true
  def run(conn, %{verb: verb, trailing: trailing, room_id: room_id}) do
    if room_id == @room_id do
      handle(verb, conn, to_string(trailing) |> String.trim())
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp handle("list", conn, _arg), do: do_list(conn)
  defp handle("duihuan", conn, arg), do: do_duihuan(conn, arg)
  defp handle(_verb, _conn, _arg), do: :not_handled

  # ---- do_list：LPC 逐字符对齐的列宽补白 ----
  #
  # 原式（fuyun.c L72-101）：
  #   write(i + "  ");  if (i < 1000) write(" "); ...   // 编号列补到 5 字符
  #   write(gx + "  "); if (gx < 100000) write(" "); ... // 门贡列补到 7 字符
  defp do_list(conn) do
    rows =
      @convert_list
      |> Enum.with_index(1)
      |> Enum.map(fn {{_id, name, cost}, index} ->
        pad_number(index) <> pad_cost(cost) <> name <> "\n"
      end)

    Helpers.render(
      conn,
      "浮云目前可以兑换（duihuan）以下物品：\n" <>
        "==========================================\n" <>
        "编号  门贡      物品\n" <>
        "------------------------------------------\n" <>
        Enum.join(rows) <>
        "==========================================\n"
    )
  end

  defp pad_number(n) do
    pad = Enum.count([1000, 100, 10], fn threshold -> n < threshold end)
    "#{n}  " <> String.duplicate(" ", pad)
  end

  defp pad_cost(cost) do
    pad = Enum.count([100_000, 10_000, 1000, 100], fn threshold -> cost < threshold end)
    "#{cost}  " <> String.duplicate(" ", pad)
  end

  # ---- do_duihuan <编号> <数量> ----
  defp do_duihuan(conn, arg) do
    case parse(arg) do
      {:ok, index, count} -> exchange(conn, index, count)
      :error -> Helpers.render(conn, "浮云微笑道：你要兑换什么东西？指令：duihuan <编号> <数量>\n")
    end
  end

  # LPC `sscanf(arg, "%d %d", n, count) != 2` → 提示格式
  defp parse(arg) do
    case Regex.run(~r/^\s*(-?\d+)\s+(-?\d+)\s*$/, arg) do
      [_, index, count] -> {:ok, String.to_integer(index), String.to_integer(count)}
      _ -> :error
    end
  end

  defp exchange(conn, index, count) do
    cond do
      # LPC 只有 `n > sizeof(convert_list)`；n <= 0 与 count <= 0 的越界/负数
      # 漏洞见 moduledoc「与 LPC 的差异」
      index < 1 or index > length(@convert_list) or count < 1 ->
        Helpers.render(conn, "浮云微笑道：输入（list）看清编号再来吧。\n")

      true ->
        {item_id, name, unit_cost} = Enum.at(@convert_list, index - 1)
        do_exchange(conn, item_id, name, unit_cost, count)
    end
  end

  defp do_exchange(conn, item_id, name, unit_cost, count) do
    gongxian = gongxian_of(conn)
    cost = unit_cost * count

    cond do
      # LPC: if (me->query("gongxian") < gx)
      gongxian < cost ->
        Helpers.render(conn, "浮云对你冷笑一声，没理你。\n")

      # 本仓世界数据缺该物品定义（LPC 侧 new() 必定成功，见 moduledoc）
      Items.get(item_id) == {:error, :not_found} ->
        Helpers.render(conn, "浮云翻了翻箱笼，摇头道：这东西一时没货，改日再来吧。\n")

      true ->
        conn
        |> deduct_gongxian(cost)
        |> Helpers.give_items(item_id, count)
        |> then(&Helpers.render(&1, "浮云拿出一些#{name}，笑眯眯的说：欢迎下次光临。\n"))
    end
  end

  defp gongxian_of(conn) do
    case current(conn).meta do
      %{stats: %Stats{gongxian: value}} -> value || 0
      _ -> 0
    end
  end

  # LPC `me->add("gongxian", -gx)`
  defp deduct_gongxian(conn, cost) do
    character = current(conn)
    stats = character.meta.stats || %Stats{}
    stats = %{stats | gongxian: (stats.gongxian || 0) - cost}
    put_character(conn, %{character | meta: %{character.meta | stats: stats}})
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
