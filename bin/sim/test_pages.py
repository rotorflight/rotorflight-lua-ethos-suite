"""Opens every page of the Rotorflight app and fails when one logs a Lua error.

The menu is read from MENUS in src/rfsuite/app/tool.lua, so a new page is covered as
soon as it has a tile. Each tile is found on the screen by its English title (OCR),
touched, and the page must load its script (the simulator and the radio log every
loadFile()). The page is then left with RTN. One screenshot per page is saved.

Options (run.py --option name=value):
  offline=1   only the tiles that open without a flight controller
  only=TEXT   only the pages whose script path contains TEXT (the menus are still walked)
  passes=N    walk the menu N times (default 1): with memory logs enabled in the suite,
              the Lua heap after each pass is printed, to spot growth between passes
"""

import json
import os
import re
import threading
import time

import ethos_ocr
from ethos_test import EthosBaseTest

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SUITE = 'rfsuite'
APP_TILE = 'Rotorflight'
BACKGROUND_TASK = 'Rotorflight [Background]'
ROOT = '__root__'

# Pages that act on the model as soon as they are used. They are opened in the
# simulator only: a radio may be bound to a powered model.
SIMULATOR_ONLY = ('app/pages/motor_override.lua', 'app/pages/setup_wizard.lua')

LUA_ERROR = re.compile(r'\.lua:\d+: |stack traceback|attempt to (call|index|compare|perform|concatenate)')
MEMORY = re.compile(r'\[mem\] (.+?): lua=([\d.]+)KB')


def english(text, strings):
    """text with its @i18n(key)@ tags replaced by the English of bin/i18n/json/en.json."""
    def resolve(match):
        node = strings
        for part in match.group(1).split('.'):
            node = node[part]
        return node['english']
    return re.sub(r'@i18n\(([\w.]+)\)@', resolve, text)


def read_menus():
    """{menu id: [entry]} from app/tool.lua, the root menu under ROOT. An entry is a
    dict: title (English), script or menu, and why it is skipped, if it is."""
    with open(os.path.join(REPO, 'bin', 'i18n', 'json', 'en.json'), encoding='utf-8') as f:
        strings = json.load(f)
    menus, current, in_menus = {}, None, False
    with open(os.path.join(REPO, 'src', SUITE, 'app', 'tool.lua'), encoding='utf-8') as f:
        for line in f:
            if line.startswith('local ROOT_ENTRIES = {'):
                current = ROOT
            elif line.startswith('local MENUS = {'):
                in_menus = True
            elif in_menus and line.startswith('}'):
                break
            elif in_menus and re.match(r'  \w+ = \{', line):
                current = line.split('=')[0].strip()
            entry = re.match(r'\s*\{title = "([^"]*)"', line)
            if not entry or current is None:
                continue
            script = re.search(r'script = "([^"]+)"', line)
            menu = re.search(r'menuId = "([^"]+)"', line)
            if not script and not menu:
                continue
            skip = None
            if 'escProtocolId' in line:
                skip = 'needs a given ESC protocol'
            elif 'requiresServoBus' in line:
                skip = 'needs a servo bus'
            elif 'visibleWhen' in line:
                skip = 'hidden unless developer mode is on'
            menus.setdefault(current, []).append({
                'title': english(entry.group(1), strings),
                'script': script.group(1) if script else None,
                'menu': menu.group(1) if menu else None,
                'offline': 'offline = true' in line,
                'skip': skip,
            })
    return menus


class LogReader(threading.Thread):
    """Reads the log all the time, in the background. getLog gives at most the last
    200 lines since the previous call, and opening one page can log more than that
    while the test reads the screen (OCR): a Lua error among them would be missed."""

    def __init__(self, remote):
        super().__init__(daemon=True)
        self.remote = remote
        self.next = remote.call('getLog')['next']
        self.lines = []
        self.lost = 0  # polls that lost lines all the same
        self.lock = threading.Lock()
        self.stopped = threading.Event()

    def run(self):
        while not self.stopped.wait(0.1):
            try:
                body = self.remote.call('getLog', since=self.next)
            except Exception:  # pylint: disable=broad-except
                continue       # the server restarts (reload), or is gone: the test fails on its own
            with self.lock:
                self.lines += body['lines']
                self.next = body['next']
                self.lost += bool(body.get('truncated'))

    def take(self):
        """The lines read since the previous call."""
        with self.lock:
            lines, self.lines = self.lines, []
        return lines


class PagesTest(EthosBaseTest):
    TITLE = 'Every page of the app opens without a Lua error'

    def steps(self):
        # No reload on a radio: `reload ALL` restarted an X20S (26.2.0-RC11) into its STM32
        # bootloader, off the serial port, until it was turned off and on again.
        start = [self.go_home] if self.kind == 'radio' else [self.reload_all, self.close_checklist_warning]
        return start + [self.enable_background_task, self.open_app, self.open_every_page]

    def setup(self):
        self.menus = read_menus()
        self.errors = []      # (page, log line)
        self.skipped = []     # (page, reason)
        self.opened = 0
        self.memory = []      # (tag, Lua heap in KB), as the suite logs them
        self.cut = []         # (title, text shown) of the tiles too narrow for their title
        self.reader = LogReader(self.remote)  # the errors are listed at the end, not raised
        self.reader.start()

    def teardown(self):
        self.reader.stopped.set()

    # ---------- Log ----------

    def read_log(self, page):
        """The new log lines: the Lua errors go to self.errors, the memory lines to self.memory."""
        lines = self.reader.take()
        for line in lines:
            if LUA_ERROR.search(line):
                self.errors.append((page, line.strip()))
                self.trace(f'Lua error: {line.strip()}')
            memory = MEMORY.search(line)
            if memory:
                self.memory.append((memory.group(1), float(memory.group(2))))
        return lines

    def wait_loaded(self, script, timeout=8):
        """True once the log shows that script was loaded."""
        wanted = f'{SUITE}/{script}'
        deadline = time.time() + timeout
        while True:
            if any('loadFile' in line and wanted in line for line in self.read_log(script)):
                return True
            if time.time() > deadline:
                return False
            time.sleep(0.2)

    def wait_quiet(self, page, quiet=1.0, timeout=8):
        """Waits until the log has no new line for quiet seconds: the page read its values."""
        deadline = time.time() + timeout
        last = time.time()
        while time.time() < deadline and time.time() - last < quiet:
            # The simulated sensors are read from their files all the time: not activity.
            if any('/sim/sensors/' not in line for line in self.read_log(page)):
                last = time.time()
            time.sleep(0.2)

    # ---------- Steps ----------

    def background_task_switch(self):
        """(on, where to touch) for the OFF / ON switch of the background task. The text
        of its state is the bright one, white or orange with the focus: toggle_is_on()
        of ethos-tools only knows the orange one."""
        label = self.find_text(BACKGROUND_TASK)
        line = [t for t in self.texts if t.x > label.x + label.w and abs(t.center[1] - label.center[1]) < label.h]
        texts = {t.text.strip().upper(): t for t in line}
        if 'ON' not in texts or 'OFF' not in texts:
            self.fail(f'No OFF / ON switch on the "{BACKGROUND_TASK}" line')
        image = ethos_ocr.load(os.path.join(self.remote.shots_dir, 'ocr.png'))

        def brightness(t):
            return int(image[t.y:t.y + t.h, t.x:t.x + t.w].max())

        on, off = texts['ON'], texts['OFF']
        return brightness(on) > brightness(off), ((off.x + off.w + on.x) // 2, on.center[1])

    def enable_background_task(self):
        """Model / Lua: the background task is on"""
        self.open_model_menu('Lua')
        on, switch = self.background_task_switch()
        if on:
            self.trace('already on')
        elif self.kind == 'radio':
            self.fail(f'Turn "{BACKGROUND_TASK}" on in Model / Lua (not changed on a radio)')
        else:
            self.touch(*switch, ms=100, what=f'"{BACKGROUND_TASK}" switch')
            self.wait(0.5)
            if not self.background_task_switch()[0]:
                self.fail(f'"{BACKGROUND_TASK}" did not turn on')
        self.go_home()

    def open_app(self):
        """System / Rotorflight"""
        self.open_system_menu(APP_TILE)
        first = self.menus[ROOT][0]['title']
        if not self.find_tile(first, timeout=10):
            self.fail(f'The app did not open: no "{first}" tile')
        self.wait(3)  # the background task connects to the flight controller
        self.read_log('app')
        self.screenshot('app')

    def open_every_page(self):
        """Open every page"""
        passes = int(self.option('passes', 1))
        for number in range(1, passes + 1):
            self.walk(ROOT, [])
            heap = next((kb for tag, kb in reversed(self.memory) if tag.startswith('menu:')), None)
            if heap is not None:
                self.trace(f'pass {number}: Lua heap {heap:.1f} KB back on the menu')
        self.trace(f'{self.opened} pages opened, {len(self.skipped)} skipped')
        for title, shown in self.cut:
            self.trace(f'title cut on this display: "{title}" shown as "{shown}"')
        if self.reader.lost:
            self.trace(f'warning: log lines were lost {self.reader.lost} time(s), an error among them is not seen')
        for page, reason in self.skipped:
            self.trace(f'skipped {page}: {reason}')
        if self.errors:
            self.fail(f'{len(self.errors)} Lua error(s): ' + '; '.join(f'{page}: {line}' for page, line in self.errors))

    # ---------- Menu walk ----------

    def why_skipped(self, entry):
        if entry['skip']:
            return entry['skip']
        if self.option('offline') and not entry['offline']:
            return 'needs a flight controller (offline=1)'
        script = entry['script']
        if script:
            if self.kind == 'radio' and script in SIMULATOR_ONLY:
                return 'acts on the model: simulator only'
            only = self.option('only')
            if only and only not in script:
                return 'not selected (only=...)'
        return None

    def wanted(self, menu_id):
        """True when a page of this menu, or of its submenus, is opened."""
        return any(not self.why_skipped(e) and (e['script'] or self.wanted(e['menu']))
                   for e in self.menus.get(menu_id, []))

    def walk(self, menu_id, trail):
        for entry in self.menus.get(menu_id, []):
            name = entry['script'] or ' / '.join(trail + [entry['title']])
            reason = self.why_skipped(entry)
            if reason:
                if 'not selected' not in reason and (name, reason) not in self.skipped:
                    self.skipped.append((name, reason))
                continue
            if entry['menu'] and not self.wanted(entry['menu']):
                reasons = sorted({self.why_skipped(e) or 'no page in it' for e in self.menus.get(entry['menu'], [])})
                reasons = [r for r in reasons if 'not selected' not in r]
                if reasons and not any(n == name for n, _ in self.skipped):
                    self.skipped.append((name, f'{len(self.menus.get(entry["menu"], []))} tiles, {"; ".join(reasons)}'))
                continue
            self.open_tile(entry['title'])
            if entry['menu']:
                self.wait(0.5)
                self.read_log(name)
                self.walk(entry['menu'], trail + [entry['title']])
            elif not self.check_page(entry):
                continue  # nothing opened: an RTN would leave the menu itself
            self.leave(entry, name)

    def find_tile(self, title, timeout=2):
        """The text of the tile titled title, or None. A title too long for the tile is
        cut ("PID Bandwid..."): the text which is its beginning then, and it is noted."""
        found = self.find_text(title, timeout=timeout, required=False)
        if found:
            return found
        wanted = ethos_ocr.normalize(title)
        for text in self.texts:
            shown = text.text.strip()
            stem = ethos_ocr.normalize(shown.rstrip('.…'))
            if (shown != shown.rstrip('.…') and len(stem) >= 5 and wanted.startswith(stem)
                    and text.center[1] > self._title_bottom()):
                if (title, shown) not in self.cut:
                    self.cut.append((title, shown))
                return text
        return None

    def open_tile(self, title):
        """Touches the tile, the menu scrolled down, then up, until it is shown."""
        width, height = self.display[0] or 800, self.display[1] or 480
        top, bottom = height * 3 // 10, height * 85 // 100
        found = self.find_tile(title)
        for start, end in ((bottom, top), (top, bottom)):
            previous = None
            while not found:
                shown = [(t.text, t.y) for t in self.texts]
                if shown == previous:  # the end of the menu
                    break
                previous = shown
                self.swipe(width // 2, start, width // 2, end)
                self.wait(0.3)
                found = self.find_tile(title, timeout=0)
        if not found:
            self.fail(f'No "{title}" tile, only: {", ".join(t.text for t in self.texts)}')
        self.touch(*found.center, ms=100, label=title)

    def check_page(self, entry):
        """Waits for the page of the tile just touched and saves its screen. False when
        the tile did not open it: a tile greyed out by a condition this test doesn't know."""
        script = entry['script']
        name = os.path.splitext(os.path.basename(script))[0]
        if not self.wait_loaded(script):
            self.errors.append((script, 'the tile did not open the page (its script was not loaded)'))
            self.trace(f'{script} was not loaded')
            self.screenshot(f'{name}-not-opened')
            return False
        self.opened += 1
        self.wait_quiet(script)
        self.screenshot(name)
        return True

    def leave(self, entry, name):
        """Back to the menu the tile is on: RTN, until the tile is shown again."""
        for _ in range(3):
            self.press('RTN')
            self.wait(0.5)
            self.read_log(name)
            if self.find_tile(entry['title']):
                return
        self.fail(f'{name}: RTN does not go back to the "{entry["title"]}" tile')
