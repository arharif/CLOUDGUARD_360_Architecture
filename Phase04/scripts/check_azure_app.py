#!/usr/bin/env python3
"""Read-only assertion: existing Phase 03 app includes exactly a vote frontend + Redis."""
import argparse, json, sys
p=argparse.ArgumentParser()
p.add_argument('--expected', required=True)
a=p.parse_args()
try:
    obj=json.load(sys.stdin)
    containers=obj['properties']['template']['containers']
    assert isinstance(containers,list)
    names={x['name'] for x in containers}
    assert names=={'vote-frontend','redis'}, f'unexpected containers: {names}'
    front=next(x for x in containers if x['name']=='vote-frontend')
    redis=next(x for x in containers if x['name']=='redis')
    assert front.get('image') and redis.get('image'), 'missing container image'
    assert obj['name'].lower()==a.expected.lower(), 'wrong app name'
    ingress=obj['properties']['configuration']['ingress']
    assert ingress['external'] is True, 'app ingress is not external'
    assert int(ingress['targetPort'])==80, 'expected frontend port 80'
    redis_env={x['name']: x.get('value') for x in front.get('env',[])}
    assert redis_env.get('REDIS') in ('localhost','127.0.0.1'), 'frontend REDIS not localhost: sidecar connectivity may fail'
    print('PASS: existing Azure Container App has expected frontend, Redis, port 80 and REDIS=localhost')
except (KeyError,TypeError,ValueError,AssertionError) as e:
    sys.exit(f'STOP: Existing app mismatch: {e}')
