with open('/app/lib/kantele/world/item.ex', 'r') as f:
    content = f.read()

# Add :flag to defstruct
content = content.replace(':armor_prop\n  ]', ':armor_prop,\n    :flag\n  ]')

# Add flag documentation after book line
content = content.replace(
    '`book` 秘籍五元组 `%Meta.Book{}`（消费端研习命令属 b 期）\n  """',
    '`book` 秘籍五元组 `%Meta.Book{}`（消费端研习命令属 b 期）\n  - `flag` 武器类型位掩码（LPC weapon.h：ONE_HANDED=0x1, SECONDARY=0x2, TWO_HANDED=0x4；缺省 0x1 单手）\n  """'
)

with open('/app/lib/kantele/world/item.ex', 'w') as f:
    f.write(content)

print('Done')