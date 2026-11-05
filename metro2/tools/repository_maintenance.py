#!/usr/bin/env python3
"""Archive first, compact Pages, then remove replaceable CI output and empty refs."""
import argparse
import concurrent.futures
import io
import json
import os
import tempfile
import urllib.error
import urllib.parse
import zipfile
from pathlib import Path
from web_publication import GitHub, Archive, REPO, ARCHIVE_TAG, INITIAL_CURRENT, INITIAL_PREVIOUS, compact, sha, site_bytes

PLACEHOLDERS=['feature/audio','feature/cab','feature/cameras','feature/carriage','feature/controls-ui','feature/graphics','feature/passengers','feature/platforms','feature/station-logic','feature/train-physics']
TEMPLATE_SHA='47f59630431104f6bb93434993a15b37cf330814'
OBSOLETE_WORKFLOWS={'.github/workflows/metro2-four-car-diagnostics.yml','.github/workflows/metro2-four-car-audit.yml','.github/workflows/metro2-android-finalize.yml','.github/workflows/metro2-tunnel-v31-web.yml','.github/workflows/metro2-tunnel-v32-web.yml','.github/workflows/metro2-pages-recovery.yml','.github/workflows/metro2-browser-preview.yml','.github/workflows/metro2-cab-validation.yml','.github/workflows/metro2-p1-build.yml','.github/workflows/metro2-web-preview.yml','.github/workflows/browser-visual.yml','.github/workflows/passengers.yml','.github/workflows/publish-cab.yml','.github/workflows/publish-modular-preview.yml','.github/workflows/publish-preview.yml','.github/workflows/station-base-webgl.yml','.github/workflows/station-base.yml','.github/workflows/v106-browser-smoke.yml','.github/workflows/v106-gh-pages.yml','.github/workflows/v106-preview-pages.yml','.github/workflows/validate-cab.yml','.github/workflows/wagon-pages.yml','.github/workflows/wagon-visual.yml'}
GENERATED_BUILDS={'four-car-web-build','four-car-common-source','tz31-web-build','tz32-web-build','four-car-baseline-web','four-car-lighting-web','four-car-diagnostic-web','four-car-probe-web','four-car-audit-build','metro2-browser-preview','metro2-p1-web','metro2-p1-android-debug'}
KEEP_LATEST={'tz33-web-build','metro2-tz30-android-apk','repository-audit-inventory','repository-maintenance-result','v106-browser-smoke','v106-source-reference','wagon-3d-visual-report','browser-smoke-screenshots','metro-browser-screenshots','cab-browser-screenshots','station-base-webgl-diagnostics','station-base-acceptance','passenger-layout-browser'}

def suffix():return os.environ['GITHUB_RUN_ID']+'-'+os.environ.get('GITHUB_RUN_ATTEMPT','1')
def ref(api,name):return api.request(f'/repos/{REPO}/git/ref/'+urllib.parse.quote(name,safe='/'))['object']['sha']
def tag(api,name,target):
    try:return ref(api,'tags/'+name)
    except urllib.error.HTTPError as error:
        if error.code!=404:raise
    api.request(f'/repos/{REPO}/git/refs','POST',{'ref':'refs/tags/'+name,'sha':target})
    return target

def prepare(args):
    root=Path(args.site).resolve();out=Path(args.out).resolve();out.mkdir(parents=True,exist_ok=True)
    api=GitHub()
    import subprocess
    pages_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root).decode().strip()
    branches=api.paged(f'/repos/{REPO}/branches')
    artifacts=api.paged(f'/repos/{REPO}/actions/artifacts','artifacts')
    workflows=api.paged(f'/repos/{REPO}/actions/workflows','workflows')
    repository=api.request(f'/repos/{REPO}')
    source_head=ref(api,'heads/feature/metro2-cab-integration-v33')
    source_tree=api.request(f'/repos/{REPO}/git/trees/{source_head}?recursive=1')
    assets_tree=next(x['sha'] for x in source_tree['tree'] if x['path']=='metro2/assets')
    snapshots={
      'pages':tag(api,'backup/pre-cleanup-2026-11-06-pages',pages_head),
      'source':tag(api,'backup/pre-cleanup-2026-11-06-source',source_head),
      'empty_template':tag(api,'archive/empty-feature-template-2026-11-06',TEMPLATE_SHA),
    }
    inventory={'repository_size_kib':repository['size'],'source_head':source_head,'source_asset_tree':assets_tree,'source_files_bytes':sum(x.get('size',0) for x in source_tree['tree']),'pages_head':pages_head,'pages_bytes':site_bytes(root),'branches':branches,'artifacts':artifacts,'artifact_bytes':sum(x['size_in_bytes'] for x in artifacts if not x['expired']),'workflows':workflows,'rollback_tags':snapshots,'policy_commit':os.environ['GITHUB_SHA']}
    # Retain every CI source commit before removing reproducible compiled output.
    sources=sorted({a.get('workflow_run',{}).get('head_sha') for a in artifacts if a.get('workflow_run',{}).get('head_sha')})
    # A self-contained Git bundle also preserves CI commits that GITHUB_TOKEN
    # cannot tag because their historical workflows differ from this workflow.
    archived_sources={}
    fetch=['git','fetch','--no-recurse-submodules','--no-tags']
    if subprocess.check_output(['git','rev-parse','--is-shallow-repository'],cwd=root).decode().strip()=='true':fetch.append('--unshallow')
    fetch+=['origin','+refs/heads/*:refs/remotes/origin/*','+refs/tags/*:refs/tags/*']
    subprocess.run(fetch,cwd=root,check=True)
    for source in sources:
        exists=subprocess.run(['git','cat-file','-e',source+'^{commit}'],cwd=root,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
        if not exists:subprocess.run(['git','fetch','--no-tags','origin',source],cwd=root,check=True)
        name='refs/archive/ci-source/'+source
        subprocess.run(['git','update-ref',name,source],cwd=root,check=True)
        archived_sources[name]=source
    inventory['ci_source_refs']=archived_sources
    file=out/'inventory-before.json';file.write_text(json.dumps(inventory,indent=2))
    archive=Archive(api,pages_head)
    archive.upload(file,'revision-before-'+suffix()+'.json')
    bundle=out/'repository-before-cleanup.bundle'
    subprocess.run(['git','bundle','create',str(bundle),'--all'],cwd=root,check=True)
    subprocess.run(['git','bundle','verify',str(bundle)],cwd=root,check=True)
    archive.upload(bundle,'repository-before-cleanup-'+suffix()+'.bundle')
    inventory['repository_bundle']='repository-before-cleanup-'+suffix()+'.bundle'
    bundle.unlink()
    newest={}
    for a in artifacts:
        if not a['expired']:newest[a['name']]=max(newest.get(a['name'],0),a['id'])
    evidence=[]
    for a in artifacts:
        if a['expired'] or a['size_in_bytes']>30_000_000 or a['name'] in {'github-pages','tz33-web-build','metro2-tz30-android-apk','repository-audit-inventory'}:continue
        name=a['name'].lower()
        historical=('four-car' in name and 'evidence' in name) or name.startswith('wagon-3d-visual-report-')
        latest=a['id']==newest[a['name']] and any(t in name for t in ['evidence','diagnostic','report','screenshots','reference','acceptance','layout-browser','smoke','p1-android'])
        if historical or latest:evidence.append(a)
    archived_ids=[];skipped=[]
    if evidence:
        def read(item):
            try:
                data=api.request(f'/repos/{REPO}/actions/artifacts/{item["id"]}/zip',raw=True)
                with zipfile.ZipFile(io.BytesIO(data)) as z:
                    if z.testzip() is not None:raise RuntimeError('CRC failure')
                return item,data,None
            except Exception as error:return item,None,type(error).__name__
        target=out/'diagnostic-evidence.zip'
        with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_STORED) as z:
            with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
                for item,data,error in pool.map(read,evidence):
                    if error:skipped.append({'id':item['id'],'reason':error});continue
                    z.writestr(str(item['id'])+'.zip',data);archived_ids.append(item['id'])
            z.writestr('inventory.json',json.dumps(evidence,indent=2))
        archive.upload(target,'diagnostic-evidence-'+suffix()+'.zip')
        target.unlink()
    manifest=compact(root,archive,INITIAL_CURRENT,INITIAL_PREVIOUS,os.environ['GITHUB_SHA'])
    state={'inventory':inventory,'manifest':manifest,'archived_evidence_ids':archived_ids,'evidence_skipped':skipped,'release_url':archive.release['html_url']}
    (out/'maintenance-state.json').write_text(json.dumps(state,indent=2))
    print('PREPARE_COMPLETE',json.dumps({'pages_before':inventory['pages_bytes'],'pages_after':site_bytes(root),'archives':len(manifest['archives']),'release':archive.release['html_url'],'evidence_archived':len(archived_ids),'evidence_skipped':len(skipped)}),flush=True)

def finalize(args):
    root=Path(args.site).resolve();out=Path(args.out).resolve()
    state=json.loads((out/'maintenance-state.json').read_text());api=GitHub();inventory=state['inventory']
    removed=[];branches_skipped=[]
    for branch in PLACEHOLDERS:
        try:head=ref(api,'heads/'+branch)
        except urllib.error.HTTPError as error:
            if error.code==404:continue
            raise
        if head!=TEMPLATE_SHA:branches_skipped.append(branch);continue
        api.request(f'/repos/{REPO}/git/refs/heads/'+urllib.parse.quote(branch,safe='/'),'DELETE')
        removed.append(branch)
    disabled=[];disable_skipped=[]
    for workflow in api.paged(f'/repos/{REPO}/actions/workflows','workflows'):
        if workflow['path'] not in OBSOLETE_WORKFLOWS or workflow['state']!='active':continue
        try:
            api.request(f'/repos/{REPO}/actions/workflows/{workflow["id"]}/disable','PUT')
            disabled.append(workflow['path'])
        except urllib.error.HTTPError as error:disable_skipped.append({'path':workflow['path'],'status':error.code})
    artifacts=api.paged(f'/repos/{REPO}/actions/artifacts','artifacts')
    newest={}
    for item in artifacts:
        if not item['expired']:
            newest[item['name']]=max(newest.get(item['name'],0),item['id'])
    deletes=[];delete_skipped=[]
    evidence=set(state['archived_evidence_ids'])
    for item in artifacts:
        if item['expired']:continue
        name=item['name'];candidate=False
        if name=='github-pages':candidate=item['id']!=newest[name]
        elif name in GENERATED_BUILDS:candidate=True
        elif name in KEEP_LATEST:candidate=item['id']!=newest[name]
        elif item['id'] in evidence:candidate=True
        elif name.startswith('wagon-3d-visual-report-') and item['id'] not in {x['id'] for x in state['evidence_skipped']}:candidate=True
        elif 'four-car' in name and 'evidence' in name and item['id'] not in {x['id'] for x in state['evidence_skipped']}:candidate=True
        elif name=='tz31-minimal-visual-evidence' and item['id'] in evidence:candidate=True
        if not candidate:continue
        try:
            api.request(f'/repos/{REPO}/actions/artifacts/{item["id"]}','DELETE')
            deletes.append({'id':item['id'],'name':name,'bytes':item['size_in_bytes']})
        except urllib.error.HTTPError as error:delete_skipped.append({'id':item['id'],'status':error.code})
    after=api.paged(f'/repos/{REPO}/actions/artifacts','artifacts')
    # Every unique source/recovery branch remains; all originals remain reachable.
    current_source=ref(api,'heads/feature/metro2-cab-integration-v33')
    current_tree=api.request(f'/repos/{REPO}/git/trees/{current_source}?recursive=1')
    current_assets=next(x['sha'] for x in current_tree['tree'] if x['path']=='metro2/assets')
    if current_assets!=inventory['source_asset_tree']:raise RuntimeError('Original asset tree changed unexpectedly')
    report={'pages_before_bytes':inventory['pages_bytes'],'pages_after_bytes':site_bytes(root),'pages_budget_bytes':state['manifest']['site_budget_bytes'],'actions_before_bytes':inventory['artifact_bytes'],'actions_after_bytes':sum(a['size_in_bytes'] for a in after if not a['expired']),'actions_deleted_bytes':sum(a['bytes'] for a in deletes),'actions_deleted_count':len(deletes),'branches_before':len(inventory['branches']),'branches_removed':removed,'branches_skipped':branches_skipped,'workflows_disabled':disabled,'workflow_skips':disable_skipped,'artifact_skips':delete_skipped,'evidence_skipped':state['evidence_skipped'],'original_asset_tree_unchanged':True,'policy_commit':os.environ['GITHUB_SHA'],'source_head_before':inventory['source_head'],'archive_release':state['release_url'],'web_url':'https://sskuz.github.io/Minskmetrogame/metro2/play/','previous_url':'https://sskuz.github.io/Minskmetrogame/metro2/previous/','apk_url':state['manifest']['apk']['url'],'archives':len(state['manifest']['archives']),'rollback_tags':inventory['rollback_tags']}
    path=out/'maintenance-result.json';path.write_text(json.dumps(report,indent=2,ensure_ascii=False))
    archive=Archive(api,inventory['pages_head']);archive.upload(path,'revision-after-'+suffix()+'.json')
    print('MAINTENANCE_RESULT',json.dumps(report,ensure_ascii=False),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('command',choices=['prepare','finalize']);parser.add_argument('--site',required=True);parser.add_argument('--out',required=True)
    args=parser.parse_args()
    (prepare if args.command=='prepare' else finalize)(args)
