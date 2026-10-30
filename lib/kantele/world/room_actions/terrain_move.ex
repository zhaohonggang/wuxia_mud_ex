defmodule Kantele.World.RoomActions.TerrainMove do
  @moduledoc """
  地形穿越类 `do_*` 的数据驱动 handler（P5-4aq-A）。

  覆盖一批「攀爬 / 跳跃 / 渡水 / 穿潭」类房间动作，形状高度一致：

      校验参数 →（可选）忙乱/战斗守卫 →（可选）内力(qi)/轻功(dodge)门控
      → 房间广播 + 玩家私发 + 瞬移 +（可选）昏厥

  与 `VisionMove` 同源思路：重复形状走 `@terrain` 数据表，独有逻辑才写专用模块。
  本批 11 个房间的 12 个 verb handler 共享同一张表，差异只在参数名 / 门控阈值 /
  三段文案 / 目标房间 / 是否排除行动者 / 是否昏厥。

  ## 本批范围

  同步执行的 11 间房：hengyang 的 outzhushendong / outzigai / shuiliandong /
  xuanyadi，jueqing 的 eyutan1 / eyutan2 / eyutan3 / ontree1 / ontree3 / undertan /
  underya2。

  另有 4 间需引擎级延迟回调 / 发物、暂未移植（P5-4aq-B 待办）：
  jueqing:duanchang（两步确认 + `call_out`）、jueqing:underya（do_jump 含
  `call_out(out_water, 6, me)`）、jueqing:xiangfang1（do_jump 含 `call_out`）、
  jueqing:jianshi（do_pick 克隆君子剑/淑女剑）。jueqing:zhifang 的 do_open 在
  LPC 源里被整段注释掉（死代码），不移植。

  ## 表结构

      {{room_id, canonical_verb}, %{
        args:      可触发参数（字符串列表；`nil`=任意；`:none`=必须为空），
                   不在其中的参数 → 走 `otherwise`。
        otherwise: 参数不符时（`{:write, text}` 私发提示；`:not_handled` 放行）。
        guard:     `:busy_fighting` 时先查 is_busy/is_fighting，命中即私发对应文案并放弃。
        branches:  有序分支列表，按 `:"when"` 顺序取第一个命中者，每项 `%{:"when" => cond,
                   :path => path()}`：
                      :always
                      [%{arg, "teng"}]
                      [%{qi, :<, 100}]
                      [%{dodge, :>, 120, :effective}]
                    （`cond` 为 `:always` 或条件列表；列表须全部满足）
      }}

  `canonical_verb` 是玩家动词的归一化结果：`pa`→`climb`、`tiao`→`jump`、`you`→`swim`
  （LPC 同一 `do_*` 常挂多个同义动词，归一后一张表项即可覆盖全部别名）。

  ## path 结构

      %{
        before:       旧房间(message_vision / tell_room 含行动者) 广播文案；`nil`=不广播
        before_excl:  true → before 广播排除行动者（对应 LPC `tell_room(..., me)`）
        after:        目标房间到达广播文案；`nil`=不广播
        after_excl:   true → after 广播排除行动者
        player_msg:   仅发给行动者本人的文案（LPC `write` / `tell_object`）
        target:       瞬移目标房间 id；`nil`=不移动
        unconcious:   true → 末尾 `me->unconcious()`（LPC 体力不支/摔落）
      }
  """
  use Kantele.World.RoomAction

  alias Kalevala.Character.Conn
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.Helpers

  # LPC `is_busy()` / `is_fighting()` 守卫文案（eyutan*/ontree*/undertan/underya2 完全一致）
  @busy_msg "你现在正忙着呢！\n"
  @fighting_msg "你还是先把你面前这个家伙解决了再说。\n"

  # 同义动词归一：LPC `add_action("do_climb", ({"climb","pa"}))` 一类。
  @verb_alias %{"pa" => "climb", "tiao" => "jump", "you" => "swim"}

  # ---- 各房间 spec（先于 @terrain 定义，便于多动词别名共享同一份）----

  @outzhushendong_climb %{
    args: ["teng"],
    otherwise: {:write, "你想往哪儿爬？\n"},
    branches: [
      %{
        :"when" => [{:qi, :<, 100}],
        :path => %{
          before: "\n$N拉着树藤往峭壁上爬去。\n$N体力不知，从峭壁上摔了下来。\n",
          unconcious: true
        }
      },
      %{
        :"when" => :always,
        :path => %{
          before: "\n$N拉着树藤往峭壁上爬去。\n",
          after: "\n$N从峭壁下面爬了上来。\n",
          after_excl: true,
          target: "hengyang:shilinfeng"
        }
      }
    ]
  }

  @outzigai_climb %{
    args: ["stone"],
    otherwise: {:write, "你要往哪儿爬？\n"},
    branches: [
      %{
        :"when" => :always,
        :path => %{
          player_msg:
            "\n你走到洞壁旁，手拉上面突石，脚踩下面突石，不一会而便到了高处。\n\n",
          target: "hengyang:outzigai1"
        }
      }
    ]
  }

  @outzigai_tiao %{
    args: ["stone"],
    otherwise: {:write, "你要往哪儿跳？\n"},
    branches: [
      %{
        :"when" => :always,
        :path => %{
          before:
            "\n$N纵身往突石上一跳，不料上面却长满了青苔，$N一个不留神摔了下来，顿时晕了过去。\n\n",
          unconcious: true
        }
      }
    ]
  }

  # 突石上 `do_tiao`：只能 `tiao down` 往下跳。轻功 <120 摔下去昏倒，否则稳稳落地。
  # 这间房的 `down` 出口被 `valid_leave` 拦住（「这里又没有路，看来只有跳下去了」），
  # 所以缺这个 handler 玩家会被**困在突石上**出不来。
  @outzigai1_tiao %{
    args: ["down"],
    otherwise: {:write, "你要往哪儿跳？\n"},
    branches: [
      %{
        :"when" => [{:dodge, :<, 120, :raw}],
        :path => %{
          before: "\n$N鼓起勇气纵身往下一跳...\n",
          target: "hengyang:outzigai",
          after: "$N从上面摔了下来，昏倒了。\n",
          unconcious: true
        }
      },
      %{
        :"when" => :always,
        :path => %{
          before: "\n$N你纵身一跳，稳稳地落在了地上。\n\n",
          target: "hengyang:outzigai",
          after: "$N从上面跳了下来。\n",
          after_excl: true
        }
      }
    ]
  }

  @shuiliandong_tiao %{
    args: ["pubu", "瀑布"],
    otherwise: {:write, "你想往哪儿跳？\n"},
    branches: [
      %{
        :"when" => [{:dodge, :<, 60, :raw}],
        :path => %{
          before:
            "\n$N使劲向前一跃，眼见要到洞口，但$N感觉气力已尽，身在半空却被瀑布冲了下去。\n\n",
          player_msg:
            "你迷迷糊糊地任湍急的水流将你冲走，身上却是一点力气也使不出来。\n\n",
          target: "hengyang:heishatan",
          unconcious: true
        }
      },
      %{
        :"when" => [{:dodge, :<, 140, :raw}],
        :path => %{
          before:
            "\n$N奋力往前一跳，险些被瀑布打落，但有惊无险，$N终于落在洞口处，可样子却甚是狼狈。\n\n",
          after: "\n$N从瀑布外跳狼狈万分地跳了进来。\n\n",
          after_excl: true,
          target: "hengyang:inhole"
        }
      },
      %{
        :"when" => :always,
        :path => %{
          before: "\n$N提气向前一纵，轻松地落在洞口处。\n\n",
          after: "\n$N从瀑布外跳了进来。\n",
          after_excl: true,
          target: "hengyang:inhole"
        }
      }
    ]
  }

  @xuanyadi_climb %{
    args: ["teng", "tree"],
    otherwise: {:write, "你想往哪儿爬？\n"},
    branches: [
      %{
        :"when" => [{:arg, "teng"}, {:qi, :<, 100}],
        :path => %{
          before: "\n$N拉着树藤往峭壁上爬去。\n$N体力不知，从峭壁上摔了下来。\n",
          unconcious: true
        }
      },
      %{
        :"when" => [{:arg, "teng"}],
        :path => %{
          before: "\n$N拉着树藤往峭壁上爬去。\n",
          after: "\n$N从峭壁下面爬了上来。\n",
          after_excl: true,
          target: "hengyang:zigai"
        }
      },
      %{
        :"when" => [{:arg, "tree"}],
        :path => %{target: "hengyang:ontree"}
      }
    ]
  }

  @eyutan1_cross %{
    args: ["tan"],
    otherwise: {:write, "你要往哪儿跳？\n"},
    guard: :busy_fighting,
    branches: [
      %{
        :"when" => [{:dodge, :>, 120, :effective}],
        :path => %{
          before:
            "$N飞身前跃，跳向鄂鱼潭，只见$N到至深潭上空却又忽地落下，眼见要坠入潭中。却见$N双足在鄂鱼背上一点，顷刻间腾向对岸。\n",
          before_excl: true,
          player_msg:
            "你飞身前跃，跳至深潭半空身双足在鄂鱼背上一点，眨眼间已到得对岸。\n\n",
          after: "$N从对岸跳了过来。\n",
          after_excl: true,
          target: "jueqing:eyutan3"
        }
      },
      %{
        :"when" => :always,
        :path => %{
          before:
            "$N飞身前跃，跳向鄂鱼潭，只见$N到至深潭上空却力气已尽，落入潭中。\n",
          before_excl: true,
          player_msg:
            "你飞身前跃，跳至深潭半空身却感觉力气已尽，想回头已不能，只听“扑咚”一声，你已经落入深潭之中。\n\n",
          target: "jueqing:eyutan2"
        }
      }
    ]
  }

  @eyutan2_swim %{
    args: ["bank"],
    otherwise: {:write, "你要往哪儿游？\n"},
    guard: :busy_fighting,
    branches: [
      %{
        :"when" => :always,
        :path => %{
          player_msg: "你使尽所有力气向岸边游去…\n",
          after: "$N游了上来。\n",
          after_excl: true,
          target: "jueqing:eyutan1"
        }
      }
    ]
  }

  @eyutan3_cross %{
    args: ["tan"],
    otherwise: {:write, "你要往哪儿跳？\n"},
    guard: :busy_fighting,
    branches: [
      %{
        :"when" => [{:dodge, :>, 120, :effective}],
        :path => %{
          before:
            "$N飞身前跃，跳向鄂鱼潭，只见$N到至深潭上空却又忽地落下，眼见要坠入潭中。却见$N双足在鄂鱼背上一点，顷刻间腾向对岸。\n",
          before_excl: true,
          player_msg:
            "你飞身前跃，跳至深潭半空身双足在鄂鱼背上一点，眨眼间已到得对岸。\n\n",
          after: "$N从对岸跳了过来。\n",
          after_excl: true,
          target: "jueqing:eyutan1"
        }
      },
      %{
        :"when" => :always,
        :path => %{
          before:
            "$N飞身前跃，跳向鄂鱼潭，只见$N到至深潭上空却力气已尽，落入潭中。\n",
          before_excl: true,
          player_msg:
            "你飞身前跃，跳至深潭半空身却感觉力气已尽，想回头已不能，只听“扑咚”一声，你已经落入深潭之中。\n\n",
          target: "jueqing:eyutan2"
        }
      }
    ]
  }

  @ontree1_jump %{
    args: ["down"],
    otherwise: {:write, "你要往哪儿跳？\n"},
    guard: :busy_fighting,
    branches: [
      %{
        :"when" => :always,
        :path => %{
          after: "$N从大枣树上跳了下来。\n",
          after_excl: true,
          target: "jueqing:undertan"
        }
      }
    ]
  }

  @ontree3_climb %{
    args: ["teng"],
    otherwise: {:write, "你想往哪儿爬？\n"},
    guard: :busy_fighting,
    branches: [
      %{
        :"when" => :always,
        :path => %{
          before: "$N顺着树藤向上爬去…\n",
          target: "jueqing:ligui"
        }
      }
    ]
  }

  @undertan_climb %{
    args: ["tree"],
    otherwise: {:write, "你想往哪儿爬？\n"},
    guard: :busy_fighting,
    branches: [
      %{
        :"when" => :always,
        :path => %{
          after: "$N从下面爬了上来。\n",
          after_excl: true,
          target: "jueqing:ontree1"
        }
      }
    ]
  }

  @underya2_jump %{
    args: ["tan"],
    otherwise: {:write, "你要往哪儿跳？\n"},
    guard: :busy_fighting,
    branches: [
      %{
        :"when" => :always,
        :path => %{
          player_msg:
            "你纵身入潭，顺势而下忙，向光亮处游去，过不多时，便到了寒潭另一侧，你迫不及待，纵身跃出水面。\n\n",
          target: "jueqing:underya"
        }
      }
    ]
  }

  @terrain %{
    {"hengyang:outzhushendong", "climb"} => @outzhushendong_climb,
    {"hengyang:outzigai", "climb"} => @outzigai_climb,
    {"hengyang:outzigai", "jump"} => @outzigai_tiao,
    {"hengyang:outzigai1", "jump"} => @outzigai1_tiao,
    {"hengyang:shuiliandong", "jump"} => @shuiliandong_tiao,
    {"hengyang:xuanyadi", "climb"} => @xuanyadi_climb,
    {"jueqing:eyutan1", "cross"} => @eyutan1_cross,
    {"jueqing:eyutan2", "swim"} => @eyutan2_swim,
    {"jueqing:eyutan3", "cross"} => @eyutan3_cross,
    {"jueqing:ontree1", "jump"} => @ontree1_jump,
    {"jueqing:ontree3", "climb"} => @ontree3_climb,
    {"jueqing:undertan", "climb"} => @undertan_climb,
    {"jueqing:underya2", "jump"} => @underya2_jump
  }

  @doc "已配置的 `{room_id, canonical_verb}` 列表（覆盖度自查用）"
  def entries, do: @terrain

  @impl true
  def run(conn, %{verb: verb, trailing: arg, room_id: room_id}) do
    cverb = Map.get(@verb_alias, verb, verb)

    case Map.fetch(@terrain, {room_id, cverb}) do
      {:ok, spec} -> perform(conn, room_id, spec, String.trim(arg || ""))
      :error -> :not_handled
    end
  end

  defp perform(conn, room_id, spec, arg) do
    if not arg_in?(spec.args, arg) do
      otherwise(conn, spec.otherwise)
    else
      case guard(conn, Map.get(spec, :guard)) do
        {:halt, c} -> c
        {:ok, c} -> route_branch(c, room_id, Map.get(spec, :branches, []), arg)
      end
    end
  end

  defp route_branch(conn, room_id, branches, arg) do
    case find_branch(branches, conn, arg) do
      nil -> conn
      %{:path => path} -> apply_path(conn, room_id, path)
    end
  end

  defp find_branch(branches, conn, arg) do
    Enum.find(branches, fn %{:"when" => when_spec} ->
      when_matches?(when_spec, conn, arg)
    end)
  end

  defp when_matches?(:always, _conn, _arg), do: true

  defp when_matches?(when_spec, conn, arg) when is_list(when_spec) do
    Enum.all?(when_spec, &cond_matches?(&1, conn, arg))
  end

  defp cond_matches?({:arg, value}, _conn, arg), do: arg == value
  defp cond_matches?({:qi, op, n}, conn, _arg), do: apply_op(op, qi(conn), n)

  defp cond_matches?({:dodge, op, n, mode}, conn, _arg),
    do: apply_op(op, dodge(conn, mode), n)

  defp apply_op(:<, a, b), do: a < b
  defp apply_op(:<=, a, b), do: a <= b
  defp apply_op(:>, a, b), do: a > b
  defp apply_op(:>=, a, b), do: a >= b

  defp arg_in?(nil, _arg), do: true
  defp arg_in?(:none, ""), do: true
  defp arg_in?(:none, _arg), do: false
  defp arg_in?(list, arg) when is_list(list), do: arg in list

  defp guard(conn, nil), do: {:ok, conn}

  defp guard(conn, :busy_fighting) do
    combat = current(conn).meta.combat

    cond do
      Combat.busy?(combat) ->
        {:halt, Helpers.render_to_player(conn, @busy_msg)}

      Combat.fighting?(combat) ->
        {:halt, Helpers.render_to_player(conn, @fighting_msg)}

      true ->
        {:ok, conn}
    end
  end

  defp otherwise(conn, {:write, text}), do: Helpers.render_to_player(conn, text)
  defp otherwise(conn, :not_handled), do: conn

  defp apply_path(conn, room_id, path) do
    target = Map.get(path, :target)

    conn
    |> maybe_vision(room_id, Map.get(path, :before), Map.get(path, :before_excl))
    |> maybe_player_msg(Map.get(path, :player_msg))
    |> maybe_move(target)
    |> maybe_vision(target || room_id, Map.get(path, :after), Map.get(path, :after_excl))
    |> maybe_unconcious(Map.get(path, :unconcious))
  end

  defp maybe_vision(conn, _room_id, nil, _excl), do: conn

  defp maybe_vision(conn, room_id, text, excl) do
    opts = if excl, do: [exclude_actor: true], else: []
    Helpers.broadcast_vision(conn, room_id, text, opts)
  end

  defp maybe_player_msg(conn, nil), do: conn
  defp maybe_player_msg(conn, text), do: Helpers.render_to_player(conn, text)

  defp maybe_move(conn, nil), do: conn
  defp maybe_move(conn, target), do: Helpers.move_to(conn, target)

  defp maybe_unconcious(conn, true), do: Break.unconcious(conn)
  defp maybe_unconcious(conn, _), do: conn

  defp qi(conn) do
    vitals = current(conn).meta.vitals
    Map.get(vitals, :qi, 0)
  end

  defp dodge(conn, mode) do
    character = current(conn)
    stats = character.meta.stats

    case mode do
      :raw -> Stats.skill(stats, "dodge")
      :effective -> Stats.effective(stats, "dodge", Combat.skill_applies(character))
    end
  end

  # 取当前角色（优先更新后的副本，与 Break.current/1 同语义）
  defp current(%{private: %{update_character: c}} = conn) when not is_nil(c), do: c
  defp current(%{character: c}), do: c
end
