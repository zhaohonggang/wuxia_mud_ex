defmodule Kantele.NPC.XingXiuAzi do
  @moduledoc """
  阿紫 `accept_kill` 状态机（`kungfu/class/xingxiu/azi.c:91-134`）。

  LPC 的六条分支按原顺序逐条落地：

  1. `!living(this_object())` → `return 1`（放行）。
  2. `!query("swmuding")` → 说「原来在我这里，后来被抢走」、`command("inn <id>")`、
     `tell_object` 楚楚可怜文案 → `return -1`。
  3. 攻击者与 NPC 门派不同 → `return 1`（无文案）。
  4. `children("/clone/misc/swmuding")` 里存在非克隆原型 → 「呜呜，真的被人抢走啦」、
     「神情不象作伪」 → `return -1`。
  5. `combat_exp > 500000 && shen < -10000` → 大叫、`new("/clone/misc/swmuding")`、
     `give` 给攻击者、`set("swmuding", 0)` → `return -1`。
  6. 其余 → 「我说了没有木鼎了，你怎么不信！」→ `return 1`。

  ## ex 的对应物

  * `swmuding` 标记存在 NPC 的 `meta.env["swmuding"]`（UCL `env = [...]` 写入，
    `azi.c:70` 的 `set("swmuding", 1)`）；未配置时按 LPC 初值 1 处理。
  * 分支 4 的全局原型检查走 `Kantele.World.PrototypeObject`，只认 `load_object`
    登记的非克隆原型；分支 5 给出的鼎是克隆，不登记。
  * 分支 5 的 `set("swmuding", 0)` 由 NPC 进程处理
    `xingxiu_azi/revoke-swmuding` 事件落回 `meta.env`；给物品的副作用经
    `npc/give` 投到玩家进程（`Kantele.Character.NpcScriptEvent.give_result/2`）。
  * 文案全部来自 UCL 的 `env["swmuding/…"]` 键，代码里只保留缺省值以保证
    没有 UCL 配置时也不崩；`/` 形态与 loader `parse_env/1` 的 string-key 完全一致。

  `engage_decide/3` 由 `Kantele.Npc.EngageRule.decide/5` 按
  `engage.kill.handler = "Kantele.NPC.XingXiuAzi"` 调用。返回 `{:deny, msg}` 表示
  LPC `return -1`，`:allow` 表示 `return 1`。
  """

  alias Kalevala.Event
  alias Kantele.Character.BeastTaming
  alias Kantele.World.PrototypeObject
  alias Kantele.World.Room

  @defaults %{
    "item" => "clone_lib:swmuding",
    "prototype" => "swmuding",
    "exp_threshold" => 500_000,
    "shen_threshold" => -10_000,
    "msg/stolen" => "神王木鼎原来的确在我这里，可是后来被人抢走啦！",
    # 多行文案用数组逐行存放（UCL 字符串不能含真实换行），lines/1 渲染时以 "\n" 连接。
    "msg/inn_others" => [
      "{npc}大声嚷嚷起来：我是无辜的，冤枉啊冤枉！",
      "{npc}满脸委屈地望着{name}，很无辜的样子。"
    ],
    "msg/inn_target" => "阿紫一副哭丧的脸，真是好委屈啊！",
    "msg/pitiful" => "你看到阿紫一副楚楚可怜的样子，不禁心头一软。",
    "msg/denied" => "呜呜，神王木鼎真的被人抢走啦！",
    "msg/sigh" => "你看阿紫神情不象是作伪，不由得叹了一口气。",
    "msg/shout" => "{npc}大叫：别动手，别动手！我给你木鼎就是！",
    "msg/give_others" => [
      "{npc}拿出神木王鼎给{name}。",
      "{name}接过了{npc}的神木王鼎。"
    ],
    "msg/give_self" => [
      "{npc}拿出神木王鼎给你。",
      "你接过了{npc}的神木王鼎。"
    ],
    "msg/insist" => "我说了没有木鼎了，你怎么不信！"
  }

  @doc "LPC `accept_kill` 的 ex 对应；只处理 `kill`，其余战斗类型放行。"
  def engage_decide(npc, attacker, type) do
    cfg = config(npc)

    cond do
      type != "kill" -> :allow
      not BeastTaming.living?(npc) -> :allow
      not has_swmuding?(npc, cfg) -> branch_stolen(npc, attacker, cfg)
      not same_family?(npc, attacker) -> :allow
      PrototypeObject.loaded?(cfg["prototype"]) -> branch_prototype(npc, attacker, cfg)
      qualifies?(attacker, cfg) -> branch_give(npc, attacker, cfg)
      true -> branch_insist(npc, attacker, cfg)
    end
  end

  @doc "把 NPC `meta.env` 的 `swmuding/*` 配置取出，缺省值即 LPC 原文。"
  def config(npc) do
    env = Map.get(Map.get(npc, :meta, %{}), :env) || %{}

    Map.new(@defaults, fn {key, default} ->
      {key, env_get(env, "swmuding/#{key}", default)}
    end)
  end

  # ---- 六条分支 ----

  # !query("swmuding")：say + inn emote + tell_object，拒绝。
  defp branch_stolen(npc, attacker, cfg) do
    say(npc, cfg["msg/stolen"])
    broadcast(npc, lines(cfg["msg/inn_others"], npc, attacker), [npc.pid, attacker.pid])

    {:deny, lines(cfg["msg/inn_target"], npc) <> lines(cfg["msg/pitiful"], npc)}
  end

  # children("/clone/misc/swmuding") 里有原型对象：say + tell_object，拒绝。
  defp branch_prototype(npc, _attacker, cfg) do
    say(npc, cfg["msg/denied"])
    {:deny, lines(cfg["msg/sigh"], npc)}
  end

  # combat_exp > 500000 && shen < -10000：大叫 + 创建克隆 + give + set("swmuding", 0)。
  # 给物品/改标记由 NPC 进程事件落地；文案在这里直接渲染给攻击者，避免异步重复。
  defp branch_give(npc, attacker, cfg) do
    broadcast(npc, lines(cfg["msg/shout"], npc, attacker), nil)
    broadcast(npc, lines(cfg["msg/give_others"], npc, attacker), [npc.pid, attacker.pid])

    give_text = lines(cfg["msg/give_self"], npc)

    notify(npc, "xingxiu_azi/revoke-swmuding", %{
      asker: attacker,
      item_id: cfg["item"],
      text: ""
    })

    {:deny, give_text}
  end

  # 其余：say 后放行（LPC `return 1` 仍会进入真正战斗）。
  defp branch_insist(npc, _attacker, cfg) do
    say(npc, cfg["msg/insist"])
    :allow
  end

  # ---- 判定 ----

  defp has_swmuding?(npc, _cfg) do
    env = Map.get(Map.get(npc, :meta, %{}), :env) || %{}
    truthy?(env_get(env, "swmuding", 1))
  end

  defp same_family?(npc, attacker) do
    family_name(npc_family(npc)) == family_name(npc_family(attacker))
  end

  # 门派身份：玩家落 `meta.family` map；NPC 没有 `:family` 字段，门派名只在
  # `meta.teach.family`（loader.parse_teach），按 host（sect_master.ex:2215）同源读法。
  defp npc_family(%{meta: %{family: family}}) when is_map(family) and map_size(family) > 0,
    do: family

  defp npc_family(%{meta: %{teach: %{family: name}}}) when is_binary(name), do: %{name: name}

  defp npc_family(%{meta: %{apprentice: %{family: name}}}) when is_binary(name),
    do: %{name: name}

  defp npc_family(_), do: %{}

  defp family_name(%{name: name}) when is_binary(name), do: name
  defp family_name(_), do: nil

  defp qualifies?(attacker, cfg) do
    stats = Map.get(Map.get(attacker, :meta, %{}), :stats) || %{}

    to_number(Map.get(stats, :combat_exp) || Map.get(stats, "combat_exp") || 0) >
      to_number(cfg["exp_threshold"]) and
      to_number(Map.get(stats, :shen) || Map.get(stats, "shen") || 0) <
        to_number(cfg["shen_threshold"])
  end

  # ---- 文案与广播 ----

  # UCL 文案：多行以数组逐行存放（elias 不能含真实换行），单行是字符串。
  # 渲染时统一转成带尾部换行的单条字符串 —— 与 engage_rule.deny_msg 的
  # `msg <> "\n"` 约定一致（room.ex 动态分支直接 render，不自加换行）。
  #
  # 三种变体：
  #   lines/1               纯文本，不替换占位符
  #   lines/2  (npc)        自我视角：{npc}→阿紫，{name}→你
  #   lines/3  (npc,attk)   旁观视角：{npc}→阿紫，{name}→攻击者姓名
  defp lines(text) when is_list(text), do: Enum.map_join(text, "\n", &to_string/1) <> "\n"
  defp lines(text) when is_binary(text), do: text <> "\n"
  defp lines(nil), do: ""
  defp lines(other), do: to_string(other) <> "\n"

  defp lines(text, npc, attacker) when is_list(text) do
    Enum.map_join(text, "\n", &decorate(&1, npc, attacker)) <> "\n"
  end

  defp lines(text, npc, attacker), do: decorate(text, npc, attacker) <> "\n"

  defp lines(text, npc) when is_list(text) do
    Enum.map_join(text, "\n", &decorate_self(&1, npc)) <> "\n"
  end

  defp lines(text, npc), do: decorate_self(text, npc) <> "\n"

  # `command("say …")`：以 NPC 名义向房间广播。
  defp say(npc, text) when is_binary(text) and byte_size(text) > 0 do
    broadcast(npc, "#{Map.get(npc, :name, "阿紫")}说道：#{text}\n", nil)
  end

  defp say(_npc, _text), do: :ok

  defp broadcast(npc, text, except) when is_binary(text) and byte_size(text) > 0 do
    case Map.get(npc, :room_id) do
      room_id when is_binary(room_id) and byte_size(room_id) > 0 ->
        Room.tell_room(%Room{id: room_id}, text, except || [])

      _ ->
        # 没有房间（纯函数单测）时退化为只通知攻击者，保留可见文案。
        if is_pid(Map.get(npc, :pid)) and is_nil(except) do
          send(Map.get(npc, :pid), {:room_message, text})
        end

        :ok
    end
  rescue
    _ -> :ok
  end

  defp broadcast(_npc, _text, _except), do: :ok

  defp notify(%{pid: pid}, topic, data) when is_pid(pid) do
    send(pid, %Event{from_pid: self(), topic: topic, data: data})
  end

  defp notify(_, _topic, _data), do: :ok

  defp decorate(text, npc, attacker) when is_binary(text) do
    text
    |> String.replace("{npc}", to_string(Map.get(npc, :name, "阿紫")))
    |> String.replace(
      "{name}",
      to_string(Map.get(attacker, :name, Map.get(attacker, :id, "玩家")))
    )
  end

  defp decorate(text, _npc, _attacker), do: to_string(text || "")

  defp decorate_self(text, npc) when is_binary(text) do
    text
    |> String.replace("{npc}", to_string(Map.get(npc, :name, "阿紫")))
    |> String.replace("{name}", "你")
  end

  defp decorate_self(text, _npc), do: to_string(text || "")

  # ---- 小工具 ----

  defp env_get(env, key, default) do
    case Map.get(env, key) || Map.get(env, String.to_atom(key)) do
      nil -> default
      value -> value
    end
  end

  defp to_number(value) when is_integer(value), do: value
  defp to_number(value) when is_float(value), do: value

  defp to_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp to_number(_), do: 0

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(0), do: false
  defp truthy?("0"), do: false
  defp truthy?("false"), do: false
  defp truthy?(_), do: true
end
