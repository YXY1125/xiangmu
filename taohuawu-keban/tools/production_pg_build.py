"""App-scoped PostgreSQL build worker. No credentials, shared packages or service changes."""
import os, json, hashlib, urllib.request, tarfile, subprocess, time, pathlib

ROOT = pathlib.Path('/www/server/thwkb.zh.huawei')
VERSION = '17.11'
URL = 'https://ftp.postgresql.org/pub/source/v17.11/postgresql-17.11.tar.gz'
STATUS = ROOT / 'postgres-build-status.json'

def status(phase, **extra):
    record = dict(app='thwkb.zh.huawei', phase=phase, time=time.time(), **extra)
    temporary = STATUS.with_suffix('.pending')
    temporary.write_text(json.dumps(record))
    os.replace(temporary, STATUS)

try:
    assert json.loads((ROOT / 'owner.json').read_text())['app'] == 'thwkb.zh.huawei'
    build = ROOT / 'build'; build.mkdir(exist_ok=True)
    archive = build / ('postgresql-' + VERSION + '.tar.gz')
    status('downloading')
    expected = urllib.request.urlopen(URL + '.sha256', timeout=30).read().decode().split()[0]
    if not archive.exists():
        with urllib.request.urlopen(URL, timeout=60) as response, open(archive, 'xb') as output:
            while True:
                part = response.read(1024 * 1024)
                if not part: break
                output.write(part)
    actual = hashlib.sha256(archive.read_bytes()).hexdigest()
    assert actual == expected, 'Official source checksum mismatch'
    status('verified', sourceSha256=actual)
    source = build / ('postgresql-' + VERSION)
    if not source.exists():
        with tarfile.open(archive) as package:
            base = build.resolve()
            for member in package.getmembers():
                target = (base / member.name).resolve()
                assert target.is_relative_to(base) and not member.issym() and not member.islnk(), 'Unsafe archive member'
            package.extractall(build)
    prefix = ROOT / 'pgsql'
    build_env = dict(os.environ, PERL5LIB=str(build / 'perl-lib'))
    with open(ROOT / 'postgres-build.log', 'ab') as log:
        status('configuring', sourceSha256=actual)
        options = [str(source / 'configure'), '--prefix=' + str(prefix), '--without-readline', '--without-zlib', '--without-icu']
        if pathlib.Path('/usr/include/openssl/ssl.h').exists(): options += ['--with-openssl']
        subprocess.run(options, cwd=source, stdout=log, stderr=log, check=True, env=build_env)
        status('compiling', sourceSha256=actual)
        subprocess.run(['nice', '-n', '19', 'make', '-j1'], cwd=source, stdout=log, stderr=log, check=True, env=build_env)
        status('installing', sourceSha256=actual)
        subprocess.run(['make', 'install'], cwd=source, stdout=log, stderr=log, check=True, env=build_env)
    version = subprocess.check_output([str(prefix / 'bin/postgres'), '--version']).decode().strip()
    status('built', sourceSha256=actual, version=version, sharedPackagesChanged=False)
except Exception as error:
    previous=json.loads(STATUS.read_text()).get('phase') if STATUS.exists() else 'unknown'
    status('failed', failedStage=previous, errorType=type(error).__name__, details='Sensitive diagnostics suppressed; inspect app-owned build log securely')
    raise SystemExit(1)
