"""Provision only the explicitly authorized application-owned PostgreSQL instance."""
import os, json, pathlib, pwd, secrets, subprocess, socket, hashlib, time, base64

ROOT=pathlib.Path('/www/server/thwkb.zh.huawei')
PORT=55426
DATABASE='thwkb_zh_huawei'
USER='thwkbpg'
BIN=ROOT/'pgsql/bin'
DATA=ROOT/'postgres-data'
SOCKET=ROOT/'postgres-socket'
SECRETS=ROOT/'secrets'
BACKUPS=ROOT/'backups'
REPORT=ROOT/'postgres-provision-status.json'
stage='preflight'
os.umask(0o077)

def run(args, input=None, env=None):
    return subprocess.run(args,input=input,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,check=True,timeout=90).stdout

def sql(query, database='postgres'):
    return run(['runuser','-u',USER,'--',str(BIN/'psql'),'-X','-A','-t','-v','ON_ERROR_STOP=1','-h',str(SOCKET),'-p',str(PORT),'-U',USER,'-d',database],query.encode()).decode().strip()

def persist(record):
    record.update(app='thwkb.zh.huawei',at=time.time())
    temporary=REPORT.with_suffix('.pending');temporary.write_text(json.dumps(record));os.replace(temporary,REPORT)

def processes():
    return json.loads(run(['pm2','jlist']))

try:
    assert json.loads((ROOT/'owner.json').read_text())['app']=='thwkb.zh.huawei'
    assert json.loads((ROOT/'postgres-build-status.json').read_text())['phase']=='built'
    assert all(m['version'] in ['001','002'] and hashlib.sha256(base64.b64decode(m['sqlBase64'])).hexdigest()==m['sha256'] for m in INPUT['migrations'])
    stage='service-account'
    try:
        account=pwd.getpwnam(USER)
        assert account.pw_dir==str(ROOT/'postgres-home') and account.pw_shell in ['/usr/sbin/nologin','/sbin/nologin'],'Service account conflict'
    except KeyError:
        run(['useradd','--system','--user-group','--home-dir',str(ROOT/'postgres-home'),'--no-create-home','--shell','/usr/sbin/nologin',USER])
        account=pwd.getpwnam(USER)
    for directory in [DATA,SOCKET]:
        if not directory.exists():directory.mkdir(mode=0o700)
        assert directory.stat().st_uid in [0,account.pw_uid]
        os.chown(directory,account.pw_uid,account.pw_gid);os.chmod(directory,0o700)
    for directory in [SECRETS,BACKUPS]:
        directory.mkdir(mode=0o700,exist_ok=True);assert directory.stat().st_uid==0;os.chmod(directory,0o700)
    stage='cluster-initialization'
    if not (DATA/'PG_VERSION').exists():
        assert not list(DATA.iterdir()),'Nonempty uninitialized database directory'
        run(['runuser','-u',USER,'--',str(BIN/'initdb'),'-D',str(DATA),'--locale=C','--encoding=UTF8','--auth-local=peer','--auth-host=scram-sha-256'])
    assert (DATA/'PG_VERSION').read_text().strip()=='17'
    config="""# thwkb.zh.huawei dedicated instance; never a shared default PostgreSQL.
listen_addresses = '127.0.0.1'
port = 55426
unix_socket_directories = '/www/server/thwkb.zh.huawei/postgres-socket'
max_connections = 20
shared_buffers = '64MB'
work_mem = '2MB'
maintenance_work_mem = '32MB'
effective_cache_size = '128MB'
autovacuum_max_workers = 1
max_wal_size = '256MB'
min_wal_size = '80MB'
password_encryption = 'scram-sha-256'
log_statement = 'none'
log_min_error_statement = 'panic'
log_error_verbosity = 'terse'
"""
    custom=DATA/'postgresql.auto.conf'
    # initdb creates an empty auto.conf with only comments; do not overwrite other settings.
    existing=custom.read_text() if custom.exists() else ''
    if existing!=config:
        assert not any(line.strip() and not line.lstrip().startswith('#') for line in existing.splitlines()),'Existing database settings conflict'
        custom.write_text(config);os.chown(custom,account.pw_uid,account.pw_gid);os.chmod(custom,0o600)
    stage='dedicated-process-start'
    old=processes();owned=[p for p in old if p.get('name')=='thwkb-postgres']
    if owned:
        e=owned[0].get('pm2_env',{})
        assert e.get('pm_exec_path')=='/usr/sbin/runuser' and str(DATA) in e.get('args',[]),'Process name conflict'
        assert e.get('status')=='online','Existing instance is not online; manual recovery required'
    else:
        probe=socket.socket();probe.bind(('127.0.0.1',PORT));probe.close()
        ecosystem={'apps':[{'name':'thwkb-postgres','script':'/usr/sbin/runuser','interpreter':'none','args':['-u',USER,'--',str(BIN/'postgres'),'-D',str(DATA)],'cwd':str(ROOT),'autorestart':True,'kill_timeout':15000,'max_restarts':5,'min_uptime':'10s','out_file':str(ROOT/'postgres-stdout.log'),'error_file':str(ROOT/'postgres-stderr.log')}]}
        file=ROOT/'postgres.ecosystem.json';file.write_text(json.dumps(ecosystem));run(['pm2','start',str(file)])
    for i in range(30):
        ready=subprocess.run([str(BIN/'pg_isready'),'-h','127.0.0.1','-p',str(PORT)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0
        if ready:break
        time.sleep(1)
    assert ready,'Application database did not become ready'
    stage='restricted-role-and-database'
    credentials=SECRETS/'database.json'
    had_credentials=credentials.exists()
    if had_credentials:
        secret=json.loads(credentials.read_text());assert secret['database']==DATABASE and secret['user']=='thwkb_app' and secret['host']=='127.0.0.1' and secret['port']==PORT
    else:
        secret={'host':'127.0.0.1','port':PORT,'database':DATABASE,'user':'thwkb_app','password':secrets.token_urlsafe(48)}
    owner_exists=sql("SELECT count(*) FROM pg_roles WHERE rolname='thwkb_owner'")=='1'
    role_exists=sql("SELECT count(*) FROM pg_roles WHERE rolname='thwkb_app'")=='1'
    if not owner_exists:sql('CREATE ROLE thwkb_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;')
    if role_exists:assert had_credentials,'Existing business role has no owned credential record; do not rotate'
    else:
        assert not had_credentials,'Credential record exists without business role; manual recovery required'
        # Send over stdin. Never put passwords in argv or return them in a report.
        sql("CREATE ROLE thwkb_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD '"+secret['password']+"';")
        with open(credentials,'x') as file:json.dump(secret,file)
        os.chmod(credentials,0o600)
    db_owner=sql("SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname='thwkb_zh_huawei'")
    if not db_owner:sql('CREATE DATABASE thwkb_zh_huawei OWNER thwkb_owner TEMPLATE template0 ENCODING \'UTF8\';')
    else:assert db_owner=='thwkb_owner','Database ownership conflict'
    sql('REVOKE ALL ON DATABASE thwkb_zh_huawei FROM PUBLIC; GRANT CONNECT ON DATABASE thwkb_zh_huawei TO thwkb_app;')
    sql('REVOKE ALL ON SCHEMA public FROM PUBLIC; ALTER SCHEMA public OWNER TO thwkb_owner;',DATABASE)
    stage='backup-before-migration'
    stamp=time.strftime('%Y%m%dT%H%M%SZ',time.gmtime())
    backup=BACKUPS/('before-migration-'+stamp+'.dump')
    with open(backup,'xb') as output:
        subprocess.run(['runuser','-u',USER,'--',str(BIN/'pg_dump'),'-Fc','-h',str(SOCKET),'-p',str(PORT),'-U',USER,'-d',DATABASE],stdout=output,stderr=subprocess.PIPE,check=True,timeout=90)
    stage='app-migrations'
    registry=sql("SELECT to_regclass('public.thwkb_migrations') IS NOT NULL",DATABASE)=='t'
    versions=sql('SELECT version FROM thwkb_migrations ORDER BY version',DATABASE).splitlines() if registry else []
    ledger=ROOT/'migration-checksums.json'
    previous=json.loads(ledger.read_text()) if ledger.exists() else {}
    for migration in INPUT['migrations']:
        version=migration['version']
        if version in versions:
            assert previous.get(version)==migration['sha256'],'Applied migration checksum not verified'
            continue
        decoded=base64.b64decode(migration['sqlBase64']).decode()
        sql('SET ROLE thwkb_owner;\n'+decoded,DATABASE)
        previous[version]=migration['sha256'];ledger.write_text(json.dumps(previous))
    tables=INPUT['tables']
    assert len(tables)==16 and all(t.startswith('thwkb_') and t.replace('_','').isalnum() for t in tables)
    for table in tables:
        assert sql("SELECT to_regclass('public."+table+"') IS NOT NULL",DATABASE)=='t'
        sql('GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE "'+table+'" TO thwkb_app;',DATABASE)
    sql('GRANT USAGE ON SCHEMA public TO thwkb_app;',DATABASE)
    stage='credential-permission-check'
    appenv={**os.environ,'PGPASSWORD':secret['password']}
    query="SELECT json_build_object('version',current_setting('server_version'),'role',current_user,'superuser',(SELECT rolsuper FROM pg_roles WHERE rolname=current_user),'canCreateDatabase',(SELECT rolcreatedb FROM pg_roles WHERE rolname=current_user),'canCreateRole',(SELECT rolcreaterole FROM pg_roles WHERE rolname=current_user),'bypassRls',(SELECT rolbypassrls FROM pg_roles WHERE rolname=current_user),'canCreateSchema',has_schema_privilege(current_user,'public','CREATE'),'tables',(SELECT count(*) FROM information_schema.tables WHERE table_schema='public'));"
    business=json.loads(run([str(BIN/'psql'),'-X','-A','-t','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(PORT),'-U','thwkb_app','-d',DATABASE],query.encode(),env=appenv).decode())
    assert business['tables']==16 and not any(business[key] for key in ['superuser','canCreateDatabase','canCreateRole','bypassRls','canCreateSchema'])
    actual_versions=sql('SELECT version FROM thwkb_migrations ORDER BY version',DATABASE).splitlines()
    assert actual_versions==['001','002']
    after=processes()
    before_other={p['name']:(p.get('pid'),p.get('pm2_env',{}).get('restart_time')) for p in old if p.get('name')!='thwkb-postgres'}
    after_other={p['name']:(p.get('pid'),p.get('pm2_env',{}).get('restart_time')) for p in after if p.get('name')!='thwkb-postgres'}
    run(['pm2','save'])
    report={'phase':'provisioned','host':'127.0.0.1','port':PORT,'database':DATABASE,'businessRole':business,'migrations':actual_versions,'entityTables':len(tables),'backup':str(backup),'backupBytes':backup.stat().st_size,'backupSha256':hashlib.sha256(backup.read_bytes()).hexdigest(),'credentials':'remote root-only secret file; value never exported','publicSeedImported':False,'otherProcessesUnchanged':before_other==after_other,'sharedMysqlChanged':False,'systemPackagesChanged':False}
    persist(report);print(json.dumps(report))
except Exception as error:
    report={'phase':'failed','failedStage':stage,'errorType':type(error).__name__,'details':'Sensitive diagnostics suppressed; existing app data and backups retained'}
    persist(report);print(json.dumps(report));raise SystemExit(1)
