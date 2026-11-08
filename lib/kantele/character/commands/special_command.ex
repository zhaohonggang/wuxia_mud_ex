defmodule Kantele.Character.SpecialCommand do
  @moduledoc """
  特技命令：`special [<特技> [参数]]` / `special <玩家ID>`（LPC `cmds/std/special.c`）。

  逐条落地 LPC 分支：

  1. 巫师带参且参数命中在线玩家 → 改为**查看该玩家**的特技清单（LPC
     `wizardp(me) && find_player(arg)`，此时 `arg = 0` 走列表分支）。
  2. `born` / `reborn` 都没有 → `<称呼>还没有出生呐，会什么特技？`
  3. 一个特技都没有 → `<称呼>现在好像什么特技都不会哦。`
  4. 带参且查看自己：busy 门 → 拆出 skill + 参数 → 未拥有 → 注册表无此
     daemon → `SPECIAL_D(skill)->perform(me, skill, arg)`。
  5. 否则列清单：`转世 8 项`（guibian/guimai/jinshen/piyi/qinzong/wuxing/
     shenyan/tiandao）单独归到「 转  世」小节，其余在前。

  ## Ex 映射

  - `query("special_skill")` → `attributes["special_skills"]`（字符串 map，
    `SpecialSkills.owned?/2` 的宿主形状）+ 兼容旧旗标 `special_skill/<id>` +
    `meta.env[:special_skills]`（`BornPlayer.grant/1` 的落盘镜像）。
  - `query("born")/query("reborn")` → `meta.env[:born]` / `env[:reborn].count`
    / `attributes` 同名键 / `stats.reborn`。
  - `is_busy()` → `Combat.busy?/1`；`file_size(SPECIAL_D(skill))` →
    `SpecialSkills.daemon/1`；`name()` / `perform()` →
    `Kantele.Character.SpecialSkill` 适配层。
  - `HIG/YEL` 等色码交给输出管线，这里只留纯文本。LPC 遍历 `keys(mapping)`
    无序，Ex 排序输出以保证可测与稳定。

  ## 测试注入

  - `conn.private[:special_players]`：在线玩家列表，避免启动 `Presence`。
  - `SpecialSkills.register/2` / `unregister/1`：临时注册特技模块
    （记得 `on_exit` 清理，`persistent_term` 是全局的）。

  > 承前 F2 决策原本把本命令锁成占位桩（只写注册表 + 测试注入）。本次
  > B1 真化把它接到 `SpecialSkills` 注册表上；注册表仍从空库起步，所以
  > 没有授予路径时玩家看到的仍是「什么特技都不会」，与 F2 的保守语义一致。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access, as: AdminAccess
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Presence
  alias Kantele.Character.SpecialSkill
  alias Kantele.Character.SpecialSkills

  # LPC special.c 的 `files` 数组：这 8 项归到「转世」小节
  @reborn_skills ~w(guibian guimai jinshen piyi qinzong wuxing shenyan tiandao)

  def run(conn, params) do
    arg =
      params
      |> Map.get("rest", "")
      |> to_string()
      |> String.trim()

    me = conn.character
    {subject, arg} = resolve_subject(conn, me, arg)
    pro = if subject == me, do: "你", else: to_string(Map.get(subject, :name) || "他")

    cond do
      not born?(subject) ->
        reject(conn, "#{pro}还没有出生呐，会什么特技？\n")

      true ->
        owned = owned_skills(subject)

        cond do
          owned == [] ->
            reject(conn, "#{pro}现在好像什么特技都不会哦。\n")

          arg != "" and subject == me ->
            perform_skill(conn, me, owned, arg)

          true ->
            list_skills(conn, pro, owned)
        end
    end
  end

  # ---- 巫师查看他人 ----

  defp resolve_subject(conn, me, arg) do
    if AdminAccess.wizardp(me) and arg != "" do
      case find_player(conn, arg) do
        nil -> {me, arg}
        other -> {other, ""}
      end
    else
      {me, arg}
    end
  end

  defp find_player(conn, key) do
    key = String.downcase(key)

    players =
      case Map.get(conn.private || %{}, :special_players) do
        list when is_list(list) -> list
        _ -> safe_online_players()
      end

    Enum.find(players, fn player ->
      id = player |> Map.get(:id) |> to_string() |> String.downcase()
      name = player |> Map.get(:name) |> to_string() |> String.downcase()
      id == key or name == key
    end)
  end

  defp safe_online_players do
    Presence.characters()
  rescue
    _ -> []
  end

  # ---- 出生 / 转世 门 ----

  defp born?(character) do
    attrs = Map.get(character, :attributes) || %{}
    env = get_in(character, [Access.key(:meta), Access.key(:env)]) || %{}
    stats = get_in(character, [Access.key(:meta), Access.key(:stats)])

    reborn = Map.get(env, :reborn) || Map.get(env, "reborn") || %{}
    stats_reborn = if is_map(stats), do: Map.get(stats, :reborn) || %{}, else: %{}

    truthy = fn value -> not is_nil(value) and value not in [false, 0, "", %{}] end

    Enum.any?([
      truthy.(Map.get(attrs, "born")),
      truthy.(Map.get(attrs, :born)),
      truthy.(Map.get(env, :born)),
      Map.get(env, :registered) == true,
      truthy.(Map.get(attrs, "registered")),
      truthy.(Map.get(attrs, "reborn")),
      truthy.(reborn_count(reborn)),
      truthy.(reborn_count(stats_reborn))
    ])
  end

  defp reborn_count(map) when is_map(map) do
    Map.get(map, :count) || Map.get(map, "count") || 0
  end

  defp reborn_count(_), do: 0

  # ---- 已拥有特技集合 ----

  defp owned_skills(character) do
    attrs = Map.get(character, :attributes) || %{}
    env = get_in(character, [Access.key(:meta), Access.key(:env)]) || %{}

    specials = Map.get(attrs, "special_skills") || Map.get(attrs, :special_skills) || %{}

    from_map =
      if is_map(specials) do
        specials
        |> Enum.filter(fn {_k, v} -> v not in [nil, false, 0] end)
        |> Enum.map(fn {k, _v} -> to_string(k) end)
      else
        []
      end

    from_flags =
      attrs
      |> Enum.filter(fn
        {"special_skill/" <> _id, value} -> value not in [nil, false, 0]
        _ -> false
      end)
      |> Enum.map(fn {"special_skill/" <> id, _value} -> id end)

    from_env =
      case Map.get(env, :special_skills) || Map.get(env, "special_skills") do
        list when is_list(list) -> Enum.map(list, &to_string/1)
        map when is_map(map) -> map |> Map.keys() |> Enum.map(&to_string/1)
        _ -> []
      end

    (from_map ++ from_flags ++ from_env)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  # ---- 运用特技 ----

  defp perform_skill(conn, me, owned, arg) do
    combat = get_in(me, [Access.key(:meta), Access.key(:combat)])

    cond do
      is_map(combat) and Combat.busy?(combat) ->
        reject(conn, "你现在忙着呢，不能使用特技。\n")

      true ->
        {skill, rest} = split_arg(arg)

        cond do
          skill not in owned ->
            reject(conn, "你不会这种特技啊！\n")

          true ->
            case SpecialSkills.daemon(skill) do
              :error ->
                reject(conn, "好像没有这种特技...\n")

              {:ok, module} ->
                case SpecialSkill.perform(module, conn, skill, rest) do
                  :not_handled -> prompt_only(conn)
                  updated -> updated
                end
            end
        end
    end
  end

  defp split_arg(arg) do
    case String.split(arg, ~r/\s+/, parts: 2) do
      [skill] -> {skill, ""}
      [skill, rest] -> {skill, String.trim(rest)}
    end
  end

  # ---- 列清单 ----

  defp list_skills(conn, pro, owned) do
    {reborn, normal} = Enum.split_with(owned, &(&1 in @reborn_skills))

    text =
      "#{pro}现在会以下这些特技：\n" <>
        Enum.map_join(normal, "", &skill_line/1) <>
        if reborn == [] do
          ""
        else
          " 转  世\n" <> Enum.map_join(reborn, "", &skill_line/1)
        end

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp skill_line(skill) do
    module =
      case SpecialSkills.daemon(skill) do
        {:ok, mod} -> mod
        :error -> nil
      end

    "#{SpecialSkill.display_name(module, skill)}(#{skill})\n"
  end

  # ---- 输出 ----

  defp reject(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp prompt_only(conn), do: prompt(conn, CommandView, "prompt", %{})
end
