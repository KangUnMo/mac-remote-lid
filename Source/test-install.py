#!/usr/bin/env python3
"""임시 폴더와 모의 외부 명령으로 설치 실패 및 복구 경로를 검사합니다."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

MOCK = r'''#!/usr/bin/env python3
import hashlib, json, os, pathlib, plistlib, shutil, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
root = pathlib.Path(os.environ['INSTALL_TEST_ROOT'])
scenario = os.environ['INSTALL_TEST_SCENARIO']
log = root / 'commands.jsonl'
previous = log.read_text().splitlines() if log.exists() else []
with log.open('a') as output:
    output.write(json.dumps([name] + args) + '\n')
def fail(): sys.exit(1)
if name == 'uname':
    print('Darwin' if args == ['-s'] else 'arm64')
elif name == 'pgrep':
    count = sum(json.loads(line)[0] == 'pgrep' for line in previous)
    sys.exit(0 if scenario == 'running' or (scenario == 'late-running' and count >= 2) else 1)
elif name == 'curl':
    if scenario == 'download-failure': fail()
    destination = pathlib.Path(args[args.index('-o') + 1])
    if str(destination).endswith('.sha256'):
        digest = hashlib.sha256(b'test archive').hexdigest()
        if scenario == 'checksum': digest = 'b' * 64
        if scenario == 'malformed-checksum': digest = 'invalid'
        destination.write_text(digest + '  archive.zip\n')
    else: destination.write_bytes(b'test archive')
elif name == 'ditto':
    if args[0] == '-xk':
        shutil.copytree(root / 'fixture.app', pathlib.Path(args[2]) / '원격지킴이.app')
    else:
        if scenario == 'stage-failure': fail()
        shutil.copytree(args[0], args[1])
elif name == 'PlistBuddy':
    with open(args[2], 'rb') as source: info = plistlib.load(source)
    print(info[args[1].split(':')[-1]])
elif name == 'codesign':
    if scenario == 'signature' or (scenario == 'staged-signature' and '.RemoteLidInstall-' in args[-1]): fail()
elif name == 'xattr':
    assert args[:2] == ['-dr', 'com.apple.quarantine'], args
    if scenario == 'xattr-failure': fail()
elif name == 'mv':
    source, destination = map(pathlib.Path, args)
    if scenario == 'backup-failure' and source.name == '원격지킴이.app' and destination.name == 'previous.app': fail()
    if scenario in ('replace-failure', 'recovery-failure') and source.parent.name.startswith('.RemoteLidInstall-'):
        if source.name == '원격지킴이.app' or scenario == 'recovery-failure': fail()
    source.rename(destination)
elif name == 'open':
    if scenario in ('launch-failure', 'new-launch-failure'): fail()
elif name == 'sudo':
    sys.exit(subprocess.run(args).returncode)
else:
    raise AssertionError('Unexpected external command: ' + name)
'''


def main():
    installer = (Path(__file__).resolve().parent.parent / 'install.sh').read_text()
    assert 'killall' not in installer
    assert 'xattr -cr' not in installer
    scenarios = [
        'running', 'late-running', 'download-failure', 'checksum', 'malformed-checksum',
        'identifier', 'version', 'executable-name', 'missing-executable', 'signature',
        'staged-signature', 'new', 'replace', 'sudo-replace', 'stage-failure',
        'backup-failure', 'replace-failure', 'recovery-failure', 'launch-failure',
        'new-launch-failure', 'xattr-failure',
    ]
    successes = {'new', 'replace', 'sudo-replace', 'xattr-failure'}
    with tempfile.TemporaryDirectory(prefix='remotelid-install-test-') as temporary:
        for scenario in scenarios:
            root = Path(temporary) / scenario
            target_dir = root / 'Applications with spaces'
            target = target_dir / '원격지킴이.app'
            binary_dir = root / 'bin'
            binary_dir.mkdir(parents=True)
            target_dir.mkdir()
            (root / 'tmp').mkdir()
            mock = binary_dir / 'mock'
            mock.write_text(MOCK)
            mock.chmod(0o755)
            for command in ['uname', 'pgrep', 'curl', 'ditto', 'PlistBuddy', 'codesign', 'xattr', 'mv', 'open', 'sudo']:
                (binary_dir / command).symlink_to(mock)
            fixture = root / 'fixture.app'
            (fixture / 'Contents/MacOS').mkdir(parents=True)
            info = {'CFBundleIdentifier': 'personal.remotelid', 'CFBundleShortVersionString': '1.1.8',
                    'CFBundleExecutable': 'RemoteLid'}
            if scenario == 'identifier': info['CFBundleIdentifier'] = 'wrong.app'
            if scenario == 'version': info['CFBundleShortVersionString'] = '1.1.6'
            if scenario == 'executable-name': info['CFBundleExecutable'] = '../other'
            with (fixture / 'Contents/Info.plist').open('wb') as output:
                plistlib.dump(info, output)
            executable = fixture / 'Contents/MacOS/RemoteLid'
            executable.write_text('new')
            executable.chmod(0o644 if scenario == 'missing-executable' else 0o755)
            (fixture / 'marker').write_text('new')
            had_old = scenario not in {'new', 'new-launch-failure'}
            if had_old:
                target.mkdir()
                (target / 'marker').write_text('old')
            # 실제 설치 경로와 절대 경로 도구를 복사본에서만 치환합니다.
            script = installer.replace('TARGET_DIR="/Applications"', 'TARGET_DIR="' + str(target_dir) + '"')
            script = script.replace('/usr/libexec/PlistBuddy', str(binary_dir / 'PlistBuddy'))
            if scenario == 'sudo-replace':
                script = script.replace('[[ ! -w "$TARGET_DIR" ]]', '[[ 1 == 1 ]]')
            assert 'TARGET_DIR="/Applications"' not in script
            script_path = root / 'install.sh'
            script_path.write_text(script)
            env = dict(os.environ, PATH=str(binary_dir) + ':' + os.environ['PATH'],
                       INSTALL_TEST_ROOT=str(root), INSTALL_TEST_SCENARIO=scenario,
                       TMPDIR=str(root / 'tmp'))
            result = subprocess.run(['/bin/bash', str(script_path)], env=env, input='n\n',
                                    capture_output=True, text=True, timeout=30, start_new_session=True)
            assert (result.returncode == 0) == (scenario in successes), (scenario, result.stdout, result.stderr)
            if scenario in successes:
                assert (target / 'marker').read_text() == 'new', scenario
            elif scenario == 'recovery-failure':
                assert not target.exists()
                backups = list(target_dir.glob('.RemoteLidInstall-*/previous.app/marker'))
                assert len(backups) == 1 and backups[0].read_text() == 'old'
                assert str(backups[0].parent) in result.stderr
            elif had_old:
                assert (target / 'marker').read_text() == 'old', scenario
            else:
                assert not target.exists(), scenario
            if scenario != 'recovery-failure':
                assert not list(target_dir.glob('.RemoteLidInstall-*')), scenario
            assert not list((root / 'tmp').iterdir()), scenario
            commands = [json.loads(line) for line in (root / 'commands.jsonl').read_text().splitlines()]
            if scenario == 'running':
                assert all(command[0] == 'uname' or command[0] == 'pgrep' for command in commands)
            xattrs = [command for command in commands if command[0] == 'xattr']
            assert all(command[1:3] == ['-dr', 'com.apple.quarantine'] for command in xattrs)
            if scenario in successes:
                assert len(xattrs) == 1
                assert len([command for command in commands if command[0] == 'codesign']) == 2
            if scenario == 'sudo-replace':
                assert any(command[0] == 'sudo' for command in commands)
            print('PASS:', scenario)
    print(f'PASS: {len(scenarios)} isolated installation scenarios; no real installation, authentication, app termination or xattr changes')


if __name__ == '__main__':
    main()
