defmodule Kantele.World.InquiryHandlers.MeizhuangRiyue do
  @moduledoc """
  梅庄「日月神教访客」直授技能（`kind = "meizhuang_riyue"`，Task #869）。

  对应 `kungfu/class/meizhuang/{danqing,heibai,huang,tubi}.c` 的
  `ask_riyue()`：只有 `family/family_name == "日月神教"` 的访客能学到本庄
  一门基础技能（丁坚没有该分支，故只覆盖 4 名庄主）。

  LPC 行为逐条落地：

  1. 非日月神教 → `say 本庄只接待神教人士！`（`family_deny`）；
  2. 已有 `can_learn/meizhuang` → `say 你不是已经会了吗？还来找我干什么！`（`maxed`）；
  3. `say 恩，那好吧，我就教你<技能>。`，`set_skill(<技能>, 10)`，
     `set("can_learn/meizhuang", 1)`，`tell_object` 习得文案，`say 下去好好练习吧。`；
  4. 额外分支：玩家 `gongxian > 10000` **且** 钱庄存款（LPC `balance`）
     `> 100000000`（严格大于）→ 再扣 `10000` 贡献与 `100000000` 银两，
     并把本庄对应绝招直接置为已会（见 UCL `unlock_performs`）。

  UCL 配置（`inquiries` 的 map 值）：

      value = {
        kind = "meizhuang_riyue"
        skill = "pomopima-jian"        # 直授技能
        family = "日月神教"            # 访客门派要求
        granted_level = 10             # 缺省 10
        learn_mark = "can_learn/meizhuang"
        unlock_performs = [ "pomopima-jian/zui" ]   # 高贡献+高存款时解锁
        min_gongxian = 10000           # 严格 >，不是 >=
        cost_gongxian = 10000
        min_bank_coins = 10000000000   # LPC balance 100000000 银 × 100 铜
        cost_bank_coins = 10000000000
        family_deny = "本庄只接待神教人士！"
        maxed = "你不是已经会了吗？还来找我干什么！"
        say_teach = "恩，那好吧，我就教你泼墨披麻剑。"
        say_close = "下去好好练习吧。"
        learned = "你学会了泼墨披麻剑！"
      }
  """

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  alias Kantele.Character, as: PlayerMeta
  alias Kantele.Character.CommandView
  alias Kantele.Character.Family
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.SectMaster
  alias Kantele.World.NpcActions.Helpers

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "skill")) -> conn
      Map.get(data, :asker_id) != character.id -> conn
      true -> run_for(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, character, config, data) do
    stats = stats_with_family_and_marks(character)

    case SectMaster.riyue_grant(stats, config) do
      {:error, msg} ->
        reply(conn, msg)

      {:ok, skill, level} ->
        teach(conn, character, config, data, skill, level)
    end
  end

  defp teach(conn, character, config, data, skill, level) do
    meta = character.meta
    bonus? = bonus_eligible?(config, meta.stats, character)

    stats = Stats.set_skill(meta.stats, skill, level)

    stats =
      if bonus? do
        stats
        |> apply_unlocks(config)
        |> deduct_gongxian(Map.get(config, "cost_gongxian"))
      else
        stats
      end

    meta = %{meta | stats: stats}

    meta =
      if bonus? do
        cost = Map.get(config, "cost_bank_coins") || 0
        PlayerMeta.put_bank_coins(meta, max(PlayerMeta.bank_coins(meta) - cost, 0))
      else
        meta
      end

    meta = PlayerMeta.put_mark(meta, Map.get(config, "learn_mark") || "can_learn/meizhuang", 1)
    character = %{character | meta: meta}
    Records.save(character)

    conn = put_character(conn, character)
    conn = say(conn, data, Map.get(config, "say_teach"))

    conn =
      conn
      |> render(CommandView, "text", %{
        text: Map.get(config, "learned") || "你学会了「#{skill}」！\n"
      })
      |> prompt(CommandView, "prompt", %{})

    say(conn, data, Map.get(config, "say_close"))
  end

  # 高贡献 + 高存款：额外解锁本庄绝招（LPC ask_riyue 末尾的 if 分支）。
  defp apply_unlocks(stats, config) do
    case Map.get(config, "unlock_performs") do
      performs when is_list(performs) ->
        Enum.reduce(performs, stats, fn perform, acc ->
          if is_binary(perform) and byte_size(perform) > 0 do
            Stats.learn_perform(acc, perform)
          else
            acc
          end
        end)

      _ ->
        stats
    end
  end

  # LPC `gongxian > 10000 && balance > 100000000`（严格大于，不是 >=）。
  defp bonus_eligible?(config, stats, character) do
    min_gongxian = Map.get(config, "min_gongxian") || 0
    min_bank = Map.get(config, "min_bank_coins") || 0

    (Map.get(stats || %{}, :gongxian) || 0) > min_gongxian and
      PlayerMeta.bank_coins(character.meta) > min_bank
  end

  defp deduct_gongxian(%Stats{} = stats, cost) when is_integer(cost) and cost > 0 do
    %{stats | gongxian: max((stats.gongxian || 0) - cost, 0)}
  end

  defp deduct_gongxian(stats, _cost), do: stats

  # ---- 消息 / stats 归一 ----

  defp say(conn, %{npc_room_id: room_id, npc_name: npc_name}, text)
       when is_binary(room_id) and is_binary(text) and byte_size(text) > 0 do
    Helpers.say(conn, room_id, npc_name || "对方", text)
  end

  defp say(conn, _data, _text), do: conn

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp stats_with_family_and_marks(character) do
    base =
      case character.meta.stats do
        %Stats{} = stats -> Map.from_struct(stats)
        stats when is_map(stats) -> stats
        _ -> %{}
      end

    base
    |> put_family(character)
    |> Map.put(:marks, character.meta.marks || %{})
  end

  defp put_family(stats, character) do
    case character.meta.family do
      family when is_map(family) and map_size(family) > 0 ->
        Map.put(stats, :family, Family.name(family))

      _ ->
        stats
    end
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
