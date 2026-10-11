#!/usr/bin/env python3
"""
Enhanced Python port of scripts/translate_perform.exs

Extracts perform/exert data from LPC .c files and generates Elixir skeleton modules
with detailed logic extraction (AP/DP formulas, damage calc, messages, callbacks, etc.).
"""

import os
import re
import sys
from pathlib import Path
from typing import Optional, List, Tuple, Dict, Any, Set

CJK_RE = __import__('re').compile(r'[\u4e00-\u9fff]')


class TranslatePerform:
    def __init__(self):
        # Relative paths (skill_dir/move.ex) that must never be overwritten.
        # These were hand-written BEFORE translate_perform.py existed (the
        # commit-488139fb baseline), so the extractor only generates them if
        # missing; existing content is preserved verbatim.
        self.protected: Set[str] = self.load_protected()
        # Embed the full raw LPC source as a comment block so nothing is
        # silently dropped when the structured extractor can't parse a
        # construct (malformed quotes, unsupported calls, parser gaps, ...).
        # Set KUNGFU_EMBED_SOURCE=0 to disable (smaller skeletons).
        self.embed_source = os.getenv('KUNGFU_EMBED_SOURCE', '1') not in ('0', 'false', 'False', 'no')
        # Emit real code for the mechanically-derivable subset of the extracted
        # facts (level/map/resource gates, weapon check, literal resource
        # costs) instead of only comment stubs. Set KUNGFU_EMIT_CODE=1 to enable.
        self.emit_code = os.getenv('KUNGFU_EMIT_CODE', '0') not in ('0', 'false', 'False', 'no')
        # Regex patterns ported from Elixir version
        self.perform_re = re.compile(r'^\s*int\s+perform\s*\(', re.MULTILINE)
        self.exert_re = re.compile(r'^\s*int\s+exert\s*\(', re.MULTILINE)
        self.inherit_re = re.compile(r'\binherit\s+(F_\w+)\b')
        self.sense_re = re.compile(r'#define\s+\w+\s*"「"\s*\w*\s*"([^"「」]+)')
        self.level_gate_re = re.compile(r'query_skill\("([a-z0-9-]+)"[^)]*\)+\s*<\s*(\d+)')
        self.assign_re = re.compile(r'(\w+)\s*=\s*[^;\n]*?query_skill\("([a-z0-9-]+)"')
        self.var_gate_re = re.compile(r'\b(\w+)\s*<\s*(\d+)')
        self.map_gate_re = re.compile(r'query_skill_mapped\("(\w+)"\)\s*!=\s*"([a-z0-9-]+)"')
        self.prepared_gate_re = re.compile(r'query_skill_prepared\("(\w+)"\)\s*!=\s*"([a-z0-9-]+)"')
        self.resource_gate_re = re.compile(r'query\("(\w+)"[^)]*\)+\s*<\s*(\d+)')
        self.add_re = re.compile(r'\badd\("(\w+)",\s*(-?\d+)\)')
        self.set_re = re.compile(r'\bset\("(\w+)",\s*(\d+)\)')
        self.set_temp_re = re.compile(r'\bset_temp\("(\w+)"')
        self.add_temp_re = re.compile(r'\badd_temp\("apply\/(\w+)"')
        self.apply_temp_lit_re = re.compile(r'\badd_temp\("apply/(\w+)"\s*,\s*(-?\d+)\s*\)')
        self.busy_self_lit_re = re.compile(r'\bme->start_busy\(\s*(-?\d+)\s*\)')
        # Offensive payload received by the opponent (target/victim), used only
        # for the target-side resolve_incoming/4 skeleton.
        self.target_damage_re = re.compile(
            r'\b(?:target|victim)\s*->\s*receive_(damage|wound|heal)\("(\w+)",\s*'
            r'((?:[^(),\n]|\([^)]*\))+)(?:,\s*\w+)?\)')
        self.affect_re = re.compile(r'\baffect_by\("([a-z_]+)"')
        self.damage_re = re.compile(r'\bdo_damage\(')
        self.busy_re = re.compile(r'^\s*(?:\/\/)?\s*.*\b(?:start_busy|is_busy)\(', re.MULTILINE)
        self.notify_re = re.compile(r'notify_fail\(\s*"([^"\n]+)', re.MULTILINE)
        
        # Enhanced patterns for detailed logic extraction
        self.weapon_check_re = re.compile(r'query_temp\("weapon"\)[^)]*\)\s*\|\|\s*\(string\).*?query\("skill_type"\)\s*!=\s*"(\w+)"')
        self.offensive_target_re = re.compile(r'offensive_target\((\w+)\)')
        self.ap_calc_re = re.compile(r'(\w+)\s*=\s*([^;]+query_skill[^;]+);')
        self.dp_calc_re = re.compile(r'(\w+)\s*=\s*([^;]+query_skill[^;]+);')
        self.hit_formula_re = re.compile(r'if\s*\(\s*([^)]+)\s*>\s*([^)]+)\s*\)')
        self.damage_formula_re = re.compile(r'damage\s*=\s*([^;]+);')
        self.do_damage_detail_re = re.compile(r'do_damage\([^)]+,\s*([^,]+),\s*([^,]+),\s*([^)]+)\)')
        self.affect_by_detail_re = re.compile(r'affect_by\("([^"]+)",\s*\(\[\s*"level"\s*:\s*([^,]+),\s*"id"\s*:\s*([^,]+),\s*"duration"\s*:\s*([^\]]+)\s*\]\)')
        self.msg_construction_re = re.compile(r'msg\s*[+=]\s*([^;]+);')
        self.msg_initial_re = re.compile(r'msg\s*=\s*([^;]+);')
        self.color_codes_re = re.compile(r'(HIM|HIR|HIC|HIY|HIG|HIB|HIW|NOR|CYN|RED|GRN|YEL|BLU|MAG|WHT)')
        
        # New patterns for message extraction
        self.notify_fail_re = re.compile(r'notify_fail\s*\(\s*"([^"]+)"', re.MULTILINE)
        # Match if/else blocks with msg assignments inside
        self.hit_check_block_re = re.compile(
            r'if\s*\([^)]+ap[^)]+>\s*dp[^)]*\)\s*\{([^}]+)\}(?:\s*else\s*\{([^}]+)\})?',
            re.DOTALL
        )

        # New patterns for resource / damage / buff / throwing logic (gap analysis)
        self.receive_damage_re = re.compile(
            r'->receive_(damage|wound|heal)\("(\w+)",\s*((?:[^(),\n]|\([^)]*\))+)\s*,\s*(\w+)\)')
        self.receive_damage_2arg_re = re.compile(
            r'->receive_(damage|wound|heal)\("(\w+)",\s*((?:[^(),\n]|\([^)]*\))+)\)')
        self.resource_add_re = re.compile(
            r'\badd\("(neili|qi|jing|max_neili|max_qi|max_jing|combat_exp|shen|food|water|potential|ep|score|gongxian|weiwang|seniority|tianmo|lingtong|liangong)",\s*((?:[^()\n]|\([^)]*\))+)\)')
        self.resource_set_re = re.compile(
            r'\bset\("(neili|qi|jing|max_neili|max_qi|max_jing|combat_exp|shen|food|water|potential|ep|score|gongxian|weiwang|seniority|tianmo|lingtong|liangong)",\s*((?:[^()\n]|\([^)]*\))+)\)')
        self.delete_temp_re = re.compile(r'\bdelete_temp\("([a-z_/]+)"')
        self.start_call_out_re = re.compile(
            r'->start_call_out\(\(:\s*call_other,\s*__FILE__,\s*"(\w+)",\s*((?:[^)]|\n)*?)\s*:\),\s*((?:[^()\n]|\([^)]*\))+)\)')
        self.hit_ob_re = re.compile(r'->hit_ob\((\w+),\s*(\w+),\s*((?:[^(),\n]|\([^)]*\))+)\)')
        self.amount_re = re.compile(r'->(query_amount|set_amount)\(([^)]*)\)')
        self.exp_gate_re = re.compile(r'if\s*\(\s*random\((\w+)\)\s*>\s*(\w+)\)')
        self.ahinfo_re = re.compile(r'COMBAT_D->(clear_ahinfo|query_ahinfo)\(')
        self.neili_query_re = re.compile(r'query\("(neili|max_neili|qi|max_qi|jing|max_jing)"')
        self.query_amount_gate_re = re.compile(r'query_amount\(\)\s*<\s*(\d+)')

        # Patterns for misc gates/formulas lost by the first gap pass (audit)
        self.skill_type_eq_re = re.compile(r'query\("skill_type"\)\s*==\s*"(\w+)"')
        self.combat_exp_formula_re = re.compile(
            r'\b(\w+)\s*=\s*(to_int\(pow\([^;]*?query\("combat_exp"[^;]*?\));')
        self.combat_exp_inline_re = re.compile(
            r'random\((\w+)\)\s*>\s*[^;]*query\("combat_exp"\)')
        self.reset_action_re = re.compile(r'->reset_action\(')
        self.wield_re = re.compile(r'->(wield|unwield|equip|unequip)\(')
        self.improve_skill_re = re.compile(r'improve_skill\(')
        self.misc_gate_re = re.compile(r'query\("(gender|age|family|class)"')
        
    # Vitals fields (lib/kantele/character/vitals.ex) addressable by codegen.
    # LPC add()/set()/query() keys matching these map straight onto vitals.<key>.
    VITALS_FIELDS = ("qi", "max_qi", "jing", "max_jing", "jingli", "max_jingli", "neili", "max_neili")
    # Combat.temp keys supported by Kantele.Character.Combat (@applies_keys);
    # other apply/* keys (e.g. dispel_poison) have no K-side model and stay commented.
    APPLY_KEYS = ("attack", "defense", "damage", "unarmed_damage", "dodge", "parry", "armor")
    # Elixir formatter default line length (repo .formatter.exs sets none); a
    # generated `cond` clause wider than this must be emitted in broken form so
    # `mix format` leaves it untouched.
    COND_WIDTH = 98

    def classify(self, src: Path) -> Tuple[str, Optional[str]]:
        text = src.read_text(encoding='utf-8')

        if self.perform_re.search(text):
            kind = 'perform'
        elif self.exert_re.search(text):
            kind = 'exert'
        else:
            kind = 'skip'

        inherit_match = self.inherit_re.search(text)
        inherit = inherit_match.group(1) if inherit_match else None

        return kind, inherit

    def extract(self, src: Path) -> Optional[Dict[str, Any]]:
        kind, inherit = self.classify(src)

        if kind == 'skip':
            return None

        text = src.read_text(encoding='utf-8')
        # Use correct skill name (grandparent for exert/perform subdirs)
        skill = skill_from_path(src)
        move = src.stem

        # Extract all enhanced data
        weapon_type = self.extract_weapon_type(text)
        target_logic = self.extract_target_logic(text)
        all_fails = self.extract_all_fails(text)
        ap_dp = self.extract_ap_dp(text)
        hit_logic = self.extract_hit_logic(text)
        damage_logic = self.extract_damage_logic(text)
        do_damage_details = self.extract_do_damage_details(text)
        damage_descriptions = self.extract_damage_descriptions(text)
        affect_by_details = self.extract_affect_by_details(text)
        messages = self.extract_messages(text)
        gate_messages = self.extract_gate_messages(text)
        hit_miss_messages = self.extract_hit_miss_messages(text)
        color_codes = self.extract_color_codes(text)
        callbacks = self.extract_callbacks(text)
        attacker_vars = self._extract_attacker_vars(text)
        initial_msg = self.extract_initial_message(text)

        return {
            'skill': skill,
            'move': move,
            'kind': kind,
            'inherit': inherit,
            'title': self.title_of(text, move),
            # Original gates
            'level_gates': self.pairs(self.level_gate_re.findall(text)),
            'assign_refs': self.pairs(self.assign_re.findall(text)),
            'var_gates': self.pairs(self.var_gate_re.findall(text)),
            'map_gates': self.pairs(self.map_gate_re.findall(text)),
            'prepared_gates': self.pairs(self.prepared_gate_re.findall(text)),
            'resource_gates': self.pairs(self.resource_gate_re.findall(text)),
            # Position-aware gates + paired notify_fail (see pair_gates_with_messages)
            'gates_paired': self.pair_gates_with_messages(text, gate_messages),
            # Original effects
            'add_costs': self.pairs(self.dedup(self.add_re.findall(text))),
            'set_flags': self.pairs(self.dedup(self.set_re.findall(text))),
            'temp_set': self.dedup(self.set_temp_re.findall(text)),
            'apply_adds': self.dedup(self.add_temp_re.findall(text)),
            'apply_temp_literals': self.pairs(self.dedup(self.apply_temp_lit_re.findall(text))),
            'busy_self_literals': self.dedup([int(n) for n in self.busy_self_lit_re.findall(text)]),
            'affect_by': self.dedup(self.affect_re.findall(text)),
            'remote_damage': self.damage_re.search(text) is not None,
            'busy_lines': self.busy_lines(text),
            'first_fail': self.first_fail(text),
            # Enhanced extraction
            'weapon_type': weapon_type,
            'target_logic': target_logic,
            'all_fails': all_fails,
            'ap_dp': ap_dp,
            'hit_logic': hit_logic,
            'damage_logic': damage_logic,
            'do_damage_details': do_damage_details,
            'damage_descriptions': damage_descriptions,
            'affect_by_details': affect_by_details,
            'messages': messages,
            'gate_messages': gate_messages,
            'hit_miss_messages': hit_miss_messages,
            'color_codes': color_codes,
            'callbacks': callbacks,
            'initial_message': initial_msg,
            # Gap-analysis additions: resource / damage / buff / throwing
            'receive_damages': self.extract_receive_damages(text),
            'target_damages': self.extract_target_damages(text),
            'attacker_vars': attacker_vars,
            'resource_adds': self.extract_resource_calls(text, 'add'),
            'resource_sets': self.extract_resource_calls(text, 'set'),
            'buff_delete': self.dedup(self.delete_temp_re.findall(text)),
            'call_outs': self.extract_call_outs(text),
            'hit_obs': self.pairs(self.dedup(self.hit_ob_re.findall(text))),
            'amounts': self.dedup(self.amount_re.findall(text)),
            'exp_gates': self.pairs(self.dedup(self.exp_gate_re.findall(text))),
            'ahinfo': self.extract_ahinfo(text),
            'resource_queries': self.dedup(self.neili_query_re.findall(text)),
            'amount_gates': self.dedup(self.query_amount_gate_re.findall(text)),
            # Audit additions: misc gates / formulas
            'weapon_forbidden': self.dedup(self.skill_type_eq_re.findall(text)),
            'combat_exp_formulas': self.pairs(self.dedup(self.combat_exp_formula_re.findall(text))),
            'combat_exp_inline': self.dedup(self.dedup(self.combat_exp_inline_re.findall(text))),
            'reset_actions': self.reset_action_re.search(text) is not None,
            'wield_actions': self.dedup(self.wield_re.findall(text)),
            'improve_skills': self.dedup(self.improve_skill_re.findall(text)),
            'misc_gates': self.dedup(self.misc_gate_re.findall(text)),
            # Safety net: keep the raw LPC source so nothing is silently dropped
            # (malformed quotes, unsupported calls, brace/parser gaps, ...).
            'raw_source': text.rstrip('\n') if self.embed_source else '',
        }

    def extract_weapon_type(self, text: str) -> Optional[str]:
        """Extract required weapon skill_type from weapon check."""
        match = self.weapon_check_re.search(text)
        if match:
            return match.group(1)
        # Alternative pattern
        alt = re.search(r'query\("skill_type"\)\s*!=\s*"(\w+)"', text)
        if alt:
            return alt.group(1)
        return None

    def extract_target_logic(self, text: str) -> Dict[str, Any]:
        """Extract target selection logic."""
        return {
            'uses_offensive_target': bool(self.offensive_target_re.search(text)),
            'requires_fighting': 'is_fighting' in text,
            'requires_living': 'living(target)' in text or 'living (target)' in text,
        }

    def extract_all_fails(self, text: str) -> List[str]:
        """Extract all notify_fail messages."""
        return self.notify_re.findall(text)

    def extract_ap_dp(self, text: str) -> Dict[str, Any]:
        """Extract AP/DP calculation formulas."""
        ap_dp = {}
        
        # Find AP calculation (usually: ap = me->query_skill("sword") + me->query_skill("force"))
        ap_matches = re.findall(r'(ap|AP)\s*=\s*([^;]+);', text)
        for var, expr in ap_matches:
            ap_dp[f'{var}_formula'] = expr.strip()
            
        # Find DP calculation (usually: dp = target->query_skill("force") * 2)
        dp_matches = re.findall(r'(dp|DP)\s*=\s*([^;]+);', text)
        for var, expr in dp_matches:
            ap_dp[f'{var}_formula'] = expr.strip()
            
        return ap_dp

    def extract_hit_logic(self, text: str) -> Dict[str, Any]:
        """Extract hit probability formula using proper paren matching."""
        # Find all if conditions with balanced parentheses
        if_matches = list(re.finditer(r'if\s*\(', text))
        
        for match in if_matches:
            start = match.end()
            paren_count = 1
            pos = start
            
            while pos < len(text) and paren_count > 0:
                if text[pos] == '(':
                    paren_count += 1
                elif text[pos] == ')':
                    paren_count -= 1
                pos += 1
            
            if paren_count == 0:
                condition = text[start:pos-1].strip()
                
                # Skip if operator is part of !=, >=, <=
                # Check for comparison operators in order of precedence
                for op in ['>=', '<=', '>', '<']:
                    # Make sure it's not part of !=
                    if op in condition and not (op == '>' and '!=' in condition):
                        left, right = condition.split(op, 1)
                        left = left.strip()
                        right = right.strip()
                        
                        # Check if it's a combat formula: ap/dp in arithmetic context
                        # Must have ap or dp on both sides, with arithmetic operators
                        if (re.search(r'\b(ap|AP|dp|DP)\b', left) and 
                            re.search(r'\b(ap|AP|dp|DP)\b', right) and
                            re.search(r'[+\-*/]', left)):
                            return {
                                'left_side': left,
                                'right_side': right,
                                'operator': op
                            }
        return {}

    def extract_damage_logic(self, text: str) -> Dict[str, Any]:
        """Extract damage calculation formula."""
        dmg_match = re.search(r'damage\s*=\s*([^;]+);', text)
        if dmg_match:
            return {'formula': dmg_match.group(1).strip()}
        return {}

    def extract_do_damage_details(self, text: str) -> List[Dict[str, Any]]:
        """Extract do_damage call details: attack_type, damage_factor, callback."""
        details = []
        # Pattern: do_damage(me, target, WEAPON_ATTACK, damage, 70, (: final, ... :))
        matches = re.finditer(
            r'do_damage\([^,]+,\s*[^,]+,\s*(\w+),\s*([^,]+),\s*(\d+),\s*\(:\s*(\w+)',
            text
        )
        for m in matches:
            details.append({
                'attack_type': m.group(1),
                'damage_var': m.group(2).strip(),
                'damage_factor': int(m.group(3)),
                'callback': m.group(4)
            })
        return details

    # A `do_damage` call's 6th argument is either:
    #   - absent           -> no description text
    #   - a closure `(: ... :)` -> no description text (it's a death callback)
    #   - a quoted string  -> the literal damage description
    #   - a bare variable  -> e.g. `pmsg`, resolved from a nearby assignment
    # The description often spans several concatenated literals, so it must be
    # scanned paren/quote-aware rather than matched with a single regex.
    def extract_damage_descriptions(self, text: str) -> List[Dict[str, str]]:
        """Extract the description text of each `do_damage(...)` call.

        Returns a list of {'desc': <cleaned text>} in source order.  Calls with
        no description (absent arg, closure, or unresolvable variable) are
        omitted.  `$N`/`$n`/`$p`/`$P` placeholders and the surrounding `\\n` are
        preserved; colour macros are stripped by `_clean_message_fragment`.
        """
        out = []
        for m in re.finditer(r'do_damage\s*\(', text):
            end = self._scan_balanced(text, m.end())  # m.end()-1 == '('
            if end == -1:
                continue
            call = text[m.end():end - 1]
            # Split the call into top-level args (comma at depth 0, outside
            # strings/closure).
            args = self._split_top_level_args(call)
            if len(args) < 6:
                continue
            arg6 = args[5].strip()
            # Unwrap a leading colour macro / whitespace; bail on closures.
            if arg6.startswith('(:'):
                continue
            desc = None
            if '"' in arg6:
                desc = arg6
            elif re.fullmatch(r'[A-Za-z_]\w*', arg6):
                # bare variable: resolve to its most recent assignment
                assign = None
                for am in re.finditer(
                        r'\b' + re.escape(arg6) + r'\s*=\s*', text[:m.start()]):
                    assign = am
                if assign:
                    vstart = assign.end()
                    v_is_str = False
                    depth = 0
                    i = vstart
                    while i < len(text):
                        ch = text[i]
                        if ch == '"':
                            v_is_str = True
                        elif ch == ';' and depth == 0:
                            break
                        elif ch == '(':
                            depth += 1
                        elif ch == ')':
                            depth = max(0, depth - 1)
                        i += 1
                    if v_is_str:
                        desc = text[vstart:i]
            if not desc:
                continue
            clean = self._clean_message_fragment(desc)
            if clean and CJK_RE.search(clean):
                out.append({'desc': clean})
        return out

    def _split_top_level_args(self, s: str) -> List[str]:
        """Split a call's argument list on commas at paren/string depth 0."""
        args, buf, depth, in_str = [], [], 0, False
        i = 0
        while i < len(s):
            ch = s[i]
            if in_str:
                buf.append(ch)
                if ch == '\\' and i + 1 < len(s):
                    buf.append(s[i + 1])
                    i += 2
                    continue
                if ch == '"':
                    in_str = False
                i += 1
                continue
            if ch == '"':
                in_str = True
                buf.append(ch)
            elif ch in '([':
                depth += 1
                buf.append(ch)
            elif ch in ')]':
                depth = max(0, depth - 1)
                buf.append(ch)
            elif ch == ',' and depth == 0:
                args.append(''.join(buf))
                buf = []
            else:
                buf.append(ch)
            i += 1
        if buf:
            args.append(''.join(buf))
        return args


    def extract_affect_by_details(self, text: str) -> List[Dict[str, Any]]:
        """Extract affect_by callback details: buff name, level formula, id, duration formula."""
        details = []
        # Pattern: target->affect_by("damo_luanqi", ([ "level" : lvl + random(lvl), "id" : me->query("id"), "duration" : 5 + random(lvl / 20) ]))
        matches = re.finditer(
            r'affect_by\("([^"]+)",\s*\(\[\s*"level"\s*:\s*([^,]+),\s*"id"\s*:\s*([^,]+),\s*"duration"\s*:\s*([^\]]+)\s*\]\)',
            text
        )
        for m in matches:
            details.append({
                'buff_name': m.group(1),
                'level_formula': m.group(2).strip(),
                'id_formula': m.group(3).strip(),
                'duration_formula': m.group(4).strip()
            })
        return details

    def extract_messages(self, text: str) -> Dict[str, List[str]]:
            """Extract combat messages (success, fail, etc.)."""
            messages = {'success': [], 'fail': [], 'other': []}

            # Extract message_combatd calls and msg += patterns
            msg_lines = re.findall(r'msg\s*[+=]\s*([^;]+);', text)
            for line in msg_lines:
                line = line.strip()
                if 'HIR' in line or '$n' in line and 'HIR' in line:
                    messages['success'].append(line)
                elif 'CYN' in line and ('内力深厚' in line or '化解' in line or '没有起到任何作用' in line):
                    messages['fail'].append(line)
                else:
                    messages['other'].append(line)

            return messages

    def extract_initial_message(self, text: str) -> Optional[str]:
        """Extract the initial message assignment (msg = ...) before hit check.

        Handles multi-line messages by finding the first 'msg = ' assignment
        and capturing everything up to the ';' that terminates the statement
        (a ';' outside of string literals, at paren depth 0).  The naive
        regex `[^;]+(?:;[^;]*)*` greedily swallowed the rest of the function
        body (including `ap = ...`, `dp = ...` assignments) whenever a later
        ';' appeared after the message, which leaked garbage identifiers like
        "strikethrowingdodgeparryneili" into the generated broadcast text.
        """
        match = re.search(r'msg\s*=\s*', text)
        if not match:
            return None
        start = match.end()
        in_str = False
        depth = 0
        i = start
        while i < len(text):
            ch = text[i]
            if in_str:
                if ch == '\\':
                    i += 2
                    continue
                if ch == '"':
                    in_str = False
                i += 1
                continue
            if ch == '"':
                in_str = True
            elif ch == '(':
                depth += 1
            elif ch == ')':
                depth = max(0, depth - 1)
            elif ch == ';' and depth == 0:
                return text[start:i].strip()
            i += 1
        return text[start:].strip()

    def extract_gate_messages(self, text: str) -> Dict[str, Any]:
        """Extract notify_fail messages and associate with gate types by context.

        Returns a dict with the per-type message lists PLUS `ordered`: a list of
        ``(gate_type, message)`` pairs **in source order**.

        Why both: the per-type lists lose source order, so an emitter that zips
        ``level_gates[i]`` with ``gate_msgs['level'][i]`` mis-pairs whenever the
        two regexes collect their gates in different orders (e.g. yiyang-zhi/die
        has `yiyang-zhi < 200 -> "你一阳指诀不够"` *before* `force < 300 ->
        "你的内功火候不够"`, but level_gate_re returns force first).  Consumers
        should prefer `ordered` and match each gate condition to the FIRST
        unmatched notify_fail of the same type that appears *after* it.
        """
        gate_msgs = {
            'level': [],
            'mapped': [],
            'prepared': [],
            'resource': [],
            'weapon': [],
            'other': [],
            'living': [],
        }
        ordered: List[Tuple[str, int, int]] = []  # (gate_type, pos, msg_id)
        order_store: List[Tuple[str, str]] = []   # ordered (gate_type, clean)

        # Current context gate type - only changes when a NEW gate condition is seen
        current_gate = 'other'
        lines = text.split('\n')

        for line in lines:
            stripped = line.strip()

            # Detect gate conditions - these SET the current gate for subsequent notify_fail
            if 'living(target)' in stripped and 'notify_fail' not in stripped:
                current_gate = 'living'
            elif 'is_fighting' in stripped and 'notify_fail' not in stripped:
                current_gate = 'other'
            elif 'query_skill_prepared(' in stripped and '!=' in stripped and 'notify_fail' not in stripped:
                current_gate = 'prepared'
            elif 'query_skill_mapped(' in stripped and '!=' in stripped and 'notify_fail' not in stripped:
                current_gate = 'mapped'
            elif 'query_skill(' in stripped and '<' in stripped and 'notify_fail' not in stripped:
                current_gate = 'level'
            elif 'query("skill_type")' in stripped and '!=' in stripped and 'notify_fail' not in stripped:
                current_gate = 'weapon'
            elif 'query_temp("weapon")' in stripped and 'notify_fail' not in stripped:
                current_gate = 'weapon'
            elif 'query("' in stripped and '<' in stripped and 'notify_fail' not in stripped:
                # resource gate: neili, qi, etc.
                current_gate = 'resource'

            # Extract notify_fail - associate with current gate
            for m in self.notify_fail_re.finditer(stripped):
                msg = m.group(1)
                clean = self._clean_message_fragment(msg)
                if clean:
                    gate_msgs[current_gate].append(clean)
                    order_store.append((current_gate, clean))

        # Deduplicate the per-type lists
        for k in gate_msgs:
            gate_msgs[k] = self.dedup(gate_msgs[k])

        gate_msgs['ordered'] = order_store
        return gate_msgs

    def gate_msgs_in_order(self, data: Dict[str, Any], gate_type: str) -> List[str]:
        """Return that type's notify_fail messages in SOURCE order (undeduped).

        The `ordered` stream preserves the true sequence; filter it by type so
        emitters can consume messages positionally in the same order the
        conditions were parsed.
        """
        gate = data.get('gate_messages', {}) or {}
        ordered = gate.get('ordered')
        if ordered:
            return [msg for (t, msg) in ordered if t == gate_type]
        return list(gate.get(gate_type, []))

    def pair_gates_with_messages(self, text: str, gate_messages: Dict[str, Any]) -> List[Dict[str, str]]:
        """Pair each notifiable gate condition with the notify_fail that follows it.

        Walks the source once, recording every gate *condition* with its offset,
        then each notify_fail with its offset, and binds each condition to the
        first still-unconsumed notify_fail appearing after it (the LPC idiom is
        always ``if (cond) return notify_fail("msg");``).  This fixes the
        positional zip bug where ``level_gates`` order differs from
        ``gate_messages`` order.

        Returns a list of dicts: {kind, skill/field, value, msg, pos}.
        `kind` is one of level|mapped|prepared|resource|weapon.
        """
        kinds = [
            ('level', re.compile(r'query_skill\("([a-z0-9-]+)"[^)]*\)+\s*<\s*(\d+)')),
            ('mapped', re.compile(r'query_skill_mapped\("(\w+)"\)\s*!=\s*"([a-z0-9-]+)"')),
            ('prepared', re.compile(r'query_skill_prepared\("(\w+)"\)\s*!=\s*"([a-z0-9-]+)"')),
            ('resource', re.compile(r'query\("(\w+)"[^)]*\)+\s*<\s*(\d+)')),
            ('weapon', re.compile(r'query_temp\("weapon"\)[^)]*\)\s*(?:\|\||&&|>)')),
        ]
        conds = []  # (pos, kind, arg1, arg2)
        for kind, rx in kinds:
            for m in rx.finditer(text):
                g = m.groups()
                a1 = g[0] if g else ''
                a2 = g[1] if len(g) > 1 else ''
                conds.append((m.start(), kind, a1 or '', a2 or ''))
        fails = [(m.start(), self._clean_message_fragment(m.group(1)))
                 for m in self.notify_fail_re.finditer(text)]
        fails = [(p, c) for (p, c) in fails if c]
        conds.sort(key=lambda x: x[0])
        fails.sort(key=lambda x: x[0])

        used = set()
        out = []
        for (pos, kind, a1, a2) in conds:
            msg = ''
            for i, (fp, fmsg) in enumerate(fails):
                if i in used:
                    continue
                if fp > pos:
                    msg = fmsg
                    used.add(i)
                    break
            # Only keep gates whose message is CJK (avoid pairing to code noise)
            if msg and CJK_RE.search(msg):
                out.append({'kind': kind, 'arg1': a1, 'arg2': a2, 'msg': msg, 'pos': pos})
        return out

    def extract_hit_miss_messages(self, text: str) -> Dict[str, List[str]]:
        """Extract hit/miss messages from msg construction in hit check block.
        
        Looks for all combat if (ap > dp) blocks and extracts msg += in each branch.
        Uses balanced brace/paren matching to handle nested structures.
        """
        messages = {'hit': [], 'miss': []}
        
        # Find ALL hit check if statements (ap > dp)
        if_pos = text.find('if (')
        while if_pos != -1:
            # Check if this if statement contains ap and dp with >
            paren_start, paren_end = self._find_balanced_parens(text, if_pos + 3)  # after 'if '
            if paren_start != -1:
                condition = text[paren_start:paren_end+1]
                if 'ap' in condition and 'dp' in condition and '>' in condition:
                    # Found a hit check!
                    # Find opening brace after the condition
                    brace_pos = text.find('{', paren_end)
                    if brace_pos != -1:
                        hit_start, hit_end = self._find_balanced_braces(text, brace_pos)
                        if hit_start != -1:
                            hit_block = text[hit_start + 1:hit_end]
                            
                            # Look for else after hit block
                            else_pos = text.find('else', hit_end)
                            miss_block = ''
                            if else_pos != -1 and else_pos < hit_end + 100:
                                else_brace = text.find('{', else_pos)
                                if else_brace != -1:
                                    miss_start, miss_end = self._find_balanced_braces(text, else_brace)
                                    if miss_start != -1:
                                        miss_block = text[miss_start + 1:miss_end]
                            
                            # Extract msg += from hit branch
                            hit_msgs = []
                            for m in re.finditer(r'msg\s*[+=]\s*([^;]+);', hit_block):
                                clean = self._clean_message_fragment(m.group(1))
                                if clean and not self._is_function_call(clean):
                                    hit_msgs.append(clean)
                            
                            # Extract msg += from miss branch
                            miss_msgs = []
                            if miss_block:
                                for m in re.finditer(r'msg\s*[+=]\s*([^;]+);', miss_block):
                                    clean = self._clean_message_fragment(m.group(1))
                                    if clean and not self._is_function_call(clean):
                                        miss_msgs.append(clean)
                            
                            # Also check for message_combatd in hit branch (final message).
                            # Skip `message_combatd(msg, me, target)` -- a bare
                            # variable argument just re-emits the accumulated
                            # msg buffer, it is not a literal message.
                            for m in re.finditer(r'message_combatd\s*\(([^)]+)\)', hit_block):
                                msg_arg = m.group(1).split(',')[0].strip()
                                if not re.search(r'"', msg_arg):
                                    continue
                                clean = self._clean_message_fragment(msg_arg)
                                if clean and clean not in hit_msgs:
                                    hit_msgs.append(clean)
                            
                            # Add to messages (extend, not replace)
                            messages['hit'].extend(hit_msgs)
                            messages['miss'].extend(miss_msgs)
            
            # Try next 'if ('
            if_pos = text.find('if (', if_pos + 1)
        
        # ---- do_damage-based path ----
        # Many performs use a hit condition that does not literally name
        # `ap`/`dp` (e.g. `random(my_exp) > ob_exp`, `random(me->query_skill(...))`)
        # so the ap/dp heuristic above misses them.  A do_damage(...) call is
        # only ever made in the HIT branch, so locate every do_damage call, find
        # the block that contains it, and pair it with the following else block.
        dd_pos = text.find('do_damage(')
        while dd_pos != -1:
            brace = text.rfind('{', 0, dd_pos)
            if brace != -1:
                bs, be = self._find_balanced_braces(text, brace)
                if bs != -1 and be != -1 and bs <= dd_pos <= be:
                    # confirm this block belongs to an if (not a bare {} block)
                    head = text[max(0, brace - 120):brace]
                    if re.search(r'if\s*\([^)]*\)\s*$', head):
                        hit_block = text[bs + 1:be]
                        # else block after it
                        miss_block = ''
                        else_pos = text.find('else', be)
                        if else_pos != -1 and else_pos < be + 400:
                            eb = text.find('{', else_pos)
                            if eb != -1:
                                es2, ee2 = self._find_balanced_braces(text, eb)
                                if es2 != -1 and ee2 != -1:
                                    miss_block = text[es2 + 1:ee2]
                        # hit: msg = / msg += in the hit branch, plus do_damage desc
                        hit_msgs = []
                        for m in re.finditer(r'msg\s*[+=]\s*([^;]+);', hit_block):
                            clean = self._clean_message_fragment(m.group(1))
                            if clean and not self._is_function_call(clean):
                                hit_msgs.append(clean)
                        miss_msgs = []
                        if miss_block:
                            for m in re.finditer(r'msg\s*[+=]\s*([^;]+);', miss_block):
                                clean = self._clean_message_fragment(m.group(1))
                                if clean and not self._is_function_call(clean):
                                    miss_msgs.append(clean)
                        messages['hit'].extend(hit_msgs)
                        messages['miss'].extend(miss_msgs)
            dd_pos = text.find('do_damage(', dd_pos + 1)
        
        # Deduplicate
        messages['hit'] = self.dedup(messages['hit'])
        messages['miss'] = self.dedup(messages['miss'])
        
        return messages

    def extract_color_codes(self, text: str) -> List[str]:
        """Extract ANSI color codes used."""
        return self.dedup(self.color_codes_re.findall(text))

    def extract_callbacks(self, text: str) -> List[Dict[str, Any]]:
        """Extract callback functions (like `final` in luan.c)."""
        callbacks = []
        # Look for function definitions after the main perform function
        func_matches = re.finditer(
            r'(string|int|void)\s+(\w+)\s*\(([^)]*)\)\s*\{([^}]+)\}',
            text,
            re.DOTALL
        )
        for m in func_matches:
            if m.group(2) not in ['perform', 'exert']:
                callbacks.append({
                    'name': m.group(2),
                    'return_type': m.group(1),
                    'params': m.group(3).strip(),
                    'body': m.group(4).strip()[:200]  # truncate for readability
                })
        return callbacks

    def _scan_balanced(self, text: str, start: int, end_char: str = ')') -> int:
        """Return index just past the matching close paren, starting after an
        opening '(' at position `start` (text[start-1] == '('). Handles nesting.
        """
        depth = 1
        i = start
        n = len(text)
        while i < n:
            c = text[i]
            if c == '(':
                depth += 1
            elif c == end_char:
                depth -= 1
                if depth == 0:
                    return i + 1
            i += 1
        return -1

    def _is_function_call(self, text: str) -> bool:
        """Check if a cleaned message fragment is actually a function call
        (like COMBAT_D->do_damage or message_combatd) rather than a user message."""
        # Common function call patterns in msg assignments
        func_patterns = [
            'COMBAT_D->do_damage',
            'message_combatd',
            'message_vision',
            'tell_object',
            'tell_room',
            'tell_user',
            'write',
            'sprintf',
            'sprintf(',
            '->',
            'allocate',
            'map(',
            'filter(',
            'sort_array',
        ]
        for pattern in func_patterns:
            if pattern in text:
                return True
        return False

    def _find_balanced_braces(self, text: str, start: int) -> Tuple[int, int]:
        """Find matching { ... } pair starting from `start` (which should be at '{').
        Returns (brace_start, brace_end) where brace_end is index of matching '}'.
        Returns (-1, -1) if not found.
        """
        if start >= len(text) or text[start] != '{':
            return -1, -1
        depth = 1
        i = start + 1
        n = len(text)
        while i < n:
            c = text[i]
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    return start, i
            i += 1
        return -1, -1

    def _find_balanced_parens(self, text: str, start: int) -> Tuple[int, int]:
        """Find matching ( ... ) pair starting from `start` (which should be at '(').
        Returns (paren_start, paren_end) where paren_end is index of matching ')'.
        Returns (-1, -1) if not found.
        """
        if start >= len(text) or text[start] != '(':
            return -1, -1
        depth = 1
        i = start + 1
        n = len(text)
        while i < n:
            c = text[i]
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    return start, i
            i += 1
        return -1, -1

    def _call_args(self, text: str, callee: str) -> List[List[str]]:
        """Extract argument lists of every `->callee(...)` call, splitting on
        top-level commas (parens/strings preserved). Returns list of arg lists.
        """
        results = []
        rx = re.compile(re.escape(callee) + r'\s*\(')
        for m in rx.finditer(text):
            end = self._scan_balanced(text, m.end(), ')')
            if end < 0:
                continue
            inner = text[m.end():end - 1]
            args = []
            depth = 0
            cur = []
            in_str = False
            for ch in inner:
                if ch == '"':
                    in_str = not in_str
                    cur.append(ch)
                elif ch == '(' and not in_str:
                    depth += 1
                    cur.append(ch)
                elif ch == ')' and not in_str:
                    depth -= 1
                    cur.append(ch)
                elif ch == ',' and depth == 0 and not in_str:
                    args.append(''.join(cur).strip())
                    cur = []
                else:
                    cur.append(ch)
            if cur:
                args.append(''.join(cur).strip())
            results.append(args)
        return results

    def extract_resource_calls(self, text: str, verb: str) -> List[Tuple[str, str]]:
        """Extract add("neili", V) / set("neili", V) with V possibly a nested
        expression like -(300 + random(200)). Balanced-paren aware.
        """
        RESOURCES = (
            'neili', 'qi', 'jing', 'max_neili', 'max_qi', 'max_jing',
            'combat_exp', 'shen', 'food', 'water', 'potential', 'ep', 'score',
            'gongxian', 'weiwang', 'seniority', 'tianmo', 'lingtong', 'liangong',
        )
        out = []
        for args in self._call_args(text, f'->{verb}'):
            if len(args) >= 2:
                name = args[0].strip('"').strip()
                if name in RESOURCES:
                    out.append((name, args[1]))
        return self.pairs(self.dedup(out))

    def extract_receive_damages(self, text: str) -> List[Dict[str, Any]]:
        """Extract direct damage/wound/heal calls:
        me->receive_damage("qi", skill * 3 / 2 + random(skill * 3 / 2), me)   (3-arg)
        me->receive_damage("qi", 0)                                          (2-arg, source=None)
        """
        details = []
        for m in self.receive_damage_re.finditer(text):
            kind, part, formula, source = m.groups()
            details.append({
                'kind': kind,
                'part': part,
                'formula': formula.strip(),
                'source': source,
            })
        # 2-arg variant: source is implicit (environment / caller)
        for m in self.receive_damage_2arg_re.finditer(text):
            kind, part, formula = m.groups()
            details.append({
                'kind': kind,
                'part': part,
                'formula': formula.strip(),
                'source': None,
            })
        return details

    def extract_target_damages(self, text: str) -> List[Dict[str, Any]]:
        """Direct damage/wound/heal calls whose receiver is the opponent
        (target/victim), i.e. the perform's own offensive payload. Used only to
        seed the target-side resolve_incoming/4 skeleton comment."""
        results = []
        for m in self.target_damage_re.finditer(text):
            results.append({'kind': m.group(1), 'part': m.group(2), 'formula': m.group(3).strip()})
        # Also cover do_damage(COMBAT_D->do_damage) to target/victim/ob
        for m in re.finditer(r'do_damage\(([^)]+)\)', text):
            g = m.group(1)
            # split respecting parens
            args = []
            depth = 0; cur = ''
            for ch in g:
                if ch == "(" or ch == "[": depth += 1
                if ch == ")" or ch == "]": depth -= 1
                if ch == "," and depth == 0:
                    args.append(cur.strip()); cur = ''
                else:
                    cur += ch
            args.append(cur.strip())
            if len(args) > 3:
                tgt = args[1] if len(args) > 1 else '';
                if tgt in ('target', 'victim', 'ob'):
                    # damage var is typically args[3]
                    dmg_expr = args[3] if len(args) > 3 else '';
                    if dmg_expr:
                        results.append({'kind': 'damage', 'part': 'qi', 'formula': dmg_expr})
        # Deduplicate by (kind, part, formula)
        seen = set()
        deduped = []
        for r in results:
            key = (r['kind'], r['part'], r['formula'])
            if key not in seen:
                seen.add(key)
                deduped.append(r)
        return deduped

    def extract_call_outs(self, text: str) -> List[Dict[str, Any]]:
        """Extract delayed callbacks:
        me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill :), skill)
        """
        details = []
        for m in self.start_call_out_re.finditer(text):
            fn, args, delay = m.groups()
            details.append({
                'fn': fn,
                'args': args.strip(),
                'delay': delay.strip(),
            })
        return details

    def extract_ahinfo(self, text: str) -> Dict[str, bool]:
        """COMBAT_D aggregate hit info usage."""
        return {
            'clear': 'clear_ahinfo' in text,
            'query': 'query_ahinfo' in text,
        }

    # ===== LPC Expression Translator (restricted arithmetic subset) =====
    # Supports: numbers, + - * / %, (int) cast, random(X), me->query_skill("x"),
    # target->query_skill("x"), identifiers from `scope`.
    # Division -> div/2, % -> rem/2, random -> Engine.rand(rng, ...).
    # Raises ExprError if unsupported.

    class ExprError(Exception):
        pass

    _TOKEN_RE = re.compile(
        r'\s*('
        r'0x[0-9a-fA-F]+|\d+|'
        r'random|int|'
        r'->|'
        r'[A-Za-z_]\w*|'
        r'"[^"]*"|'
        r'[-+*/%(),]'
        r')'
    )

    def _tokenize(self, s):
        toks = []
        pos = 0
        while pos < len(s):
            m = self._TOKEN_RE.match(s, pos)
            if not m:
                if s[pos].isspace():
                    pos += 1
                    continue
                raise self.ExprError(f"bad token at {pos}: {s[pos:pos+20]!r}")
            toks.append(m.group(1))
            pos = m.end()
        return toks

    def _translate_expr(self, expr, scope, self_obj='me', stats_var='stats'):
        """Translate a single LPC arithmetic expression to Elixir."""
        ExprError = self.ExprError
        class Parser:
            def __init__(self, toks, scope, self_obj, stats_var):
                self.toks = toks
                self.i = 0
                self.scope = scope
                self.self_obj = self_obj
                self.stats_var = stats_var

            def peek(self):
                return self.toks[self.i] if self.i < len(self.toks) else None

            def next(self):
                t = self.peek()
                if t is None:
                    raise ExprError("unexpected end")
                self.i += 1
                return t

            def expect(self, t):
                got = self.next()
                if got != t:
                    raise ExprError(f"expected {t!r} got {got!r}")

            def parse(self):
                e = self.expr()
                if self.peek() is not None:
                    raise ExprError(f"trailing tokens: {self.toks[self.i:]}")
                return e

            def expr(self):
                left = self.term()
                while self.peek() in ('+', '-'):
                    op = self.next()
                    right = self.term()
                    left = f"({left} {op} {right})"
                return left

            def term(self):
                left = self.unary()
                while self.peek() in ('*', '/', '%'):
                    op = self.next()
                    right = self.unary()
                    if op == '*':
                        left = f"({left} * {right})"
                    elif op == '/':
                        left = f"div({left}, {right})"
                    else:
                        left = f"rem({left}, {right})"
                return left

            def unary(self):
                if self.peek() == '-':
                    self.next()
                    return f"(-{self.unary()})"
                return self.atom()

            def atom(self):
                t = self.peek()
                if t == '(':
                    # (int) cast?
                    if self.i + 2 < len(self.toks) and self.toks[self.i + 1] == 'int' and self.toks[self.i + 2] == ')':
                        self.i += 3
                        return self.atom()
                    self.next()
                    e = self.expr()
                    self.expect(')')
                    return e
                if t == 'random':
                    self.next()
                    self.expect('(')
                    e = self.expr()
                    self.expect(')')
                    return f"Engine.rand(rng, {e})"
                if t is not None and re.fullmatch(r'0x[0-9a-fA-F]+|\d+', t):
                    self.next()
                    return str(int(t, 0))
                if t is not None and re.fullmatch(r'[A-Za-z_]\w*', t):
                    name = self.next()
                    if self.peek() == '->':
                        self.next()
                        fn = self.next()
                        if fn != 'query_skill':
                            raise ExprError(f"unsupported method {fn}")
                        self.expect('(')
                        sk = self.next()
                        if not (sk.startswith('"')):
                            raise ExprError("query_skill expects string literal")
                        skill = sk.strip('"')
                        if self.peek() == ',':
                            self.next()
                            self.next()  # the int flag
                        self.expect(')')
                        if name != self.self_obj:
                            raise ExprError(f"query_skill on other object {name}")
                        return f'Stats.skill({self.stats_var}, "{skill}")'
                    if name == 'int':
                        return self.atom()  # stray cast
                    if name not in self.scope:
                        raise ExprError(f"unknown ident {name}")
                    return self.scope[name]
                raise ExprError(f"unexpected token {t!r}")

        toks = self._tokenize(expr)
        return Parser(toks, scope, self_obj, stats_var).parse()

    def _extract_attacker_vars(self, text: str) -> Dict[str, Any]:
        """Extract attacker-side variable assignments that are translatable
        (no target-> references), in textual order. Returns dict
        var_name -> {'expr': translated_elixir, 'raw': raw_expr}."""
        # Find all assignments: name = expr;
        assign_re = re.compile(r'\b(\w+)\s*=\s*([^;]+?);', re.DOTALL)
        vars_result = {}
        scope = {}
        for m in assign_re.finditer(text):
            name = m.group(1)
            rhs = m.group(2).strip()
            # Skip if rhs references target (not available attacker-side)
            if 'target->' in rhs or 'victim->' in rhs:
                continue
            # Skip known non-scalar/unsupported patterns
            if any(kw in rhs for kw in ('allocate', 'map(', 'filter(', 'sort_array', '::', '->query_temp')):
                continue
            if '->query_skill(' in rhs and not rhs.lstrip().startswith('me->'):
                continue
            # Skip self-referential assignments (e.g., damage = damage/2 + ...)
            # where LHS variable appears on RHS (would be circular in Elixir)
            if re.search(rf'\b{re.escape(name)}\b', rhs):
                continue
            try:
                # Allow me->query_skill, random, arithmetic, (int)
                translated = self._translate_expr(rhs, scope, self_obj='me', stats_var='stats')
                scope[name] = name  # later vars can reference this
                vars_result[name] = {'expr': translated, 'raw': rhs}
            except self.ExprError:
                pass
        return vars_result

    def title_of(self, text: str, move: str) -> str:
        match = self.sense_re.search(text)
        if match:
            return match.group(1).strip()
        return move

    def first_fail(self, text: str) -> Optional[str]:
        match = self.notify_re.search(text)
        if match:
            return match.group(1)
        return None

    def busy_lines(self, text: str) -> List[str]:
        lines = text.split('\n')
        return [line.strip() for line in lines if self.busy_re.match(line)]

    def dedup(self, items: List) -> List:
        return sorted(list(set(items)))

    def pairs(self, items: List[Tuple]) -> List[Tuple]:
        return sorted(list(set(items)))

    def skill_dir(self, skill: str) -> str:
        return skill.replace('-', '_')

    def camel(self, id_str: str) -> str:
        return ''.join(part.capitalize() for part in id_str.split('-'))

    def module_name(self, skill: str, move: str) -> str:
        return f"Kantele.Combat.Skills.Performs.{self.camel(skill)}.{self.camel(move)}"

    def comment_block(self, text: str, indent: str = "      #   ") -> str:
        return '\n'.join(indent + line for line in text.split('\n'))

    @staticmethod
    def _elixir_fmt(obj) -> str:
        """Format Python dict/list/tuple as Elixir map/keyword/list (compact)."""
        if isinstance(obj, dict):
            if not obj:
                return '%{}'
            items = [f'{TranslatePerform._elixir_fmt(k)}: {TranslatePerform._elixir_fmt(v)}'
                     for k, v in sorted(obj.items())]
            return '%{' + ', '.join(items) + '}'
        if isinstance(obj, list):
            if not obj:
                return '[]'
            return '[' + ', '.join(TranslatePerform._elixir_fmt(v) for v in obj) + ']'
        if isinstance(obj, tuple):
            return '{' + ', '.join(TranslatePerform._elixir_fmt(v) for v in obj) + '}'
        if isinstance(obj, str):
            return f'"{obj}"'
        if isinstance(obj, bool):
            return 'true' if obj else 'false'
        return str(obj)

    def render_skeleton(self, data: Dict[str, Any]) -> str:
        if self.emit_code:
            return self.render_code_skeleton(data)
        return self.render_comment_skeleton(data)

    # ------------------------------------------------------------------
    # Code-emitting promoter (KUNGFU_EMIT_CODE=1)
    #
    # Turns the mechanically-derivable extracted facts into compilable
    # Elixir: perform-known check, level/map/resource gates, weapon check,
    # and literal resource add/set costs. Ambiguous semantics (messages,
    # affect_by, apply/<skill> values, call_outs, hit/damage) stay as
    # TODO(migrate) comments plus the raw LPC source for manual porting.
    # ------------------------------------------------------------------

    @staticmethod
    def _literal_int(expr: str) -> Optional[int]:
        match = re.fullmatch(r'\s*(-?\d+)\s*', expr or '')
        return int(match.group(1)) if match else None

    def _clean_message_fragment(self, frag: str) -> str:
        """Extract readable text from LPC message fragment.

        Input like: 'HIY "突然只听$N" HIY "喝道："'
        Output: '突然只听$N喝道：' (color codes stripped, $N/$n/$p preserved)

        Also handles C string-concatenation expressions that mix literals with
        function calls, e.g.
            HIY "但见$N" HIY "手中" + weapon->query("name") + HIY "窜动不"
        Only the *top-level* string literals are message text.  A function-call
        operand such as `weapon->query("name")` must NOT contribute its inner
        `"name"` argument -- doing so leaked the literal identifier into the
        broadcast (tiangang-chenfa/bai, never-defeated/yuce, ...).  Such
        operands are replaced with a runtime marker so the text reads
        naturally instead of containing a stray ASCII token.
        """
        if not frag:
            return ''
        operands = self._split_concat_operands(frag)
        parts = []
        for op in operands:
            op = op.strip()
            if not op:
                continue
            # Pure string literal(s): keep their contents.
            if self._is_string_operand(op):
                for m in re.finditer(r'"([^"]*)"', op):
                    parts.append(m.group(1))
                continue
            # A bare variable (`name`) or an accessor call whose only argument
            # is a bare identifier (`query("name")`) is a *runtime value*, not
            # message text -- emit a placeholder and drop the inner literal.
            if self._is_bare_runtime_ref(op):
                parts.append(self._placeholder_for_call(op))
                continue
            # Otherwise (e.g. `do_damage(me, target, ..., HIR "结果$p" ...)`)
            # the operand wraps real message literals: keep them.
            found = re.findall(r'"([^"]*)"', op)
            if found:
                parts.extend(found)
            elif not re.search(r'[A-Za-z_]\w*\s*\(', op):
                parts.append(op)
        if not parts:
            # No quoted strings / operands found - treat as plain text.
            parts = [frag]
        joined = ''.join(parts)
        # Collapse runs of the same placeholder introduced by adjacent call
        # operands (e.g. weapon->query("base_unit") + weapon->name() -> 某物)
        for ph in ('某人', '某物'):
            joined = re.sub(ph + r'(?:' + ph + r')+', ph, joined)
        # Strip color codes (HIR, HIC, HIY, HIG, HIB, HIW, NOR, CYN, RED, GRN, YEL, BLU, MAG, WHT)
        joined = re.sub(r'\b(HIM|HIR|HIC|HIY|HIG|HIB|HIW|NOR|CYN|RED|GRN|YEL|BLU|MAG|WHT)\b', '', joined)
        # Normalize escaped newlines
        joined = joined.replace('\\n', '\n').strip()
        return joined

    @staticmethod
    def _placeholder_for_call(op: str) -> str:
        """Pick a readable Chinese placeholder for a runtime reference.

        Only *person*-name lookups read as a person (`me->name()`,
        `query("couple/name")`).  Object lookups -- `weapon->name()`,
        `query("base_unit")` -- read as an object even though the accessor is
        named `name`, so a weapon becomes 某物, not 某人.
        """
        # You / the actor / a person-specific field.
        if re.search(r'\b(?:me|target|obj|who|player)\s*->\s*name\s*\(', op):
            return '某人'
        if re.search(r'query\s*\(\s*"(?:[^"]*/)?name"\s*\)', op):
            return '某人'
        return '某物'

    # A color-code token list shared by the operand classifiers.
    _COLOR_TOKENS = r'\b(HIM|HIR|HIC|HIY|HIG|HIB|HIW|NOR|CYN|RED|GRN|YEL|BLU|MAG|WHT)\b'

    def _is_string_operand(self, op: str) -> bool:
        """True when the operand is only color codes + string literals
        (no function call, no bare identifier)."""
        stripped = re.sub(self._COLOR_TOKENS, '', op)
        # Remove all quoted literals, then check nothing meaningful remains.
        leftover = re.sub(r'"(?:[^"\\]|\\.)*"', '', stripped).strip()
        return leftover == ''

    def _is_bare_runtime_ref(self, op: str) -> bool:
        """True when the operand is a runtime *value* reference rather than an
        expression that merely wraps message text.

        Matches:
          - a plain variable / member chain: `name`, `me`, `a->b`
          - an accessor call with a single bare-identifier argument:
            `query("name")`, `weapon->query("base_unit")`, `obj->name()`
        Deliberately does NOT match calls that carry real message literals as
        arguments (e.g. `do_damage(..., HIR "结果$p" ...)`), so those keep
        their text.
        """
        stripped = re.sub(self._COLOR_TOKENS, '', op).strip()
        if not stripped:
            return False
        # Plain variable / member chain (no parentheses at all).
        if re.fullmatch(r'[A-Za-z_]\w*(?:\s*(?:\.|->)\s*[A-Za-z_]\w*)*', stripped):
            return True
        # `...query("x")` / `...name()` style: exactly one call, its arguments
        # (if any) are bare identifiers only, and there is no other literal.
        call = re.fullmatch(
            r'[A-Za-z_]\w*(?:\s*(?:\.|->)\s*[A-Za-z_]\w*)*\s*\(([^()]*)\)\s*',
            stripped,
        )
        if call:
            args = call.group(1).strip()
            if args == '':
                return True
            # Args must be only quoted bare identifiers / numbers, no color
            # codes, no CJK, no nested message text.
            if re.fullmatch(r'(?:"[A-Za-z0-9_/]*"\s*,?\s*)+', args):
                return True
        return False

    @staticmethod
    def _split_concat_operands(frag: str) -> List[str]:
        """Split a C expression on top-level `+` (ignoring `+` inside strings
        and parentheses).  Returns the operand substrings in order."""
        operands = []
        buf = []
        in_str = False
        depth = 0
        i = 0
        while i < len(frag):
            ch = frag[i]
            if in_str:
                buf.append(ch)
                if ch == '\\' and i + 1 < len(frag):
                    buf.append(frag[i + 1])
                    i += 2
                    continue
                if ch == '"':
                    in_str = False
                i += 1
                continue
            if ch == '"':
                in_str = True
                buf.append(ch)
            elif ch == '(':
                depth += 1
                buf.append(ch)
            elif ch == ')':
                depth = max(0, depth - 1)
                buf.append(ch)
            elif ch == '+' and depth == 0:
                operands.append(''.join(buf))
                buf = []
            else:
                buf.append(ch)
            i += 1
        operands.append(''.join(buf))
        return operands

    def _render_cond(self, clauses) -> str:
        """Render `cond` arms (list of (expr, body)) in the exact form the
        Elixir formatter produces: compact when every clause fits, otherwise all
        clauses broken with a blank line between them."""
        compact = [f'      {expr} -> {body}' for expr, body in clauses]
        if all(len(line) <= self.COND_WIDTH for line in compact):
            return '\n'.join(compact)
        blocks = [f'      {expr} ->\n        {body}' for expr, body in clauses]
        return '\n\n'.join(blocks)

    def _emit_level_checks(self, data: Dict[str, Any]) -> Optional[Tuple[str, str]]:
        # Derive conditions from `gates_paired`, which preserves LPC source
        # order.  `level_gates` cannot be used: `pairs()` applies
        # `sorted(set(...))`, which reorders the checks alphabetically and
        # makes the emitter's `cond` short-circuit in the wrong order (e.g.
        # bagua-biao evaluates before bagua-zhang, so a character low in both
        # sees the wrong rejection message first).
        paired = [g for g in data.get('gates_paired', []) if g['kind'] == 'level']
        if paired:
            pairs = [(g['arg1'], g['arg2']) for g in paired]
            msgs_for = [g['msg'] for g in paired]
        else:
            pairs = [(s, n) for (s, n) in data.get('level_gates', []) if s and n]
            msgs_for = data.get('gate_messages', {}).get('level', [])
        if not pairs:
            return None
        clauses = []
        for i, (s, n) in enumerate(pairs):
            msg = msgs_for[i] if i < len(msgs_for) else f'TODO(migrate) {s} 等级不足。'
            clauses.append((f'Stats.skill(stats, "{s}") < {n}', f'{{:error, "{msg}\\n"}}'))
        clauses.append(('true', ':ok'))
        body = (
            "    stats = character.meta.stats\n\n"
            "    cond do\n"
            f"{self._render_cond(clauses)}\n"
            "    end"
        )
        return ("check_levels", body)

    def _emit_map_checks(self, data: Dict[str, Any]) -> Optional[Tuple[str, str]]:
        # Prefer source-ordered gates from `gates_paired` (see _emit_level_checks).
        paired_mapped = [g for g in data.get('gates_paired', []) if g['kind'] == 'mapped']
        paired_prep = [g for g in data.get('gates_paired', []) if g['kind'] == 'prepared']
        if paired_mapped:
            pairs = [(g['arg1'], g['arg2']) for g in paired_mapped]
            mapped_msgs = [g['msg'] for g in paired_mapped]
        else:
            pairs = [(u, s) for (u, s) in data.get('map_gates', []) if u and s]
            mapped_msgs = data.get('gate_messages', {}).get('mapped', [])
        if paired_prep:
            prep_pairs = [(g['arg1'], g['arg2']) for g in paired_prep]
            prepared_msgs = [g['msg'] for g in paired_prep]
        else:
            prep_pairs = [(u, s) for (u, s) in data.get('prepared_gates', []) if u and s]
            prepared_msgs = data.get('gate_messages', {}).get('prepared', [])
        if not pairs and not prep_pairs:
            return None
        clauses = []
        for i, (u, s) in enumerate(pairs):
            msg = mapped_msgs[i] if i < len(mapped_msgs) else f'TODO(migrate) 未激发 {s}。'
            clauses.append((f'Stats.mapped(stats, "{u}") != "{s}"', f'{{:error, "{msg}\\n"}}'))
        # LPC query_skill_prepared("strike") != "bagua-zhang" — the usage must
        # have a prepared perform whose skill matches.  Elixir side keeps the
        # prepared perform id ("bagua-zhang/xian"); compare its skill prefix.
        #
        # NOTE: emitted only when KUNGFU_EMIT_PREPARED_GATES=1.  The prepared
        # gate is a genuine LPC check, but many test fixtures populate `mapped`
        # without `prepared`, so emitting it unconditionally changes runtime
        # behaviour for performs that used to cast.  Flip the flag on after
        # the fixtures/registrations are updated alongside.
        if os.getenv('KUNGFU_EMIT_PREPARED_GATES', '0') not in ('0', 'false', 'False', 'no'):
            for i, (u, s) in enumerate(prep_pairs):
                msg = prepared_msgs[i] if i < len(prepared_msgs) else f'TODO(migrate) 未准备 {s}。'
                clauses.append(
                    (f'Stats.prepared_perform(stats, "{u}") == nil '
                     f'or String.split(Stats.prepared_perform(stats, "{u}"), "/") |> hd() != "{s}"',
                     f'{{:error, "{msg}\\n"}}')
                )
        clauses.append(('true', ':ok'))
        body = (
            "    stats = character.meta.stats\n\n"
            "    cond do\n"
            f"{self._render_cond(clauses)}\n"
            "    end"
        )
        return ("check_mapped", body)

    def _emit_resource_checks(self, data: Dict[str, Any]) -> Optional[Tuple[str, str]]:
        # Prefer source-ordered gates from `gates_paired` (see _emit_level_checks).
        paired_res = [g for g in data.get('gates_paired', []) if g['kind'] == 'resource']
        if paired_res:
            pairs = [(g['arg1'], g['arg2']) for g in paired_res
                     if g['arg1'] in self.VITALS_FIELDS and g['arg2']]
            gate_msgs = [g['msg'] for g in paired_res
                         if g['arg1'] in self.VITALS_FIELDS and g['arg2']]
        else:
            pairs = [(r, n) for (r, n) in data.get('resource_gates', [])
                     if r in self.VITALS_FIELDS and n]
            gate_msgs = data.get('gate_messages', {}).get('resource', [])
        if not pairs:
            return None
        clauses = []
        for i, (r, n) in enumerate(pairs):
            msg = gate_msgs[i] if i < len(gate_msgs) else f'TODO(migrate) {r} 不足。'
            clauses.append((f'vitals.{r} < {n}', f'{{:error, "{msg}\\n"}}'))
        clauses.append(('true', ':ok'))
        body = (
            "    vitals = character.meta.vitals\n\n"
            "    cond do\n"
            f"{self._render_cond(clauses)}\n"
            "    end"
        )
        return ("check_resources", body)

    def _weapon_gate_direction(self, raw: str) -> Optional[str]:
        """Determine the direction of the weapon gate from raw LPC source.

        Returns 'must_be_empty' when the gate rejects a wielded weapon
        (`if (me->query_temp("weapon"))` / `objectp(...)` positive check,
        message like "只能空手施展"), 'must_be_wielded' when the gate requires a
        weapon (`if (!objectp(weapon = me->query_temp("weapon")))`, message like
        "你必须手持武器"), or None when the direction is not mechanically
        decidable.
        """
        if not raw:
            return None
        # 1) positive check: weapon present -> reject (bare-handed performs)
        m = re.search(
            r'if\s*\(\s*objectp\(\s*(?:me\s*->\s*)?query_temp\("weapon"\)\s*\)\s*\)',
            raw)
        if m:
            return 'must_be_empty'
        # 2) `if (me->query_temp("weapon"))` (truthy) -> reject when wielded
        m = re.search(
            r'if\s*\(\s*(?:me\s*->\s*)?query_temp\("weapon"\)\s*\)', raw)
        if m:
            return 'must_be_empty'
        # 3) `if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))`
        m = re.search(
            r'if\s*\(\s*(?:me\s*->\s*)?query_temp\("weapon"\)\s*\|\|', raw)
        if m:
            return 'must_be_empty'
        # 4) negative check: weapon missing -> reject (weapon-required performs)
        m = re.search(
            r'if\s*\(\s*!\s*objectp\s*\(\s*(?:\w+\s*=\s*)?(?:me\s*->\s*)?query_temp\("weapon"\)',
            raw)
        if m:
            return 'must_be_wielded'
        return None

    # Messages that unambiguously mean "you must be empty-handed".  A gate may
    # only be emitted as a real `combat.weapon != nil` check when its text is
    # in this set AND the direction helper agrees.  This guards against
    # positional message↔condition mismatches: LPC often has *two* weapon-ish
    # gates (e.g. `objectp(weapon)` → "只能空手施展" AND
    # `!objectp(anqi = me->query_temp("handing"))` → "手中并没有拿着暗器"),
    # where the second concerns the `handing` slot, not `weapon` at all.
    _EMPTY_HAND_HINTS = ('空手', '空着', '双手必须空', '没拿', '手中没')
    _WIELD_HINTS = ('必须手持', '须持', '手中必须有', '武器不对', '兵器不对',
                    '没刀还使', '手中必须拿着', '手中并没有拿')

    def _emit_weapon_check(self, data: Dict[str, Any]) -> Optional[Tuple[str, str]]:
        # Use extracted weapon gate messages if available
        gate_msgs = data.get('gate_messages', {}).get('weapon', [])
        if not gate_msgs:
            return None
        # Determine the gate direction from the raw LPC source.
        direction = self._weapon_gate_direction(data.get('raw_source', ''))
        # Only trust the direction when the accompanying message text agrees
        # with it.  `gate_msgs[0]` is the first weapon-ish notify_fail, which is
        # not necessarily the one that pairs with the matched condition.
        msg0 = gate_msgs[0]
        agrees = (
            (direction == 'must_be_empty' and any(h in msg0 for h in self._EMPTY_HAND_HINTS))
            or (direction == 'must_be_wielded' and any(h in msg0 for h in self._WIELD_HINTS))
        )
        if not agrees:
            # Direction is not mechanically certain (or the message/condition
            # pairing is ambiguous): preserve the texts as comments and return
            # :ok rather than emitting a gate that may reject legal casts.
            body = (
                "    # TODO(migrate) 武器检查需人工核对（自动提取的文案仅供参考）：\n"
                + ''.join('    #   {:error, "' + msg + '\\n"}\n' for msg in gate_msgs)
                + "    :ok\n"
            )
            return ("check_weapon", body)
        if direction == 'must_be_empty':
            clause = ('combat.weapon != nil', f'{{:error, "{msg0}\\n"}}')
        else:
            clause = ('combat.weapon == nil', f'{{:error, "{msg0}\\n"}}')
        clauses = [clause, ('true', ':ok')]
        body = (
            "    combat = character.meta.combat\n\n"
            "    cond do\n"
            f"{self._render_cond(clauses)}\n"
            "    end"
        )
        return ("check_weapon", body)

    def _emit_living_check(self, data: Dict[str, Any]) -> Optional[Tuple[str, str]]:
        """Return the `! living(target)` guard message for the target side.

        LPC guards the perform with `if (! living(target)) return
        notify_fail("对方都已经这样了，用不着这么费力吧？\\n");`.  The
        attacker only holds a lightweight enemy *ref* (`%{id, pid, name,
        room_id}`) with no `status`, so the check cannot run attacker-side —
        it must run in `resolve_incoming/4` on the victim process, which has the
        full character (including `meta.combat.dead`).  This helper just
        surfaces the message; `_emit_resolve_incoming` inlines the guard.
        """
        msgs = data.get('gate_messages', {}).get('living', [])
        return msgs[0] if msgs else None

    def _emit_other_checks(self, data: Dict[str, Any]) -> Optional[Tuple[str, str]]:
        """Emit checks for notify_fail messages that couldn't be categorized.

        These gates (can_perform / is_fighting / living / busy / temp-state /
        item checks) are already covered by dedicated helpers where they are
        mechanically decidable (`check_perform_known`, `target/1`, target-side
        living check).  Associating an `other` message with a concrete
        condition by position is unreliable, so keep the texts as a TODO
        comment instead of emitting a never-firing `false ->` placeholder or a
        mis-bound check.  Function always returns :ok.

        The `can_perform` text ("你所使用的外功中没有这种功能") is already
        emitted verbatim by `check_perform_known/1`, so it is filtered out here
        to avoid a duplicate that would otherwise look like a missing gate.
        """
        gate_msgs = [
            m for m in data.get('gate_messages', {}).get('other', [])
            if '你所使用的外功中没有这种功能' not in m
        ]
        if not gate_msgs:
            return None
        body = (
            "    # TODO(migrate) 其它门槛（战斗/临时状态/道具等）需人工核对：\n"
            + ''.join('    #   {:error, "' + msg + '\\n"}\n' for msg in gate_msgs)
            + "    :ok\n"
        )
        return ("check_other", body)

    def _emit_check_gates(self, data: Dict[str, Any]) -> Tuple[str, bool]:
        """Return (code, uses_stats)."""
        helpers = [h for h in (
            self._emit_level_checks(data),
            self._emit_map_checks(data),
            self._emit_resource_checks(data),
            self._emit_weapon_check(data),
            self._emit_other_checks(data),
        ) if h]

        uses_stats = any(name in ('check_levels', 'check_mapped') for name, _ in helpers)

        if not helpers:
            return ("  defp check_gates(_character), do: :ok\n", uses_stats)

        if len(helpers) == 1:
            name, _ = helpers[0]
            head = ("  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对\n"
                    f"  defp check_gates(character), do: {name}(character)\n")
        else:
            first, *rest = helpers
            clauses = f":ok <- {first[0]}(character)"
            for name, _ in rest:
                clauses += f",\n         :ok <- {name}(character)"
            head = (
                "  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对\n"
                "  defp check_gates(character) do\n"
                f"    with {clauses} do\n"
                "      :ok\n"
                "    end\n"
                "  end\n"
            )

        parts = [head]
        for name, body in helpers:
            parts.append(f"\n  defp {name}(character) do\n{body}\n  end\n")
        return (''.join(parts), uses_stats)

    def _emit_apply_effect(self, data: Dict[str, Any]) -> Tuple[str, bool, bool]:
        """Return (body_lines, uses_vitals, uses_combat)."""
        ops = []  # (field, kind, value)

        def add_op(field: str, kind: str, value: int):
            if field in self.VITALS_FIELDS:
                ops.append((field, kind, value))

        for key, val in data.get('add_costs', []):
            iv = self._literal_int(val)
            if iv is not None:
                add_op(key, 'add', iv)
        for res, expr in data.get('resource_adds', []):
            iv = self._literal_int(expr)
            if iv is not None:
                add_op(res, 'add', iv)
        for key, val in data.get('set_flags', []):
            iv = self._literal_int(val)
            if iv is not None:
                add_op(key, 'set', iv)
        for res, expr in data.get('resource_sets', []):
            iv = self._literal_int(expr)
            if iv is not None:
                add_op(res, 'set', iv)

        def dedup_keep(values):
            seen = set()
            return [v for v in values if not (v in seen or seen.add(v))]

        ops = dedup_keep(ops)

        apply_vals = {}
        for key, val in data.get('apply_temp_literals', []):
            if key in self.APPLY_KEYS:
                iv = self._literal_int(val)
                if iv is not None:
                    apply_vals.setdefault(key, set()).add(iv)

        # Only emit a key when it has a single distinct literal value; conflicting
        # branches (e.g. +50 on hit / -50 on miss) stay in the facts comment.
        apply_adds = [(key, next(iter(vals))) for key, vals in apply_vals.items() if len(vals) == 1]

        busy = dedup_keep([n for n in data.get('busy_self_literals', []) if isinstance(n, int) and n > 0])

        # Amount changes (throwing weapons, etc.)
        amounts = data.get('amounts', [])

        if not ops and not apply_adds and not busy and not amounts:
            return ('', False, False)

        lines = [
            "    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播",
        ]

        if ops:
            lines.append("    vitals = character.meta.vitals")
            for field, kind, value in ops:
                if kind == 'set':
                    lines.append(f"    vitals = %{{vitals | {field}: {value}}}")
                elif value < 0:
                    lines.append(f"    vitals = %{{vitals | {field}: vitals.{field} - {abs(value)}}}")
                else:
                    lines.append(f"    vitals = %{{vitals | {field}: vitals.{field} + {value}}}")
            lines.append("    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}")

        if apply_adds or busy:
            lines.append("    combat = character.meta.combat")
            if apply_adds:
                pairs = ', '.join(f"{key}: {value}" for key, value in apply_adds)
                lines.append(f"    combat = Combat.apply_temp(combat, %{{{pairs}}})")
            for rounds in busy:
                lines.append(f"    combat = Combat.start_busy(combat, {rounds})")
            lines.append("    character = %{character | meta: Map.put(character.meta, :combat, combat)}")

        if amounts:
            lines.append("    # TODO(migrate) 暗器/投掷数量扣减逻辑需人工核对")
            for op, arg in amounts:
                lines.append(f"    #   {op}({arg})")

        # Initial message broadcast
        initial_msg = data.get('initial_message')
        if initial_msg:
            clean = self._clean_message_fragment(initial_msg)
            if clean:
                lines.append(f'    conn = Broadcast.publish(conn, "{clean}", n1: character.name)')

        return ('\n'.join(lines) + '\n\n', bool(ops), bool(apply_adds or busy or amounts))

    def _emit_resolve_incoming(self, data: Dict[str, Any]) -> str:
        """Generate executable target-side resolve_incoming/4.
        
        Translates target damage formulas using attacker-provided data
        (ap, damage, level, skill) + target stats (for dp/dodge/parry).
        Falls back to TODO comments for unsupported constructs.
        """
        target_damages = data.get('target_damages', [])
        attacker_vars = data.get('attacker_vars', {})
        hit_logic = data.get('hit_logic', {})
        messages = data.get('messages', {})
        
        # Determine which attacker vars are available in event data
        avail = set()
        if attacker_vars:
            avail.update(attacker_vars.keys())
        # Always provide these if mentioned in formulas
        if any('level' in d['formula'] for d in target_damages):
            avail.add('level')
        if any('skill' in d['formula'] for d in target_damages):
            avail.add('skill')

        # Payload keys the attacker sends and resolve_incoming binds:
        # level/skill/ap/damage/rng (canonical), plus any attacker var that
        # got translated into the event payload.  Formulas that reference
        # `damage` (e.g. `damage / 4`) failed translation with
        # `unknown ident damage` because `damage` was never registered in the
        # target-side scope.
        avail.update({'level', 'skill', 'ap', 'damage', 'rng'})

        # Build target scope: attacker-provided vars + target stats
        tscope = {name: name for name in avail}
        tscope.update({
            'dp': 'dp', 'dodge': 'dodge', 'parry': 'parry',
            'con': 'con', 'str': 'str', 'dex': 'dex', 'int': 'int',
        })
        
        # Translate target damage formulas
        damage_lines = []
        fallback_comments = []
        for d in target_damages:
            try:
                expr = self._translate_expr(d['formula'], tscope, self_obj='target', stats_var='stats')
                part = d['part']
                if d['kind'] == 'damage':
                    damage_lines.append(f"    vitals = Vitals.damage(vitals, :{part}, {expr})")
                elif d['kind'] == 'wound':
                    damage_lines.append(f"    vitals = Vitals.wound(vitals, :{part}, {expr})")
                elif d['kind'] == 'heal':
                    damage_lines.append(f"    vitals = Vitals.heal(vitals, :{part}, {expr})")
            except self.ExprError as e:
                fallback_comments.append(
                    f'  #   target->receive_{d["kind"]}("{d["part"]}", {d["formula"]})  # UNSUPPORTED: {e}'
                )
        
        # Compute dp from target stats if needed
        needs_dp = bool(damage_lines) or any('dp' in d['formula'] for d in target_damages)
        dp_line = '    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")\n' if needs_dp else ''
        
        # Hit check: use ap from attacker, dp from target
        has_ap = 'ap' in avail or any('ap' in d['formula'] for d in target_damages)
        hit_check_lines = []
        if has_ap and needs_dp:
            hit_check_lines = [
                '    hit = div(ap, 2) + Engine.rand(rng, ap) > dp',
                '    vitals = character.meta.vitals',
                '    if hit do',
            ]
            indent = '      '
            close = '    end\n'
        elif has_ap:
            # Have ap but no dp needed - just apply damage
            hit_check_lines = [
                '    vitals = character.meta.vitals',
            ]
            indent = '    '
            close = ''
        else:
            # No ap - just apply damage unconditionally
            hit_check_lines = [
                '    vitals = character.meta.vitals',
            ]
            indent = '    '
            close = ''
        
        # Messages: use extracted hit/miss messages from LPC
        hit_miss_msgs = data.get('hit_miss_messages', {})
        hit_msgs = hit_miss_msgs.get('hit', [])
        miss_msgs = hit_miss_msgs.get('miss', [])

        # Fallback to old messages extraction if new ones empty
        if not miss_msgs:
            fail_frags = messages.get('fail', ['$n躲过了$N的攻击！\n'])
            miss_msgs = [self._clean_message_fragment(f) for f in fail_frags if self._clean_message_fragment(f)]

        # `do_damage(...)` 的第 6 参数是原始 LPC 的伤害描述文案（例如
        # “结果$p闪避不及，被$P这招插中…”）。它比 hit_miss_messages 里
        # 泛化的“$n被$N击中！”更贴近原文，因此优先采用。
        dmg_descs = [d['desc'] for d in data.get('damage_descriptions', []) if d.get('desc')]
        if dmg_descs:
            hit_msgs = dmg_descs
        elif not hit_msgs:
            success_frags = messages.get('success', ['$n被$N击中！\n'])
            hit_msgs = [self._clean_message_fragment(f) for f in success_frags if self._clean_message_fragment(f)]

        lines = [
            "",
            "  @impl true",
            "  def resolve_incoming(conn, character, attacker, data) do",
        ]
        # Target-side `! living(target)` guard: LPC refuses the perform when the
        # victim is already a corpse.  The victim process has the full
        # character here, so `meta.combat.dead` is authoritative.  The callback
        # must return a conn (it is not a with-chain), so broadcast the LPC
        # message and skip the damage instead of returning a tuple.
        living_msg = self._emit_living_check(data)
        if living_msg:
            lines.extend([
                "    if character.meta.combat.dead do",
                f'      Broadcast.publish(conn, "{living_msg}", n1: attacker.name, n2: character.name)',
                "    else",
                "      do_resolve_incoming(conn, character, attacker, data)",
                "    end",
                "  end",
                "",
                "  defp do_resolve_incoming(conn, character, attacker, data) do",
            ])
        lines.append("    _stats = character.meta.stats")  # prefix unused
        # Add data bindings - only for vars actually used
        used_in_damage = set()
        for d in target_damages:
            # Collect identifiers from formula (rough heuristic)
            for name in avail:
                if name in d['formula']:
                    used_in_damage.add(name)
        
        # Determine what we need from data
        need_level = 'level' in used_in_damage or any('level' in d['formula'] for d in target_damages)
        need_skill = 'skill' in used_in_damage or any('skill' in d['formula'] for d in target_damages)
        need_ap = 'ap' in used_in_damage or has_ap
        need_damage = 'damage' in used_in_damage
        
        # Always define level first if needed by skill or directly
        if need_level or need_skill:
            lines.append("    level = Map.get(data, :level, 0)")
        if need_skill:
            lines.append("    skill = Map.get(data, :skill, 0)")
        if need_ap:
            lines.append("    ap = Map.get(data, :ap, 0)")
        if need_damage:
            lines.append("    damage = Map.get(data, :damage, 0)")
        if needs_dp or need_ap or (has_ap and needs_dp):
            lines.append("    rng = Map.get(data, :rng, &:rand.uniform/1)")
        
        # stats for target-side queries
        if needs_dp or any('dodge' in d['formula'] or 'parry' in d['formula'] for d in target_damages):
            lines.append("    stats = character.meta.stats")
        else:
            lines.append("    _stats = character.meta.stats")  # unused
        
        if dp_line:
            lines.append(dp_line.rstrip())
        
        lines.extend(hit_check_lines)
        
        if damage_lines:
            lines.extend([f"{indent}{line}" for line in damage_lines])
        
        if close:
            lines.append(close)
        
        lines.append(f"    character = %{{character | meta: %{{character.meta | vitals: vitals}}}}")
        
        # Performs.feedback
        neili_cost = 0
        for key, val in data.get('add_costs', []):
            if key == 'neili':
                iv = self._literal_int(val)
                if iv is not None and iv < 0:
                    neili_cost = abs(iv)
        busy_rounds = 0
        for n in data.get('busy_self_literals', []):
            if isinstance(n, int) and n > 0:
                busy_rounds = max(busy_rounds, n)
        if neili_cost > 0 or busy_rounds > 0:
            lines.append(f"    Performs.feedback(attacker, {neili_cost}, {busy_rounds or 1})")
        
        # Messages with $N/$n placeholders.  When LPC has several variants
        # (multiple `do_damage` branches / `msg +=` alternatives inside the hit
        # or miss branch) pick one at random, matching the original
        # `random(...)`-driven branch selection.  Otherwise emit the literal.
        def _msg_expr(msgs: List[str], fallback: str) -> str:
            seen = []
            for s in msgs:
                if s and s not in seen:
                    seen.append(s)
            if not seen:
                seen = [fallback]
            if len(seen) == 1:
                return f'"{seen[0]}"'
            inner = ', '.join(f'"{s}"' for s in seen)
            return f'Enum.random([{inner}])'

        hit_expr = _msg_expr(hit_msgs, '$n被$N击中！')
        miss_expr = _msg_expr(miss_msgs, '$n躲过了$N的攻击！')

        if has_ap and needs_dp:
            lines.append(f'    msg = if hit, do: {hit_expr}, else: {miss_expr}')
        else:
            lines.append(f'    msg = {hit_expr}')
        lines.append('    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)')
        
        lines.append('    conn')
        lines.append('    |> Broadcast.publish(result)')
        lines.append('    |> put_character(character)')
        lines.append('  end')
        
        if fallback_comments:
            lines = ["", "  # TODO(migrate) 目标侧结算：命中/闪避/伤害公式与文案需按原始源码（见文末）补齐。"] + fallback_comments + lines
        
        return '\n'.join(lines) + '\n'

    def render_code_skeleton(self, data: Dict[str, Any]) -> str:
        mod = self.module_name(data['skill'], data['move'])
        skill = data['skill']
        move = data['move']
        is_perform = data['kind'] == 'perform'

        gates_str, gates_use_stats = self._emit_check_gates(data)
        effect_str, effect_use_vitals, effect_use_combat = self._emit_apply_effect(data)

        uses_stats = is_perform or gates_use_stats or effect_use_vitals

        target_logic = data.get('target_logic') or {}
        offensive = bool(target_logic.get('uses_offensive_target')) or bool(target_logic.get('requires_fighting'))
        use_incoming = is_perform and offensive

        aliases = ["  alias Kantele.Combat.Broadcast", "  alias Kantele.Character.CommandView"]
        if effect_use_combat:
            aliases.append("  alias Kantele.Character.Combat")
        if uses_stats:
            aliases.append("  alias Kantele.Character.Stats")
        if use_incoming:
            aliases.append("  alias Kalevala.Event")
            aliases.append("  alias Kantele.Combat.Engine")
            aliases.append("  alias Kantele.Character.Vitals")
            aliases.append("  alias Kantele.Combat.Messages")
            aliases.append("  alias Kantele.Combat.Performs")
        aliases_str = '\n'.join(aliases)

        perform_known = ''
        if is_perform:
            perform_known = (
                "\n  defp check_perform_known(character) do\n"
                "    if Stats.perform_known?(character.meta.stats, @perform_id) do\n"
                "      :ok\n"
                "    else\n"
                '      {:error, "你所使用的外功中没有这种功能。\\n"}\n'
                "    end\n"
                "  end\n"
            )
            with_head = (":ok <- check_perform_known(character),\n"
                         "         :ok <- check_gates(character)")
        else:
            with_head = ":ok <- check_gates(character)"

        # Offensive performs: compute attacker vars, select target, dispatch event
        helpers = ''
        incoming = ''
        if use_incoming:
            with_head += ",\n         {:ok, target} <- target(combat)"
            helpers = (
                "\n  defp target(combat) do\n"
                "    case combat.enemies do\n"
                "      [enemy | _] -> {:ok, enemy}\n"
                '      [] -> {:error, "这里没有可供攻击的对手。\\n"}\n'
                "    end\n"
                "  end\n"
                "\n  defp ref(character) do\n"
                "    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}\n"
                "  end\n"
            )
            incoming = self._emit_resolve_incoming(data)
            
            # Build attacker var computation - map LPC vars to canonical payload keys
            # resolve_incoming expects: level, skill, ap, damage, rng
            attacker_vars = data.get('attacker_vars', {})
            
            # Canonical payload keys that resolve_incoming understands
            canonical_keys = ['level', 'skill', 'ap', 'damage', 'rng']
            
            # Map LPC variable names to canonical names
            lpc_to_canonical = {
                'lvl': 'level',
                'skill_lvl': 'level',
                'level': 'level',
                'skill': 'skill',
                'ap': 'ap',
                'dp': 'dp',
                'damage': 'damage',
                'force': 'force',
                'neili': 'neili',
                'count': 'count',
                'i': 'i', 'j': 'j', 'n': 'n',
            }
            
            # Build payload: for each canonical key, find the LPC var that provides it
            payload_map = {}  # canonical -> lpc_var_name
            for lpc_name in attacker_vars:
                canon = lpc_to_canonical.get(lpc_name)
                if canon and canon not in payload_map:
                    payload_map[canon] = lpc_name
            
            # Always provide level/skill from main skill
            if 'level' not in payload_map:
                payload_map['level'] = 'lvl'  # will be computed as main skill
            if 'skill' not in payload_map:
                payload_map['skill'] = 'lvl'  # alias
            
            # RNG always needed for offensive performs
            payload_map['rng'] = 'rng'
            
            canonical_keys = list(payload_map.keys())
            lpc_names = set(payload_map.values())
            
            var_lines = [
                "    character = conn.character",
                "    combat = character.meta.combat",
            ]
            # stats needed for skill queries
            needs_stats = any('me->query_skill' in info['raw'] for info in attacker_vars.values()) or ('level' in payload_map or 'skill' in payload_map)
            if needs_stats:
                var_lines.append("    stats = character.meta.stats")
            else:
                var_lines.append("    _stats = character.meta.stats")
            # Always include RNG for offensive performs (used in damage formulas)
            var_lines.append("    rng = &:rand.uniform/1")
            
            # Main skill level - compute as 'lvl' (common LPC name)
            # Only if not already provided by attacker_vars (to avoid duplicate)
            if ('level' in payload_map or 'skill' in payload_map) and 'lvl' not in attacker_vars:
                var_lines.append(f'    lvl = Stats.skill(stats, "{skill}")')
            
            # Compute attacker vars in order
            for name, info in attacker_vars.items():
                var_lines.append(f"    {name} = {info['expr']}")
            
            # Build event data payload with canonical keys
            payload_entries = []
            for canon in ['level', 'skill', 'ap', 'damage', 'rng']:
                if canon in payload_map:
                    lpc_name = payload_map[canon]
                    if canon == 'level':
                        payload_entries.append("level: lvl")
                    elif canon == 'skill':
                        payload_entries.append("skill: lvl")
                    elif canon == 'rng':
                        payload_entries.append("rng: rng")
                    else:
                        payload_entries.append(f"{canon}: {lpc_name}")
            
            run_prelude = '\n'.join(var_lines) + '\n\n'
            payload_str = ',\n          '.join(payload_entries)
            run_body = (
                '      send(target.pid, %Event{\n'
                '        from_pid: self(),\n'
                '        topic: "combat/perform-incoming",\n'
                '        data: %{attacker: ref(character), perform_id: @perform_id,\n'
                '          ' + payload_str + '\n'
                '        }\n'
                '      })\n\n'
                '      apply_effect(conn, character)'
            )
        else:
            run_prelude = "    character = conn.character\n\n"
            run_body = "      apply_effect(conn, character)"

        facts = self._render_reference_comments(data)
        raw_str = self._render_raw_source(data)

        perform_id_attr = f'\n  @perform_id "{skill}/{move}"\n' if is_perform else ''

        return f'''defmodule {mod} do
  @moduledoc """
  {data['kind']}「{data['title']}」（source {skill}/{move}.c，由 translate_perform.py 生成，inherit {data['inherit'] or "?"}）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

{aliases_str}
{perform_id_attr}
  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
{run_prelude}    with {with_head} do
{run_body}
    else
      {{:error, message}} ->
        conn
        |> render(CommandView, "text", %{{text: message}})
        |> assign(:prompt, false)
    end
  end
{perform_known}
{gates_str}
  defp apply_effect(conn, character) do
{effect_str}    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end
{helpers}{incoming}
{facts}{raw_str}end
'''

    def _render_raw_source(self, data: Dict[str, Any]) -> str:
        if not data.get('raw_source'):
            return ''
        return (
            '\n  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====\n'
            + self.comment_block(data['raw_source'], indent="  # ")
            + '\n'
        )

    def _render_reference_comments(self, data: Dict[str, Any]) -> str:
        # Keep the extracted facts as a reference so nothing is lost while the
        # mechanical code above is verified against the raw LPC.
        gates = {
            'level_gates': data['level_gates'],
            'assign_refs': data['assign_refs'],
            'var_gates': data['var_gates'],
            'map_gates': data['map_gates'],
            'prepared_gates': data['prepared_gates'],
            'resource_gates': data['resource_gates'],
        }
        effects = {
            'add_costs': data['add_costs'],
            'set_flags': data['set_flags'],
            'temp_set': data['temp_set'],
            'apply_adds': data['apply_adds'],
            'affect_by': data['affect_by'],
            'remote_damage': data['remote_damage'],
            'busy_lines': data['busy_lines'],
        }
        facts = {k: v for k, v in {**gates, **effects}.items() if v not in (None, [], {})}
        return (
            "  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：\n"
            + self.comment_block(self._elixir_fmt(facts), indent="  #   ")
            + '\n'
        )

    def render_comment_skeleton(self, data: Dict[str, Any]) -> str:
        mod = self.module_name(data['skill'], data['move'])

        gates = {
            'level_gates': data['level_gates'],
            'assign_refs': data['assign_refs'],
            'var_gates': data['var_gates'],
            'map_gates': data['map_gates'],
            'prepared_gates': data['prepared_gates'],
            'resource_gates': data['resource_gates']
        }

        effects = {
            'add_costs': data['add_costs'],
            'set_flags': data['set_flags'],
            'temp_set': data['temp_set'],
            'apply_adds': data['apply_adds'],
            'affect_by': data['affect_by'],
            'remote_damage': data['remote_damage'],
            'busy_lines': data['busy_lines']
        }

        gates_str = self.comment_block(self._elixir_fmt(gates))
        effects_str = self.comment_block(self._elixir_fmt(effects))

        # Enhanced comment blocks
        enhanced = {}
        if data.get('weapon_type'):
            enhanced['weapon_type'] = data['weapon_type']
        if data.get('target_logic'):
            enhanced['target_logic'] = data['target_logic']
        if data.get('all_fails'):
            enhanced['all_fail_messages'] = data['all_fails']
        if data.get('ap_dp'):
            enhanced['ap_dp_formulas'] = data['ap_dp']
        if data.get('hit_logic'):
            enhanced['hit_formula'] = data['hit_logic']
        if data.get('damage_logic'):
            enhanced['damage_formula'] = data['damage_logic']
        if data.get('do_damage_details'):
            enhanced['do_damage_calls'] = data['do_damage_details']
        if data.get('affect_by_details'):
            enhanced['affect_by_callbacks'] = data['affect_by_details']
        if data.get('messages'):
            enhanced['combat_messages'] = data['messages']
        if data.get('color_codes'):
            enhanced['color_codes'] = data['color_codes']
        if data.get('callbacks'):
            enhanced['callback_functions'] = data['callbacks']
        # Gap-analysis additions
        if data.get('receive_damages'):
            enhanced['receive_damage_calls'] = data['receive_damages']
        if data.get('resource_adds'):
            enhanced['resource_adds'] = data['resource_adds']
        if data.get('resource_sets'):
            enhanced['resource_sets'] = data['resource_sets']
        if data.get('buff_delete'):
            enhanced['buff_delete'] = data['buff_delete']
        if data.get('call_outs'):
            enhanced['call_outs'] = data['call_outs']
        if data.get('hit_obs'):
            enhanced['hit_ob_calls'] = data['hit_obs']
        if data.get('amounts'):
            enhanced['amount_calls'] = data['amounts']
        if data.get('exp_gates'):
            enhanced['exp_compare'] = data['exp_gates']
        if data.get('ahinfo') and (data['ahinfo']['clear'] or data['ahinfo']['query']):
            enhanced['combat_d_ahinfo'] = data['ahinfo']
        if data.get('resource_queries'):
            enhanced['resource_queries'] = data['resource_queries']
        if data.get('amount_gates'):
            enhanced['amount_gates'] = data['amount_gates']
        # Audit additions
        if data.get('weapon_forbidden'):
            enhanced['weapon_forbidden'] = data['weapon_forbidden']
        if data.get('combat_exp_formulas'):
            enhanced['combat_exp_formulas'] = data['combat_exp_formulas']
        if data.get('combat_exp_inline'):
            enhanced['combat_exp_inline'] = data['combat_exp_inline']
        if data.get('reset_actions'):
            enhanced['reset_action'] = True
        if data.get('wield_actions'):
            enhanced['wield_actions'] = data['wield_actions']
        if data.get('improve_skills'):
            enhanced['improve_skill'] = data['improve_skills']
        if data.get('misc_gates'):
            enhanced['misc_gates'] = data['misc_gates']

        enhanced_str = self.comment_block(self._elixir_fmt(enhanced)) if enhanced else ''

        stanzas = '\n'.join(f"      #   - {line}" for line in data['busy_lines'])

        raw_str = ''
        if data.get('raw_source'):
            raw_str = (
                '\n  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====\n'
                + self.comment_block(data['raw_source'], indent="      # ")
                + '\n'
            )

        return f'''defmodule {mod} do
  @moduledoc """
  {data['kind']}「{data['title']}」（source {data['skill']}/{data['move']}.c，由 translate_perform.py 骨架生成，inherit {data['inherit'] or "?"}）

  TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
  以上注释行（TODO(migrate)）校对完成后删除。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {{:error, message}} ->
        conn
        |> render(CommandView, "text", %{{text: message}})
        |> assign(:prompt, false)
    end
  end

  # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
{gates_str}
  # TODO(migrate) 增强提取逻辑：
{enhanced_str}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
{effects_str}
{stanzas}
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
{raw_str}end
'''

    def load_protected(self) -> Set[str]:
        """Load the set of hand-written perform files that must never be overwritten.

        Reads a newline-separated list of relative paths (e.g. 'bagua_biao/zhi.ex')
        from the PROTECTED_PERFORMS env var file, or from the default location
        next to this script: scripts/protected_performs.txt.
        Returns an empty set when the file is missing (no protection).
        """
        env_file = os.getenv('PROTECTED_PERFORMS')
        candidates = []
        if env_file:
            candidates.append(Path(env_file))
        candidates.append(Path(__file__).resolve().parent / 'protected_performs.txt')

        for path in candidates:
            if path.exists():
                items = {
                    line.strip()
                    for line in path.read_text(encoding='utf-8').splitlines()
                    if line.strip() and not line.strip().startswith('#')
                }
                print(f"translate_perform: protected {len(items)} hand-written files from {path}")
                return items
        print("translate_perform: WARNING no protected list found, will overwrite existing files")
        return set()

    def write_skeleton(self, out_root: Path, skill: str, data: Dict[str, Any]) -> Optional[str]:
        dir_path = out_root / self.skill_dir(skill)
        dir_path.mkdir(parents=True, exist_ok=True)
        file_path = dir_path / f"{data['move']}.ex"
        rel_path = f"{self.skill_dir(skill)}/{data['move']}.ex"
        rendered = self.render_skeleton(data)

        # Never touch hand-written performs: the baseline 155 files were
        # converted before this extractor existed, so skip them entirely.
        if rel_path in self.protected:
            if file_path.exists():
                return None
            print(f"translate_perform: protected file MISSING, generating: {rel_path}")
            file_path.write_text(rendered, encoding='utf-8')
            return str(file_path.relative_to(out_root))

        if file_path.exists() and file_path.read_text(encoding='utf-8') == rendered:
            return None

        file_path.write_text(rendered, encoding='utf-8')
        return str(file_path.relative_to(out_root))

    @staticmethod
    def source_rank(c_file: Path) -> int:
        """Priority of a source file when several map to the same output path.

        Files living under a `perform/` or `exert/` subdirectory are the
        canonical location and win over files placed directly in the skill
        directory (e.g. `taixuan-gong/perform/xuan.c` beats
        `taixuan-gong/xuan.c`). Both still render to the same flat target
        `performs/<skill>/<move>.ex`.
        """
        return 1 if c_file.parent.name in ('perform', 'exert') else 0

    def run(self, src_root: Path, out_root: Path) -> Dict[str, List[str]]:
        written = []
        skipped = []
        protected_hits = []
        collisions = []

        for skill_dir in sorted(src_root.iterdir()):
            if not skill_dir.is_dir():
                continue

            # Group every extracted file by its flat output path so that
            # duplicate (skill, move) sources can be de-duplicated instead of
            # silently overwriting each other.
            by_output: Dict[str, List[Tuple[int, Path, Dict[str, Any]]]] = {}

            # Use Python's rglob for cross-platform .c file discovery
            for c_file in sorted(skill_dir.rglob('*.c')):
                data = self.extract(c_file)

                if data is None:
                    skipped.append(str(c_file.relative_to(src_root)))
                    continue

                rel_path = f"{self.skill_dir(data['skill'])}/{data['move']}.ex"
                if rel_path in self.protected:
                    protected_hits.append(rel_path)
                    continue

                by_output.setdefault(rel_path, []).append((self.source_rank(c_file), c_file, data))

            for rel_path, candidates in sorted(by_output.items()):
                # Stable sort keeps input order for equal rank; highest rank
                # (subdirectory source) wins.
                candidates.sort(key=lambda c: -c[0])
                _, c_file, data = candidates[0]

                if len(candidates) > 1:
                    collisions.append({
                        'output': rel_path,
                        'chosen': str(c_file.relative_to(src_root)),
                        'dropped': [str(c[1].relative_to(src_root)) for c in candidates[1:]],
                    })

                written_path = self.write_skeleton(out_root, skill_from_path(c_file), data)
                if written_path:
                    written.append(written_path)

        return {
            'written': sorted(written),
            'skipped': sorted(skipped),
            'protected_skipped': sorted(protected_hits),
            'collisions': sorted(collisions, key=lambda c: c['output'])
        }


def skill_from_path(c_file: Path) -> str:
    parent = c_file.parent.name
    # If file is in exert/ or perform/ subdirectory, use grandparent as skill name
    if parent in ('exert', 'perform'):
        return c_file.parent.parent.name
    return parent


def main():
    import os

    src = Path(os.getenv('KUNGFU_SRC', '/app/kungfu_source/kungfu/skill'))
    out = Path(os.getenv('KUNGFU_OUT', '/tmp/perf_out'))

    if not src.exists():
        print(f"Source directory not found: {src}")
        sys.exit(1)

    translator = TranslatePerform()
    result = translator.run(src, out)

    print(f"translate_perform: {result}")


if __name__ == '__main__':
    main()