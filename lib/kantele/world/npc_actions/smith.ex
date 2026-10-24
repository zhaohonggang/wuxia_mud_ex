defmodule Kantele.World.NpcActions.Smith do
  @moduledoc """
  P5-9 NPC 私有动作：襄阳铁匠（`xiangyang:tiejiangpu`）的打工动词
  `gu` / `dapi` / `cuihuo` 与修理动词 `repair` / `xiuli`。

  LPC 源：`d/xiangyang/npc/smith.c` + 基类 `/inherit/char/smith.c` 的
  `do_gu` / `do_dapi` / `do_cuihuo` / `reward` / `do_repair`。派活入口
  （inquiry「job/工作」→ `ask_me`）在玩家侧
  `Kantele.World.InquiryHandlers.SmithJob`（kind = "smith_job"）——
  它写 `smith/gu|dapi|cuihuo` 会话 temp，本模块的动词消费之。

  ## 移植范围

  ### gu / dapi / cuihuo（`do_*` + `reward`）

  1. `is_busy()` → 「你现在正忙。」（LPC `notify_fail`，仅本人可见）
  2. 未领对应活计（`query_temp("smith/<job>")` 为空）→ 房间广播斥责
     （LPC `message_vision`，`$n`=玩家 `$N`=铁匠）
  3. 已领 → 广播干活 vision + `reward(me)`：
     - 清三个 `smith/*` temp（LPC 三个一起删）
     - 工钱 50 + random(50) 文铜钱（LPC `new("/clone/money/coin")` 后
       `command("give coin to ...")`；本框架货币是扁平 `meta.coins`，
       直接入账并补一条到账文案——LPC 的 give 输出对玩家同样可见）
     - 经验 20 + random(10)（`meta.stats.combat_exp`）
     - 潜能 10 + random(10)（`Stats.improve_potential/2`，封顶发放，
       对应 LPC `improve_potential`；文案报请求值，与 LPC 忽略返回值一致）
     - `mark/job_smith + 1`（持久，落 `meta.marks`）
     - 掉气 30 + random(20)（`Feature.Damage.receive_damage/3`）
     - `start_busy(3)`（`meta.combat.busy`，战斗 tick 逐轮递减）

  ### repair / xiuli（`do_repair`，两段确认）

  1. 无参 → 「你打算修理什么对象？」（`notify_fail`）
  2. 背包无此物 → 「你身上好像没有这样东西。」
  3. 物品无 `consistence`（读实例 `meta["consistence"]`）→
     「…似乎不需要在这里修理吧？」——**世界数据当前无一件物品定义
     consistence**（LPC 仅 18 个特殊文件 `set("consistence", ...)`，
     clone 兵器/防具均无），故本分支是忠实现状；数据补齐后下方报价/
     确认链自动生效。
  4. `consistence >= 100` → 「…现在完好无损，修理做什么？」
  5. 已有 pending 且 item 匹配 → 忙乱拒绝 / 钱不够（`meta.coins`，
     对应 `MONEY_D->player_pay`）/ 扣钱 + consistence 归 100 +
     `start_busy(1 + random(100 - consistence) / 10)` + 清 pending
  6. 否则报价：`cost = (120 - consistence) * value / 480` 按 LPC 四档
     取整，广播报价 + 提示再输一次 + 落 pending temp

  ## 与 LPC 的差异

  - LPC `message_vision` 的 `$N`（铁匠）/`$n`（玩家）在本框架统一为
    `Helpers.broadcast/3`：模板 `$N` → 行动玩家，NPC 名直接写进文案
    （与 jobs.ex 等同例）。
  - LPC 颜色宏（HIY/CYN/HIR/NOR）已剥离，仅保留文案。
  - pending 存实例 id（LPC 存对象指针）；实例 `meta` 不随角色落盘
    （`Item.Instance` 的 Jason 编码不含 meta），consistence 修复
    当前为会话级，重启丢失（@todo：实例 meta 持久化）。
  """

  use Kantele.World.NpcAction

  import Kalevala.Character.Conn, only: [put_character: 2]

  alias Kantele.Character.Combat
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Economy.Money
  alias Kantele.Feature.Damage
  alias Kantele.World.Item
  alias Kantele.World.NpcActions.Helpers

  @room_id "xiangyang:tiejiangpu"
  @npc_name "铁匠"

  # LPC ask_me 派的三种活计（InquiryHandlers.SmithJob 写，本模块消费）
  @job_temps ~w(smith/gu smith/dapi smith/cuihuo)

  # reward 常量（LPC reward() 字面量）
  @coin_base 50
  @coin_span 50
  @exp_base 20
  @exp_span 10
  @pot_base 10
  @pot_span 10
  @qi_base 30
  @qi_span 20
  @busy_rounds 3

  # repair pending temp 键（LPC query_temp("pending/repair") 映射）
  @pending_key "smith/repair"

  @impl true
  def run(conn, %{room_id: room_id, verb: verb, trailing: trailing}) when is_binary(room_id) do
    if room_id == @room_id do
      case verb do
        "gu" -> do_gu(conn)
        "dapi" -> do_dapi(conn)
        "cuihuo" -> do_cuihuo(conn)
        "repair" -> do_repair(conn, trailing)
        "xiuli" -> do_repair(conn, trailing)
        _ -> :not_handled
      end
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  # ---- gu：鼓风箱 ----

  defp do_gu(conn) do
    cond do
      # LPC: if (me->is_busy()) return notify_fail("你现在正忙。\n");
      busy?(conn) ->
        Helpers.render(conn, "你现在正忙。\n")

      # LPC: if (! me->query_temp("smith/gu")) → message_vision 斥责
      blank_temp?(conn, "smith/gu") ->
        Helpers.broadcast(
          conn,
          @room_id,
          "\n$N刚偷偷的拉起鼓风机，鼓了几阵风。\n就听见#{@npc_name}对$N大喝道：滚开，乱搞什么。\n"
        )

      true ->
        conn
        |> Helpers.broadcast(@room_id, "$N拉起鼓风机拼命鼓了起来，#{@npc_name}看了点了点头。\n")
        |> reward()
    end
  end

  # ---- dapi：打坯 ----

  defp do_dapi(conn) do
    cond do
      busy?(conn) ->
        Helpers.render(conn, "你现在正忙。\n")

      blank_temp?(conn, "smith/dapi") ->
        Helpers.broadcast(
          conn,
          @room_id,
          "\n$N拿起几块生铁，在手里掂了掂。\n就听见#{@npc_name}对$N大喝道：放下，乱搞什么。\n"
        )

      true ->
        conn
        |> Helpers.broadcast(
          @room_id,
          "$N拿着锤子对刚出炉的火热的生铁用力敲打着，#{@npc_name}“嗯”了一声，看上去有些满意。\n"
        )
        |> reward()
    end
  end

  # ---- cuihuo：淬火 ----

  defp do_cuihuo(conn) do
    cond do
      busy?(conn) ->
        Helpers.render(conn, "你现在正忙。\n")

      blank_temp?(conn, "smith/cuihuo") ->
        Helpers.broadcast(
          conn,
          @room_id,
          "\n$N刚抄起一个打造好的坯子，摆弄了几下。\n就听见#{@npc_name}对$N大喝道：放下，别给我搞坏了。\n"
        )

      true ->
        # LPC do_cuihuo 成功段的 message_vision 首参是 me（玩家），
        # $N 即玩家，与本框架 broadcast 的 $N 语义一致，直接映射。
        conn
        |> Helpers.broadcast(
          @room_id,
          "$N用铁钳抄起一块火红的坯子，伸进了水池，“哧”的一声轻烟四冒。\n"
        )
        |> reward()
    end
  end

  # ---- reward：发工钱 + 经验/潜能 + 计数 + 掉气 + 忙乱 ----

  defp reward(conn) do
    character = current(conn)
    meta = character.meta || %{}
    stats = meta.stats || %Stats{}

    exp = @exp_base + :rand.uniform(@exp_span) - 1
    pot = @pot_base + :rand.uniform(@pot_span) - 1
    coin = @coin_base + :rand.uniform(@coin_span) - 1
    qi_loss = @qi_base + :rand.uniform(@qi_span) - 1

    {:ok, wounded} = Damage.receive_damage(character, :qi, qi_loss)

    # LPC improve_potential：封顶发放（Stats.improve_potential/2 同语义）
    new_stats =
      stats
      |> Map.put(:combat_exp, (stats.combat_exp || 0) + exp)
      |> Stats.improve_potential(pot)

    job_count = (meta.marks || %{})["mark/job_smith"] || 0

    combat = Combat.start_busy(meta.combat || %Combat{}, @busy_rounds)

    conn =
      put_character(conn, %{
        wounded
        | meta: %{
            wounded.meta
            | stats: new_stats,
              coins: (meta.coins || 0) + coin,
              marks: Map.put(meta.marks || %{}, "mark/job_smith", job_count + 1),
              combat: combat,
              temp: Enum.reduce(@job_temps, meta.temp || %{}, &Map.delete(&2, &1))
          }
      })

    conn
    |> Helpers.broadcast(@room_id, "#{@npc_name}对$N道：干得不坏，这是给你的工钱。\n")
    |> then(&Helpers.render(&1, "#{@npc_name}给你#{Money.money_str(coin)}。\n"))
    |> then(&Helpers.render(&1, "你获得了#{exp}点经验和#{pot}点潜能。\n"))
    |> persist()
  end

  # ---- repair / xiuli：两段确认修理 ----

  defp do_repair(conn, trailing) do
    arg = to_string(trailing || "") |> String.trim()

    cond do
      # LPC: if (! arg) return notify_fail("你打算修理什么对象？\n");
      arg == "" ->
        Helpers.render(conn, "你打算修理什么对象？\n")

      # LPC: if (! objectp(ob = present(arg, me)))
      true ->
        case find_instance(conn, arg) do
          nil -> Helpers.render(conn, "你身上好像没有这样东西。\n")
          inst -> repair_item(conn, inst)
        end
    end
  end

  defp repair_item(conn, inst) do
    item = Item.instance_item(inst)
    name = item.name || inst.item_id
    consistence = instance_consistence(inst)

    cond do
      # LPC: if (undefinedp(consistence = ob->query("consistence")))
      is_nil(consistence) ->
        Helpers.render(conn, "#{name}似乎不需要在这里修理吧？\n")

      # LPC: if (consistence >= 100)
      consistence >= 100 ->
        Helpers.render(conn, "#{name}现在完好无损，修理做什么？\n")

      # LPC: 已有 pending 且 repair["item"] == ob → 确认付费修理
      pending_matches?(conn, inst) ->
        confirm_repair(conn, inst, name, consistence)

      true ->
        quote_repair(conn, inst, name, consistence)
    end
  end

  defp quote_repair(conn, inst, name, consistence) do
    item = Item.instance_item(inst)
    value = item_meta_value(item, "value") || 0
    cost = repair_cost(consistence, value)

    conn =
      conn
      |> Helpers.put_temp(@pending_key, %{"item" => inst.id, "cost" => cost})
      |> Helpers.broadcast(
        @room_id,
        "\n$N拿出一#{unit_of(item)}#{name}，#{@npc_name}瞥了一眼，道：要修好它得要#{Money.money_str(cost)}才行。\n"
      )
      |> Helpers.render("如果你的确想修理这件物品，请再输入一次这条命令。\n")

    persist(conn)
  end

  defp confirm_repair(conn, inst, name, consistence) do
    character = current(conn)
    meta = character.meta || %{}
    cost = (meta.temp || %{})[@pending_key]["cost"] || 0
    coins = meta.coins || 0

    cond do
      # LPC: if (me->is_busy()) return notify_fail("你现在正忙着呢！\n");
      busy?(conn) ->
        Helpers.render(conn, "你现在正忙着呢！\n")

      # LPC: if (MONEY_D->player_pay(me, repair["cost"]) != 1)
      coins < cost ->
        Helpers.render(conn, "你身上的钱不够呀！\n")

      true ->
        # LPC: ob->set("consistence", 100) —— 写实例 meta（会话级，见 moduledoc）
        character = put_instance_consistence(character, inst, 100)
        # LPC: me->start_busy(1 + random(100 - consistence) / 10)（C 整数除法）
        busy = 1 + :rand.uniform(max(100 - consistence, 1)) |> div(10)
        combat = Combat.start_busy(meta.combat || %Combat{}, busy)

        conn =
          put_character(conn, %{
            character
            | meta: %{
                character.meta
                | coins: coins - cost,
                  combat: combat,
                  temp: Map.delete(meta.temp || %{}, @pending_key)
              }
          })

        conn
        |> Helpers.broadcast(
          @room_id,
          "$N把#{name}递给了#{@npc_name}。\n只见#{@npc_name}拿起工具，东敲西补，将#{name}好好修了修。\n"
        )
        |> Helpers.broadcast(
          @room_id,
          "#{@npc_name}道：“好了。”随手把#{name}还给了$N，$N看了看，满意的掏出了一些钱付了帐。\n"
        )
        |> persist()
    end
  end

  # LPC: cost = (120 - consistence) * ob->query("value") / 480; 四档取整
  defp repair_cost(consistence, value) do
    cost = div((120 - consistence) * value, 480)

    cond do
      cost >= 100_000 -> div(div(cost - 100_000, 2) + 100_000, 10_000) * 10_000
      cost >= 10_000 -> div(cost, 1_000) * 1_000
      cost >= 1_000 -> div(cost, 100) * 100
      cost >= 100 -> div(cost, 10) * 10
      true -> cost
    end
  end

  # ---- 小工具 ----

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp busy?(conn) do
    meta = current(conn).meta || %{}
    meta.combat && Combat.busy?(meta.combat)
  end

  # LPC 真值语义：query_temp 未设置返回 0（假）
  defp blank_temp?(conn, key) do
    case Helpers.temp(conn, key) do
      nil -> true
      false -> true
      0 -> true
      "" -> true
      _ -> false
    end
  end

  defp find_instance(conn, name) do
    character = current(conn)

    Enum.find(character.inventory || [], fn inst ->
      Item.matches?(Item.instance_item(inst), name)
    end)
  end

  defp instance_consistence(inst) do
    case Map.get(inst.meta || %{}, "consistence") do
      value when is_integer(value) -> value
      _ -> nil
    end
  end

  defp put_instance_consistence(character, inst, value) do
    inventory =
      Enum.map(character.inventory || [], fn i ->
        if i.id == inst.id, do: %{i | meta: Map.put(i.meta || %{}, "consistence", value)}, else: i
      end)

    %{character | inventory: inventory}
  end

  defp pending_matches?(conn, inst) do
    pending = Helpers.temp(conn, @pending_key)
    is_map(pending) and Map.get(pending, "item") == inst.id
  end

  # LPC ob->query("value") / ob->query("unit")：落在物品 meta（世界数据
  # 的 items 块 meta 段；Kalevala.World.Item 结构体无这两字段）。
  defp item_meta_value(item, key) do
    meta = Map.get(item, :meta) || %{}
    Map.get(meta, key) || Map.get(meta, String.to_atom(key))
  end

  defp unit_of(item) do
    case item_meta_value(item, "unit") do
      unit when is_binary(unit) and unit != "" -> unit
      _ -> ""
    end
  end

  # 落盘 stats/coins/marks/consistence（put_character 只改内存态）。
  # 仅对真实玩家落盘：单测 fixture 的 id 为 nil，跳过可避免 Records.save/1
  # 在沙盒里刷 error 日志（同 peiyao.ex 惯例）。
  defp persist(conn) do
    character = current(conn)

    if is_binary(character.id) and String.starts_with?(character.id, "player:") do
      Records.save(character)
    end

    conn
  end
end
