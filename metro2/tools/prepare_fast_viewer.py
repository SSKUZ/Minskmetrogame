#!/usr/bin/env python3
"""Stage unchanged V50 modules, compute their source dependency closure, export boot only."""
import argparse, json, re, shutil
from pathlib import Path
from prepare_module_viewer import stage

ROOT = Path(__file__).resolve().parents[1]
ENTRIES = {'v106':'viewers/v106_inspection.tscn', 'uruchye':'modules/stations/uruchye/uruchye.tscn',
           'tunnel_16m':'modules/tunnels/tunnel_section_16m.tscn', 'depot':'modules/depot/depot.tscn'}
BOOT = ['viewers/module_viewer.tscn','viewers/module_viewer.gd','viewers/inspection_camera.gd',
        'viewers/flight_joystick.gd','viewers/module_pack_loader.gd','modules/core/module_catalog.gd',
        'tools/fast_loading/verify_module_packs.gd']


def closure(folder, seeds):
    pending=list(seeds); seen=set()
    while pending:
        name=pending.pop()
        if name in seen: continue
        source=folder/name
        if source.is_dir(): continue
        if not source.is_file(): raise RuntimeError('Missing module dependency: '+name)
        seen.add(name)
        if source.suffix in {'.gd','.tscn','.gdshader','.json','.tres'}:
            pending.extend(re.findall(r'''res://([^"'\s]+)''',source.read_text()))
    return seen


def prepare(output):
    stage(output)
    for name in ['build_module_packs.gd','verify_module_packs.gd']:
        target=output/'tools/fast_loading'/name;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/'tools/fast_loading'/name,target)
    # All dynamic advertising paths come from the unchanged V50 placement manifest.
    # That JSON and every referenced artwork stay exclusively in the V106 pack.
    groups={key:closure(output,[entry]) for key,entry in ENTRIES.items()}
    boot=set(BOOT)
    occurrences={name:sum(name in group for group in groups.values()) for name in set.union(*groups.values())}
    shared={name for name,count in occurrences.items() if count>1}-boot
    partitions={'shared':sorted(shared)}
    partitions.update({key:sorted(group-boot-shared) for key,group in groups.items()})
    all_paths=[p for group in partitions.values() for p in group]
    assert len(all_paths)==len(set(all_paths)), 'Resource duplicated between packs'
    assert not any(p.endswith('.glb') or '/saloon_' in p for p in boot)
    plan={'entries':ENTRIES,'boot':sorted(boot),'groups':partitions}
    (output/'pack-plan.json').write_text(json.dumps(plan,indent=2))
    # Export a single Web executable containing only the viewer and its interface.
    # Native PCKPacker separately packages imported optional resources, no engine rebuilds.
    config=(output/'export_presets.cfg').read_text().replace('export_filter="all_resources"','export_filter="resources"\nexport_files=PackedStringArray('+','.join(json.dumps('res://'+p) for p in BOOT)+')')
    config=config.replace('include_filter="*.json"','include_filter=""')
    (output/'export_presets.cfg').write_text(config)
    print('FAST_VIEWER_PLAN', {k:len(v) for k,v in partitions.items()})

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True)
    prepare(parser.parse_args().output)
