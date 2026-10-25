"""macOS preview branding and explicit Developer ID distribution gates."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shutil
import subprocess


def run(command):
    # Signing tools can echo account names, credentials or certificate subjects.
    # Keep their output private and report only the failed tool to CI.
    result = subprocess.run([str(part) for part in command], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(Path(command[0]).name + ' failed; check signing credentials and Apple service status')
    return result.stdout + result.stderr


def install_icon(bundle, icon):
    data = icon.read_bytes()
    if len(data) < 8 or data[:4] != b'icns' or int.from_bytes(data[4:8], 'big') != len(data):
        raise ValueError('invalid application ICNS')
    destination = bundle / 'Contents/Resources/GameIcon.icns'
    shutil.copyfile(icon, destination)
    info = bundle / 'Contents/Info.plist'
    with info.open('rb') as stream:
        values = plistlib.load(stream)
    # LÖVE's asset-catalog name takes precedence over the legacy ICNS key.
    for key in ('CFBundleIconName', 'CFBundleIcons', 'CFBundleIcons~ipad'):
        values.pop(key, None)
    values['CFBundleIconFile'] = 'GameIcon.icns'
    with info.open('wb') as stream:
        plistlib.dump(values, stream)
    return hashlib.sha256(data).hexdigest()


MACHO = {bytes.fromhex(value) for value in (
    'feedface', 'cefaedfe', 'feedfacf', 'cffaedfe', 'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}


def signing_targets(bundle):
    bundle = bundle.resolve()
    with (bundle / 'Contents/Info.plist').open('rb') as stream:
        executable = plistlib.load(stream)['CFBundleExecutable']
    main = (bundle / 'Contents/MacOS' / executable).resolve()
    targets = set()
    for path in bundle.rglob('*'):
        resolved = path.resolve()
        if not resolved.is_relative_to(bundle):
            raise ValueError('app symlink escapes bundle')
        if path.is_dir() and path.suffix in ('.framework', '.app', '.xpc'):
            targets.add(resolved)
        elif path.is_file() and resolved != main:
            with path.open('rb') as stream:
                if stream.read(4) in MACHO:
                    targets.add(resolved)
    # Libraries and helpers before their containing frameworks, then the app.
    return sorted(targets, key=lambda path: (-len(path.parts), str(path))) + [bundle]


def sign_and_notarize(bundle, entitlements, identity=None, profile=None, keychain=None):
    if bool(identity) != bool(profile) or (keychain and not identity):
        raise ValueError('Developer ID identity and notary profile must be supplied together')
    if not identity:
        run(['codesign', '--force', '--deep', '--sign', '-', '--entitlements', entitlements, bundle])
        run(['codesign', '--verify', '--deep', '--strict', bundle])
        return dict(signing='ad-hoc', notarized=False, ticketStapled=False, gatekeeperVerified=False)
    options = ['--force', '--options', 'runtime', '--timestamp', '--sign', identity]
    if keychain:
        options += ['--keychain', keychain]
    for target in signing_targets(bundle):
        command = ['codesign', *options]
        if target == bundle.resolve():
            command += ['--entitlements', entitlements]
        run([*command, target])
    run(['codesign', '--verify', '--deep', '--strict', bundle])
    signature = run(['codesign', '--display', '--verbose=4', bundle])
    if ('Authority=Developer ID Application:' not in signature or
            '(runtime)' not in signature or 'Timestamp=' not in signature):
        raise ValueError('Developer ID, hardened runtime and secure timestamp are required')
    submission = bundle.parent / (bundle.stem + '-notary.zip')
    run(['ditto', '-c', '-k', '--norsrc', '--noextattr', '--keepParent', bundle, submission])
    command = ['xcrun', 'notarytool', 'submit', submission, '--keychain-profile', profile,
               '--wait', '--timeout', '20m', '--output-format', 'json']
    if keychain:
        command += ['--keychain', keychain]
    try:
        report = json.loads(run(command))
    finally:
        submission.unlink(missing_ok=True)
    if report.get('status') != 'Accepted' or not re.fullmatch(
            r'[0-9a-fA-F-]{36}', str(report.get('id', ''))):
        raise ValueError('Apple did not accept this notarization submission')
    run(['xcrun', 'stapler', 'staple', bundle])
    run(['xcrun', 'stapler', 'validate', bundle])
    run(['codesign', '--verify', '--deep', '--strict', bundle])
    run(['spctl', '--assess', '--type', 'execute', bundle])
    return dict(signing='developer-id', notarized=True, ticketStapled=True,
                gatekeeperVerified=True, notarizationId=report['id'])


def ci_keychain(directory):
    return directory / 'native-preview-signing.keychain-db'


def setup_ci(directory, environment):
    required = ('MACOS_CERTIFICATE_P12_BASE64', 'MACOS_CERTIFICATE_PASSWORD',
                'APPLE_ID', 'APPLE_APP_PASSWORD', 'APPLE_TEAM_ID')
    if any(not os.environ.get(name) for name in required):
        raise ValueError('Notarized macOS builds require all five documented GitHub secrets')
    keychain = ci_keychain(directory)
    if keychain.exists():
        raise ValueError('signing keychain already exists')
    certificate = directory / ('native-preview-' + secrets.token_hex(8) + '.p12')
    password = secrets.token_urlsafe(32)
    try:
        with certificate.open('xb') as stream:
            os.chmod(certificate, 0o600)
            stream.write(base64.b64decode(os.environ[required[0]], validate=True))
        run(['security', 'create-keychain', '-p', password, keychain])
        run(['security', 'set-keychain-settings', '-lut', '21600', keychain])
        run(['security', 'unlock-keychain', '-p', password, keychain])
        run(['security', 'import', certificate, '-P', os.environ[required[1]], '-k', keychain,
             '-T', '/usr/bin/codesign', '-T', '/usr/bin/security'])
        run(['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:',
             '-s', '-k', password, keychain])
        identities = run(['security', 'find-identity', '-v', '-p', 'codesigning', keychain])
        matches = re.findall(r'\b([0-9A-Fa-f]{40})\s+"Developer ID Application:[^"\n]+"', identities)
        if len(matches) != 1:
            raise ValueError('the certificate must contain exactly one valid Developer ID Application identity')
        profile = 'native-preview-notary'
        run(['xcrun', 'notarytool', 'store-credentials', profile, '--keychain', keychain,
             '--apple-id', os.environ['APPLE_ID'], '--team-id', os.environ['APPLE_TEAM_ID'],
             '--password', os.environ['APPLE_APP_PASSWORD']])
        with environment.open('a') as stream:
            stream.write('MACOS_SIGNING_IDENTITY=' + matches[0] + '\n')
            stream.write('MACOS_NOTARY_PROFILE=' + profile + '\n')
            stream.write('MACOS_SIGNING_KEYCHAIN=' + str(keychain) + '\n')
    finally:
        certificate.unlink(missing_ok=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('setup-ci', 'cleanup-ci'))
    args = parser.parse_args()
    directory = Path(os.environ['RUNNER_TEMP'])
    if args.action == 'setup-ci':
        setup_ci(directory, Path(os.environ['GITHUB_ENV']))
    elif ci_keychain(directory).exists():
        run(['security', 'delete-keychain', ci_keychain(directory)])
