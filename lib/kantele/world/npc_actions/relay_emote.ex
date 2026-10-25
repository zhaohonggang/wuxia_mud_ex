defmodule Kantele.World.NpcActions.RelayEmote do
  @moduledoc """
  P5-8 #8 后半：NPC `relay_emote` 表情回应子系统（数据驱动，按 NPC 名分派）。

  LPC 源：`d/city/npc/tao1.c`–`tao6.c`、`d/huashan/npc/lao-denuo.c` 的
  `void relay_emote(object ob, string verb)`。玩家对 NPC 做出社交动词
  （kick/hug/kiss/mo/18mo/nocloth/beg）时，NPC 给出回应。

  ## 触发

  本模块**不是** `NpcAction`（`relay_emote` 不是 `add_action` 动词，而是社交
  命令层在「动词指向某 NPC」时调用）。触发由 `Kantele.World.RelayEmoteDispatcher`
  负责：取出动词 + 目标 NPC，若目标 NPC 在 `config/1` 中有登记则调用 `run/3`。

  ## 分派键

  LPC `relay_emote` 是按 NPC 对象挂的方法，端口用 **NPC 名** 作稳定键
  （`loader` 给房间 NPC 重新生成 `id`，不能靠 `id`；NPC 名在 UCL 里固定且世界内
  唯一）。配置表见 `config/1`：
  - 桃根仙 → `:tao1`（kick 三分支与 tao2–6 不同）
  - 桃干仙/桃枝仙/桃叶仙/桃花仙/桃实仙 → `:tao`
  - 劳德诺 → `:lao_denuo`

  ## 与 LPC 的差异 / 简化

  - LPC `command("say"/"chat"/"kick"/"giggle"/...)`：NPC「说话」用
    `Helpers.say`（NPC 名广播），NPC「动作」用 `Helpers.broadcast` 的 vision
    （玩家处 `{npc}` 渲染为「你」）。`chat` 与 `say` 在此统一为广播说话。
  - LPC `RANK_D->query_rude(ob)`：尊称/贬称系统未建模，统一用「这家伙」。
  - LPC `drool()` + `memory` 记忆机制：需按 NPC 持久记忆，未建模；
    default 分支的 `drool` 简化为固定兜底台词。
  - 随机性用 `:rand.uniform/1` 保留 LPC 的 `random(N)` 概率语义。
  """
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.NpcActions.Helpers

  @doc "NPC 名 → 配置分组（atom）；非登记 NPC 返回 nil。"
  def config(npc_name) when is_binary(npc_name) do
    case npc_name do
      "桃根仙" -> :tao1
      "桃干仙" -> :tao
      "桃枝仙" -> :tao
      "桃叶仙" -> :tao
      "桃花仙" -> :tao
      "桃实仙" -> :tao
      "劳德诺" -> :lao_denuo
      _ -> nil
    end
  end

  def config(_), do: nil

  @doc """
  触发入口：NPC 对玩家社交动词的回应。

  `npc` 为目标 NPC 角色结构体（需含 `name`），`verb` 为社交动词。
  返回更新后的 `conn`（NPC 的说话/动作 vision 已写入 `conn` 的 `channel_changes`；
  lao_denuo 在玩家为华山剑宗时会写 `meta.temp["beg_huashan"] = 1`）。
  """
  def run(conn, %{name: npc_name} = _npc, verb) when is_binary(verb) do
    case config(npc_name) do
      nil -> conn
      group -> do_relay(conn, npc_name, verb, group)
    end
  end

  def run(conn, _npc, _verb), do: conn

  # ---- 分派 ----

  defp do_relay(conn, npc_name, verb, group) when group in [:tao1, :tao] do
    actor = current(conn)
    actor_name = actor.name
    room_id = actor.room_id
    gender = actor_gender(actor)
    tao1? = group == :tao1

    case verb do
      "kick" ->
        tao_kick(conn, npc_name, room_id, tao1?, gender)

      v when v in ["hug", "kiss", "mo", "18mo", "nocloth"] ->
        conn
        |> tao_hug_branch(npc_name, actor_name, room_id, gender)
        |> tao_default(npc_name, actor_name, room_id, v)

      _ ->
        tao_default(conn, npc_name, actor_name, room_id, verb)
    end
  end

  defp do_relay(conn, npc_name, verb, :lao_denuo) do
    relay_lao_denuo(conn, npc_name, verb)
  end

  # ---- 桃谷六仙（tao1 与 tao2–6 仅 kick 分支不同）----

  # tao1 kick：三分支（每支都 break，不与 default 串接）
  defp tao_kick(conn, npc_name, room_id, true, _gender) do
    roll = :rand.uniform(10)

    cond do
      roll < 5 ->
        conn
        |> broadcast(room_id, "#{npc_name}对着{npc}一口咬了下去！")
        |> say(npc_name, room_id, "我操！你皮痒啊？")

      roll < 10 ->
        conn
        |> broadcast(room_id, "#{npc_name}挥拳打向半空，作势要揍{npc}！")
        |> say(npc_name, room_id, "他奶奶的！找死啊？")

      true ->
        conn
        |> broadcast(room_id, "#{npc_name}对着{npc}狠狠踢了三脚！")
        |> say(npc_name, room_id, "奶奶的，这样够爽么？")
    end
  end

  # tao2–6 kick：random<5 说「为什麽踢我」并 break；否则落入 hug/default 串接
  defp tao_kick(conn, npc_name, room_id, false, gender) do
    if :rand.uniform(10) < 5 do
      say(conn, npc_name, room_id, "为什麽踢我？会痛耶！")
    else
      actor_name = current(conn).name

      conn
      |> tao_hug_branch(npc_name, actor_name, room_id, gender)
      |> tao_default(npc_name, actor_name, room_id, "kick")
    end
  end

  # hug/kiss/mo/18mo/nocloth 公共分支（无 break，之后会串接 default）
  defp tao_hug_branch(conn, npc_name, actor_name, room_id, gender) do
    conn =
      if gender in ["男性", "无性"] do
        conn
        |> say(npc_name, room_id, "这算啥，#{actor_name}！我就喜欢这个调调儿！")
        |> say(npc_name, room_id, "谁想得到这家伙，竟然有龙阳之好。")
      else
        conn
        |> broadcast(room_id, "#{npc_name}咯咯一笑。")
        |> say(npc_name, room_id, "想不到#{actor_name}自动把豆腐送上门来了。再开心没有了！")
      end

    broadcast(conn, room_id, "#{npc_name}摇了摇头，对{npc}幽幽叹道：唉，你这又是何苦呢？")
  end

  # default 分支：random<5 NPC 用同动词回敬玩家；否则 drool 兜底
  defp tao_default(conn, npc_name, _actor_name, room_id, verb) do
    if :rand.uniform(10) < 5 do
      broadcast(conn, room_id, "#{npc_name}对着{npc}#{verb_action(verb)}了一下。")
    else
      say(conn, npc_name, room_id, "（冲着{npc}直咽口水，不知在想些什么。）")
    end
  end

  defp verb_action(verb) do
    case verb do
      "kick" -> "踢"
      "hug" -> "抱"
      "kiss" -> "亲"
      "mo" -> "摸"
      "18mo" -> "动手动脚"
      "nocloth" -> "上下其手"
      "beg" -> "乞讨"
      v -> v
    end
  end

  # ---- 劳德诺 ----

  defp relay_lao_denuo(conn, npc_name, verb) do
    actor = current(conn)
    room_id = actor.room_id

    if verb != "beg" do
      lao_nonbeg(conn, npc_name, room_id, :rand.uniform(5) - 1)
    else
      if Helpers.family_name(actor) == "华山剑宗" do
        conn
        |> broadcast(room_id, "#{npc_name}叹了口气。")
        |> say(npc_name, room_id, "这位#{Helpers.respect(actor)}！入了剑宗，后悔了吧？不要紧，回头是岸嘛！")
        |> Helpers.put_temp("beg_huashan", 1)
      else
        broadcast(conn, room_id, "#{npc_name}冲着{npc}装出一副可怜相。")
      end
    end
  end

  defp lao_nonbeg(conn, npc_name, room_id, roll) do
    text =
      case roll do
        0 -> "#{npc_name}一副百无聊赖的样子。"
        1 -> "#{npc_name}打了个哈欠。"
        2 -> "#{npc_name}发出一声怪叫。"
        3 -> "#{npc_name}打了个冷战。"
        _ -> "#{npc_name}嘿嘿一笑。"
      end

    broadcast(conn, room_id, text)
  end

  # ---- helpers ----

  defp broadcast(conn, room_id, text), do: Helpers.broadcast(conn, room_id, text)
  defp say(conn, npc_name, room_id, text), do: Helpers.say(conn, room_id, npc_name, text)

  defp current(%{private: %{update_character: character}}) when not is_nil(character), do: character
  defp current(%{character: character}), do: character

  defp actor_gender(%{meta: meta}) when is_map(meta) do
    env = meta.env || %{}

    case Map.get(env, "gender") do
      g when is_binary(g) and g != "" -> g
      _ -> stats_gender(meta.stats)
    end
  end

  defp actor_gender(_), do: nil

  defp stats_gender(%{gender: g}) when is_binary(g) and g != "", do: g
  defp stats_gender(_), do: nil
end
