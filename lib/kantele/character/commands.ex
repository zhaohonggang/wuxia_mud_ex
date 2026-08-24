defmodule Kantele.Character.Commands do
  @moduledoc false

  use Kalevala.Character.Command.Router, scope: Kantele.Character

  module(ChannelCommand) do
    parse("general", :general, fn command ->
      command |> spaces() |> text(:text)
    end)
  end

  module(DelayedCommand) do
    parse("delay", :run, fn command ->
      command |> spaces() |> text(:parse)
    end)
  end

  module(EmoteCommand) do
    parse("emote", :broadcast, fn command ->
      command |> spaces() |> text(:text)
    end)

    parse("emotes", :list)
  end

  module(EnableCommand) do
    parse("enable", :run, fn command ->
      command |> spaces() |> word(:usage) |> spaces() |> word(:skill)
    end)
  end

  module(FightCommand) do
    parse("kill", :run, fn command ->
      command |> spaces() |> word(:name)
    end)

    parse("fight", :run, fn command ->
      command |> spaces() |> word(:name)
    end)
  end

  module(HaltCommand) do
    parse("halt", :run)
  end

  module(HelpCommand) do
    parse("help", :show, fn command ->
      command |> spaces() |> text(:topic)
    end)

    parse("help", :index)
  end

  module(CommandsCommand) do
    parse("commands", :run)
    parse("命令", :run)
  end

  module(ItemCommand) do
    parse("drop", :drop, fn command ->
      command |> spaces() |> text(:item_name)
    end)

    parse("get", :get, fn command ->
      command |> spaces() |> text(:item_name)
    end)
  end

  module(InfoCommand) do
    parse("info", :run)
  end

  module(InventoryCommand) do
    parse("i", :run)
    parse("inv", :run)
    parse("inventory", :run)
  end

  module(LearnCommand) do
    parse("learn", :run, fn command ->
      command |> spaces() |> word(:skill) |> spaces() |> word(:name)
    end)

    parse("practice", :run, fn command ->
      command |> spaces() |> word(:skill)
    end)
  end

  module(LookCommand) do
    parse("look", :run)
  end

  module(MapCommand) do
    parse("map", :run)
  end

  module(MoveCommand) do
    parse("north", :north, aliases: ["n"])
    parse("south", :south, aliases: ["s"])
    parse("east", :east, aliases: ["e"])
    parse("west", :west, aliases: ["w"])
    parse("up", :up, aliases: ["u"])
    parse("down", :down, aliases: ["d"])
  end

  module(PerformCommand) do
    parse("perform", :run, fn command ->
      command |> spaces() |> text(:action)
    end)
  end

  module(ExertCommand) do
    parse("exert", :run, fn command ->
      command |> spaces() |> word(:function)
    end)
  end

  module(QuitCommand) do
    parse("quit", :run)
  end

  module(ReloadCommand) do
    parse("recompile", :recompile)
    parse("reload", :reload)
  end

  module(ReplyCommand) do
    parse("reply", :run, fn command ->
      command |> spaces() |> text(:text)
    end)
  end

  module(ScoreCommand) do
    parse("score", :run)
  end

  module(WieldCommand) do
    parse("wield", :wield, fn command ->
      command |> spaces() |> word(:item_name)
    end)

    parse("wear", :wear, fn command ->
      command |> spaces() |> word(:item_name)
    end)

    parse("unwield", :unwield, fn command ->
      command |> spaces() |> word(:item_name)
    end)

    parse("remove", :remove, fn command ->
      command |> spaces() |> word(:item_name)
    end)
  end

  module(SayCommand) do
    parse("say", :run, fn command ->
      command
      |> spaces()
      |> optional(
        repeat(
          choice([
            symbol("@") |> word(:at) |> spaces(),
            symbol(">") |> word(:adverb) |> spaces()
          ])
        )
      )
      |> text(:text)
    end)
  end

  module(TellCommand) do
    parse("tell", :run, fn command ->
      command
      |> spaces()
      |> word(:name)
      |> spaces()
      |> text(:text)
    end)
  end

  module(VersionCommand) do
    parse("version", :run)
  end

  module(WhisperCommand) do
    parse("whisper", :run, fn command ->
      command
      |> spaces()
      |> word(:name)
      |> spaces()
      |> text(:text)
    end)
  end

  module(WhoCommand) do
    parse("who", :run)
  end

  dynamic(EmoteCommand, :emote, [])
end
