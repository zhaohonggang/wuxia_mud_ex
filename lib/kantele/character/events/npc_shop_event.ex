defmodule Kantele.Character.NpcShopEvent do
  @moduledoc """
  NPC 侧商店应答（A10/N2）

  收到房间转发的 `shop/list` / `shop/buy` 后，商人核对自家 goods
  并把结果作为事件回给玩家进程，由玩家侧 ShopEvent 渲染与扣钱。
  """

  use Kalevala.Character.Event

  alias Kantele.Npc.Dealer
  alias Kantele.World.Items

  def list(conn, %{data: %{reply_to: reply_to}}) do
    goods = conn.character.meta.goods || []

    case goods do
      [] ->
        conn

      goods ->
        catalog =
          goods
          |> Enum.map(fn item_id -> {item_id, item_info(item_id)} end)
          |> Enum.reject(fn {_id, info} -> is_nil(info) end)
          |> Enum.into(%{}, fn {_id, info} -> {info.id, info} end)

        # 货单走纯层 dealer.c do_list：聚合 {short, unit, price, count}（目录大量供应）
        rows = Dealer.build_list([], catalog)

        reply(reply_to, "shop/list-result", %{
          vendor: conn.character.name,
          items: rows
        })

        conn
    end
  end

  def buy(conn, %{data: %{reply_to: reply_to, item_name: item_name} = data}) do
    goods = conn.character.meta.goods || []
    item_name = item_name || ""

    matched =
      Enum.find(goods, fn item_id ->
        info = item_info(item_id)
        info != nil && Kantele.World.Item.matches?(%{name: info.name}, item_name)
      end)

    case matched && item_info(matched) do
      nil ->
        reply(reply_to, "shop/buy-result", %{
          vendor: conn.character.name,
          unavailable: true,
          item_name: item_name,
          buyer_id: Map.get(data, :buyer_id),
          buyer_name: Map.get(data, :buyer_name)
        })

        conn

      info ->
        item_map = %{
          name: info.name,
          id: info.id,
          unit: info.unit,
          value: info.value,
          file: info.id,
          amount: 1
        }

        # 计价走纯层 dealer.c do_buy（成本价因子 10 / 目录覆盖 / 店东折扣），
        # 单价随 event 串联（玩家侧再按 quantity 乘总价）
        case Dealer.do_buy(item_map, 1, %{}) do
          {:ok, unit_price} ->
            reply(reply_to, "shop/buy-result", %{
              vendor: conn.character.name,
              unavailable: false,
              item_id: info.id,
              item_name: info.name,
              price: unit_price,
              quantity: Map.get(data, :quantity, 1),
              buyer_id: Map.get(data, :buyer_id),
              buyer_name: Map.get(data, :buyer_name)
            })

            conn

          {:reject, _msg} ->
            reply(reply_to, "shop/buy-result", %{
              vendor: conn.character.name,
              unavailable: true,
              item_name: info.name,
              buyer_id: Map.get(data, :buyer_id),
              buyer_name: Map.get(data, :buyer_name)
            })

            conn
        end
    end
  end

  defp item_info(item_id) do
    item = Items.get!(item_id)
    meta = item.meta || %{}

    %{
      id: item_id,
      name: item.name,
      unit: Map.get(meta, :unit) || "个",
      value: Map.get(meta, :value) || 0
    }
  rescue
    _ -> nil
  end

  defp reply(reply_to, topic, data) do
    send(
      reply_to,
      %Kalevala.Event{from_pid: self(), topic: topic, data: data}
    )
  end
end

defmodule Kantele.Character.NpcFamilyEvent do
  @moduledoc """
  NPC 侧拜师/叛师应答（A11/N5 门派 v0）

  带 teach 配置（即有门派）的 NPC 应允拜师，把门派名与师父信息
  回给玩家进程存档；无 teach 配置者婉拒。
  叛师请求使用 Master.attempt_detach 判定是否为嫡传弟子。
  """

  use Kalevala.Character.Event

  alias Kantele.Character.Family
  alias Kantele.Npc.Master

  def apprentice(conn, %{data: %{reply_to: reply_to, student_name: student_name}}) do
    teach = conn.character.meta.teach

    case teach && Map.get(teach, :family) do
      nil ->
        send(reply_to, %Kalevala.Event{
          from_pid: self(),
          topic: "family/result",
          data: %{ok: false, reason: "#{conn.character.name}摆了摆手：老朽并无门派，不敢误人子弟。"}
        })

        conn

      family ->
        send(reply_to, %Kalevala.Event{
          from_pid: self(),
          topic: "family/result",
          data: %{
            ok: true,
            family: family,
            master_id: conn.character.id,
            master_name: conn.character.name,
            student_name: student_name,
            teach: teach
          }
        })

        conn
    end
  end

  def detach(conn, %{data: %{reply_to: reply_to, student_family: student_family}}) do
    my_family = conn.character.meta.family

    case Master.attempt_detach(
           conn.character.meta.family,
           student_family,
           Map.get(student_family, :name)
         ) do
      {:noop} ->
        send(reply_to, %Kalevala.Event{
          from_pid: self(),
          topic: "family/detach-result",
          data: %{ok: false, reason: "#{conn.character.name}摆了摆手：你并非我门下弟子，何来叛师之说？"}
        })

        conn

      {:detach, %{penalty?: penalty?}} ->
        send(reply_to, %Kalevala.Event{
          from_pid: self(),
          topic: "family/detach-result",
          data: %{ok: true, penalty?: penalty?, master_name: conn.character.name}
        })

        conn
    end
  end
end

defmodule Kantele.Character.NpcAskEvent do
  @moduledoc """
  NPC 侧问答应答（A10/N4，对应 LPC inquiry）+ 任务交付判定（A11/N6 v0）
  + 任务发布/取消（A11/N6 v1）

  关键词包含匹配 inquiries 表后以 tell 回话；
  若配置了 turn_in 且玩家背包有所需物品，则触发任务完成流程。
  若配置了 quest 且玩家请求任务/取消，则按 Quest.ask_quest/cancel_quest 处理。
  """

  use Kalevala.Character.Event

  alias Kantele.World.Items
  alias Kantele.Quest
  alias Kantele.Npc.Quester

  def call(conn, %{data: %{reply_to: reply_to, asker_id: asker_id} = data}) do
    keyword = Map.get(data, :keyword) || ""

    cond do
      answer = find_answer(conn.character.meta.inquiries || %{}, keyword) ->
        # 一问多态：inquire 值可为文本（直接回话）、脚本化 map（Q6 数据驱动
        # 事件）或 atom（交给各 NPC 专属应答）
        case answer do
          script when is_map(script) -> handle_scripted_answer(conn, Map.merge(data, %{reply_to: reply_to, asker_id: asker_id}), script)
          a when is_atom(a) -> handle_special_answer(conn, data, a)
          text -> publish_tell(conn, asker_id, text)
        end

      turn_in = conn.character.meta.turn_in ->
        # 任务交付引导（A11/N6 v0 + q1-T2）：
        # - 配了交付物（letter 回执/送货）→ quest/turnin-request（玩家侧校验物品并结算）
        # - 未配交付物（师门击杀类，无首级物品）→ quest/report（玩家侧按击杀进度结算）
        send(
          reply_to,
          %Kalevala.Event{
            from_pid: self(),
            topic: turn_topic(turn_in),
            data: %{
              vendor_name: conn.character.name,
              quest: Map.get(turn_in, :quest),
              item_id: Map.get(turn_in, :item),
              prompt: Map.get(turn_in, :prompt),
              rumor: Map.get(turn_in, :rumor),
              rewards: Map.get(turn_in, :rewards)
            }
          }
        )

        conn

      conn.character.meta.quest ->
        # 任务发布/取消（A11/N6 v1）：委托 Quester
        keyword_lower = String.downcase(keyword)

        if String.contains?(keyword_lower, "取消") or String.contains?(keyword_lower, "cancel") do
          handle_cancel_quest(conn, reply_to, asker_id)
        else
          handle_ask_quest(conn, reply_to, asker_id)
        end

      quest = Kantele.World.QuestDaemon.quest_for(conn.character.id) ->
        # 开放任务委员（Q1-T3）：无静态任务配置但挂有 daemon 开放任务的 NPC
        handle_daemon_quest(conn, reply_to, quest)

      true ->
        conn
    end
  end

  # 开放任务分发（Q1-T3）：
  # - deliver/supply：直接走 turnin-request（玩家有货即交付结算，无货则提示引导）
  # - search/explore：登记 todo（ask-result ok），方便玩家追踪
  defp handle_daemon_quest(conn, reply_to, quest)
       when quest.type in ~w(deliver supply) do
    send(
      reply_to,
      %Kalevala.Event{
        from_pid: self(),
        topic: "quest/turnin-request",
        data: %{
          vendor_name: conn.character.name,
          quest: quest.id,
          item_id: quest.item_id,
          prompt: quest.prompt,
          rumor: nil,
          rewards: quest.rewards
        }
      }
    )

    conn
  end

  defp handle_daemon_quest(conn, reply_to, quest)
       when quest.type in ~w(search explore) do
    send(
      reply_to,
      %Kalevala.Event{
        from_pid: self(),
        topic: "quest/ask-result",
        data: %{
          ok: true,
          npc_name: conn.character.name,
          quest: %{
            file: quest.id,
            type: quest.type,
            level: quest.level,
            limit: quest.limit,
            master_name: conn.character.name,
            master_id: conn.character.id
          }
        }
      }
    )

    conn
  end

  defp handle_daemon_quest(conn, _reply_to, _quest), do: conn

  defp handle_ask_quest(conn, reply_to, asker_id) do
    case Quester.ask_quest(conn.character, asker_id) do
      {:ok, quest_spec} ->
        send(reply_to, %Kalevala.Event{
          from_pid: self(),
          topic: "quest/ask-result",
          data: %{ok: true, quest: quest_spec, npc_name: conn.character.name}
        })

      {:error, reason} ->
        send(reply_to, %Kalevala.Event{
          from_pid: self(),
          topic: "quest/ask-result",
          data: %{ok: false, reason: reason, npc_name: conn.character.name}
        })
    end

    conn
  end

  defp handle_cancel_quest(conn, reply_to, asker_id) do
    case Quester.cancel_quest(conn.character, asker_id) do
      {:ok, quest_file} ->
        send(reply_to, %Kalevala.Event{
          from_pid: self(),
          topic: "quest/cancel-result",
          data: %{ok: true, quest: quest_file, npc_name: conn.character.name}
        })

      {:error, reason} ->
        send(reply_to, %Kalevala.Event{
          from_pid: self(),
          topic: "quest/cancel-result",
          data: %{ok: false, reason: reason, npc_name: conn.character.name}
        })
    end

    conn
  end

  # 交付话题选择：配置了交付物走收物结算；item 为空/缺省走无物品结算
  defp turn_topic(turn_in) do
    case Map.get(turn_in, :item) do
      nil -> "quest/report"
      "" -> "quest/report"
      _ -> "quest/turnin-request"
    end
  end

  # 关键词包含匹配：问题里含表中的关键词即命中（LPC add_action/inquiry 风格）
  defp find_answer(inquiries, keyword) when map_size(inquiries) > 0 and keyword != "" do
    Enum.find_value(inquiries, fn {key, value} ->
      if String.contains?(keyword, key), do: value, else: nil
    end)
  end

  defp find_answer(_, _), do: nil

  # atom 问询分发：目前只有子虚道人的宝镜链使用（对应 LPC ask/1 的动作分支）
  defp handle_special_answer(conn, %{asker_id: asker_id} = data, answer) do
    case conn.character.meta.kind do
      "zixu" -> Kantele.World.MirrorDaemon.Zixu.respond_to_ask(conn, data, answer)
      _ -> conn
    end
  end

  # 脚本化问询分发（Q6 数据驱动事件，不写死模块）：
  #   reply       -> 文本回话（默认回话文案）
  #   give        -> npc/give    给物品
  #   learn_skill -> npc/learn   传授技能
  #   family      -> npc/faction 拜入门派（gongxian 一并发放）
  # 各效果以事件送回玩家进程，由玩家侧 NpcScriptEvent 落盘并渲染。
  defp handle_scripted_answer(conn, %{reply_to: reply_to, asker_id: asker_id, keyword: keyword} = data, script) do
    npc_name = conn.character.name

    case Map.get(script, "reply") do
      text when is_binary(text) and text != "" ->
        publish_tell(conn, asker_id, text)

      _ ->
        :ok
    end

    cond do
      item_id = Map.get(script, "give") ->
        send(reply_to, %Kalevala.Event{
          topic: "npc/give",
          data: %{npc_name: npc_name, item_id: item_id, asker_id: asker_id}
        })

        conn

      skill = Map.get(script, "learn_skill") ->
        send(reply_to, %Kalevala.Event{
          topic: "npc/learn",
          data: %{npc_name: npc_name, skill: skill, asker_id: asker_id}
        })

        conn

      family = Map.get(script, "family") ->
        send(reply_to, %Kalevala.Event{
          topic: "npc/faction",
          data: %{
            npc_name: npc_name,
            family: family,
            gongxian: Map.get(script, "gongxian", 0),
            asker_id: asker_id
          }
        })

        conn

      register_item = Map.get(script, "register_summon") ->
        keyword = Map.get(data, "keyword", "")
        send(reply_to, %Kalevala.Event{
          topic: "npc/register_summon",
          data: %{npc_name: npc_name, item_id: register_item, asker_id: asker_id, keyword: keyword}
        })

        conn

      true ->
        conn
    end
  end

  defp publish_tell(conn, asker_id, text) do
    Kalevala.Character.Conn.publish_message(
      conn,
      "characters:#{asker_id}",
      text,
      [],
      &publish_error/2
    )
  end

  defp publish_error(conn, _error), do: conn
end
