defmodule Kantele.World.NpcActions.Exchange do
  @moduledoc """
  P5-1e NPC 私有动作：`exchange` / `duihuan`（积分兑换，`d/city/npc/xiaoer.c`
  `do_exchange(arg)`）。

  仅注册于 `city:kedian`（扬州客店，UCL `characters.xiaoer` 经
  `room_characters "kedian"` 挂入）。LPC 用 `do_exchange` 同时注册
  `exchange` 与 `duihuan` 两个动词，本模块同样覆盖两者。

  ## 移植范围（整链）

  LPC `do_exchange` 的判定链（全部 `write` + `return 1`，命令恒消费）：

  1. `state/jifen` 为 0/空 → 「客官，您暂时没有积分呢，可以通过报告BUG或在
     扬州武庙祈祷获得积分。」
  2. 无 arg → 「你要兑换什么东西？(help jifen)」
  3. arg 不在 32 种兑换表 → 「你只能兑换规定范围内的物品。」
  4. `jifen < cost` → 「您当前积分只有 X 点，兑换此物品需要 Y 点积分。」
  5. 物品对象缺失（`!ob`）→ 「咦？我的东西…我的东西呢?！」
  6. 成功：扣积分 + `give` 物品 + say「兑换完成，欢迎再次光临！」

  本模块落地 1-6 全部（含 32 种兑换表）。积分走
  `Kantele.Character.PlayerMeta` 的 `jifen`/`put_jifen`（与 S4 jifen.c 同源，
  落盘 metadata.jifen）；发物走 `Helpers.give_item/2`。

  ## 与世界数据的差异（第 5 分支的真实用途）

  32 种兑换物里 18 种在 `clone_lib.ucl` 有定义（puti/sheli/linghui/renshen/
  lingzhi/xuelian 各编号），另 14 种（`clone/fam/gift/*` 的 con/dex/int/str
  1-3 与 `clone/fam/max/*` 的 longjia/xuanhuang/zhenyu）**世界数据里不存在**。
  LPC 的 `if (!ob)` 分支（「我的东西呢?！」）在本世界恰好承接这批物品：
  走查表命中但 `Items.get` 查不到定义时渲染该文案，**不扣积分**。世界数据
  补齐后这 14 条自动转为可兑换。

  ## 已建模依赖

  - `CHANNEL_D->do_channel(..., "rumor", ...)` 江湖传闻广播：Kantele 的
    `communication.ex` 已在 `initial_channels()` 注册 `rumor` 频道，兑换成功分支
    经 `Communication.announce("rumor", ...)` 播「听说<玩家>在店小二处兑换了一<
    unit><物品>。」；`announce/2` 内部 try/rescue/catch，无频道/进程时不崩（仅少一条
    传闻）。文案构造见 `rumor_text/3`，量词取物品 `unit`，缺失回落「个」。
  - `RANK_D->query_respect` 尊称未在其他分支用到（本 handler 无），无需处理。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.PlayerMeta
  alias Kantele.Communication
  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers

  @room_id "city:kedian"
  @npc_name "店小二"

  # LPC do_exchange 内联 switch 表：中文名 => {clone_lib 物品键, 积分 cost}。
  # 键为 `clone_lib.ucl` 的 items 键（Kantele item id = "clone_lib:<键>"）。
  @exchange_table %{
    "血菩提" => {"puti1", 5},
    "舍利子" => {"sheli1", 5},
    "昊天果" => {"linghui1", 5},
    "壮骨粉" => {"con1", 5},
    "福寿膏" => {"dex1", 5},
    "增慧丹" => {"int1", 5},
    "神力丸" => {"str1", 5},
    "冰菩提" => {"puti3", 10},
    "昊天丹" => {"linghui2", 10},
    "帝者舍利" => {"sheli3", 10},
    "菩提子" => {"puti4", 15},
    "圣舍利" => {"sheli4", 15},
    "百年人参" => {"renshen1", 15},
    "百年灵芝" => {"lingzhi1", 15},
    "天山雪莲" => {"xuelian1", 15},
    "百年参心丹" => {"renshen3", 20},
    "天山雪莲膏" => {"xuelian3", 20},
    "百年灵芝丸" => {"lingzhi3", 20},
    "玄武铸骨丹" => {"con2", 30},
    "朱雀玲珑丹" => {"dex2", 30},
    "青龙炼睿丹" => {"int2", 30},
    "白虎赐元丹" => {"str2", 30},
    "千年参心丹" => {"renshen4", 40},
    "千年雪莲丹" => {"xuelian4", 40},
    "千年灵芝丸" => {"lingzhi4", 40},
    "洗髓再造仙丹" => {"con3", 50},
    "破阳无极仙丹" => {"dex3", 50},
    "神恩通慧仙丹" => {"int3", 50},
    "蚩尤诛元仙丹" => {"str3", 50},
    "子午龙甲丹" => {"longjia", 80},
    "玄黄紫箐丹" => {"xuanhuang", 80},
    "镇狱惊天丸" => {"zhenyu", 100}
  }

  @impl true
  def run(conn, %{room_id: room_id, trailing: trailing}) when is_binary(room_id) do
    if room_id == @room_id do
      do_exchange(conn, to_string(trailing) |> String.trim())
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp do_exchange(conn, arg) do
    meta = conn.character.meta || %PlayerMeta{}
    jifen = PlayerMeta.jifen(meta)

    cond do
      # LPC: if (!jifen) —— query("state/jifen", 1) 为 0/缺省
      jifen <= 0 ->
        Helpers.render(
          conn,
          "店小二微笑道：客官，您暂时没有积分呢，可以通过报告BUG或在扬州武庙祈祷获得积分。\n"
        )

      # LPC: if (!arg)
      arg == "" ->
        Helpers.render(conn, "店小二微笑道：你要兑换什么东西？(help jifen)\n")

      # LPC: switch 未命中 → default
      not Map.has_key?(@exchange_table, arg) ->
        Helpers.render(conn, "店小二对你摇摇头道：你只能兑换规定范围内的物品。\n")

      true ->
        {item_key, cost} = Map.fetch!(@exchange_table, arg)
        exchange_item(conn, meta, jifen, arg, item_key, cost)
    end
  end

  defp exchange_item(conn, meta, jifen, arg, item_key, cost) do
    cond do
      # LPC: if (jifen < cost)
      jifen < cost ->
        Helpers.render(
          conn,
          "店小二对你摇摇头道：您当前积分只有 #{jifen} 点，兑换此物品需要 #{cost} 点积分。\n"
        )

      # LPC: if (!ob) —— 本世界承接为「物品定义缺失」（详见 moduledoc）
      Items.get("clone_lib:#{item_key}") == {:error, :not_found} ->
        Helpers.render(conn, "店小二一惊，叫道：咦？我的东西…我的东西呢?！\n")

      true ->
        player_name = conn.character.name

        conn
        |> put_jifen(meta, jifen - cost)
        |> Helpers.give_item("clone_lib:#{item_key}")
        |> then(&Helpers.say(&1, @room_id, @npc_name, "兑换完成，欢迎再次光临！"))
        |> announce_rumor(item_key, player_name)
    end
  end

  # LPC 成功后 CHANNEL_D->do_channel(this_object(), "rumor",
  # sprintf("听说%s在店小二处兑换了一%s%s。", me->name(), ob->query("unit"),
  # ob->name())) —— 全服江湖传闻。Kantele 已有 rumor 频道（communication.ex
  # initial_channels），announce/2 异常已被吞掉，缺频道/进程不崩。
  defp announce_rumor(conn, item_key, player_name) do
    case Items.get("clone_lib:#{item_key}") do
      {:ok, item} ->
        Communication.announce("rumor", rumor_text(player_name, item_name(item), item_unit(item)))

      _ ->
        :ok
    end

    conn
  end

  # 传闻文案：量词取物品 unit（如「颗」「本」），缺失时回落「个」。
  # 逐字对 LPC `sprintf("听说%s在店小二处兑换了一%s%s。", me->name(),
  # ob->query("unit"), ob->name())`。
  @doc false
  def rumor_text(player_name, item_name, unit) when is_binary(unit) and unit != "" do
    "听说#{player_name}在店小二处兑换了一#{unit}#{item_name}。"
  end

  def rumor_text(player_name, item_name, _unit) do
    "听说#{player_name}在店小二处兑换了一个#{item_name}。"
  end

  defp item_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp item_name(_item), do: "物品"

  defp item_unit(%{unit: unit}) when is_binary(unit) and unit != "", do: unit
  defp item_unit(%{meta: meta}) when is_map(meta), do: meta[:unit]
  defp item_unit(_item), do: nil

  defp put_jifen(conn, _meta, value) do
    character = conn.character
    meta = character.meta || %PlayerMeta{}
    put_character(conn, %{character | meta: PlayerMeta.put_jifen(meta, value)})
  end
end
