defmodule ExVenture.Repo.Migrations.AddRegistrationFieldsToCharacterMetadata do
  use Ecto.Migration

  def up do
    alter table(:character_metadata) do
      # 注册/转世迁移承载字段（EX-注册与转世迁移计划.zh-CN.md Phase 0.2.1）

      # env: LPC `set()` 属性统一仓库（gender/born/surname/registered/age/
      #     reborn 计数/地府三关标记/startroom 等），落盘后重登不丢
      add(:env, :map, default: %{})

      # personality: 人格/天性（如 "国士无双"，仅转世时由 updated.c 设定；
      #           普通玩家恒 nil，与 LPC 一致）。注意不能与 belongs_to(:character)
      #           同名（schema 已用 :character 作角色外键关联），故列名用 personality。
      add(:personality, :string)

      # per/kar: 容貌/福缘，由新玩家「阎罗殿洗点」(washto) 分配，随机 5+random(26)
      add(:per, :integer, default: 20)
      add(:kar, :integer, default: 0)

      # setup_done: 注册问答是否已完成（首登判定，对应 LPC 每次注册即新角色）。
      # 默认 false → 新账号首次登录进入阎罗殿问答；迁移前已存在的角色在下方
      # 统一回填为 true，避免被新玩家流程误伤（Phase 0.3 风险点）。
      add(:setup_done, :boolean, default: false)
    end

    # 迁移前已存在（已基本成型的）角色视为已完成注册，跳过新玩家问答
    execute("UPDATE character_metadata SET setup_done = TRUE")
  end

  def down do
    alter table(:character_metadata) do
      remove(:env)
      remove(:personality)
      remove(:per)
      remove(:kar)
      remove(:setup_done)
    end
  end
end
