// jue.c（提取器回归夹具：标题「绝杀」末字含 0x80 字节，验证 u 标志下不被截断）
#include <ansi.h>

inherit F_SSERVER;

#define SHA "「" HIR "绝杀" NOR "」"

int perform(object me, object target)
{
        if (! target) target = offensive_target(me);

        return notify_fail("你所使用的外功中没有这种功能。\n");
}
