defmodule Kantele.Character.GiveEvent do
  @moduledoc """
  give 的两端处理（Batch 5）

  - 收受端 `characters/give`：把对方赠予的物品实例加入自己背包并落盘，回执赠与人
  - 店小二等特殊 NPC：委托给 Kantele.NPC.Xiaoer 处理钱币/尸体/兑换（跨进程由给予者更新状态）
  - 赠与端 `give/result`：确认后从自己背包移除该物品并落盘，提示成功
  """

  use Kalevala.Character.Event

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Teleport
  alias Kantele.NPC.Xiaoer
  alias Kantele.Communication
  alias Kantele.World.Items
  alias Kantele.World.Forging
  alias Kantele.World.RoomActions.Helpers
  alias Kalevala.World.Item
  alias Kantele.Item, as: KItem
  alias Kantele.Item.Backpack

  # ---- 收受端 ----

  def receive(conn, %{data: %{item_instance: item_instance, from_name: from_name} = data}) do
    character = conn.character

    cond do
      # 通用 accept_object 规则表优先生效（converter 从 accept_object() 抽取）
      generic_accept?(character) ->
        handle_accept_give(conn, character, item_instance, data, from_name)

      # 店小二 NPC 特殊处理：验证物品后，由给予者进程处理状态更新
      Xiaoer.is_xiaoer?(character) ->
        handle_xiaoer_give(conn, character, item_instance, data, from_name)

      true ->
        handle_normal_give(conn, character, item_instance, data, from_name)
    end
  end

  defp generic_accept?(%{meta: %{accept: rules}}) when is_list(rules) and rules != [], do: true
  defp generic_accept?(_), do: false

  # ---- 通用 accept_object 规则分发（对应 LPC accept_object/2） ----

  defp handle_accept_give(conn, npc, item_instance, data, from_name) do
    reply_to = Map.get(data, :reply_to)
    from_id = Map.get(data, :from_id)
    rules = npc.meta.accept

    case match_accept_rule(item_instance, rules) do
      {:forge} ->
        Kantele.World.ForgingAccept.handle(conn, npc, item_instance, data, from_name)

      {:wuxiuwen} ->
        Kantele.World.WuxiuwenAccept.handle(conn, npc, item_instance, data, from_name)

      {:reborn} ->
        Kantele.World.RebornAccept.handle(conn, npc, item_instance, data, from_name)

      {:suoyangdan} ->
        Kantele.World.SuoyangdanAccept.handle(conn, npc, item_instance, data, from_name)

      {:ok, reply} ->
        npc = take_item(npc, item_instance)

        send(
          reply_to,
          %Event{
            from_pid: self(),
            topic: "give/result",
            data: %{
              ok: true,
              item_id: item_instance.item_id,
              instance_id: item_instance.id,
              to_id: npc.id,
              from_id: from_id
            }
          }
        )

        if npc != conn.character, do: Records.save(npc)

        conn
        |> put_character(npc)
        |> render(CommandView, "text", %{text: reply <> "\n"})
        |> prompt(CommandView, "prompt", %{})

      {:error, reason} ->
        send(
          reply_to,
          %Event{
            from_pid: self(),
            topic: "give/result",
            data: %{
              ok: false,
              item_id: item_instance.item_id,
              instance_id: item_instance.id,
              to_id: npc.id,
              from_id: from_id,
              reason: reason
            }
          }
        )

        conn
        |> put_character(npc)
        |> render(CommandView, "text", %{text: reason <> "\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # 按收录顺序匹配规则；命中即返回代表文案。规则：
  #   { kind: "money" }        收钱币，可选 min 下限
  #   { kind: "item_id" }      收指定物品 id
  #   { kind: "item_name" }    收指定名字物品
  #   { kind: "any" }          兜底接受/拒绝（accept 布尔）
  defp match_accept_rule(item_instance, rules) do
    item =
      case Items.get(item_instance.item_id) do
        {:ok, item} -> item
        _ -> nil
      end

    if is_nil(item) do
      {:error, from_drop_message()}
    else
      Enum.reduce(rules, {:error, refuse_message(item)}, fn rule, acc ->
        case acc do
          {:ok, _} ->
            acc

          {:forge} ->
            acc

          {:wuxiuwen} ->
            acc

          _ ->
            case rule_hit(rule, item) do
              :hit -> {:ok, take_message(rule, item)}
              :decline -> {:error, failure_message(rule, item)}
              :forge -> {:forge}
              :suoyangdan -> {:suoyangdan}
              :miss -> acc
            end
        end
      end)
    end
  end

  defp rule_hit(%{kind: "money"} = rule, item) do
    if KItem.is_currency?(item) do
      min = rule.min || 0

      if KItem.currency_amount(item) >= min,
        do: :hit,
        else: :miss
    else
      :miss
    end
  end

  defp rule_hit(%{kind: "item_id"} = rule, item) do
    if rule.id == item.id, do: :hit, else: :miss
  end

  defp rule_hit(%{kind: "item_name"} = rule, item) do
    if Kantele.World.Item.matches?(item, rule.name), do: :hit, else: :miss
  end

  defp rule_hit(%{kind: "any"} = rule, _item) do
    if rule.accept, do: :hit, else: :decline
  end

  # forge 议价规则：命中即交给 Kantele.World.ForgingAccept 处理（莫邪锻造工坊）
  defp rule_hit(%{kind: "forge"}, _item), do: :forge

  # 武修文收还工具：命中即交给 Kantele.World.WuxiuwenAccept 处理（郭府打工闭环）
  defp rule_hit(%{kind: "wuxiuwen"}, _item), do: :wuxiuwen

  # 转世献丹：命中即交给 Kantele.World.RebornAccept 处理（地藏王收精元丹）
  defp rule_hit(%{kind: "reborn"}, _item), do: :reborn

  # 锁阳丹药引：命中即交给 Kantele.World.SuoyangdanAccept 处理（阎罗收四味药引）
  defp rule_hit(%{kind: "suoyangdan"} = rule, item) do
    if rule.id == item.id, do: :suoyangdan, else: :miss
  end

  defp rule_hit(_rule, _item), do: :miss

  # 收下的物品进入 NPC 背包（钱币不进背包，避免污染商店货架）
  defp take_item(npc, %{item_id: item_id} = item_instance) do
    case Items.get(item_id) do
      {:ok, item} ->
        if KItem.is_currency?(item) do
          npc
        else
          %{npc | inventory: [item_instance | npc.inventory]}
        end

      _ ->
        npc
    end
  end

  defp take_message(%{msg: msg} = _rule, item) when is_list(msg) and msg != [],
    do: Enum.random(msg)

  defp take_message(_rule, item), do: "你给了#{item.name}。"

  # 拒绝文案：优先使用规则 fail_msg 台词池，缺省回退泛化拒绝语
  defp failure_message(%{fail_msg: fail_msg} = rule, item)
       when is_list(fail_msg) and fail_msg != [],
       do: Enum.random(fail_msg)

  defp failure_message(%{kind: "any"} = rule, _item), do: refuse_message(nil)
  defp failure_message(_rule, item), do: refuse_message(item)

  defp refuse_message(nil), do: "对方不肯收下。"
  defp refuse_message(item), do: "对方不收#{item.name}。"
  defp from_drop_message(), do: "物品不在房间中。"

  defp handle_normal_give(conn, character, item_instance, data, from_name) do
    item = Items.get!(item_instance.item_id)
    item_name = item.name

    case item_instance do
      nil ->
        deny(conn, from_name)

      _ ->
        inventory = [item_instance | character.inventory]
        character = %{character | inventory: inventory}

        send(
          Map.get(data, :reply_to),
          %Event{
            from_pid: self(),
            topic: "give/result",
            data: %{
              ok: true,
              item_id: item_instance.item_id,
              instance_id: item_instance.id,
              to_id: character.id,
              from_id: Map.get(data, :from_id)
            }
          }
        )

        Records.save(character)

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: "#{from_name}给你#{item_name}。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp handle_xiaoer_give(conn, npc, item_instance, data, from_name) do
    reply_to = Map.get(data, :reply_to)
    from_id = Map.get(data, :from_id)

    # 在 NPC 进程验证物品，通过则让给予者进程处理状态更新
    case Xiaoer.validate_give(npc, item_instance) do
      {:ok, action} ->
        # 发送给给予者进程处理
        send(reply_to, %Event{
          from_pid: self(),
          topic: "xiaoer/process_give",
          data: %{
            action: action,
            item_id: item_instance.item_id,
            instance_id: item_instance.id,
            npc_id: npc.id,
            npc_pid: self(),
            from_id: from_id
          }
        })

        # NPC 即时回应
        conn
        |> put_character(conn.character)
        |> render(CommandView, "text", %{
          text: "店小二接过#{Xiaoer.item_name(item_instance)}，正在为您办理...\n"
        })
        |> prompt(CommandView, "prompt", %{})

      {:error, msg} ->
        send(reply_to, %Event{
          from_pid: self(),
          topic: "give/result",
          data: %{
            ok: false,
            item_id: item_instance.item_id,
            instance_id: item_instance.id,
            to_id: npc.id,
            from_id: Map.get(data, :from_id),
            reason: msg
          }
        })

        conn
        |> put_character(conn.character)
        |> render(CommandView, "text", %{text: msg <> "\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp deny(conn, from_name) do
    conn
    |> render(CommandView, "text", %{text: "#{from_name}递来东西，但你无法接受。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 给予者端：处理店小二业务（更新自身 meta）----

  def xiaoer_process_give(conn, %{data: %{action: action}} = event) do
    character = conn.character

    case do_xiaoer_action(character, action, event.data) do
      {:ok, new_character, msg} ->
        send(
          Map.get(event.data, :npc_pid) || :ignore,
          %Event{
            from_pid: self(),
            topic: "xiaoer/give_result",
            data: %{ok: true, msg: msg, from_id: character.id}
          }
        )

        conn
        |> put_character(new_character)
        |> render(CommandView, "text", %{text: msg <> "\n"})
        |> prompt(CommandView, "prompt", %{})

      {:error, msg} ->
        conn
        |> render(CommandView, "text", %{text: msg <> "\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp do_xiaoer_action(character, :pay_rent, data) do
    amount = data.amount
    rent_paid = PlayerMeta.get_temp(character.meta, "rent_paid") || 0
    new_rent = rent_paid + amount

    new_meta = PlayerMeta.put_temp(character.meta, "rent_paid", new_rent)
    new_character = %{character | meta: new_meta}
    Records.save(new_character)

    change = amount - Xiaoer.rent_per_night()

    msg =
      if change > 0 do
        "多谢客官，找您 #{change} 文钱。您已预付 #{new_rent} 文房钱。"
      else
        "多谢客官，您已预付 #{new_rent} 文房钱。"
      end

    {:ok, %{character | meta: new_meta}, msg}
  end

  defp do_xiaoer_action(character, :exchange_item, data) do
    item_key = data.item_key
    exchange = Map.get(Xiaoer.exchange_items(), item_key)

    if exchange == nil do
      {:error, "没有这个兑换项目。"}
    else
      points = Kantele.Character.PlayerMeta.jifen(character.meta)

      if points >= exchange.cost do
        new_points = points - exchange.cost
        new_meta = Kantele.Character.PlayerMeta.put_jifen(character.meta, new_points)
        new_character = %{character | meta: new_meta}

        # 创建物品实例给玩家
        case Kantele.World.Items.get(exchange.item) do
          {:ok, item_template} ->
            item_instance = %Kalevala.World.Item.Instance{
              id: Kalevala.World.Item.Instance.generate_id(),
              item_id: exchange.item,
              created_at: DateTime.utc_now()
            }

            new_character = %{
              new_character
              | inventory: [item_instance | new_character.inventory]
            }

            Kantele.Character.Records.save(new_character)

            {:ok, new_character, "兑换成功！您获得了 #{exchange.name}。"}

          _ ->
            {:error, "兑换物品不存在，请联系巫师。"}
        end
      else
        {:error, "您的积分不足，需要 #{exchange.cost} 点。"}
      end
    end
  end

  defp do_xiaoer_action(character, :dispose_corpse, _data) do
    # 尸体处理：直接丢弃（已从给予者背包移除）
    {:ok, character, "店小二拖着尸体拖到了后院。"}
  end

  # ---- 赠与端 ----

  def result(conn, %{data: %{ok: true, from_id: from_id, instance_id: instance_id}} = _event) do
    character = conn.character

    if from_id == character.id do
      inventory =
        Enum.reject(character.inventory, fn item_instance ->
          item_instance.id == instance_id
        end)

      character = %{character | inventory: inventory}
      Records.save(character)

      conn
      |> put_character(character)
      |> render(CommandView, "text", %{text: "你把东西交给了对方。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      conn
    end
  end

  def result(conn, %{data: %{ok: false}}) do
    conn
    |> render(CommandView, "text", %{text: "对方不肯收下。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def result(conn, _event), do: conn

  # ---- forge 议价结果（莫邪进程 → 玩家进程） ----
  # 玩家把材料/钱币交给莫邪后，莫邪进程通过 `forge/accept` 事件把回复与结算送达玩家：
  #   ok:true  → 玩家侧移除该物品实例（完成物理转移），展示莫邪回复
  #   ok:false → 莫邪拒收，物品仍在玩家背包，仅展示拒绝文案

  def forge_accept(conn, %{data: %{ok: true, instance_id: instance_id, message: message} = data}) do
    character = conn.character

    inventory = Enum.reject(character.inventory, fn item_instance -> item_instance.id == instance_id end)
    character = %{character | inventory: inventory}

    # 乾坤袋：炼成给袋 / 已有背包则 +5 格
    {character, message} = grant_or_upgrade(character, data, message)

    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end

  # 炼成如意乾坤袋：直接入包（LPC `me->set("storage_bag", 1)` 的等价物）
  defp grant_or_upgrade(character, %{grant_item_id: item_id}, message) when is_binary(item_id) do
    instance = %Item.Instance{
      id: Item.Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now()
    }

    {%{character | inventory: [instance | character.inventory]}, message}
  end

  # 乾坤石强化背包：只改该玩家那件背包实例的 meta（`Forging.upgrade_bag/2`），
  # 不动全局物品定义，否则一个玩家的升级会摊到所有人身上。
  defp grant_or_upgrade(character, %{upgrade_bag: delta}, message) when is_integer(delta) do
    {character, extra} = Forging.upgrade_bag(character, delta)
    capacity = Backpack.capacity(character.meta.stats.combat_exp, extra)

    {character, message <> "一道华光闪过，你的背包空间增加了，当前容量 #{capacity} 格。\n"}
  end

  defp grant_or_upgrade(character, _data, message), do: {character, message}

  def forge_accept(conn, %{data: %{ok: false, message: message}} = _event) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- forge 退款（莫邪进程 → 玩家进程，对应 LPC do_answer 干将不在场 / time_out 超时） ----
  # 莫邪把材料与定金一并交还玩家：重新入背包并落盘。
  # `message` 可覆盖默认文案（超时退款用「想好再来吧」那条）。
  def forge_refund(conn, %{data: data} = _event) do
    material_instance = Map.get(data, :material_instance)
    money_instance = Map.get(data, :money_instance)
    message = Map.get(data, :message) || "莫邪把材料与定金交还给了你。\n"
    character = conn.character

    inventory =
      character.inventory
      |> then(fn inv -> if money_instance, do: [money_instance | inv], else: inv end)
      |> then(fn inv -> if material_instance, do: [material_instance | inv], else: inv end)

    character = %{character | inventory: inventory}
    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end

  # 干将的私有提示（LPC `tell_rules` 的 tell_object）
  def forge_notice(conn, %{data: %{text: text}}) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 转世献丹回执（地藏王进程 → 玩家进程）----
  # 地藏王收下精元丹后，通过 `reborn/give-jingyuandan` 事件送达玩家：
  #   校验 SkyPass + DiZangPass → 销毁精元丹 → 逐个遍历六道轮回 → 无间道

  # LPC `dizangwang.c:243-262` accept_object() 里连着 7 次 `me->move(...)`：
  # 天道 → 地狱道 → 人间道 → 饿鬼道 → 畜生道 → 修罗道 → 无间道。
  # 之前 Ex 直接一跳到无间道，跳过了这 6 个房间。
  @six_paths [
    {"death:tiandao", "天极道"},
    {"death:diyudao", "地狱道"},
    {"death:rendao", "人间道"},
    {"death:eguidao", "饿鬼道"},
    {"death:chushengdao", "畜生道"},
    {"death:xiuluodao", "修罗道"},
    {"death:wujiandao", "无间道"}
  ]

  @doc "六道轮回逐房遍历表（含终点无间道），对应 LPC `accept_object` 的 7 次 move()"
  def six_paths, do: @six_paths

  @doc "按 LPC 顺序连续 7 次 `Teleport.teleport/2`，每房留一句掠过文案"
  def traverse_six_paths(conn) do
    Enum.reduce(@six_paths, conn, fn {room_id, name}, acc ->
      acc
      |> Teleport.teleport(room_id)
      |> Helpers.render_to_player("你眼前一花，六道轮回转过#{name}……\n")
    end)
  end

  def reborn_give_jingyuandan(conn, %{data: %{item_id: item_id, instance_id: instance_id, from_id: from_id}}) do
    character = conn.character

    if from_id == character.id do
      env = character.meta.env || %{}
      sky_pass = Map.get(env, :SkyPass) == true
      dizang_pass = Map.get(env, :DiZangPass) == true

      cond do
        sky_pass and dizang_pass ->
          # 销毁精元丹（LPC destruct(ob)）
          inventory =
            Enum.reject(character.inventory, fn inst -> inst.id == instance_id end)
          character = %{character | inventory: inventory}
          Records.save(character)

          # 江湖传闻
          Communication.announce("rumor", "#{character.name}将精元丹献给地藏王，六道轮回轰然转动！")

          # 逐个遍历六道轮回 7 个房间，最终落在无间道（LPC 的 7 次 move()）。
          # 注意：不要在这里再 put_character(conn.character) —— Teleport 已把最新
          # 角色写进 private.update_character，用旧的 conn.character 覆盖会把
          # room_id 退回献丹前，令位移在 flush 时失效。
          traverse_six_paths(conn)
          |> render(CommandView, "text", %{text: "精元丹护住你的元神，你进入六道轮回，来到无间道……\n"})
          |> prompt(CommandView, "prompt", %{})

        true ->
          conn
          |> render(CommandView, "text", %{text: "地藏王道：无功不受禄，这个你还是自己留着吧。\n"})
          |> prompt(CommandView, "prompt", %{})
      end
    else
      conn
    end
  end

  # ---- 锁阳丹药引回执（阎罗进程 → 玩家进程）----
  # 阎罗收下药引后，通过 `suoyangdan/give-ingredient` 事件送达玩家：
  #   玩家侧移除该物品实例，按 Quest.add_item/4 追踪收集进度；
  #   四味齐备时置位 Quest.set_solved/2，发放奖励（exp/potential/寰宇天晶）。
  #
  # LPC `yanluo.c` accept_object() 里连着检查 4 味药引，全部齐备后置位
  # over_quest/hell_quest/锁阳丹=1，给予寰宇天晶并奖励经验/潜能。
  @suoyangdan_items ~w(longdan hugu yumao jiake)a

  @doc "锁阳丹四味药引 item_id 表（与 UCL 物品定义键一致）"
  def suoyangdan_items, do: @suoyangdan_items

  def suoyangdan_give_ingredient(conn, %{data: %{item_id: item_id, instance_id: instance_id, from_id: from_id, from_name: from_name}}) do
    character = conn.character

    if from_id == character.id and item_id in @suoyangdan_items do
      # 移除该药引实例（LPC destruct(ob)）
      inventory =
        Enum.reject(character.inventory, fn inst -> inst.id == instance_id end)

      quests0 = PlayerMeta.quests(character.meta)
      spec = %{file: "hell_quest/锁阳丹", item: @suoyangdan_items}

      # 追踪收集进度（Quest.add_item/4 要求 item 在 spec.item 声明过）
      case Quest.add_item(quests0, spec, item_id, 1) do
        {:ok, quests1} ->
          all_collected? =
            Enum.all?(@suoyangdan_items, fn iid ->
              Quest.get_item(quests1, spec, iid) >= 1
            end)

          if all_collected? do
            # 四味齐备：置位已解、发放奖励、赠予寰宇天晶
            {quests2, rewards} = complete_suoyangdan(quests1, character.meta.stats)

            stats = character.meta.stats
            stats =
              %{
                stats
                | combat_exp: stats.combat_exp + (Map.get(rewards, :exp) || 0),
                  potential: stats.potential + (Map.get(rewards, :potential) || 0),
                  score: stats.score + (Map.get(rewards, :score) || 0),
                  weiwang: stats.weiwang + (Map.get(rewards, :weiwang) || 0),
                  gongxian: stats.gongxian + (Map.get(rewards, :gongxian) || 0)
              }

            coins = (character.meta.coins || 0) + (Map.get(rewards, :coins) || 0)

            # 赠予寰宇天晶
            tianjing_instance =
              %Kalevala.World.Item.Instance{
                id: Kalevala.World.Item.Instance.generate_id(),
                item_id: "tianjing",
                created_at: DateTime.utc_now()
              }
            inventory = [tianjing_instance | inventory]

            character =
              character
              |> Map.put(:inventory, inventory)
              |> Map.put(:meta, %{
                character.meta
                | stats: stats,
                  coins: coins,
                  quests: quests2
              })

            Records.save(character)

            Communication.announce(
              "rumor",
              "#{character.name}为阎罗备齐锁阳丹四味药引，阎罗赐予寰宇天晶一块！\n"
            )

            conn
            |> put_character(character)
            |> render(
              CommandView,
              "text",
              %{text:
                "十殿阎罗大喜道：「这下四种原料都已备齐，终于可以开始炼制老大要的锁阳丹了！多亏有你的帮助啊，这个是以前我从蓬莱仙山得来的宝物，留着也没用，就当是酬劳好了。」\n" <>
                  "你把东西交给了#{from_name || "十殿阎罗"}。\n" <>
                  "任务完成！（实战经验+#{Map.get(rewards, :exp) || 0} 潜能+#{Map.get(rewards, :potential) || 0} 阅历+#{Map.get(rewards, :score) || 0} 威望+#{Map.get(rewards, :weiwang) || 0} 门派贡献+#{Map.get(rewards, :gongxian) || 0}）\n" <>
                  "你获得了寰宇天晶。\n"
              }
            )
            |> prompt(CommandView, "prompt", %{})
          else
            # 尚未齐备：只记录进度，药引已收下
            character =
              character
              |> Map.put(:inventory, inventory)
              |> Map.put(:meta, %{character.meta | quests: quests1})

            Records.save(character)

            conn
            |> put_character(character)
            |> render(
              CommandView,
              "text",
              %{text:
                "十殿阎罗 nods：「这味药引可用，还差其他原料，你继续寻找。」\n"
              }
            )
            |> prompt(CommandView, "prompt", %{})
          end

        {:error, _reason} ->
          # Quest.add_item 失败（如任务不在办中）：不消耗物品，提示
          conn
          |> render(CommandView, "text", %{text: "十殿阎罗道：这差事你似乎还未领取，先去问我「锁阳丹」。\n"})
          |> prompt(CommandView, "prompt", %{})
      end
    else
      conn
    end
  end

  defp complete_suoyangdan(quests, stats) do
    # 置位已解 + 连续计数 +1
    quests =
      case Quest.set_solved(quests, %{file: "hell_quest/锁阳丹"}) do
        {:ok, qs} -> qs
        _ -> quests
      end

    quests = Quest.del_todo(quests, "hell_quest/锁阳丹") |> Quest.bump_quest_count()

    # 奖励：参照 LPC 给予经验/潜能/阅历，这里用 fixed 档位
    rewards = %{exp: 5000, potential: 2000, score: 1000, weiwang: 50, gongxian: 100, coins: 0}

    {quests, rewards}
  end

  # ---- 武修文收还工具回执（武修文进程 → 玩家进程）----
  # 玩家把工具交给武修文后，武修文进程 `WuxiuwenAccept` 发回此事件：玩家侧落
  # `mark/还了`（LPC `set_temp("mark/还了", 1)`），并回话。完成标记 / job_name
  # 的校验放在玩家侧（武修文进程看不见玩家 meta）。

  # 五种打工活计的完成 mark（与 Wuguan.Work 写出的 done mark 对应；不含「挑完了」，
  # LPC accept_object 仅查这五个）。
  @wuguan_done_marks ~w(mark/劈完了 mark/浇完了 mark/锄完了 mark/锯完了 mark/扫完了)

  def wuxiuwen_returned(conn, %{data: %{ok: true, message: message}}) do
    character = current(conn)
    meta = character.meta || %PlayerMeta{}
    temp = meta.temp || %{}

    completed = Enum.any?(@wuguan_done_marks, &present_temp?(temp, &1))
    has_job = not blank?(Map.get(temp, "job_name"))

    cond do
      not completed ->
        reject_reply(conn, "你还没完成工作，怎么就回来还工具了，偷懒吗？\n")

      not has_job ->
        reject_reply(conn, "我没有发给你过东西，你是不是还错了？\n")

      true ->
        new_meta = PlayerMeta.put_temp(meta, "mark/还了", 1)
        new_character = %{character | meta: new_meta}
        Records.save(new_character)

        conn
        |> put_character(new_character)
        |> render(CommandView, "text", %{text: message})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def wuxiuwen_returned(conn, %{data: %{ok: false, message: message}}) do
    reject_reply(conn, message)
  end

  def wuxiuwen_returned(conn, _event), do: conn

  defp present_temp?(temp, key) do
    case Map.get(temp, key) do
      nil -> false
      false -> false
      0 -> false
      "" -> false
      _ -> true
    end
  end

  defp blank?(nil), do: true
  defp blank?(false), do: true
  defp blank?(0), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  defp reject_reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
