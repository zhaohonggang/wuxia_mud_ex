defmodule Kantele.Character.BankVerbAliasesTest do
  @moduledoc """
  钱庄顶层动词别名（P5-1 NPC 通道，`BankCommand` 别名段）。

  LPC 的银行 NPC 是把子命令当**独立顶层动词**注册的
  （`add_action("do_deposit", "cun")` 等），玩家直接输 `cun 10 银`。
  移植后 `BankCommand` 只注册了 `bank`/`银行`，于是这批动词在全局命令表里
  不存在 —— 玩家输 `cun 10 银` 没有任何反应。

  本文件验证两件事：
  1. 路由层：`cun`/`qu`/`deposit`/`withdraw`/`convert`/`duihuan`/`transfer`/
     `zhuan`/`chazhang` 都能解析到 `BankCommand` 的对应入口；
  2. 行为层：别名与 `bank <子命令>` 走**同一份**实现（不复制存取逻辑）。
  """

  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Character.Command.ParsedCommand
  alias Kantele.Character.BankCommand
  alias Kantele.Character.Commands
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(coins \\ 0) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new(),
        coins: coins
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp updated_meta(conn), do: (conn.private.update_character || conn.character).meta

  describe "路由层：LPC 顶层动词都能解析" do
    test "存款类 cun / deposit" do
      assert {:ok, %ParsedCommand{module: BankCommand, function: :cun, params: params}} =
               Commands.parse("cun 5 silver")

      assert params["rest"] == "5 silver"

      assert {:ok, %ParsedCommand{module: BankCommand, function: :deposit_cmd}} =
               Commands.parse("deposit 5 silver")
    end

    test "取款类 qu / withdraw" do
      assert {:ok, %ParsedCommand{module: BankCommand, function: :qu, params: params}} =
               Commands.parse("qu 5 silver")

      assert params["rest"] == "5 silver"

      assert {:ok, %ParsedCommand{module: BankCommand, function: :withdraw_cmd}} =
               Commands.parse("withdraw 5 silver")
    end

    test "兑换类 convert / duihuan" do
      assert {:ok, %ParsedCommand{module: BankCommand, function: :convert_cmd, params: params}} =
               Commands.parse("convert 1 silver to coin")

      assert params["rest"] == "1 silver to coin"

      assert {:ok, %ParsedCommand{module: BankCommand, function: :duihuan}} =
               Commands.parse("duihuan 1 silver to coin")
    end

    test "转账类 transfer / zhuan" do
      assert {:ok, %ParsedCommand{module: BankCommand, function: :transfer_cmd}} =
               Commands.parse("transfer 1 silver to 李四")

      assert {:ok, %ParsedCommand{module: BankCommand, function: :zhuan}} =
               Commands.parse("zhuan 1 silver to 李四")
    end

    test "查帐 chazhang" do
      assert {:ok, %ParsedCommand{module: BankCommand, function: :chazhang}} =
               Commands.parse("chazhang")
    end

    test "裸动词也能解析（落到打用法提示的分支）" do
      assert {:ok, %ParsedCommand{module: BankCommand, function: :cun_bare}} =
               Commands.parse("cun")

      assert {:ok, %ParsedCommand{module: BankCommand, function: :qu_bare}} = Commands.parse("qu")
    end

    test "短动词 qu 不会前缀抢掉更长的动词" do
      # Router.parse_text/4 不要求 leftover 为空，裸注册若不写 eos() 会前缀匹配：
      # `qu` 会把 `quanjia`（劝架）、`quest` 全吃掉。这条防回归。
      assert {:ok, %ParsedCommand{module: quanjia}} = Commands.parse("quanjia")
      refute quanjia == BankCommand

      case Commands.parse("quest") do
        {:ok, %ParsedCommand{module: mod}} -> refute mod == BankCommand
        {:error, :unknown} -> :ok
      end

      # 裸 qu 本身仍然解析到钱庄
      assert {:ok, %ParsedCommand{module: BankCommand, function: :qu_bare}} = Commands.parse("qu")
    end

    test "没有覆盖已有的全局命令 check" do
      # LPC 的银行也用 check 查帐，但 check 在 Kantele 已是全局命令（查看某人，
      # 需要目标参数），不能抢 —— 否则玩家在任意房间的 check 都会被改道钱庄。
      assert {:ok, %ParsedCommand{module: mod}} = Commands.parse("check 张三")
      refute mod == BankCommand

      # 查帐用的是没被占用的 chazhang
      assert {:ok, %ParsedCommand{module: BankCommand, function: :chazhang}} =
               Commands.parse("chazhang")
    end
  end

  describe "行为层：别名复用同一份实现" do
    test "cun 与 bank deposit 结果一致" do
      via_alias = BankCommand.cun(build_conn(player(500)), %{"rest" => "5 silver"})
      via_bank = BankCommand.run(build_conn(player(500)), %{"rest" => "deposit 5 silver"})

      assert updated_meta(via_alias).coins == updated_meta(via_bank).coins
      assert PlayerMeta.bank_coins(updated_meta(via_alias)) ==
               PlayerMeta.bank_coins(updated_meta(via_bank))

      assert output_text(via_alias) =~ "你存入了五两白银"
      assert updated_meta(via_alias).coins == 0
    end

    test "qu 取款：户头减少、身上钱增加" do
      stored = %{player(0) | meta: PlayerMeta.put_bank_coins(player(0).meta, 500)}

      conn = BankCommand.qu(build_conn(stored), %{"rest" => "5 silver"})

      assert output_text(conn) =~ "你取出了五两白银"
      assert updated_meta(conn).coins == 500
      assert PlayerMeta.bank_coins(updated_meta(conn)) == 0
    end

    test "duihuan 兑换：按面额换算" do
      conn = BankCommand.duihuan(build_conn(player(500)), %{"rest" => "5 silver to coin"})

      assert output_text(conn) =~ "兑换"
      assert updated_meta(conn).coins == 500
    end

    test "chazhang 只查余额，不改钱" do
      conn = BankCommand.chazhang(build_conn(player(500)), %{})

      assert output_text(conn) =~ "共存了"
      assert conn.private.update_character == nil
    end

    test "参数不全时打 LPC 原文的用法提示" do
      conn = BankCommand.cun(build_conn(player(500)), %{"rest" => "5"})

      assert output_text(conn) =~ "命令格式：deposit|cun <数量> <货币单位>"
      assert conn.private.update_character == nil
    end

    test "裸动词打用法提示（与 LPC notify_fail 一致）" do
      conn = BankCommand.qu_bare(build_conn(player(500)), %{})

      assert output_text(conn) =~ "命令格式：withdraw|qu <数量> <货币单位>"
    end

    test "货币单位不认识时拒绝，不动钱" do
      conn = BankCommand.cun(build_conn(player(500)), %{"rest" => "5 贝壳"})

      assert output_text(conn) =~ "没有这种货币"
      assert conn.private.update_character == nil
    end
  end
end
