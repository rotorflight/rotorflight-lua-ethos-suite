#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile

# The speech and audio libraries are imported only when prompts are built, so --check runs
# offline without them (issue #2366).
sox = None
texttospeech = None


def require_tts_dependencies():
    global sox, texttospeech
    try:
        import sox as _sox
    except ImportError:
        print("You need sox for python: python -m pip install sox")
        return False
    try:
        from google.cloud import texttospeech as _texttospeech
    except ImportError:
        print("You need google cloud text-to-speech for python: python -m pip install google-cloud-texttospeech")
        return False
    sox, texttospeech = _sox, _texttospeech
    return True


# Files the suite plays that no manifest declares: they are generated from the suite's own tables
# (tasks/adjfunctions/wavs.lua), so a check does not report them as orphans.
CHECK_IGNORED_PREFIXES = ("adjfunctions/",)


def load_manifest(path):
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return [entry for entry in data if isinstance(entry, dict) and entry.get('file')]


def check_manifest(json_file, audio_root, base_dir, variant, english_json=None):
    """Reconciles one manifest with the audio tree.

    Returns a dict with lists: missing (declared, no WAV), orphans (WAV, no entry),
    absent (declared in English, not in this manifest), untranslated (entry without a
    translation, so the generator speaks the English text).
    """
    entries = load_manifest(json_file)
    declared = {entry['file'] for entry in entries}
    root = os.path.join(audio_root, base_dir, variant)
    missing = sorted(f for f in declared if not os.path.isfile(os.path.join(root, f)))

    on_disk = set()
    for dirpath, _, names in os.walk(root):
        for name in names:
            if name.lower().endswith('.wav'):
                rel = os.path.relpath(os.path.join(dirpath, name), root)
                on_disk.add(rel.replace(os.sep, '/'))
    orphans = sorted(f for f in on_disk - declared if not f.startswith(CHECK_IGNORED_PREFIXES))

    absent = []
    if english_json is not None:
        absent = sorted({entry['file'] for entry in load_manifest(english_json)} - declared)
    untranslated = sorted(entry['file'] for entry in entries if not entry.get('translation'))
    return {'missing': missing, 'orphans': orphans, 'absent': absent, 'untranslated': untranslated}


def run_check(args):
    root = os.path.join(args.audio_root, args.base_dir, args.variant)
    if not os.path.isdir(root):
        print(f"Error: no audio folder at {root}")
        return 1

    english = args.english_json
    if english is None and args.base_dir != 'en':
        english = os.path.join(os.path.dirname(args.json), 'en.json')
    if english is not None and not os.path.isfile(english):
        print(f"Error: no English manifest at {english} (set --english-json)")
        return 1
    if english is not None and os.path.abspath(english) == os.path.abspath(args.json):
        english = None

    result = check_manifest(args.json, args.audio_root, args.base_dir, args.variant, english)
    sections = (
        ("Declared, but no WAV file", result['missing'], True),
        ("WAV file, but no manifest entry", result['orphans'], True),
        ("Declared in English, not in this manifest", result['absent'], True),
        ("No translation (the English text is spoken)", result['untranslated'], False),
    )
    for title, items, _ in sections:
        print(f"{title}: {len(items)}")
        for item in items:
            print(f"  {item}")
    failed = any(items for _, items, blocking in sections if blocking)
    return 1 if failed else 0


def extract_entries(json_path, base_dir, variant):
    """
    Load entries from a JSON file (array of {file, english, translation, needs_translation}).
    Returns list of tuples: (full_path, text_to_generate, options_dict, None).
    Logs a warning if translation is missing and uses English text.
    """
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    entries = []
    for entry in data:
        rel_path = entry.get('file')
        if rel_path is None:
            print(f"⚠️  Entry missing 'file' field in {json_path}", file=sys.stderr)
            continue

        # Determine text to generate
        if entry.get('translation') is None:
            print(f"⚠️ Missing translation for '{rel_path}' in {os.path.basename(json_path)}; using English.", file=sys.stderr)
            text = entry.get('english', '')
        else:
            text = entry['translation']

        # Build destination file path
        dest = os.path.join(
            '..', '..', 'bin', 'sound-generator', 'soundpack',
            base_dir, variant, rel_path
        )

        options = {}  # No extra options in JSON format
        entries.append((dest, text, options, None))

    return entries


class NullCache:
    def get(self, *args, **kwargs):
        return False

    def push(self, *args, **kwargs):
        pass


class PromptsCache:
    def __init__(self, directory):
        self.directory = directory
        if not os.path.exists(directory):
            os.makedirs(directory)

    def path(self, text, options):
        text_hash = hashlib.md5((text + str(options)).encode()).hexdigest()
        return os.path.join(self.directory, text_hash)

    def get(self, filename, text, options):
        cache_path = self.path(text, options)
        if not os.path.exists(cache_path):
            return False
        shutil.copy(cache_path, filename)
        return True

    def push(self, filename, text, options):
        shutil.copy(filename, self.path(text, options))


class BaseGenerator:
    @staticmethod
    def sox(input_path, output_path, tempo=None, norm=False, silence=False):
        tfm = sox.Transformer()
        tfm.set_output_format(channels=1, rate=16000, encoding="a-law")
        extra_args = []
        if tempo:
            extra_args.extend(["tempo", str(tempo)])
        if norm:
            extra_args.append("norm")
        if silence:
            extra_args.extend(["reverse", "silence", "1", "0.1", "0.1%", "reverse"])
        tfm.build(input_path, output_path, extra_args=extra_args)


class GoogleCloudTextToSpeechGenerator(BaseGenerator):
    def __init__(self, voice, speed):
        self.voice_code = voice
        self.speed = speed
        self.client = texttospeech.TextToSpeechClient()
        self.voice = texttospeech.VoiceSelectionParams(
            language_code="-".join(voice.split("-")[:2]),
            name=voice
        )

    def cache_prefix(self):
        return f"google-{self.voice_code}"

    def build(self, path, text, options):
        print(f"Generating: {path} -> {repr(text)}")
        response = self.client.synthesize_speech(
            input=texttospeech.SynthesisInput(text=text),
            voice=self.voice,
            audio_config=texttospeech.AudioConfig(
                audio_encoding=texttospeech.AudioEncoding.LINEAR16,
                sample_rate_hertz=16000,
                speaking_rate=self.speed * float(options.get('speed', 1.0))
            )
        )
        # Write to temp and then process
        temp_dir = tempfile.mkdtemp()
        tts_output = os.path.join(temp_dir, "output.wav")
        with open(tts_output, "wb") as out_f:
            out_f.write(response.audio_content)

        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.sox(tts_output, path, silence=True)
        shutil.rmtree(temp_dir)


def build(engine, voice, speed, json_file, cache_dir, base_dir, variant,
          only_missing=False, recreate_cache=False):
    # verify required audio path
    required_audio_path = os.path.join('..', '..', 'src', 'rfsuite', 'audio')
    if not os.path.exists(required_audio_path):
        print(f"Error: Required audio path not found: {required_audio_path}")
        return 1

    if engine != 'google':
        print(f"Unknown engine '{engine}' (only 'google' supported)")
        return 1

    generator = GoogleCloudTextToSpeechGenerator(voice, speed)
    cache = PromptsCache(os.path.join(cache_dir, generator.cache_prefix())) if cache_dir else NullCache()

    prompts = extract_entries(json_file, base_dir, variant)

    for path, text, options, _ in prompts:
        if only_missing and os.path.exists(path):
            continue
        if cache and not recreate_cache and cache.get(path, text, options):
            continue
        generator.build(path, text, options)
        if cache:
            cache.push(path, text, options)

    return 0


def main():
    if sys.version_info < (3, 0):
        print(f"{__file__} requires Python 3.")
        return 1

    parser = argparse.ArgumentParser(description="Builder for Ethos audio files via JSON")
    parser.add_argument('--json', required=True, help="JSON input file")
    parser.add_argument('--engine', default="google", help="TTS engine")
    parser.add_argument('--voice', help="TTS voice name (e.g., en-US-Wavenet-D); required to build")
    parser.add_argument('--check', action="store_true",
                        help="Reconcile the manifest with the audio tree; offline, no voice needed")
    parser.add_argument('--audio-root', default=os.path.join('..', '..', 'src', 'rfsuite', 'audio'),
                        help="Audio tree to check against (default: the suite's)")
    parser.add_argument('--english-json', help="English manifest to compare with (default: en.json next to --json)")
    parser.add_argument('--cache', help="TTS files cache directory")
    parser.add_argument('--recreate-cache', action="store_true",
                        help="Recreate files cache")
    parser.add_argument('--only-missing', action="store_true",
                        help="Generate only missing files")
    parser.add_argument('--speed', type=float, default=1.0,
                        help="Base speaking speed multiplier")
    parser.add_argument('--base-dir', required=True,
                        help="Language folder name (e.g., en, fr)")
    parser.add_argument('--variant', required=True,
                        help="i18n variant (e.g., male, female)")
    args = parser.parse_args()

    if args.check:
        return run_check(args)

    if not args.voice:
        print("--voice is required to build (use --check to reconcile without one)")
        return 1
    if not require_tts_dependencies():
        return 1

    return build(
        args.engine, args.voice, args.speed,
        args.json, args.cache,
        args.base_dir, args.variant,
        args.only_missing, args.recreate_cache
    )


if __name__ == "__main__":
    sys.exit(main())
