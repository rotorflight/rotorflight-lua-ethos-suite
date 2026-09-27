#!/usr/bin/env python3
"""Generate and verify configuration page documentation for RFSuite Ethos.

Parses the menu navigation structure in src/rfsuite/app/tool.lua and
page definitions in src/rfsuite/app/pages/*.lua to generate, update, and
validate documentation skeletons in docs/pages/ conforming to docs/_template.md.

Usage:
    python bin/docs/generate_menu_docs.py --scaffold-all
    python bin/docs/generate_menu_docs.py --check
    python bin/docs/generate_menu_docs.py --update-index
    python bin/docs/generate_menu_docs.py --page flight_tuning/pids.md
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
TOOL_PATH = REPO_ROOT / "src" / "rfsuite" / "app" / "tool.lua"
PAGES_SRC_DIR = REPO_ROOT / "src" / "rfsuite" / "app" / "pages"
LIB_SRC_DIR = REPO_ROOT / "src" / "rfsuite" / "lib"
I18N_PATH = REPO_ROOT / "src" / "rfsuite" / "i18n" / "en.json"
DOCS_PAGES_DIR = REPO_ROOT / "docs" / "pages"
TEMPLATE_PATH = REPO_ROOT / "docs" / "_template.md"
INDEX_PATH = DOCS_PAGES_DIR / "README.md"
MAIN_PATH = REPO_ROOT / "src" / "rfsuite" / "main.lua"


def get_suite_version():
    """Extract suite version string from src/rfsuite/main.lua."""
    if not MAIN_PATH.exists():
        return "2.3.1"
    content = MAIN_PATH.read_text(encoding="utf-8")
    m = re.search(
        r"local\s+version\s*=\s*\{\s*major\s*=\s*(\d+),\s*minor\s*=\s*(\d+),\s*revision\s*=\s*(\d+)",
        content,
    )
    if m:
        return f"{m.group(1)}.{m.group(2)}.{m.group(3)}"
    return "2.3.1"


def load_i18n():
    """Load base English i18n lookup table."""
    if not I18N_PATH.exists():
        return {}
    try:
        with open(I18N_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Warning: Failed to load i18n file: {e}", file=sys.stderr)
        return {}


I18N_DATA = load_i18n()


def tr(text):
    """Resolve @i18n(key)@ strings to English text."""
    if not text:
        return ""
    m = re.match(r"@i18n\(([^)]+)\)@", text.strip('"\''))
    key = m.group(1) if m else text.strip('"\'')
    curr = I18N_DATA
    for part in key.split("."):
        if isinstance(curr, dict) and part in curr:
            curr = curr[part]
        else:
            return key
    if isinstance(curr, dict):
        return curr.get("english", curr.get("translation", key))
    return str(curr)


def load_field_meta(msp_module_name):
    """Load FIELD_META dictionary from a lib/msp_*.lua module if available."""
    if not msp_module_name:
        return {}
    module_path = LIB_SRC_DIR / f"{msp_module_name}.lua"
    if not module_path.exists():
        return {}
    content = module_path.read_text(encoding="utf-8")
    meta_start = content.find("local FIELD_META = {")
    if meta_start == -1:
        return {}
    meta_end = content.find("\n}", meta_start)
    if meta_end == -1:
        return {}
    block = content[meta_start:meta_end]
    meta = {}
    for line in block.splitlines():
        line = line.strip()
        m = re.search(r"(\w+)\s*=\s*\{([^}]+)\}", line)
        if m:
            k = m.group(1)
            body = m.group(2)
            fields = {}
            for param in ["min", "max", "default", "suffix", "decimals"]:
                pm = re.search(rf"\b{param}\s*=\s*([^,]+)", body)
                if pm:
                    val = pm.group(1).strip().strip('"\'')
                    fields[param] = val
            meta[k] = fields
    return meta


# Canonical mapping from script file names in app/pages/ to target doc paths in docs/pages/
# Organized logically into functional domains mirroring the menu tree.
SCRIPT_TO_DOC_PATH = {
    # Configuration -> Flight Tuning
    "app/pages/pids.lua": "flight_tuning/pids.md",
    "app/pages/rates.lua": "flight_tuning/rates.md",
    "app/pages/governor_general.lua": "flight_tuning/governor/general.md",
    "app/pages/governor_flags.lua": "flight_tuning/governor/flags.md",
    "app/pages/filters.lua": "flight_tuning/advanced/filters.md",
    "app/pages/pid_controller.lua": "flight_tuning/advanced/pid_controller.md",
    "app/pages/pid_bandwidth.lua": "flight_tuning/advanced/pid_bandwidth.md",
    "app/pages/autolevel.lua": "flight_tuning/advanced/autolevel.md",
    "app/pages/main_rotor.lua": "flight_tuning/advanced/main_rotor.md",
    "app/pages/tail_rotor.lua": "flight_tuning/advanced/tail_rotor.md",
    "app/pages/rescue.lua": "flight_tuning/advanced/rescue.md",
    "app/pages/rates_advanced.lua": "flight_tuning/advanced/rates_advanced/advanced.md",
    "app/pages/rates_cyclic.lua": "flight_tuning/advanced/rates_advanced/cyclic_behaviour.md",
    "app/pages/rates_type.lua": "flight_tuning/advanced/rates_advanced/table.md",

    # Configuration -> Setup
    "app/pages/configuration.lua": "setup/configuration.md",
    "app/pages/radio_config.lua": "setup/radio_config.md",
    "app/pages/telemetry.lua": "setup/telemetry.md",
    "app/pages/accelerometer.lua": "setup/accelerometer.md",
    "app/pages/alignment.lua": "setup/alignment.md",
    "app/pages/ports.lua": "setup/ports.md",
    "app/pages/mixer_swash.lua": "setup/mixer/swash.md",
    "app/pages/mixer_geometry.lua": "setup/mixer/geometry.md",
    "app/pages/mixer_tail.lua": "setup/mixer/tail.md",
    "app/pages/mixer_trims.lua": "setup/mixer/trims.md",
    "app/pages/servos_pwm.lua": "setup/servos/pwm.md",
    "app/pages/servos_bus.lua": "setup/servos/bus.md",
    "app/pages/modes.lua": "setup/controls/modes.md",
    "app/pages/adjustments.lua": "setup/controls/adjustments.md",
    "app/pages/failsafe.lua": "setup/controls/failsafe.md",
    "app/pages/beepers_configuration.lua": "setup/controls/beepers/configuration.md",
    "app/pages/beepers_dshot.lua": "setup/controls/beepers/dshot.md",
    "app/pages/blackbox_configuration.lua": "setup/controls/blackbox/configuration.md",
    "app/pages/blackbox_logging.lua": "setup/controls/blackbox/logging.md",
    "app/pages/blackbox_status.lua": "setup/controls/blackbox/status.md",
    "app/pages/stats.lua": "setup/controls/stats.md",
    "app/pages/power_battery.lua": "setup/power/battery.md",
    "app/pages/power_alerts.lua": "setup/power/alerts.md",
    "app/pages/power_source.lua": "setup/power/source.md",
    "app/pages/power_smartfuel.lua": "setup/power/smartfuel.md",
    "app/pages/esc_motors_throttle.lua": "setup/esc_motors/throttle.md",
    "app/pages/esc_motors_telemetry.lua": "setup/esc_motors/telemetry.md",
    "app/pages/esc_motors_rpm.lua": "setup/esc_motors/rpm.md",
    "app/pages/esc_forward_hw5.lua": "setup/esc_motors/esc_tools/hw5.md",
    "app/pages/esc_forward_am32.lua": "setup/esc_motors/esc_tools/am32.md",
    "app/pages/esc_forward_blheli_s.lua": "setup/esc_motors/esc_tools/blheli_s.md",
    "app/pages/esc_forward_bluejay.lua": "setup/esc_motors/esc_tools/bluejay.md",
    "app/pages/esc_forward_flyrotor.lua": "setup/esc_motors/esc_tools/flyrotor.md",
    "app/pages/esc_forward_omp.lua": "setup/esc_motors/esc_tools/omp.md",
    "app/pages/esc_forward_scorpion.lua": "setup/esc_motors/esc_tools/scorpion.md",
    "app/pages/esc_forward_xdfly.lua": "setup/esc_motors/esc_tools/xdfly.md",
    "app/pages/esc_forward_yge.lua": "setup/esc_motors/esc_tools/yge.md",
    "app/pages/esc_forward_ztw.lua": "setup/esc_motors/esc_tools/ztw.md",
    "app/pages/setup_governor_general.lua": "setup/governor/general.md",
    "app/pages/setup_governor_time.lua": "setup/governor/time.md",
    "app/pages/setup_governor_filters.lua": "setup/governor/filters.md",
    "app/pages/setup_governor_curves.lua": "setup/governor/curves.md",

    # System -> Tools
    "app/pages/copy_profiles.lua": "tools/copy_profiles.md",
    "app/pages/profile_select.lua": "tools/profile_select.md",
    "app/pages/diagnostics_rfstatus.lua": "tools/diagnostics/rfstatus.md",
    "app/pages/diagnostics_elrs_link.lua": "tools/diagnostics/elrs_link.md",
    "app/pages/diagnostics_fblstatus.lua": "tools/diagnostics/fblstatus.md",
    "app/pages/diagnostics_info.lua": "tools/diagnostics/info.md",
    "app/pages/developer_msp_speed.lua": "tools/developer/msp_speed.md",
    "app/pages/developer_msp_exp.lua": "tools/developer/msp_exp.md",

    # System -> Logs
    "app/pages/logs.lua": "logs.md",

    # System -> Settings
    "app/pages/settings_general.lua": "settings/general.md",
    "app/pages/settings_dashboard_theme.lua": "settings/dashboard/theme.md",
    "app/pages/settings_dashboard_settings.lua": "settings/dashboard/settings.md",
    "app/pages/settings_activelook_settings.lua": "settings/activelook/settings.md",
    "app/pages/settings_activelook_preflight.lua": "settings/activelook/preflight.md",
    "app/pages/settings_activelook_inflight.lua": "settings/activelook/inflight.md",
    "app/pages/settings_activelook_postflight.lua": "settings/activelook/postflight.md",
    "app/pages/settings_audio_events.lua": "settings/audio/events.md",
    "app/pages/settings_audio_switches.lua": "settings/audio/switches.md",
    "app/pages/settings_audio_timer.lua": "settings/audio/timer.md",
    "app/pages/developer_settings.lua": "settings/developer.md",
}


def parse_lua_menus():
    """Parse tool.lua navigation definitions and extract all reachable pages and breadcrumbs."""
    if not TOOL_PATH.exists():
        raise FileNotFoundError(f"Missing tool.lua at {TOOL_PATH}")
    content = TOOL_PATH.read_text(encoding="utf-8")

    # Extract ROOT_ENTRIES
    root_match = re.search(r"local ROOT_ENTRIES = \{([^;]+?)\n\}", content, re.DOTALL)
    if not root_match:
        raise ValueError("Could not find ROOT_ENTRIES in tool.lua")
    root_block = root_match.group(1)

    root_entries = []
    for item in re.finditer(r"\{([^}]+)\}", root_block):
        entry_text = item.group(1)
        tm = re.search(r'title\s*=\s*("(?:[^"\\]|\\.)*"|@[^@]+@)', entry_text)
        title = tr(tm.group(1)) if tm else ""
        gm = re.search(r'group\s*=\s*("(?:[^"\\]|\\.)*"|@[^@]+@)', entry_text)
        group = tr(gm.group(1)) if gm else ""
        mm = re.search(r'menuId\s*=\s*"([^"]+)"', entry_text)
        menu_id = mm.group(1) if mm else None
        sm = re.search(r'script\s*=\s*"([^"]+)"', entry_text)
        script = sm.group(1) if sm else None
        offline = "offline = true" in entry_text
        root_entries.append({
            "title": title,
            "group": group,
            "menuId": menu_id,
            "script": script,
            "offline": offline
        })

    # Extract MENUS table block
    menus_match = re.search(r"local MENUS = \{([\s\S]+?)\n\}\s*\nlocal nav", content)
    if not menus_match:
        raise ValueError("Could not find MENUS table in tool.lua")
    menus_block = menus_match.group(1)

    # Split MENUS into individual menu declaration blocks: `  <id> = {`
    menu_blocks = {}
    current_menu = None
    current_lines = []
    for line in menus_block.splitlines():
        m = re.match(r"^\s{2}([a-zA-Z0-9_]+)\s*=\s*\{", line)
        if m:
            if current_menu:
                menu_blocks[current_menu] = "\n".join(current_lines)
            current_menu = m.group(1)
            current_lines = [line]
        elif current_menu:
            current_lines.append(line)
    if current_menu:
        menu_blocks[current_menu] = "\n".join(current_lines)

    menus = {}
    for m_id, m_body in menu_blocks.items():
        tm = re.search(r'title\s*=\s*("(?:[^"\\]|\\.)*"|@[^@]+@)', m_body)
        title = tr(tm.group(1)) if tm else ""

        entries = []
        entries_block_match = re.search(r"entries\s*=\s*\{([\s\S]*)\}", m_body)
        if entries_block_match:
            entries_content = entries_block_match.group(1)
            for e_match in re.finditer(r"\{([^{}]+)\}", entries_content):
                e_body = e_match.group(1)
                et_m = re.search(r'title\s*=\s*("(?:[^"\\]|\\.)*"|@[^@]+@)', e_body)
                if not et_m:
                    continue
                e_title = tr(et_m.group(1))
                es_m = re.search(r'script\s*=\s*"([^"]+)"', e_body)
                e_script = es_m.group(1) if es_m else None
                em_m = re.search(r'menuId\s*=\s*"([^"]+)"', e_body)
                e_menu_id = em_m.group(1) if em_m else None
                offline = "offline = true" in e_body
                requires_bus = "requiresServoBus = true" in e_body
                esc_proto_m = re.search(r"escProtocolId\s*=\s*(\d+)", e_body)
                esc_proto = esc_proto_m.group(1) if esc_proto_m else None
                developer = "developerModeEnabled" in e_body or "developer" in e_body.lower()

                entries.append({
                    "title": e_title,
                    "script": e_script,
                    "menuId": e_menu_id,
                    "offline": offline,
                    "requiresServoBus": requires_bus,
                    "escProtocolId": esc_proto,
                    "developer": developer
                })
        menus[m_id] = {"title": title, "entries": entries}

    pages_list = []

    def walk_menu(menu_id, breadcrumbs, parent_conditions=None):
        conds = dict(parent_conditions or {})
        menu = menus.get(menu_id)
        if not menu:
            return
        for order_idx, entry in enumerate(menu["entries"]):
            curr_conds = dict(conds)
            if entry["offline"]:
                curr_conds["offline"] = True
            if entry["requiresServoBus"]:
                curr_conds["requiresServoBus"] = True
            if entry["escProtocolId"]:
                curr_conds["escProtocolId"] = entry["escProtocolId"]
            if entry["developer"]:
                curr_conds["developer"] = True

            tile_title = entry["title"]
            curr_crumb = breadcrumbs + [tile_title]

            if entry["script"]:
                script = entry["script"]
                doc_path = SCRIPT_TO_DOC_PATH.get(script)
                if not doc_path:
                    base_name = os.path.splitext(os.path.basename(script))[0]
                    doc_path = f"misc/{base_name}.md"
                pages_list.append({
                    "title": tile_title,
                    "script": script,
                    "doc_path": doc_path,
                    "breadcrumbs": curr_crumb,
                    "conditions": curr_conds,
                    "order": (order_idx + 1) * 10
                })
            elif entry["menuId"]:
                walk_menu(entry["menuId"], curr_crumb, curr_conds)

    for r_entry in root_entries:
        group_name = r_entry["group"]
        root_title = r_entry["title"]
        crumbs = [group_name, root_title] if group_name else [root_title]
        base_conds = {"offline": r_entry["offline"]}
        if r_entry["script"]:
            script = r_entry["script"]
            doc_path = SCRIPT_TO_DOC_PATH.get(script, f"{os.path.splitext(os.path.basename(script))[0]}.md")
            pages_list.append({
                "title": root_title,
                "script": script,
                "doc_path": doc_path,
                "breadcrumbs": crumbs,
                "conditions": base_conds,
                "order": 10
            })
        elif r_entry["menuId"]:
            walk_menu(r_entry["menuId"], crumbs, base_conds)

    return pages_list


def parse_page_lua(script_path):
    """Extract page overview, form controls, and architecture notes from Lua source."""
    full_path = REPO_ROOT / "src" / "rfsuite" / script_path
    if not full_path.exists():
        return {"summary": "", "fields": [], "reboot": False, "eeprom": False, "msp_modules": []}

    content = full_path.read_text(encoding="utf-8")

    # Extract summary from top docstring comment
    summary = ""
    comment_match = re.search(r"^\s*--\s*(.+?)(?=\n\s*(?:local|\bif\b|\bfunction\b|$))", content, re.DOTALL)
    if comment_match:
        lines = [line.strip().lstrip("-").strip() for line in comment_match.group(1).splitlines() if line.strip()]
        # Select first 1-3 sentences
        joined = " ".join(lines)
        sentences = re.split(r"(?<=[.!?])\s+", joined)
        summary = " ".join(sentences[:2])

    # Find referenced mspModules
    msp_modules = re.findall(r'requireModule\("lib/(msp_\w+)\.lua"\)', content)
    # Collect all field meta for referenced modules
    combined_meta = {}
    for mod in msp_modules:
        combined_meta.update(load_field_meta(mod))

    fields = []

    # 1. Check special grid pages like pids.lua and rates.lua
    if "COLUMNS" in content and "ROWS" in content:
        cols_m = re.search(r"COLUMNS\s*=\s*\{([^}]+)\}", content)
        rows_m = re.search(r"ROWS\s*=\s*\{([\s\S]+?)\n\}", content)
        if cols_m and rows_m:
            cols = [tr(c.group(1)) for c in re.finditer(r'("(?:[^"\\]|\\.)*"|@[^@]+@)', cols_m.group(1))]
            rows = [tr(r.group(1)) for r in re.finditer(r'label\s*=\s*("(?:[^"\\]|\\.)*"|@[^@]+@)', rows_m.group(1))]
            for r in rows:
                for c in cols:
                    if r.lower() == "yaw" and c.upper() == "O":
                        continue
                    fields.append({
                        "label": f"{r} {c}",
                        "key": f"{r.lower()}_{c.lower()}",
                        "type": "grid",
                        "meta": {}
                    })

    if "rates" in script_path.lower() and "ROWS" in content and not fields:
        rows_m = re.search(r"ROWS\s*=\s*\{([\s\S]+?)\n\}", content)
        if rows_m:
            cols = ["RC Rate", "Rate", "Expo"]
            rows = [tr(r.group(1)) for r in re.finditer(r'label\s*=\s*("(?:[^"\\]|\\.)*"|@[^@]+@)', rows_m.group(1))]
            for r in rows:
                for c in cols:
                    fields.append({
                        "label": f"{r} {c}",
                        "key": f"{r.lower()}_{c.lower().replace(' ', '_')}",
                        "type": "grid",
                        "meta": {}
                    })

    # 2. Look for fieldLayout.buildSingle
    for m in re.finditer(r'fieldLayout\.buildSingle\s*\([^,]+,\s*("(?:[^"\\]|\\.)*"|@[^@]+@)\s*,\s*\{([^}]+)\}', content):
        label = tr(m.group(1))
        body = m.group(2)
        km = re.search(r'key\s*=\s*"([^"]+)"', body)
        key = km.group(1) if km else ""
        meta = combined_meta.get(key, {})
        fields.append({
            "label": label,
            "key": key,
            "type": "number",
            "meta": meta
        })

    # 3. Look for fieldLayout.buildGroup
    for m in re.finditer(r'fieldLayout\.buildGroup\s*\([^,]+,\s*("(?:[^"\\]|\\.)*"|@[^@]+@)\s*,\s*\{([\s\S]*?)\n\s*\}\)', content):
        group_name = tr(m.group(1))
        group_body = m.group(2)
        for item in re.finditer(r'\{\s*title\s*=\s*("(?:[^"\\]|\\.)*"|@[^@]+@)\s*,\s*spec\s*=\s*\{([^}]+)\}\s*\}', group_body):
            sub_title = tr(item.group(1))
            body = item.group(2)
            km = re.search(r'key\s*=\s*"([^"]+)"', body)
            key = km.group(1) if km else ""
            meta = combined_meta.get(key, {})
            fields.append({
                "label": f"{group_name} ({sub_title})" if group_name else sub_title,
                "key": key,
                "type": "number",
                "meta": meta
            })

    # 4. Look for form.addLine(...)
    for m in re.finditer(r'form\.addLine\s*\(\s*("(?:[^"\\]|\\.)*"|@[^@]+@)\s*\)', content):
        label = tr(m.group(1)).strip()
        if label and not any(f["label"] == label for f in fields):
            fields.append({
                "label": label,
                "key": "",
                "type": "control",
                "meta": {}
            })

    reboot = "reboot = true" in content or "rebootFc" in content or "rfsuite.app.ui.rebootFc" in content
    eeprom = "msp_eeprom" in content or "EEPROM_WRITE" in content or "save" in content.lower()

    return {
        "summary": summary,
        "fields": fields,
        "reboot": reboot,
        "eeprom": eeprom,
        "msp_modules": msp_modules
    }


def format_conditions(conds):
    """Format access preconditions into standardized sentences."""
    sentences = []
    if conds.get("offline"):
        sentences.append("Always available offline without an active flight controller connection.")
    else:
        sentences.append("Greyed out until the flight controller answers.")

    if conds.get("lockedWhileArmed", True):
        sentences.append("Read-only while the model is armed.")

    if conds.get("requiresServoBus"):
        sentences.append("Only available when servo bus output is configured.")

    if conds.get("escProtocolId"):
        sentences.append(f"Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: {conds['escProtocolId']}).")

    if conds.get("developer"):
        sentences.append("Hidden until *System* → *Settings* → *Developer* mode is active.")

    return " ".join(sentences)


def format_settings_table(fields):
    """Format markdown table of configuration settings."""
    clean_fields = []
    seen_labels = set()
    for f in fields:
        label = f["label"].strip()
        if not label or label in seen_labels:
            continue
        seen_labels.add(label)
        clean_fields.append((label, f))

    if not clean_fields:
        return (
            "| Setting | What it does |\n"
            "| --- | --- |\n"
            "| *None* | This page provides status or interactive operations without persistent settings. |\n"
        )

    lines = [
        "| Setting | What it does |",
        "| --- | --- |",
    ]
    for label, f in clean_fields:
        meta = f.get("meta", {})
        parts = []
        if "min" in meta and "max" in meta:
            suffix = meta.get("suffix", "")
            suffix_str = f" {suffix}" if suffix else ""
            parts.append(f"Range: {meta['min']} to {meta['max']}{suffix_str}")
        if "default" in meta:
            suffix = meta.get("suffix", "")
            suffix_str = f" {suffix}" if suffix else ""
            parts.append(f"Default: {meta['default']}{suffix_str}")

        detail = ". ".join(parts)
        if detail:
            desc = f"Configures {label}. {detail}."
        else:
            desc = f"Configures {label}."
        lines.append(f"| {label} | {desc} |")

    return "\n".join(lines)


def generate_page_doc(page_info, suite_version):
    """Generate canonical markdown document conforming to docs/_template.md."""
    title = page_info["title"]
    doc_path = page_info["doc_path"]
    order = page_info["order"]
    breadcrumbs_str = " → ".join(f"*{crumb}*" for crumb in page_info["breadcrumbs"])
    conditions_str = format_conditions(page_info["conditions"])

    parsed = parse_page_lua(page_info["script"])
    summary = parsed["summary"] or f"Configures {title} parameters for Rotorflight."
    settings_table = format_settings_table(parsed["fields"])

    notes = []
    if parsed["reboot"]:
        notes.append("- Saving changes on this page reboots the flight controller.")
    if parsed["eeprom"]:
        notes.append("- Changes are written to the flight controller EEPROM upon Save.")
    if "pids" in doc_path or "pid_controller" in doc_path:
        notes.append("- Parameters are scoped to the currently active PID profile.")
    elif "rates" in doc_path:
        notes.append("- Parameters are scoped to the currently active Rate profile.")
    elif "governor" in doc_path and "profile" in page_info["script"]:
        notes.append("- Parameters are scoped to the currently active Governor profile.")

    notes_section = ""
    if notes:
        notes_section = "## Notes\n\n" + "\n".join(notes) + "\n\n"

    content = f"""---
title: {title}
sidebar_label: {title}
sidebar_position: {order}
---

# {title}

{summary}

## Where to find it

{breadcrumbs_str}

{conditions_str}

## Settings

{settings_table}

{notes_section}## Related

- [Rotorflight documentation](https://www.rotorflight.org/docs/)

*Documented against RFSuite Ethos {suite_version}.*
"""
    return content


def scaffold_all(force=False):
    """Scaffold documentation skeletons for all reachable pages."""
    pages = parse_lua_menus()
    suite_version = get_suite_version()
    created = 0
    skipped = 0

    for p in pages:
        target_file = DOCS_PAGES_DIR / p["doc_path"]
        if target_file.exists() and not force:
            skipped += 1
            continue

        target_file.parent.mkdir(parents=True, exist_ok=True)
        doc_content = generate_page_doc(p, suite_version)
        target_file.write_text(doc_content, encoding="utf-8")
        created += 1
        print(f"  Created: docs/pages/{p['doc_path']}")

    print(f"\nScaffolding complete: {created} created, {skipped} existing preserved.")
    update_index()


def update_index():
    """Generate or update docs/pages/README.md central index."""
    pages = parse_lua_menus()
    suite_version = get_suite_version()

    # Group pages by root domain
    sections = {}
    for p in pages:
        group_key = p["breadcrumbs"][0] if p["breadcrumbs"] else "General"
        sub_key = p["breadcrumbs"][1] if len(p["breadcrumbs"]) > 1 else ""
        section_title = f"{group_key} → {sub_key}" if sub_key else group_key
        if section_title not in sections:
            sections[section_title] = []
        sections[section_title].append(p)

    lines = [
        "---",
        "title: Pages",
        "sidebar_label: Pages",
        "---",
        "",
        "# Configuration pages",
        "",
        "Reference documentation for each configuration and settings page reachable",
        "within the RFSuite Ethos system tool.",
        "",
        f"**Status:** {len(pages)} reachable pages in navigation hierarchy.",
        "",
        "The *Conditions* column names what hides, greys out or locks a page; the sentences",
        "and structure follow [_template.md](../_template.md).",
        "",
    ]

    for sec_title, sec_pages in sections.items():
        lines.append(f"## {sec_title}\n")
        lines.append("| Page | File | Conditions | Status |")
        lines.append("| --- | --- | --- | --- |")
        for p in sec_pages:
            doc_rel = p["doc_path"]
            doc_file = DOCS_PAGES_DIR / doc_rel
            is_written = doc_file.exists()
            status = "written" if is_written else "to write"
            file_link = f"[{doc_rel}]({doc_rel})" if is_written else f"`{doc_rel}`"
            conds_desc = format_conditions(p["conditions"])
            lines.append(f"| {p['title']} | {file_link} | {conds_desc} | {status} |")
        lines.append("")

    INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
    INDEX_PATH.write_text("\n".join(lines).strip() + "\n", encoding="utf-8")
    print(f"Updated index: docs/pages/README.md ({len(pages)} pages)")


def check_docs():
    """Verify that all reachable pages have corresponding markdown documentation."""
    pages = parse_lua_menus()
    missing = []
    for p in pages:
        doc_file = DOCS_PAGES_DIR / p["doc_path"]
        if not doc_file.exists():
            missing.append(p)

    if missing:
        print(f"FAILED: {len(missing)} of {len(pages)} pages lack documentation files:")
        for m in missing:
            print(f"  Missing: docs/pages/{m['doc_path']} (script: {m['script']})")
        return 1

    print(f"OK: All {len(pages)} reachable configuration pages are documented.")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--scaffold-all", action="store_true", help="Generate skeletons for all reachable pages")
    parser.add_argument("--force", action="store_true", help="Overwrite existing documentation files when scaffolding")
    parser.add_argument("--update-index", action="store_true", help="Rebuild docs/pages/README.md central index")
    parser.add_argument("--check", action="store_true", help="Verify that all pages have documentation")
    parser.add_argument("--page", help="Scaffold or view documentation for a specific doc path")

    args = parser.parse_args()

    if args.scaffold_all:
        scaffold_all(force=args.force)
        return 0
    elif args.update_index:
        update_index()
        return 0
    elif args.check:
        return check_docs()
    elif args.page:
        pages = parse_lua_menus()
        suite_version = get_suite_version()
        matched = [p for p in pages if p["doc_path"] == args.page or p["script"] == args.page]
        if not matched:
            print(f"No page found matching: {args.page}", file=sys.stderr)
            return 1
        p = matched[0]
        content = generate_page_doc(p, suite_version)
        target = DOCS_PAGES_DIR / p["doc_path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        print(f"Generated docs/pages/{p['doc_path']}")
        return 0
    else:
        parser.print_help()
        return 0


if __name__ == "__main__":
    sys.exit(main())
