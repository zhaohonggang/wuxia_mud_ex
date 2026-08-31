defmodule Kantele.Character.CutEvent do
  @moduledoc """
  解剖结果（玩家侧）：尸体进程 do_cut 完成后把产物实例入包并落盘，
  渲染割取文案；错误 / 部位清单直接展示。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.World.Item
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def result(conn, %{data: %{kind: :grant} = data}) do
    instance = %Item.Instance{
      id: Item.Instance.generate_id(),
      item_id: data.item_id,
      created_at: DateTime.utc_now()
    }

    character = %{conn.character | inventory: [instance | conn.character.inventory]}
    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{
      text: "#{data.scene}\n你拣起一#{data.unit}#{data.part_name}。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  def result(conn, %{data: %{kind: :text, text: text}}) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  def result(conn, _event), do: conn
end

defmodule Kantele.Character.NpcCutEvent do
  @moduledoc """
  尸体侧解剖执行（`feature/cutable.c` do_cut）：

  - 无 `parts` 配置：统一回「看来你是割不下来什么东西了。」
  - `?` 部位：列出可割部位（排除已割 / no_cut）
  - 具体部位：依施术者武器/修为 `Cutable.validate_cut` 校验（已割 / no_cut / 针锤杖棍鞭
    修为门槛 / 空手内力门槛），成功则
    - 追加 `been_cut`（运行态）
    - 割头时清除 `defeated_by`（cut.c head 分支）
    - 产物 item id = 部位 clone 或 default_clone，实例 + 文案回给施术者入包

  文案 $N/$n 由尸体侧按施术者/尸体名替换（对应 LPC message_vision）。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Item.Cutable

  def call(conn, %{data: data}) do
    meta = conn.character.meta

    case meta.parts do
      parts when is_map(parts) ->
        if Map.get(data, :part) == "?" do
          reply_text(data, list_message(conn.character, parts, meta))
          conn
        else
          do_cut(conn, parts, data)
        end

      _ ->
        reply_text(data, "看来你是割不下来什么东西了。\n")
        conn
    end
  end

  # ---- do_cut ----

  defp do_cut(conn, parts, data) do
    meta = conn.character.meta
    part_id = Map.get(data, :part)
    part = Map.get(parts, part_id)

    opts = %{
      part_id: part_id,
      part: part,
      been_cut: meta.been_cut || [],
      no_cut: meta.no_cut || %{},
      weapon_skill_type: Map.get(data, :weapon_skill_type),
      weapon_name: Map.get(data, :weapon_name),
      skill: Map.get(data, :skills) || %{},
      force: Map.get(data, :force) || 0
    }

    case Cutable.validate_cut(part, opts) do
      {:ok, msg} ->
        scene = render_scene(msg, data)
        item_id = clone_id(part, meta)

        character =
          %{
            conn.character
            | meta: %{conn.character.meta | been_cut: (meta.been_cut || []) ++ [part_id]}
          }
          |> clear_defeated_by_if_head(part_id)

        reply_to = Map.get(data, :reply_to)

        send(reply_to, %Event{
          from_pid: self(),
          topic: "cut/result",
          data: %{
            kind: :grant,
            scene: scene,
            item_id: item_id,
            unit: unit_of(part),
            part_name: Cutable.part_name(part)
          }
        })

        put_character(conn, character)

      {:error, text} ->
        reply_text(data, text)
        conn

      {:error_force, _part_name} ->
        reply_text(data, "好好练练内功再来吧。\n")
        conn
    end
  end

  # ---- 部位清单（cutable.c "?" 分支） ----

  defp list_message(character, parts, meta) do
    ids = Cutable.available_parts(parts, meta.been_cut || [], meta.no_cut || %{})

    case ids do
      [] ->
        "#{character.name}已经没什么可以下刀的地方了。\n"

      ids ->
        rows =
          Enum.map_join(ids, "", fn id ->
            name = Cutable.part_name(Map.get(parts, id)) || id
            String.pad_trailing(name, 20) <> "(#{id})\n"
          end)

        "#{character.name}有以下部位可以割下来。\n#{rows}"
    end
  end

  # ---- helpers ----

  defp render_scene(msg, data) do
    msg
    |> String.replace("$N", Map.get(data, :requester_name, "某人"))
    |> String.replace("$n", Map.get(data, :name, "尸体"))
  end

  defp clone_id(part, meta) do
    case Enum.at(part, 7) do
      clone when is_binary(clone) and clone != "" -> clone
      _ -> Map.get(meta, :default_clone)
    end
  end

  defp unit_of(part) do
    case Enum.at(part, 1) do
      unit when is_binary(unit) and unit != "" -> unit
      _ -> "个"
    end
  end

  defp clear_defeated_by_if_head(character, "head") do
    Map.put(character, :meta, Map.put(character.meta, :defeated_by, nil))
  end

  defp clear_defeated_by_if_head(character, _), do: character

  defp reply_text(data, text) do
    send(Map.get(data, :reply_to), %Event{
      from_pid: self(),
      topic: "cut/result",
      data: %{kind: :text, text: text}
    })
  end
end
