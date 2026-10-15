"""Options profile audit against the independent, checked archive/tooltip snapshot."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / 'tests/options-assets.json').read_text(encoding='utf-8'))
source = (ROOT / 'KIC-Games/ProfileData.lua').read_text(encoding='utf-8')
profiles = re.findall(r'\[(\d+)\]\s*=\s*\{\s*class\s*=\s*"([A-Z]+)"\s*,\s*icons\s*=\s*\{(.*?)\}\s*,\s*sounds\s*=\s*\{(.*?)\}\s*,\s*soundEvents\s*=\s*\{(.*?)\}', source, re.S)
assert len(profiles) == len(manifest['profiles']) == 40
expected = {p['specID']: p for p in manifest['profiles']}
sets = {}
research = json.loads((ROOT / 'tests/sound-research.json').read_text(encoding='utf-8'))
audited = {p['specID']: p for p in research['profiles']}
assert len(audited) == 40
for sid, token, icons, sounds, events in profiles:
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
    detailed = {key: int(value) for key, value in re.findall(r'(\w+)\s*=\s*(\d+)', events)}
    assert detailed == {key: value['id'] for key, value in p['soundEvents'].items()}
    assert p['soundEvents'] == audited[int(sid)]['soundEvents']
    assert len(audited[int(sid)]['iconCandidates']) == 9
    for entry in p['soundEvents'].values():
        assert entry['id'] > 0 and entry['path'].startswith('sound/spells/') and entry['path'].endswith('.ogg')
        assert not re.search(r'loop|channel|precast|state|travel', entry['path'])
        checked = research['soundFiles'][str(entry['id'])]
        assert checked['path'] == entry['path'] and checked['verifiedName']
    for change in audited[int(sid)]['iconChanges']:
        assert p['icons'][change['slot'] - 1] == change['replacement']
        assert change['replacement'].get('spellID') and change['replacement']['id'] != change['replacement']['spellID']
        assert research['replacedIconFiles'][str(change['replacement']['id'])] == change['replacement']['path']
    # Complete four-line selections must be different assets/abilities, not four random variants.
    tiers = [p['soundEvents'].get(key) for key in ['tetris_1_line','tetris_2_lines','tetris_3_lines','tetris_4_lines']]
    if all(tiers):
        assert len({v['id'] for v in tiers}) == len({v['candidate'] for v in tiers}) == 4

audio_source = (ROOT / 'KIC-Games/Audio.lua').read_text(encoding='utf-8')
kits = json.loads((ROOT / 'tests/sound-kits.json').read_text(encoding='utf-8'))['kits']
assert set(re.findall(r'kit\s*=\s*(\d+)', audio_source)) == set(kits)
for file in ['Audio.lua', 'Settings.lua', 'Options.lua']:
    assert not re.search(r'\bSetCVar\s*\(|C_CVar\s*\.\s*SetCVar', (ROOT/'KIC-Games'/file).read_text(encoding='utf-8'))
assert 'volumeOverride = volume' in audio_source and 'PlaySoundFile' not in audio_source
assert 'local volume = s.soundVolume * self.gain' in audio_source
assert 'C_Sound.PlaySound, kit, "Master", true, false, nil, volume' in audio_source
assert 'uiSoundSubType = "Master"' in audio_source and '"SFX"' not in audio_source
master_kits = json.loads((ROOT / 'tests/master-sound-kits.json').read_text(encoding='utf-8'))
mapping = re.search(r'Audio.fileKits = \{(.*?)\}', audio_source, re.S).group(1)
actual = {int(file): int(kit) for file, kit in re.findall(r'\[(\d+)\]\s*=\s*(\d+)', mapping)}
assert actual == {row['file']: row['kit'] for row in master_kits['mappings']}
for row in master_kits['mappings']:
    kit, entry = row['soundKit'], row['entry']
    assert row['entryCount'] == 1
    assert int(kit['ID']) == int(entry['SoundKitID']) == row['kit']
    assert int(entry['FileDataID']) == row['file'] and str(row['file']) in research['soundFiles']
    assert float(entry['Volume']) == 1 and int(entry['PlayerConditionID']) == 0
    assert kit['SoundType'] == '1'
    for field in ['Flags', 'SoundKitAdvancedID', 'PitchAdjust', 'BusOverwriteID', 'SoundMixGroupID',
                  'VolumeVariationPlus', 'VolumeVariationMinus', 'PitchVariationPlus', 'PitchVariationMinus', 'DialogType']:
        assert float(kit[field]) == 0
assert not re.search(r'\b(SetSpecialization|LearnTalent|LoadConfig|ActivateConfig)\s*\(', (ROOT/'KIC-Games/Profiles.lua').read_text(encoding='utf-8'))
print(f'PASS: 40 spec profiles, 280 unique-per-profile icon slots, 360 compared candidates, '
      f'{sum(len(p["iconChanges"]) for p in audited.values())} verified icon replacements, '
      f'{sum(bool(p["sounds"] or p["soundEvents"]) for p in expected.values())} partial spell-audio profiles, '
      f'{len(kits)} verified SoundKit constants, {len(master_kits["mappings"])} verified single-file kit adapters; no CVar/spec writes')
