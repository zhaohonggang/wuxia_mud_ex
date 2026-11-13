defmodule Kantele.World.Hunting do
  @moduledoc """
  LPC `inherit/char/quarry.c::die()` / `inherit/char/snake.c::die()` 的狩猎掉落判定。

  严格照搬 LPC 原式（两份源码逐字一致）：

  ```c
  skill = me->query_skill("hunting", 1);

  if (ob->query("item1") && random(skill) > 10)
  {
      item = new(ob->query("item1"));
      item->move(me, 1);                       // 直接进击杀者背包

      msg = "你仔细翻寻" + ob->name() + "的尸体，从上面割下了一" + ...;

      if (ob->query("item3") && random(skill) > 60 && random(5) > 3)
          item3 也给击杀者;
      else if (ob->query("item2") && random(skill) > 30 && random(4) > 2)
          item2 也给击杀者;
      tell_object(me, msg);
  }
  ```

  要点（与端口旧「方案 A」的区别）：

  - `item1`（UCL `drop_a`）是主掉落，`random(skill) > 10` 不通过则**什么都没有**；
  - `item2` / `item3`（`drop_b` / `drop_c`）互斥、二选一，且各自再掷一次 `skill`；
  - `random(5) > 3` 与 `random(4) > 2` 是额外稀有度门（1/5 与 1/4）；
  - 战斗利品 `item->move(me, 1)` **直接进击杀者背包**，不落在地上。

  LPC 的 `random(n)` 取值域是 `[0, n-1]`；`random(0)` 恒为 0，故 hunting=0 时
  永远不会掉落 —— 这与原版一致，需向衡阳猎人学习 hunting 才有收益。

  ## 掷骰可注入

  `roll/3` 的 `rng.(n)` 约定返回 `[0, n-1]`（**LPC 风格**，不是 Elixir 的
  `:rand.uniform/1` 的 `[1, n]`），便于单元测试穷举边界。默认用 `lpc_rand/1`。
  """

  alias Kantele.World.Corpse

  @doc """
  按 LPC 原式掷骰，返回本次应掉落的**短物品引用**列表。

  `drops` 形如 `%{a: "zhurou", b: "zhupi", c: "xiongdan"}`，缺项可为 nil。
  返回 `[]` / `[a]` / `[a, c]` / `[a, b]`。
  """
  def roll(drops, skill, rng \\ nil) do
    rng = rng || &lpc_rand/1

    a = get(drops, :a)
    b = get(drops, :b)
    c = get(drops, :c)

    cond do
      is_nil(a) ->
        []

      lpc_random(skill, rng) <= 10 ->
        []

      true ->
        extra =
          cond do
            not is_nil(c) and lpc_random(skill, rng) > 60 and lpc_random(5, rng) > 3 ->
              c

            not is_nil(b) and lpc_random(skill, rng) > 30 and lpc_random(4, rng) > 2 ->
              b

            true ->
              nil
          end

        [a, extra] |> Enum.reject(&is_nil/1)
    end
  end

  @doc """
  把 UCL 短引用解析成 `[{完整缓存 key, 物品定义}]`。

  `Kantele.World.Corpse.resolve_drop_item/1` 负责补 `clone_lib:` 前缀 / 后缀兜底；
  解析不到的条目静默丢弃（与世界数据缺失时的既有降级一致）。
  """
  def resolve(refs) when is_list(refs) do
    refs
    |> Enum.map(&Corpse.resolve_drop_item/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  LPC `tell_object(me, msg)` 的回执文案。

  例（两件）：`你仔细翻寻野猪的尸体，从上面割下了一块野猪肉及一块猪皮。\\n\\n`
  """
  def message(victim_name, resolved) when is_list(resolved) do
    parts =
      Enum.map(resolved, fn {_key, item} ->
        unit = unit_of(item)
        "一#{unit}#{item.name}"
      end)

    case parts do
      [] ->
        nil

      [first] ->
        "你仔细翻寻#{victim_name}的尸体，从上面割下了#{first}。\n\n"

      [first | rest] ->
        "你仔细翻寻#{victim_name}的尸体，从上面割下了#{first}及#{Enum.join(rest, "及")}。\n\n"
    end
  end

  @doc "从 NPC meta 组装 `roll/2` 需要的掉落配置；无任何配置时返回 nil"
  def drops_from_meta(meta) when is_map(meta) do
    drops = %{
      a: Map.get(meta, :drop_a),
      b: Map.get(meta, :drop_b),
      c: Map.get(meta, :drop_c)
    }

    if Enum.any?(Map.values(drops), &is_binary/1), do: drops, else: nil
  end

  def drops_from_meta(_), do: nil

  defp get(drops, key) when is_map(drops), do: Map.get(drops, key)
  defp get(_, _), do: nil

  defp lpc_random(n, rng) when is_integer(n) and n > 0, do: rng.(n)
  defp lpc_random(_, _), do: 0

  defp lpc_rand(n) when is_integer(n) and n > 0, do: :rand.uniform(n) - 1
  defp lpc_rand(_), do: 0

  defp unit_of(%{meta: meta}) when is_map(meta) do
    unit = Map.get(meta, :unit) || Map.get(meta, "unit")
    if is_binary(unit) and unit != "", do: unit, else: "块"
  end

  defp unit_of(_), do: "块"
end
