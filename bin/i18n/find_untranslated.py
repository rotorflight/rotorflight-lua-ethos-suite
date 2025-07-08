import os
import re
import argparse

LUA_SOURCE_DIR = "../../scripts/rfsuite/"
EXCLUDE_DIR = os.path.join(LUA_SOURCE_DIR, "i18n")
ALLOWED_FIELDS = {"title", "value", "label", "text"}
WHITELIST_VALUES = {
    "bottom", "floor", "white", "green", "red", "orange",
    "rainbow", "lightgrey", "voltage", "rpm", "dial", "gauge", "ring",
    "smartfuel", "arc", "temp_esc", "object", "title", "current", "text",
    "telemetry", "time", "blackbox", "count", "black", "blue", "model",
    "governor", "rssi","gaugemin", "gaugemax", "min", "max","rate_profile",
    "throttle_percent","darkgrey","test","grey","top","center","cyan","left","right","bottom",
    "flight","bec_voltage", "image","rates","watts", "consumption","altitude","pidrates","horizontal",
    "vertical","power","pid_profile","valuepadding","valuepaddingleft","valuepaddingright","valuepaddingtop",
    "valuepaddingbottom","valuepaddingcenter","valuepaddingleftcenter","valuepaddingrightcenter",
    "titlepadding","titlepaddingleft","titlepaddingright","titlepaddingtop","titlepaddingbottom",
    "titlepaddingcenter","titlepaddingleftcenter","titlepaddingrightcenter","font","bgcolor","textcolor",
    "titlealign","titlepos","novalue","unit","titlecolor","valuealign","source","avg","value",
    "armflags","ceil","titlespacing","titlefont","font","totalflighttime","titlespacing","titlefont",
    "stattype","rowfont","highlightlarger","rowspacing","rowpadding","rowpaddingleft",
    "rowpaddingright","rowpaddingtop","rowpaddingbottom","rowpaddingleft","decimals",
    "altitudemin", "altitudemax", "altitudepadding", "altitudepaddingleft","altitudecolor",
    "crosshaircolor", "compasscolor", "laddercolor","arccolor","showladder","dynamicscalemin","dynamicscalemax",
    "imagewidth","imageheight","imagepadding","imagepaddingleft","imagepaddingright",
    "imagepaddingtop","imagepaddingbottom","imagepaddingleftcenter","imagealign",".png",
    "attpitch","attroll","attyaw","groundspeed","pixelsperdeg","showcompass","showgroundspeed",
    "groundspeedcolor","groundspeedmin","groundspeedmax","groundspeedpadding","rowalign","showaltitude",
    ".bmp","pid","rowalign","fillcolor","armdisableflags","showarc","profilecount",
    "ringbattsubtext","thresholds","fillbgcolor","thickness","ringbattsubalign",
    "ringbattsubpadding","ringbattsubpaddingleft","ringbattsubpaddingright",
    "flightcount", "general","ringbattsubpaddingbottom","ringbattsubpaddingtop",
    "innerringcolor","ringbatt","battstats",
    "battadvgap","battadvpaddingbottom","battadvpaddingleft","batterysegments",
    "innerringthickness","fuel","battadvpadding","battadvpaddingright","battadvpaddingleft","battadvvaluealign",
    "hidevalue","battadv","accentcolor","battery","batteryframe","batteryframethickness",
    "batteryspacing","battadvfont","cell_count","maxprefix","maxfont","maxpadding",
    "maxpaddingleft","maxpaddingright","maxpaddingtop","maxpaddingbottom",
    "gaugeorientation","gaugepaddingleft","gaugepaddingright",
    "gaugepaddingtop","gaugepaddingbottom","gaugepaddingleftcenter",
    "scalefactor","needlecolor","needlehubcolor","needlethickness","needlestartangle",
    "needlesweepangle","arcmax","maxtextcolor","needlehubsize","showvalue",
    "bandlabeloffset","bandlabeloffsettop","SCRIPTS:/","preflight","inflight","postflight",
    "init.lua","user","dashboard","nil","build","read","write","delete",
    "battadvblockalign","roundradius","battadvpaddingtop","panel1","func","round",
    "default_image","framecolor","dark","userdata","offsetx","offsety","bar",
    "paint","wakeup","ah","crsf","sport","crsfLegacy","sim","ringbattsubfont","yellow",
    "configure","theme_","table","transform","bandlabelfont","system","default",
    "info","accz","accy","accx","frsky","elrs","frsky_legacy","temp_mcu","adj_v","adj_f","uid",
    "vbatfullcellvoltage","vbatmaxcellvoltage","vbatwarningcellvoltage","parsed","buffer",
    "aileron","elevator","rudder","throttle","aux1","aux2","aux3","true","false",
    "events","adjfunctions","collective","id","msp","callback","big","small",
    "debug","readU","readS","@breavyn","@AERC Nitro","@RT-RC","@AERC","rftlbx",
     "uuid-","rf2sdh","little","writeU","writeS","lastflighttime","unknown",
     "crsfLegacy","@AERC","lastvalue","Ay","high"
}

def scan_for_untranslated(lua_dir, path_filter=None):
    """
    Scan the given directory for untranslated Lua strings.
    If path_filter is provided, only results from file paths containing the filter are returned.
    Returns a list of tuples: (file_path, line_number, text).
    """
    untranslated = []

    string_pattern = re.compile(r"(?<!\\)(['\"])(.*?)(?<!\\)\1")
    i18n_pattern = re.compile(r"i18n\.get\(\s*['\"](.*?)['\"]\s*\)")
    debug_line_pattern = re.compile(r"(rfsuite\.utils\.log|log\s*\(|print\s*\()")
    type_check_pattern = re.compile(r"==\s*['\"](function|string|table|number)['\"]")
    constant_pattern = re.compile(r"^[A-Z0-9_]{3,}$")
    field_pattern = re.compile(r"(\b\w+)\s*=\s*['\"](.*?)['\"]")

    def should_ignore(text):
        return (
            not text or
            constant_pattern.fullmatch(text) or
            text.lower() in WHITELIST_VALUES or
            any(c in text for c in "^()[]{}*+") or
            "/" in text or "\\" in text or
            text.endswith(('.png', '.bmp', '.lua')) or
            ("." in text and " " not in text) or
            "%" in text or text.endswith("$") or
            re.fullmatch(r"0x[0-9A-Fa-f]+", text) or
            re.fullmatch(r"[a-fA-F0-9]{8,}", text) or
            re.fullmatch(r"[a-zA-Z0-9_-]{16,}", text) or
            re.fullmatch(r"[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}", text) or
            re.fullmatch(r"\.[a-zA-Z0-9]{2,4}", text) or
            (re.fullmatch(r"[a-z0-9_]+", text) and "_" in text)
        )

    for root, _, files in os.walk(lua_dir):
        if root.startswith(EXCLUDE_DIR):
            continue
        for file in files:
            if not file.endswith(".lua"):
                continue
            full_path = os.path.join(root, file)
            try:
                with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                    in_block_comment = False
                    for lineno, line in enumerate(f, start=1):
                        stripped = line.strip()

                        if "--[[" in stripped:
                            in_block_comment = True
                        if "]]" in stripped and in_block_comment:
                            in_block_comment = False
                            continue
                        if in_block_comment or stripped.startswith("--"):
                            continue

                        if debug_line_pattern.search(line) or type_check_pattern.search(line):
                            continue

                        if "{" in line and "}" in line:
                            for key, text in field_pattern.findall(line):
                                text = text.strip()
                                if (key in ALLOWED_FIELDS and re.search(r'[a-zA-Z]{2,}', text)
                                        and not should_ignore(text)):
                                    untranslated.append((full_path, lineno, text))
                            continue

                        for match in string_pattern.findall(line):
                            text = match[1].strip()
                            if (re.search(r'[a-zA-Z]{2,}', text) and
                                    not i18n_pattern.search(line) and
                                    not should_ignore(text)):
                                untranslated.append((full_path, lineno, text))
            except Exception as e:
                print(f"[ERROR] Failed to read {full_path}: {e}")

    # Apply path filter if provided
    if path_filter:
        untranslated = [item for item in untranslated if path_filter in item[0]]

    return untranslated


def main():
    parser = argparse.ArgumentParser(description="Scan for untranslated Lua strings.")
    parser.add_argument('-d', '--dir', default=LUA_SOURCE_DIR,
                        help='Lua source directory to scan')
    parser.add_argument('-f', '--filter', dest='path_filter',
                        help='Only include results from file paths containing this string')
    args = parser.parse_args()

    results = scan_for_untranslated(args.dir, args.path_filter)
    if args.path_filter:
        print(f"🔍 Found {len(results)} potentially untranslated strings matching filter '{args.path_filter}':\n")
    else:
        print(f"🔍 Found {len(results)} potentially untranslated strings:\n")
    for file_path, line, text in results:
        print(f"{file_path}:{line} -> \"{text}\"")

if __name__ == "__main__":
    main()