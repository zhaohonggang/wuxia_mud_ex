defmodule ExVenture.Repo.Migrations.AddPersonalizationToCharacterMetadata do
  use Ecto.Migration

  def change do
    alter table(:character_metadata) do
      # 昵称（cmds/usr/nick.c）
      add(:nickname, :text)
      # 玩家头衔（cmds/usr/title.c 玩家展示层；默认空字符串）
      add(:title, :text, default: "")
      # 个人界面选项位图（cmds/usr/option.c）%{"brief_room" => 1, ...}
      add(:option, :map, default: %{})
      # 自定义命令别名（cmds/usr/alias.c）%{"sc" => "score", ...}
      add(:alias_commands, :map, default: %{})
    end
  end
end
