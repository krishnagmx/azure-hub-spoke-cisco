#!/usr/bin/env python3
"""Render a licensed Cisco config without putting credentials in git."""
import ipaddress
import os
import re
from pathlib import Path
from string import Template

repo = Path(__file__).resolve().parent.parent
required = ['AZURE_VPN_IP', 'CISCO_PUBLIC_IP', 'VPN_PSK', 'ENVIRONMENT']
missing = [key for key in required if not os.environ.get(key)]
if missing:
    raise SystemExit('Missing environment variables: ' + ', '.join(missing))
if os.environ['ENVIRONMENT'] not in ('dev', 'prod'):
    raise SystemExit('ENVIRONMENT must be dev or prod')
for key in ('AZURE_VPN_IP', 'CISCO_PUBLIC_IP'):
    ipaddress.ip_address(os.environ[key])
if not re.fullmatch(r'[a-zA-Z0-9_-]{32,128}', os.environ['VPN_PSK']):
    raise SystemExit('Use a strong random 32-128 character PSK containing only [a-zA-Z0-9_-]')
networks = {'prod': ('10.0.0.0/16', '10.10.0.0/16', '10.20.0.0/16'),
            'dev': ('10.100.0.0/16', '10.110.0.0/16', '10.120.0.0/16')}
hub, prod, nonprod = networks[os.environ['ENVIRONMENT']]
values = dict(os.environ, HUB_CIDR=hub, PROD_CIDR=prod, NONPROD_CIDR=nonprod)
content = Template((repo / 'cisco/ios-xe-config.tftpl').read_text()).substitute(values)
dest = repo / 'cisco/generated/ios-xe.cfg'
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(content)
dest.chmod(0o600)
print('Cisco startup config created at', dest, '(mode 0600, git-ignored)')
