defmodule Kantele.Character.ForgeCustomizeCommand do
  @moduledoc """
  锻造定制：`name <中文名> <英文代号>` / `desc <文字>` / `wieldmsg <文字>` /
  `unwieldmsg <文字>` / `finish` / `完成`

  对应 LPC ganjiang.c 的定制环节。玩家在干将锻造会话 status="inputing" 时，
  为待生成武器设定名称、描述、装备/收起文案，最后 `finish` 生成动态
  物品模板并入包。

  门控：
    - 会话存在且 status == "inputing"
  finish 额外门控：
    - session.name 已设（必须先起名）

  生成物品（§1.5）：
    - item_id = "forge:<owner_id>-<sid>"
    - 经 Kantele.World.Items.put 注册到 ETS，并落盘 data/forge/<item_id>.json
    - 实例化入玩家背包，清会话
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kalevala.World.Item, as: ItemDef
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.Records
  alias Kantele.World.Forging
  alias Kantele.World.Items
  alias Kantele.World.Item
  alias Kantele.World.Item.Meta

  @forge_dir "data/forge"

  # ---- 入口：各子动词独立处理函数 ----

  def run_name(conn, %{"rest" => rest}) do
    with_session(conn, fn conn, character, session ->
      handle_name(conn, character, session, rest)
    end)
  end

  def run_desc(conn, %{"rest" => rest}) do
    with_session(conn, fn conn, character, session ->
      handle_desc(conn, character, session, rest)
    end)
  end

  def run_wieldmsg(conn, %{"rest" => rest}) do
    with_session(conn, fn conn, character, session ->
      handle_wieldmsg(conn, character, session, rest)
    end)
  end

  def run_unwieldmsg(conn, %{"rest" => rest}) do
    with_session(conn, fn conn, character, session ->
      handle_unwieldmsg(conn, character, session, rest)
    end)
  end

  def run_finish(conn, %{}) do
    with_session(conn, fn conn, character, session ->
      if is_nil(session.name) do
        fail(conn, "尚未起名，请先 `name <中文名> <英文代号>`。\n")
      else
        handle_finish(conn, character, session)
      end
    end)
  end

  # ---- 会话门控 ----

  defp with_session(conn, fun) do
    character = conn.character
    session = Forging.get(character.id)

    cond do
      is_nil(session) ->
        fail(conn, "你当前没有进行中的锻造会话。\n")

      session.status != "inputing" ->
        fail(conn, "炉火尚未备好，暂时无法定制。\n")

      true ->
        fun.(conn, character, session)
    end
  end

  # ---- name <中文名> <英文代号> ----

  defp handle_name(conn, character, session, rest) do
    case parse_name(rest) do
      {:ok, chinese_name, sid} ->
        item_id = "forge:#{character.id}-#{sid}"

        cond do
          Items.get(item_id) != {:error, :not_found} ->
            fail(conn, "代号 #{sid} 已被占用，请换一个。\n")

          true ->
            new_session = Map.put(Map.put(session, :name, chinese_name), :sid, sid)
            Forging.put(character.id, new_session)

            conn
            |> render(CommandView, "text", %{
              text: "已记下武器名称：#{chinese_name}（代号 #{sid}）。\n"
            })
            |> prompt(CommandView, "prompt", %{})
        end

      {:error, reason} ->
        fail(conn, reason)
    end
  end

  defp parse_name(rest) do
    parts = String.split(rest, " ", parts: 2)

    case parts do
      [chinese_name, sid] ->
        chinese_name = String.trim(chinese_name)
        sid = String.trim(sid)

        cond do
          chinese_name == "" or sid == "" ->
            {:error, "格式：name <中文名> <英文代号>\n"}

          byte_size(chinese_name) < 2 or byte_size(chinese_name) > 20 ->
            {:error, "中文名长度需在 2~20 字节之间。\n"}

          byte_size(sid) < 2 or byte_size(sid) > 20 ->
            {:error, "英文代号长度需在 2~20 字节之间。\n"}

          not Regex.match?(~r/^[a-zA-Z0-9_]+$/, sid) ->
            {:error, "英文代号只能用字母、数字和下划线。\n"}

          true ->
            {:ok, chinese_name, sid}
        end

      _ ->
        {:error, "格式：name <中文名> <英文代号>\n"}
    end
  end

  # ---- desc <文字> ----

  defp handle_desc(conn, character, session, rest) do
    desc = String.trim(rest)

    cond do
      desc == "" ->
        fail(conn, "请输入描述文案：desc <文字>\n")

      byte_size(desc) > 200 ->
        fail(conn, "描述过长，请控制在 200 字节以内。\n")

      true ->
        new_session = Map.put(session, :long, desc)
        Forging.put(character.id, new_session)

        conn
        |> render(CommandView, "text", %{text: "已记下武器描述。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # ---- wieldmsg <文字> ----

  defp handle_wieldmsg(conn, character, session, rest) do
    msg = String.trim(rest)

    cond do
      msg == "" ->
        fail(conn, "请输入装备文案：wieldmsg <文字>\n")

      true ->
        new_session = Map.put(session, :wield_msg, msg)
        Forging.put(character.id, new_session)

        conn
        |> render(CommandView, "text", %{text: "已记下装备文案。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # ---- unwieldmsg <文字> ----

  defp handle_unwieldmsg(conn, character, session, rest) do
    msg = String.trim(rest)

    cond do
      msg == "" ->
        fail(conn, "请输入收起文案：unwieldmsg <文字>\n")

      true ->
        new_session = Map.put(session, :unwield_msg, msg)
        Forging.put(character.id, new_session)

        conn
        |> render(CommandView, "text", %{text: "已记下收起文案。\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  # ---- finish / 完成：生成物品 ----

  defp handle_finish(conn, character, session) do
    owner_id = character.id
    sid = session.sid
    item_id = "forge:#{owner_id}-#{sid}"

    material = Items.get!(session.material_item_id)
    entry = Forging.type_entry(session.ctype)

    weight = div((material.meta.weight || 150) * (session.wscale || 150), 100)

    material_name = material.meta.material_name || material.name
    default_desc = "这是由#{material_name}炼制而成的#{session.name}。"

    wield_msg = Map.get(session, :wield_msg) || "你装备上了#{session.name}。"
    unwield_msg = Map.get(session, :unwield_msg) || "你收起了#{session.name}。"

    template =
      %ItemDef{
        id: item_id,
        name: session.name,
        description: Map.get(session, :long) || default_desc,
        callback_module: Item,
        meta: %Meta{
          skill_type: entry.stype,
          unit: entry.unit,
          weight: weight,
          material: material.meta.material_attrib,
          material_name: material_name,
          damage: (if entry.type == "weapon", do: session.point, else: nil),
          armor: (if entry.type == "armor", do: session.point, else: nil),
          value: session.value,
          item_make: true,
          owner: session.owner_name,
          owner_id: owner_id,
          messages: %{wield: wield_msg, unwield: unwield_msg}
        },
        verbs: []
      }

    # 1. 注册到 ETS（动态模板，重启前有效）
    Items.put(item_id, template)

    # 2. 落盘 JSON（重启恢复）
    File.mkdir_p(@forge_dir)
    path = Path.join(@forge_dir, "#{item_id}.json")
    File.write!(path, Jason.encode!(template))

    # 3. 实例化入玩家背包
    instance =
      %Instance{
        id: Instance.generate_id(),
        item_id: item_id,
        created_at: DateTime.utc_now()
      }

    new_character = %{character | inventory: [instance | character.inventory]}
    Records.save(new_character)

    # 4. 清会话
    Forging.delete(owner_id)

    conn
    |> put_character(new_character)
    |> render(CommandView, "text", %{
      text:
        "干将将#{session.name}交给了你。\n" <>
        "锻造完成，自定义武器已入包。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
