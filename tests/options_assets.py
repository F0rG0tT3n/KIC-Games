"""Options profile audit against the independent, checked archive/tooltip snapshot."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'tests/options-assets.json').read_text(encoding='utf-8'))
source = (ROOT / 'KIC-Games/ProfileData.lua').read_text(encoding='utf-8')
profiles = re.findall(r'\[(\d+)\]\s*=\s*\{\s*class\s*=\s*"([A-Z]+)"\s*,\s*icons\s*=\s*\{(.*?)\}\s*,\s*sounds\s*=\s*\{(.*?)\}', source, re.S)
assert len(profiles) == len(manifest['profiles']) == 40
expected = {p['specID']: p for p in manifest['profiles']}
sets = {}
for sid, token, icons, sounds in profiles:
    p = expected[int(sid)]
    assert token == p['token']
    ids = list(map(int, re.findall(r'^\s*(\d+),', icons, re.M)))
    assert ids == [i['id'] for i in p['icons']]
    assert len(ids) == len(set(ids)) == 7 and 134400 not in ids
    assert all(i['path'].startswith('interface/icons/') and i['path'].endswith('.blp') for i in p['icons'])
    seen = sets.setdefault(token, set())
    assert tuple(ids) not in seen, f'Duplicate same-class icon set: {sid}'
    seen.add(tuple(ids))
    audio = list(map(int, re.findall(r'^\s*(\d+),', sounds, re.M)))
    assert audio == [i['id'] for i in p['sounds']]
    assert all(i['path'].startswith('sound/spells/') and i['path'].endswith('.ogg') for i in p['sounds'])

audio_source = (ROOT / 'KIC-Games/Audio.lua').read_text(encoding='utf-8')
kits = json.loads((ROOT / 'tests/sound-kits.json').read_text(encoding='utf-8'))['kits']
assert set(re.findall(r'kit\s*=\s*(\d+)', audio_source)) == set(kits)
for file in ['Audio.lua', 'Settings.lua', 'Options.lua']:
    assert not re.search(r'\bSetCVar\s*\(|C_CVar\s*\.\s*SetCVar', (ROOT/'KIC-Games'/file).read_text(encoding='utf-8'))
assert 'volumeOverride' in audio_source and 'PlaySoundFile, entry.file, "SFX"' in audio_source
assert not re.search(r'\b(SetSpecialization|LearnTalent|LoadConfig|ActivateConfig)\s*\(', (ROOT/'KIC-Games/Profiles.lua').read_text(encoding='utf-8'))
print(f'PASS: 40 spec profiles, 280 unique-per-profile icon slots, {sum(bool(p["sounds"]) for p in expected.values())} curated spell-audio profiles, {len(kits)} verified SoundKit constants; no CVar/spec writes')
