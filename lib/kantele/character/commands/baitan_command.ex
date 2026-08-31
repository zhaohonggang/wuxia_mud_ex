defmodule Kantele.Character.BaitanCommand do
  @moduledoc """
  摆摊命令：`baitan` / `stock <物品> [价格]` / `unstock <物品>`

  对应 LPC cmds/usr/baitan.c 的移植，使用 Kantele.Economy.Stall 全局 ETS 服务。

  简化版：不检查 is_vendor / shang ling 等 LPC 限制（M1 阶段先跑通核心流程）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Economy.Stall
  alias Kantele.World.Items

  def run(conn, params) do
    rest = String.trim(params["rest"] || "")

    cond do
      rest == "" -> start_baitan(conn)
      String.starts_with?(rest, "stock ") -> stock_item(conn, rest)
      String.starts_with?(rest, "unstock ") -> unstock_item(conn, rest)
      true -> help(conn)
    end
  end

  defp start_baitan(conn) do
    character = conn.character

    if character.meta.stall do
      conn
      |> render(CommandView, "text", %{text: "你已经占了一个摊位，适可而止吧。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      case Stall.start_stall(character, character.room_id) do
        :ok ->
          meta = Map.put(character.meta, :stall, character.name <> "的摊位")
          character = %{character | meta: meta}

          conn
          |> put_character(character)
          |> render(CommandView, "text", %{
            text: "你寻了块空地，一屁股坐了下来，随后掏出一块布摊开在地。\n现在你可以摆上(stock)货物或是收起(unstock)某种货物。\n"
          })
          |> prompt(CommandView, "prompt", %{})

        {:error, :already_stalling} ->
          conn
          |> render(CommandView, "text", %{text: "你已经占了一个摊位。\n"})
          |> prompt(CommandView, "prompt", %{})
      end
    end
  end

  defp stock_item(conn, rest) do
    rest = String.trim(String.trim_leading(rest, "stock "))

    {item_name, price} =
      case String.split(rest, ~r/\s+/, parts: 2) do
        [name, price_str] ->
          case Integer.parse(price_str) do
            {p, _} -> {String.trim(name), p}
            :error -> {String.trim(rest), 100}
          end

        [name] ->
          {String.trim(name), 100}
      end

    character = conn.character

    if is_nil(character.meta.stall) do
      conn
      |> render(CommandView, "text", %{text: "你还没有摆摊，先用 baitan 摆摊。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      item_instance =
        Enum.find(character.inventory, fn inst ->
          instance_item_name(inst) =~ item_name
        end)

      if item_instance do
        case Stall.stock_item(character.id, item_instance, price) do
          :ok ->
            meta =
              Map.update(
                character.meta,
                :shop_stock,
                [
                  %{
                    name: instance_item_name(item_instance),
                    price: price,
                    item_instance_id: item_instance.id
                  }
                ],
                fn stock ->
                  stock ++
                    [
                      %{
                        name: instance_item_name(item_instance),
                        price: price,
                        item_instance_id: item_instance.id
                      }
                    ]
                end
              )

            character = %{character | meta: meta}

            conn
            |> put_character(character)
            |> render(CommandView, "text", %{
              text: "你把#{instance_item_name(item_instance)}摆上了摊位，标价#{price}文。\n"
            })
            |> prompt(CommandView, "prompt", %{})

          {:error, :not_stalling} ->
            conn
            |> render(CommandView, "text", %{text: "你还没有摆摊。\n"})
            |> prompt(CommandView, "prompt", %{})
        end
      else
        conn
        |> render(CommandView, "text", %{text: "你身上没有这个东西。\n"})
        |> prompt(CommandView, "prompt", %{})
      end
    end
  end

  defp unstock_item(conn, rest) do
    item_name = String.trim(String.trim_leading(rest, "unstock "))
    character = conn.character

    if is_nil(character.meta.stall) do
      conn
      |> render(CommandView, "text", %{text: "你还没有摆摊。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      case Stall.unstock_item(character.id, item_name) do
        :ok ->
          updated_stock =
            Enum.reject(character.meta.shop_stock || [], fn item ->
              item.name =~ item_name
            end)

          meta = Map.put(character.meta, :shop_stock, updated_stock)
          character = %{character | meta: meta}

          conn
          |> put_character(character)
          |> render(CommandView, "text", %{text: "你把#{item_name}从摊位上收了起来。\n"})
          |> prompt(CommandView, "prompt", %{})

        {:error, :not_stalling} ->
          conn
          |> render(CommandView, "text", %{text: "你还没有摆摊。\n"})
          |> prompt(CommandView, "prompt", %{})
      end
    end
  end

  defp help(conn) do
    conn
    |> render(CommandView, "text", %{
      text: """
      指令格式：
        baitan           —— 开始摆摊
        stock <物品> [价格] —— 摆上货物（默认价格 100 文）
        unstock <物品>   —— 收起货物
      """
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp instance_item_name(inst) do
    case Items.get(inst.item_id) do
      {:ok, item} -> item.name
      _ -> inst.item_id || "物品"
    end
  end
end
