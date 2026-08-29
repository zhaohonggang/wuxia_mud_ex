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

    case Master.attempt_detach(conn.character.meta.family, student_family, Map.get(student_family, :name)) do
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

defmodule Kantele.Character.NpcAskEvent do
  @moduledoc """
  NPC 侧问答应答（A10/N4，对应 LPC inquiry）+ 任务交付判定（A11/N6 v0）

  关键词包含匹配 inquiries 表后以 tell 回话；
  若配置了 turn_in 且玩家背包有所需物品，则触发任务完成流程。
  """

  use Kalevala.Character.Event

  alias Kantele.World.Items

  def call(conn, %{data: %{reply_to: reply_to, asker_id: asker_id} = data}) do
    keyword = Map.get(data, :keyword) || ""

    cond do
      answer = find_answer(conn.character.meta.inquiries || %{}, keyword) ->
        publish_tell(conn, asker_id, answer)

      turn_in = conn.character.meta.turn_in ->
        # 任务交付引导（A11/N6 v0）：把交付请求转给玩家侧，由其校验物品并结算
        send(
          reply_to,
          %Kalevala.Event{
            from_pid: self(),
            topic: "quest/turnin-request",
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

      true ->
        conn
    end
  end

  # 关键词包含匹配：问题里含表中的关键词即命中（LPC add_action/inquiry 风格）
  defp find_answer(inquiries, keyword) when map_size(inquiries) > 0 and keyword != "" do
    Enum.find_value(inquiries, fn {key, value} ->
      if String.contains?(keyword, key), do: value, else: nil
    end)
  end

  defp find_answer(_, _), do: nil

  defp publish_tell(conn, asker_id, text) do
    Kalevala.Character.Conn.publish_message(
      conn,
      "characters:#{asker_id}",
      text,
      [],
      &publish_error/2
    )
  end

  def publish_error(conn, _error), do: conn
end
