defmodule Kantele.World.LpcCondition do
  @moduledoc """
  受限 LPC 条件表达式求值器（对应 `int valid_leave(object me, string dir)`）

  背景：转换器把房间 `valid_leave` 里的阻挡条件留成了注释，运行时从不拦截
  （`Kantele.World.Loader.parse_room_vetoes/1` 结构化保留了 `exit_vetoes`，
  `condition` 恒为空）。本模块把其中**能被无歧义还原**的那部分真正执行。

  支持的语法子集：

      逻辑     `&&`  `&`  `||`  `|`  `!`  `~`  括号
      比较     `==`  `!=`  `<`  `<=`  `>`  `>=`（int / string / nil）
      类型     `(int)`  `(string)`
      内建     `present(id, scope)`  `environment(x)`  `objectp(x)`  `living(x)`
               `userp(x)`  `wizardp(x)`  `this_object()`  `this_player()`  `id(x)`
      方法     `<obj>->query("a/b")`  `->query_temp(...)`  `->query_skill(...)`
               `->query_condition(...)`  `->refuse(me)`  `->query("id")`
      赋值     `ob = present("shi wei", environment(me))`
      变量     `me`  `dir`  `room`  `ob`  `this_object`  `this_player`

  **刻意不支持**（解析失败 -> 条件保留原文、不参与拦截）：数组下标 `inv[i]`、
  映射取键 `myfam["family_name"]`、裸标识符当值（`guarder`）、三元 `?:`、
  自定义函数（`check_dirs` / `check_out`）。这些要么依赖房间私有临时变量，
  要么需要各自的业务判定，不宜凭空猜。

  `evaluate/2` 返回 `{:ok, boolean}` 或 `{:error, reason}`；**求值出错一律按
  「不拦截」处理** —— 宁可少拦，也不能把玩家锁死在房里。
  """

  # ---------- 对外 ----------

  # 本项目实现的内建函数与对象方法。**不在表里的**（check_dirs / check_out /
  # refuse 等自定义函数）视为不可执行：解析期就拒掉，避免「能解析但求值时才炸」。
  @known_funcs ~w(present environment objectp living userp wizardp this_object this_player id)
  @known_methods ~w(query query_temp query_skill query_condition id)

  @doc """
  条件是否限定了方向（出现 `dir`）。

  转换器处理嵌套 `if` 时只保留了**最内层**条件，丢掉了外层守卫。典型受害例子：

      # mud/d/beijing/kediandayuan.c
      if (dir != "east") return ::valid_leave(me, dir);   # <- 外层守卫被丢
      ...
      if ((int)me->query_skill("force") < 100) return notify_fail(...);

  于是 UCL 里只剩 `(int)me->query_skill('force') < 100`，若照此执行会把该房
  **所有**方向都拦掉（玩家可能被锁死）。所以这类「方向未限定」的条件一律
  暂不执行，等逐房把外层守卫补回（见 scripts/audit_exit_veto_locks.py）。
  """
  def direction_scoped?(expr) when is_binary(expr) do
    String.contains?(expr, "dir")
  end

  def direction_scoped?(_), do: false

  @doc "表达式能否被本求值器处理（不能则保留原文、不执行）"
  def enforceable?(expr) when is_binary(expr) do
    case parse(expr) do
      {:ok, ast} -> known_ast?(ast)
      _ -> false
    end
  end

  def enforceable?(_), do: false

  defp known_ast?({:func, name, args}) do
    name in @known_funcs and Enum.all?(args, &known_ast?/1)
  end

  defp known_ast?({:and, l, r}), do: known_ast?(l) and known_ast?(r)
  defp known_ast?({:or, l, r}), do: known_ast?(l) and known_ast?(r)
  defp known_ast?({:not, a}), do: known_ast?(a)
  defp known_ast?({:cmp, _, l, r}), do: known_ast?(l) and known_ast?(r)
  defp known_ast?({:cast, _, a}), do: known_ast?(a)
  defp known_ast?({:assign, _, a}), do: known_ast?(a)

  defp known_ast?({:call, target, {method, args}}) do
    method in @known_methods and known_ast?(target) and Enum.all?(args, &known_ast?/1)
  end

  defp known_ast?(_), do: true

  @doc """
  求值。`ctx` 形状见 `check/2`

  返回 `{:ok, boolean}` 或 `{:error, reason}`。
  """
  def evaluate(expr, ctx) when is_binary(expr) do
    with {:ok, ast} <- parse(expr) do
      try do
        # LPC 的 `ob = present(...)` 靠副作用给后面的 `living(ob)` / `ob->query()`
        # 用；而 Elixir 里 ctx 是不可变值，短路求值不会把新绑定带下去。
        # 所以先把所有赋值按出现顺序求值、塞进 ctx.vars，再整体求值。
        ctx = seed_vars(ast, ctx)

        {:ok, truthy?(eval(ast, ctx))}
      rescue
        e -> {:error, {:runtime, Exception.message(e)}}
      catch
        :throw, reason -> {:error, reason}
      end
    end
  end

  defp seed_vars(ast, ctx), do: seed_vars(ast, ctx, [])

  defp seed_vars({:assign, name, sub}, ctx, acc) do
    ctx = seed_vars(sub, ctx, acc)
    value = eval(sub, ctx)
    Map.put(ctx, :vars, Map.put(Map.get(ctx, :vars, %{}), name, value))
  end

  defp seed_vars({:and, l, r}, ctx, acc), do: seed_vars(r, seed_vars(l, ctx, acc), acc)
  defp seed_vars({:or, l, r}, ctx, acc), do: seed_vars(r, seed_vars(l, ctx, acc), acc)
  defp seed_vars({:not, a}, ctx, acc), do: seed_vars(a, ctx, acc)
  defp seed_vars({:cmp, _, l, r}, ctx, acc), do: seed_vars(r, seed_vars(l, ctx, acc), acc)
  defp seed_vars({:cast, _, a}, ctx, acc), do: seed_vars(a, ctx, acc)

  defp seed_vars({:call, target, {_method, args}}, ctx, acc) do
    ctx = seed_vars(target, ctx, acc)
    Enum.reduce(args, ctx, &seed_vars(&1, &2, acc))
  end

  defp seed_vars({:func, _name, args}, ctx, acc), do: Enum.reduce(args, ctx, &seed_vars(&1, &2, acc))

  defp seed_vars(list, ctx, acc) when is_list(list),
    do: Enum.reduce(list, ctx, &seed_vars(&1, &2, acc))

  defp seed_vars(_, ctx, _acc), do: ctx

  @doc """
  求值一条 `valid_leave` 记录：命中返回 `{:block, message}`，否则 `:allow`。

  `ctx`：

      %{
        dir: "north",
        me: <玩家>,
        room: <房间 struct>,
        vars: %{},
        resolver: %{
          present: (id, scope) -> {:ok, obj} | :error,
          environment: (obj) -> {:ok, room} | :error,
          living: (obj) -> boolean,
          wizardp: (obj) -> boolean,
          userp: (obj) -> boolean,
          id: (obj) -> binary | nil,
          call: (target, method, args) -> {:ok, value} | :error
        }
      }
  """
  def check(veto, ctx) do
    case veto do
      %{condition: expr} when is_binary(expr) and expr != "" ->
        case evaluate(expr, ctx) do
          {:ok, true} -> {:block, Map.get(veto, :message)}
          _ -> :allow
        end

      _ ->
        :allow
    end
  end

  @doc false
  def parse(expr) do
    try do
      {ast, rest} = expr |> tokenize() |> parse_or(%{})

      if rest == [] do
        {:ok, ast}
      else
        {:error, {:trailing_tokens, rest}}
      end
    rescue
      e in __MODULE__.ParseError -> {:error, e.reason}
    end
  end

  defmodule ParseError do
    @moduledoc false
    defexception [:reason]

    def exception(reason), do: %__MODULE__{reason: reason}

    @impl true
    def message(%__MODULE__{reason: reason}), do: "LPC 条件解析失败: #{inspect(reason)}"
  end

  # ---------- 词法 ----------
  #
  # 注意：字符一律按 charlist（整数）处理。`String.graphemes/1` 返回的是
  # **字符串**列表，与 charlist 比较会永远不相等 —— 踩过一次。

  # 运算符按长度降序，避免 `->` 被切成 `-`、`&&` 被切成 `&`
  @ops ["->", "==", "!=", "<=", ">=", "&&", "||", "(", ")", "[", "]",
        ",", "!", "~", "<", ">", "&", "|", "=", "+", "-", "?", ":"]

  defp tokenize(src), do: src |> String.to_charlist() |> tok([])

  defp tok([], buf), do: Enum.reverse(buf)

  # 空白无意义
  defp tok([c | rest], buf) when c == ?\s or c == ?\t or c == ?\n or c == ?\r do
    tok(rest, buf)
  end

  # 字符串字面量（单双引号都收：数据侧用单引号存条件，避开 Elias 的嵌套转义问题）
  defp tok([q | rest], buf) when q == ?" or q == ?' do
    {str, rest} = read_string(rest, [], q)
    tok(rest, [{:string, str} | buf])
  end

  # 数字字面量
  defp tok([c | _] = chars, buf) when c >= ?0 and c <= ?9 do
    {num, rest} = read_number(chars, [])
    tok(rest, [{:number, num} | buf])
  end

  # 标识符；其余字符交给算符分支
  defp tok([c | _] = chars, buf) do
    if ident_start?(c) do
      {name, rest} = read_ident(chars, [])
      tok(rest, [{:ident, name} | buf])
    else
      tok_operator(chars, buf)
    end
  end

  defp ident_start?(c), do: (c >= ?a and c <= ?z) or (c >= ?A and c <= ?Z) or c == ?_

  defp ident_char?(c), do: ident_start?(c) or (c >= ?0 and c <= ?9)

  defp tok_operator(chars, buf) do
    case Enum.find(@ops, &starts_with?(chars, &1)) do
      nil -> raise __MODULE__.ParseError, reason: {:unexpected_char, chars}
      op -> tok(Enum.drop(chars, length(String.to_charlist(op))), [{:op, op} | buf])
    end
  end

  defp starts_with?(chars, op) do
    op_chars = String.to_charlist(op)
    Enum.take(chars, length(op_chars)) == op_chars
  end

  defp read_string([], buf, _q), do: {List.to_string(Enum.reverse(buf)), []}
  defp read_string([q | rest], buf, q), do: {List.to_string(Enum.reverse(buf)), rest}
  defp read_string([?\\, c | rest], buf, q), do: read_string(rest, [c | buf], q)
  defp read_string([c | rest], buf, q), do: read_string(rest, [c | buf], q)

  defp read_number([c | rest] = chars, buf) when c >= ?0 and c <= ?9,
    do: read_number(rest, [c | buf])

  defp read_number(chars, buf), do: {List.to_string(Enum.reverse(buf)), chars}

  defp read_ident([], buf), do: {List.to_string(Enum.reverse(buf)), []}

  defp read_ident([c | rest] = chars, buf) do
    if ident_char?(c), do: read_ident(rest, [c | buf]), else: {List.to_string(Enum.reverse(buf)), chars}
  end

  # ---------- 语法 ----------

  defp parse_or(tokens, env) do
    {left, rest} = parse_and(tokens, env)
    parse_or_tail(left, rest, env)
  end

  defp parse_or_tail(left, [{:op, op} | rest], env) when op in ["||", "|"] do
    {right, rest2} = parse_or(rest, env)
    parse_or_tail({:or, left, right}, rest2, env)
  end

  defp parse_or_tail(left, rest, _env), do: {left, rest}

  defp parse_and(tokens, env) do
    {left, rest} = parse_cmp(tokens, env)
    parse_and_tail(left, rest, env)
  end

  defp parse_and_tail(left, [{:op, op} | rest], env) when op in ["&&", "&"] do
    {right, rest2} = parse_and(rest, env)
    parse_and_tail({:and, left, right}, rest2, env)
  end

  defp parse_and_tail(left, rest, _env), do: {left, rest}

  @cmp_ops ["==", "!=", "<=", ">=", "<", ">"]

  defp parse_cmp(tokens, env) do
    {left, rest} = parse_unary(tokens, env)

    case rest do
      [{:op, op} | rest2] when op in @cmp_ops ->
        {right, rest3} = parse_unary(rest2, env)
        {{:cmp, op, left, right}, rest3}

      _ ->
        {left, rest}
    end
  end

  defp parse_unary([{:op, op} | rest], env) when op in ["!", "~"] do
    {inner, rest2} = parse_unary(rest, env)
    {{:not, inner}, rest2}
  end

  defp parse_unary(tokens, env), do: parse_postfix(tokens, env)

  defp parse_postfix(tokens, env) do
    {left, rest} = parse_primary(tokens, env)
    parse_postfix_tail(left, rest, env)
  end

  # `me->query("a/b")`：左侧 left 已解析完，这里只取方法名 + 参数
  defp parse_postfix_tail(
         left,
         [{:op, "->"}, {:ident, method}, {:op, "("} | rest],
         env
       ) do
    {args, rest2} = parse_args(rest, env)
    parse_postfix_tail({:call, left, {method, args}}, rest2, env)
  end

  defp parse_postfix_tail(left, rest, _env), do: {left, rest}

  # 类型转换 (int)x / (string)x —— 必须排在通用括号子句之前
  defp parse_primary([{:op, "("}, {:ident, type}, {:op, ")"} | rest], env)
       when type in ["int", "string"] do
    {inner, rest2} = parse_unary(rest, env)
    {{:cast, type, inner}, rest2}
  end

  defp parse_primary([{:op, "("} | rest], env) do
    {inner, rest2} = parse_or(rest, env)

    case rest2 do
      [{:op, ")"} | rest3] ->
        {inner, rest3}

      _ ->
        raise __MODULE__.ParseError, reason: {:expected_rparen, rest2}
    end
  end

  defp parse_primary([{:number, n} | rest], _env), do: {{:num, String.to_integer(n)}, rest}
  defp parse_primary([{:string, s} | rest], _env), do: {{:str, s}, rest}

  # 函数调用
  defp parse_primary([{:ident, name}, {:op, "("} | rest], env) do
    {args, rest2} = parse_args(rest, env)
    {{:func, name, args}, rest2}
  end

  # 赋值 ob = ...
  defp parse_primary([{:ident, name}, {:op, "="} | rest], env) do
    {value, rest2} = parse_or(rest, env)
    {{:assign, name, value}, rest2}
  end

  defp parse_primary([{:ident, name} | rest], _env), do: {{:var, name}, rest}

  defp parse_primary(tokens, _env),
    do: raise(__MODULE__.ParseError, reason: {:unexpected, tokens})

  defp parse_args(tokens, env), do: parse_args_1(tokens, [], env)

  # 空参数表 present()
  defp parse_args_1([{:op, ")"} | rest], _acc, _env), do: {[], rest}

  defp parse_args_1(tokens, acc, env) do
    {arg, rest} = parse_or(tokens, env)
    acc = acc ++ [arg]

    case rest do
      [{:op, ","} | rest2] ->
        parse_args_1(rest2, acc, env)

      [{:op, ")"} | rest2] ->
        {acc, rest2}

      _ ->
        raise __MODULE__.ParseError, reason: {:expected_comma_or_rparen, rest}
    end
  end

  # ---------- 求值 ----------

  defp eval({:and, l, r}, ctx), do: if(truthy?(eval(l, ctx)), do: eval(r, ctx), else: false)

  defp eval({:or, l, r}, ctx), do: if(truthy?(eval(l, ctx)), do: true, else: truthy?(eval(r, ctx)))

  defp eval({:not, ast}, ctx), do: !truthy?(eval(ast, ctx))
  defp eval({:cmp, op, l, r}, ctx), do: compare(op, eval(l, ctx), eval(r, ctx))
  defp eval({:cast, "int", ast}, ctx), do: to_int(eval(ast, ctx))
  defp eval({:cast, "string", ast}, ctx), do: to_str(eval(ast, ctx))
  defp eval({:num, n}, _ctx), do: n
  defp eval({:str, s}, _ctx), do: s

  defp eval({:var, "me"}, ctx), do: Map.get(ctx, :me)
  defp eval({:var, "dir"}, ctx), do: Map.get(ctx, :dir)
  defp eval({:var, "room"}, ctx), do: Map.get(ctx, :room)
  defp eval({:var, "this_object"}, ctx), do: Map.get(ctx, :room)
  defp eval({:var, "this_player"}, ctx), do: Map.get(ctx, :me)
  defp eval({:var, name}, ctx), do: Map.get(Map.get(ctx, :vars, %{}), name)

  defp eval({:assign, name, ast}, ctx) do
    value = eval(ast, ctx)
    vars = Map.put(Map.get(ctx, :vars, %{}), name, value)
    Map.put(ctx, :vars, vars)
    value
  end

  defp eval({:func, name, args}, ctx), do: apply_func(name, args, ctx)

  defp eval({:call, target, {method, args}}, ctx) do
    t = eval(target, ctx)
    call = resolver_call(ctx)

    if is_function(call, 3) do
      case call.(t, method, Enum.map(args, &eval(&1, ctx))) do
        {:ok, value} -> value
        :error -> nil
        other -> other
      end
    else
      nil
    end
  end

  # ---- 内建函数 ----

  defp apply_func("present", args, ctx) do
    [id, scope] = eval_args(args, ctx)
    fn2 = resolver_call(ctx, :present)
    if is_function(fn2, 2), do: unwrap(fn2.(id, scope)), else: nil
  end

  defp apply_func("environment", args, ctx) do
    [target | _] = eval_args(args, ctx)
    fn1 = resolver_call(ctx, :environment)
    if is_function(fn1, 1), do: unwrap(fn1.(target)), else: nil
  end

  defp apply_func("objectp", args, ctx) do
    case eval_args(args, ctx) do
      [v | _] -> v != nil
      _ -> false
    end
  end

  defp apply_func("living", args, ctx) do
    case eval_args(args, ctx) do
      [v | _] -> predicate(ctx, :living, v)
      _ -> false
    end
  end

  defp apply_func("userp", args, ctx), do: bool_arg(args, ctx, :userp)
  defp apply_func("wizardp", args, ctx), do: bool_arg(args, ctx, :wizardp)
  defp apply_func("this_object", _args, ctx), do: Map.get(ctx, :room)
  defp apply_func("this_player", _args, ctx), do: Map.get(ctx, :me)

  defp apply_func("id", args, ctx) do
    case eval_args(args, ctx) do
      [v | _] ->
        fn1 = resolver_call(ctx, :id)
        if is_function(fn1, 1), do: fn1.(v), else: nil

      _ ->
        nil
    end
  end

  defp apply_func(name, _args, _ctx),
    do: raise(__MODULE__.ParseError, reason: {:unknown_function, name})

  defp eval_args(args, ctx), do: Enum.map(args, &eval(&1, ctx))

  defp bool_arg(args, ctx, key) do
    case eval_args(args, ctx) do
      [v | _] -> predicate(ctx, key, v)
      _ -> false
    end
  end

  defp predicate(ctx, key, value) do
    fn1 = resolver_call(ctx, key)
    is_function(fn1, 1) and value != nil and fn1.(value) == true
  end

  defp resolver_call(ctx), do: Map.get(Map.get(ctx, :resolver, %{}), :call)
  defp resolver_call(ctx, key), do: Map.get(Map.get(ctx, :resolver, %{}), key)

  defp unwrap({:ok, v}), do: v
  defp unwrap(:error), do: nil
  defp unwrap(other), do: other

  # ---------- 值语义 ----------

  @doc "LPC 真值：nil / false / 0 / 空串为假"
  def truthy?(nil), do: false
  def truthy?(false), do: false
  def truthy?(0), do: false
  def truthy?(""), do: false
  def truthy?(_), do: true

  defp compare("==", l, r), do: loose_eq?(l, r)
  defp compare("!=", l, r), do: not loose_eq?(l, r)

  defp compare(op, l, r) do
    ln = to_int(l)
    rn = to_int(r)

    case op do
      "<" -> ln < rn
      "<=" -> ln <= rn
      ">" -> ln > rn
      ">=" -> ln >= rn
    end
  end

  # LPC 的 == 语义：两个非数字字符串按内容比；数字与非数字字符串永不相等。
  # （早期实现把两侧都 to_int 再比，导致 "south" == "north" 因为都是 0 而成立。）
  defp loose_eq?(nil, nil), do: true
  defp loose_eq?(nil, r), do: numeric_eq?(0, r)
  defp loose_eq?(l, nil), do: numeric_eq?(l, 0)
  defp loose_eq?(l, r) when is_binary(l) and is_binary(r), do: l == r
  defp loose_eq?(l, r), do: numeric_eq?(l, r)

  defp numeric_eq?(l, r) do
    case {num(l), num(r)} do
      {nil, nil} -> l == r
      {x, nil} -> false
      {nil, y} -> false
      {x, y} -> x == y
    end
  end

  # 只有「整串都是数字」才算数值
  defp num(v) when is_integer(v), do: v
  defp num(v) when is_float(v), do: trunc(v)

  defp num(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp num(_), do: nil

  defp to_int(nil), do: 0
  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: trunc(v)

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp to_int(_), do: 0

  defp to_str(nil), do: ""
  defp to_str(v) when is_binary(v), do: v
  defp to_str(v) when is_integer(v), do: Integer.to_string(v)
  defp to_str(v) when is_float(v), do: :erlang.float_to_binary(v, [:short])
  defp to_str(true), do: "1"
  defp to_str(false), do: "0"
  defp to_str(_), do: ""
end