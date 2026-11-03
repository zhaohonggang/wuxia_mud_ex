defmodule Kantele.Character.SetupController do
  @moduledoc """
  新玩家游戏内注册问答（阎罗殿）状态机（EX-注册与转世迁移计划 Phase 1）。

  流程（对应 LPC `yanluodian.c` 的 `do_wash`/`do_born` + `updated.c` 的 `born_player`）：
    1. 性别（m/f → env.gender）
    2. 洗点 washto：str/int/con/dex 各 10–30、总和=80；per/kar 随机 5–30
    3. 投胎 born：从 6 个出生地取 startroom/born/born_family，世家附 surname
    4. 与生俱来特技（BornPlayer.grant），落盘，转交 CommandController

  仅在 `meta.setup_done == false` 时由 LoginController 接管（见 login_controller.ex）。
  """

  use Kalevala.Character.Controller

  require Logger

  alias Kantele.Character.BornPlayer
  alias Kantele.Character.CommandController
  alias Kantele.Character.MoveView
  alias Kantele.Character.Records
  alias Kantele.Character.SetupView

  # LPC `yanluodian.c:12-39` 的 born 映射（zone:room 等价见 world.ex 注释）
  @birthplaces %{
    "扬州人氏" => %{startroom: "city:kedian", born: "扬州人氏", born_family: "没有", surname: nil},
    "欧阳世家" => %{startroom: "baituo:dating", born: "西域人氏", born_family: "欧阳世家", surname: "欧阳"},
    "关外胡家" => %{startroom: "guanwai:xiaowu", born: "关外人氏", born_family: "关外胡家", surname: "胡"},
    "中原苗家" => %{startroom: "zhongzhou:miaojia_houting", born: "中原人氏", born_family: "中原苗家", surname: "苗"},
    "段氏皇族" => %{startroom: "dali:wangfugate", born: "大理人氏", born_family: "段氏皇族", surname: "段"},
    "慕容世家" => %{startroom: "yanziwu:cuixia", born: "江南人氏", born_family: "慕容世家", surname: "慕容"}
  }

  @doc "按中文出生地取映射规格（测试/复用用）"
  def birthplace(name), do: Map.get(@birthplaces, name)

  @impl true
  def init(conn) do
    conn
    |> put_session(:setup_state, :gender)
    |> render(SetupView, "welcome", %{})
    |> prompt(SetupView, "gender", %{})
  end

  @impl true
  def recv_event(conn, _event), do: conn

  @impl true
  def recv(conn, ""), do: conn

  def recv(conn, data) do
    case get_session(conn, :setup_state) do
      :gender -> handle_gender(conn, data)
      :washto -> handle_washto(conn, data)
      :born -> handle_born(conn, data)
      _ -> handle_gender(conn, data)
    end
  end

  # ---- 问答①：性别 ----
  defp handle_gender(conn, data) do
    case parse_gender(data) do
      nil ->
        prompt(conn, SetupView, "gender", %{})

      gender ->
        conn = put_conn_env(conn, :gender, gender)

        conn
        |> put_session(:setup_state, :washto)
        |> render(SetupView, "washto_intro", %{})
        |> prompt(SetupView, "washto", %{})
    end
  end

  # ---- 问答②：洗点 ----
  defp handle_washto(conn, data) do
    case parse_ints(data) do
      [str, int, con, dex] ->
        validate_washto(conn, str, int, con, dex)

      _other ->
        conn
        |> render(SetupView, "washto_error", %{reason: "格式应为四个整数，如：20 20 20 20"})
        |> prompt(SetupView, "washto", %{})
    end
  end

  defp validate_washto(conn, str, int, con, dex) do
    cond do
      str > 30 ->
        retry_washto(conn, "你所选择的膂力参数不能大于 30。")

      str < 10 ->
        retry_washto(conn, "你所选择的膂力参数不能小于 10。")

      int > 30 ->
        retry_washto(conn, "你所选择的悟性参数不能大于 30。")

      int < 10 ->
        retry_washto(conn, "你所选择的悟性参数不能小于 10。")

      con > 30 ->
        retry_washto(conn, "你所选择的根骨参数不能大于 30。")

      con < 10 ->
        retry_washto(conn, "你所选择的根骨参数不能小于 10。")

      dex > 30 ->
        retry_washto(conn, "你所选择的身法参数不能大于 30。")

      dex < 10 ->
        retry_washto(conn, "你所选择的身法参数不能小于 10。")

      str + int + con + dex != 80 ->
        retry_washto(conn, "你所选择的属性总和必须为 80。")

      true ->
        apply_washto(conn, str, int, con, dex)
    end
  end

  defp retry_washto(conn, reason) do
    conn
    |> render(SetupView, "washto_error", %{reason: reason})
    |> prompt(SetupView, "washto", %{})
  end

  defp apply_washto(conn, str, int, con, dex) do
    per = Enum.random(5..30)
    kar = Enum.random(5..30)

    character =
      conn.character
      |> put_in([Access.key(:meta), Access.key(:stats), Access.key(:str)], str)
      |> put_in([Access.key(:meta), Access.key(:stats), Access.key(:int)], int)
      |> put_in([Access.key(:meta), Access.key(:stats), Access.key(:con)], con)
      |> put_in([Access.key(:meta), Access.key(:stats), Access.key(:dex)], dex)
      |> put_in([Access.key(:meta), Access.key(:stats), Access.key(:per)], per)
      |> put_in([Access.key(:meta), Access.key(:stats), Access.key(:kar)], kar)
      |> put_character_env(:washed, true)

    conn =
      conn
      |> put_character(character)
      |> put_session(:setup_state, :born)
      |> render(SetupView, "washed", %{str: str, int: int, con: con, dex: dex, per: per, kar: kar})
      |> render(SetupView, "born_intro", %{})
      |> prompt(SetupView, "born", %{})

    conn
  end

  # ---- 问答③：投胎 ----
  defp handle_born(conn, data) do
    case parse_birthplace(data) do
      nil ->
        conn
        |> render(SetupView, "born_error", %{reason: "未找到该出生地，请输入如「扬州人氏」的中文地名。"})
        |> prompt(SetupView, "born", %{})

      spec ->
        apply_born(conn, spec)
    end
  end

  defp apply_born(conn, spec) do
    character = conn.character

    character =
      character
      |> put_character_env(:born, spec.born)
      |> put_character_env(:born_family, spec.born_family)
      |> put_character_env(:registered, true)
      |> put_character_env(:startroom, spec.startroom)
      |> put_character_env(:mud_age, 0)
      |> put_character_env(:age, 14)
      |> maybe_put_surname(spec.surname)
      |> Map.put(:room_id, spec.startroom)
      |> put_in([Access.key(:meta), Access.key(:setup_done)], true)

    # 与生俱来特技（LPC born_player；新玩家 character 恒 nil）
    character = BornPlayer.grant(character)

    case Records.save(character) do
      :ok -> :ok
      :error -> Logger.warn("SetupController: failed to save character after born")
    end

    granted_ids = character.attributes |> Map.get("special_skills", %{}) |> Map.keys()

    conn =
      conn
      |> put_character(character)
      |> render(SetupView, "born_done", %{skills: granted_ids})
      |> move(:to, character.room_id, MoveView, "enter", %{})
      |> put_controller(CommandController)
      |> event("room/look", %{})
      |> event("inventory/list", %{})

    conn
  end

  defp maybe_put_surname(character, nil), do: character

  defp maybe_put_surname(character, surname),
    do: put_character_env(character, :surname, surname)

  # ---- 工具函数 ----
  defp put_character_env(character, key, value) do
    env = Map.get(character.meta, :env, %{}) || %{}
    put_in(character.meta.env, Map.put(env, key, value))
  end

  defp put_conn_env(conn, key, value) do
    put_character(conn, put_character_env(conn.character, key, value))
  end

  defp parse_gender(text) do
    case String.trim(text) |> String.downcase() do
      "m" -> "男性"
      "男" -> "男性"
      "male" -> "男性"
      "f" -> "女性"
      "女" -> "女性"
      "female" -> "女性"
      _ -> nil
    end
  end

  defp parse_ints(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(fn tok ->
      case Integer.parse(tok) do
        {n, ""} -> {:ok, n}
        _ -> :error
      end
    end)
    |> Enum.take_while(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, n} -> n end)
  end

  defp parse_birthplace(text) do
    cleaned =
      text
      |> String.trim()
      |> String.split(~r/\s+/)
      |> case do
        [head | rest] when head in ["born", "投胎"] -> rest
        other -> other
      end
      |> Enum.join("")

    Map.get(@birthplaces, cleaned)
  end
end
