defmodule Kantele.World.NpcActions.Yao do
  @moduledoc """
  P5-1c NPC 私有动作：`yao`（向 NPC「要」东西）。

  三处 `do_yao` 语义各异，按 `room_id` 分派（registry 三个房间都指向本模块
  `:run`）：

  - `xiangyang:qianzhuang` —— 黄真发「商令」（`d/xiangyang/npc/huangzhen.c`
    `do_yao()`）：需是商会成员（`is_vendor`）、非失信（`bad_vendor`）、
    未持有商令、未刚领过（`temp shang-ling`）、非已有店铺主（`SHOP_D->is_owner`）。
  - `wudu:chufang` —— 田嫂发两个蛇肉包子（`d/wudu/npc/tian.c` `do_yao(arg)`）：
    吃饱（`food >= max*90/100`）或手里/地上已有包子则拒绝。
  - `beijing:bingqi` —— 钱正伦发兵器/护甲（`d/beijing/npc/qianzhenglun.c`
    `do_yao(arg)`）：限八卦门、arg 限 11 种、受 NPC 共享发放上限 `total` 限制、
    同玩家兵器/护甲各限领 3 件（`mark/zhenyuan_*`）。

  ## 与 LPC 的返回语义

  LPC 里 `return notify_fail(msg)` 返回 0（命令未处理），但可见效果是**只显示该
  提示**（无同名二次命令 → 不会再落到默认「什么？」）。本模块对「拒绝」一律
  **渲染提示并返回 `conn`（消费本次输入）**，与玩家可见行为一致；仅当房间未注册
  时返回 `:not_handled` 放行全局命令。

  ## 未建模依赖（@todo）

  - 商会系统（`is_vendor` / `bad_vendor` / `SHOP_D->is_owner`）尚未建模：
    `flag?/2` 读 `attributes` / `meta.env`，系统未开时恒 false → 黄真恒走
    「没理你」分支（与「非商会成员」的 LPC 行为一致）。存档端接入后即生效。
  - 食物当前值未建模（O4）：`food_full?/1` 按 0 计 → 田嫂饱食守卫实际不触发。
  - `RANK_D->query_respect` 尊称未建模：钱正伦 say 文案固定用「大侠」。
  """
  use Kantele.World.NpcAction

  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Counters
  alias Kantele.World.NpcActions.Helpers

  # 钱正伦可发放的对象（`do_yao` arg 域）。
  @qianzhenglun_args ~w(blade sword dagger hammer staff throwing whip body helmet feet waist)
  # 护甲类（其余按兵器计 mark）。
  @qianzhenglun_armor ~w(body helmet feet waist)
  # 每类（护甲/兵器）每人限领 3 件。
  @qianzhenglun_mark_limit 3
  @shang_ling "clone_lib:shang_ling"
  @baozi "wudu:baozi2"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id, npc: npc}) do
    case room_id do
      "xiangyang:qianzhuang" -> huangzhen(conn, room_id, npc)
      "wudu:chufang" -> tian(conn, room_id, npc)
      "beijing:bingqi" -> qianzhenglun(conn, room_id, arg, npc)
      _ -> :not_handled
    end
  end

  # ---- 黄真：发商令 ----

  defp huangzhen(conn, room_id, npc) do
    character = conn.character

    cond do
      Helpers.flag?(character, "bad_vendor") ->
        Helpers.render(conn, "黄真不耐烦道：走开，走开。你又回来作甚？\n")

      not Helpers.flag?(character, "is_vendor") ->
        Helpers.render(conn, "黄真瞄了你一眼，没理你。\n")

      Helpers.carries?(character, "shang ling") ->
        Helpers.render(conn, "黄真皱了皱眉道：我的天，你连这都要骗？果然是奸商的料。\n")

      Helpers.temp(conn, "shang-ling") ->
        Helpers.render(conn, "黄真皱眉道：刚才我不是才给了你一张么？那么快就弄丢了？\n")

      shop_owner?(character) ->
        Helpers.render(conn, "黄真微笑道：你现在不是已经开店了么？还要这个干嘛。\n")

      true ->
        conn
        |> Helpers.give_item(@shang_ling)
        |> Helpers.put_temp("shang-ling", 1)
        |> Helpers.say(room_id, npc.name, "吃饭的家伙自己保管好，别老是来烦我。")
    end
  end

  defp shop_owner?(%{meta: meta}),
    do: is_map(meta) and is_map_key(meta, :stall) and truthy_stall?(meta.stall)

  defp shop_owner?(_), do: false

  defp truthy_stall?(nil), do: false
  defp truthy_stall?(%{} = m), do: map_size(m) > 0
  defp truthy_stall?(_), do: true

  # ---- 田嫂：发两个蛇肉包子 ----

  defp tian(conn, room_id, npc) do
    conn =
      Helpers.broadcast(conn, room_id, "$N向田嫂问道：大嫂，开饭了吗？\n")

    character = conn.character

    cond do
      Helpers.food_full?(conn) ->
        Helpers.render(conn, "田嫂笑道：没那，等开饭时再来吧！\n")

      Helpers.carries?(character, "baozi") ->
        Helpers.render(conn, "田嫂笑道：不要拿着手里的，还看着锅里的！\n")

      Helpers.room_has_item?(room_id, "baozi") ->
        Helpers.render(conn, "田嫂笑道：那不是有一块呢嘛，吃完再说！\n")

      true ->
        conn
        |> Helpers.give_items(@baozi, 2)
        |> Helpers.broadcast(room_id, "田嫂对$N笑道：饿了吧，慢点吃。\n")
    end
  end

  # ---- 钱正伦：发兵器 / 护甲 ----

  defp qianzhenglun(conn, room_id, arg, npc) do
    character = conn.character
    arg = arg |> to_string() |> String.trim()

    cond do
      arg == "" ->
        Helpers.render(conn, "钱正伦道：你要什么东西？\n")

      Helpers.family_name(character) != "八卦门" ->
        Helpers.render(conn, "钱正伦道：对不起，只有镖局里的人才能领取兵器。\n")

      arg not in @qianzhenglun_args ->
        Helpers.render(conn, "钱正伦对你摇头道：对不起，你要的东西我这里没有。\n")

      counter_exhausted?(room_id, arg) ->
        Helpers.render(conn, "钱正伦道：对不起，你要的东西我都已经发完了。\n")

      true ->
        case consume_mark(conn, arg) do
          {:limit, conn} ->
            armor_mark_reason(arg) |> then(&Helpers.render(conn, &1))

          {:ok, conn} ->
            do_grants(conn, room_id, arg, npc)
        end
    end
  end

  defp counter_exhausted?(room_id, arg) do
    case Counters.limit(room_id) do
      :none -> false
      total -> Counters.count(room_id, arg) >= total
    end
  end

  # 领用前检查并按类累计 mark（护甲 `zhenyuan_armor` / 兵器 `zhenyuan_weapon`）。
  defp consume_mark(conn, arg) do
    key = if arg in @qianzhenglun_armor, do: "mark/zhenyuan_armor", else: "mark/zhenyuan_weapon"

    if (Helpers.temp(conn, key) || 0) >= @qianzhenglun_mark_limit do
      {:limit, conn}
    else
      {:ok, Helpers.add_mark(conn, key, 1)}
    end
  end

  defp armor_mark_reason(arg) when arg in @qianzhenglun_armor,
    do: "钱正伦怒骂道：你要了这么多件护甲，还不够？\n"

  defp armor_mark_reason(_arg),
    do: "钱正伦怒骂道：你要了这么多件兵器，还不够？\n"

  defp do_grants(conn, room_id, arg, npc) do
    item_id = "beijing:#{arg}"

    case Items.get(item_id) do
      {:ok, item} ->
        Counters.record(room_id, arg)

        conn
        |> Helpers.give_item(item_id, meta: %{no_sell: "这不是镇远镖局里的东西么？我可不敢收购。", value: 50})
        |> Helpers.say(room_id, npc.name, "这位大侠，#{item.name}为数不多，千万别随便扔。")
        |> Helpers.broadcast(room_id, "钱正伦给了$N一#{unit_of(item)}#{item.name}。\n")

      _ ->
        Helpers.render(conn, "钱正伦对你摇头道：对不起，你要的东西我这里没有。\n")
    end
  end

  defp unit_of(item) do
    case Kalevala.Meta.get(item.meta, :unit) do
      unit when is_binary(unit) -> unit
      _ -> "件"
    end
  end
end
