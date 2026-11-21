#!/usr/bin/env python3
"""Execute offline tests. No Azure/GitHub API calls or Terraform apply."""
import json,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def run(cmd,stdin=None,expected=0):
    p=subprocess.run(cmd,input=stdin,text=True,capture_output=True)
    if expected==0:assert p.returncode==0,(cmd,p.stdout,p.stderr)
    else:assert p.returncode!=0,(cmd,p.stdout,p.stderr)
    return p

def test_shell():
    run(['bash','-n',str(ROOT/'automation/phase04.sh')])

def test_manifest():
    for required in ['index.html','GUIDE_COMPLET_FR.md','QUICK_START_FR.md','assets/architecture.png','automation/phase04.sh','Dockerfile','terraform/oidc/main.tf']:
        assert (ROOT/required).is_file(),required
    assert b'PNG' in (ROOT/'assets/architecture.png').read_bytes()[:16]

def test_yamls():
    import yaml
    for f in (ROOT/'.github/workflows').glob('*.yml'):
        y=yaml.load(f.read_text(),Loader=yaml.BaseLoader)
        assert 'workflow_dispatch' in y['on'] or 'push' in y['on']
        assert y['jobs'],f
    s=(ROOT/'.github/workflows/03-deploy.yml').read_text()
    assert '--container-name vote-frontend' in s
    assert 'BEFORE_REDIS' in s
    assert 'docker pull "$IMAGE"' in s

def test_identity_plan():
    image_scope='/subscriptions/s/resourceGroups/rg-cg360-app/providers/Microsoft.App/containerApps/ca-cg360-voting'
    subject='repo:NabilNet@123/cloudguard360-phase04@456:environment:cloudguard360-lab'
    items=[
      {'type':'azurerm_user_assigned_identity','address':'a','change':{'actions':['create'],'after':{}}},
      {'type':'azurerm_federated_identity_credential','address':'b','change':{'actions':['create'],'after':{'subject':subject,'issuer':'https://token.actions.githubusercontent.com','audience':['api://AzureADTokenExchange']}}},
      {'type':'azurerm_role_assignment','address':'c','change':{'actions':['create'],'after':{'role_definition_name':'Container Apps Contributor','scope':image_scope}}},
    ]
    cmd=[sys.executable,str(ROOT/'scripts/check_identity_plan.py'),'--subject',subject,'--app','ca-cg360-voting']
    run(cmd,json.dumps({'resource_changes':items}))
    bad=json.loads(json.dumps(items));bad[2]['change']['actions']=['delete']
    run(cmd,json.dumps({'resource_changes':bad}),expected=1)
    bad=json.loads(json.dumps(items));bad[2]['change']['after']['scope']='/subscriptions/s/resourceGroups/rg-cg360-app'
    run(cmd,json.dumps({'resource_changes':bad}),expected=1)
    bad=json.loads(json.dumps(items));bad[1]['change']['after']['subject']='repo:Wrong:environment:cloudguard360-lab'
    run(cmd,json.dumps({'resource_changes':bad}),expected=1)

def test_azure_app():
    d={'name':'ca-cg360-voting','properties':{'template':{'containers':[{'name':'vote-frontend','image':'abc','env':[{'name':'REDIS','value':'localhost'}]},{'name':'redis','image':'redis:7-alpine'}]},'configuration':{'ingress':{'external':True,'targetPort':80}}}}
    cmd=[sys.executable,str(ROOT/'scripts/check_azure_app.py'),'--expected','ca-cg360-voting']
    run(cmd,json.dumps(d))
    d['properties']['template']['containers'][1]['name']='redis-changed'
    run(cmd,json.dumps(d),expected=1)

def test_reconcile():
    with tempfile.TemporaryDirectory() as tmp:
        f=Path(tmp)/'terraform.tfvars'
        f.write_text('app = "test"\nfrontend_image = "old:image"\nredis_image="redis:7"\n')
        image='ghcr.io/nabilnet/cloudguard360-vote:'+'a'*40
        cmd=[sys.executable,str(ROOT/'scripts/reconcile_tfvars.py'),str(f),image]
        run(cmd)
        assert f.read_text()=='app = "test"\nfrontend_image = "'+image+'"\nredis_image="redis:7"\n'
        run(cmd[:-1]+['ghcr.io/evil/other:latest'],expected=1)
        f.write_text('frontend_image="x"\nfrontend_image="y"\n')
        run(cmd,expected=1)

def test_html():
    from bs4 import BeautifulSoup
    html=(ROOT/'index.html').read_text()
    soup=BeautifulSoup(html,'html.parser')
    assert soup.title is not None
    assert len(soup.select('section.step[id^="step-"]'))==8
    assert len(soup.select('button[data-copy]'))>=9
    ids={e['id'] for e in soup.select('[id]')}
    for btn in soup.select('[data-copy]'):
        assert btn['data-copy'] in ids
    js=soup.find('script').get_text()
    with tempfile.NamedTemporaryFile('w',suffix='.js') as f:
        f.write(js);f.flush();run(['node','--check',f.name])

def main():
    tests=[test_shell,test_manifest,test_yamls,test_identity_plan,test_azure_app,test_reconcile,test_html]
    for fn in tests:
        fn();print('PASS',fn.__name__)
    print('OFFLINE PACKAGE TESTS: ALL PASS (live Azure/GitHub operations not executed)')

if __name__=='__main__':main()
