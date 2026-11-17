"""Actual database grant/rollback and backup-restore probes; no persistent business fixtures."""
import os,json,pathlib,subprocess,secrets,hashlib,time,re,uuid
ROOT=pathlib.Path('/www/server/thwkb.zh.huawei')
BIN=ROOT/'pgsql/bin'
SOCKET=ROOT/'postgres-socket'
PORT=55426
DB='thwkb_zh_huawei'
os.umask(0o077)
scratch='thwkb_restore_'+secrets.token_hex(8)
assert re.fullmatch('thwkb_restore_[a-f0-9]{16}',scratch)
created=False
stage='preflight'
def admin(query,database=DB):
    return subprocess.run(['runuser','-u','thwkbpg','--',str(BIN/'psql'),'-X','-q','-A','-t','-v','ON_ERROR_STOP=1','-h',str(SOCKET),'-p',str(PORT),'-U','thwkbpg','-d',database],input=query.encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True,timeout=60).stdout.decode().strip()
try:
    assert json.loads((ROOT/'postgres-provision-status.json').read_text())['phase']=='provisioned'
    secret=json.loads((ROOT/'secrets/database.json').read_text())
    assert secret['user']=='thwkb_app' and secret['database']==DB
    env=dict(os.environ,PGPASSWORD=secret['password'])
    def business(query):
        return subprocess.run([str(BIN/'psql'),'-X','-q','-A','-t','-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate','-h','127.0.0.1','-p',str(PORT),'-U','thwkb_app','-d',DB],input=query.encode(),env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60)
    stage='business-role-read-write-rollback'
    record=str(uuid.uuid4());subject='thwkb-grant-probe-'+secrets.token_hex(8)
    insert="INSERT INTO thwkb_user_profiles(id,\"tenantId\",\"appId\",\"userId\",nickname,\"createdAt\",\"updatedAt\") VALUES ('"+record+"','thwkb.zh.huawei','thwkb.zh.huawei','"+subject+"','仅事务权限检查',now(),now());"
    positive=business('BEGIN;'+insert+'SELECT count(*) FROM thwkb_user_profiles WHERE id=\''+record+'\';ROLLBACK;')
    assert positive.returncode==0 and positive.stdout.decode().strip()=='1'
    assert admin("SELECT count(*) FROM thwkb_user_profiles WHERE id='"+record+"'")=='0'
    denied=business('BEGIN;CREATE TABLE public.thwkb_ddl_probe(id integer);ROLLBACK;')
    assert denied.returncode!=0 and b'42501' in denied.stderr
    duplicate=business('BEGIN;'+insert+insert.replace(record,str(uuid.uuid4()))+'ROLLBACK;')
    assert duplicate.returncode!=0 and b'23505' in duplicate.stderr
    assert admin("SELECT count(*) FROM thwkb_user_profiles WHERE \"userId\"='"+subject+"'")=='0'
    stage='post-migration-backup'
    dump=ROOT/'backups'/('after-migration-'+time.strftime('%Y%m%dT%H%M%SZ',time.gmtime())+'.dump')
    with open(dump,'xb') as output:
        subprocess.run(['runuser','-u','thwkbpg','--',str(BIN/'pg_dump'),'-Fc','-h',str(SOCKET),'-p',str(PORT),'-U','thwkbpg','-d',DB],stdout=output,stderr=subprocess.PIPE,check=True,timeout=60)
    assert dump.read_bytes().startswith(b'PGDMP')
    stage='isolated-backup-restore'
    admin('CREATE DATABASE "'+scratch+'" OWNER thwkb_owner TEMPLATE template0;','postgres');created=True
    subprocess.run(['runuser','-u','thwkbpg','--',str(BIN/'pg_restore'),'--exit-on-error','--no-owner','-h',str(SOCKET),'-p',str(PORT),'-U','thwkbpg','-d',scratch],input=dump.read_bytes(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True,timeout=60)
    count=int(admin("SELECT count(*) FROM information_schema.tables WHERE table_schema='public'",scratch))
    assert count==17
    assert admin('SELECT string_agg(version,\',\' ORDER BY version) FROM thwkb_migrations',scratch)=='001,002'
    # This exact database was created in this run for restoration only; never target the app database.
    assert created and scratch!=DB
    admin('DROP DATABASE "'+scratch+'";','postgres');created=False
    stage='production-empty-record-check'
    tables=INPUT['tables'];assert len(tables)==16
    counts={}
    for table in tables:
        assert re.fullmatch('thwkb_[a-z_]+',table)
        counts[table]=int(admin('SELECT count(*) FROM "'+table+'"'))
    assert all(n==0 for n in counts.values())
    constraints=json.loads(admin("SELECT coalesce(json_object_agg(type,n),'{}'::json) FROM (SELECT contype::text AS type,count(*) AS n FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE n.nspname='public' GROUP BY contype) t"))
    result={'phase':'verified','version':admin('SHOW server_version'),'listenAddresses':admin('SHOW listen_addresses'),'port':PORT,'businessDmlAndRollbackPassed':True,'runtimeDdlDeniedSqlstate':'42501','uniqueConstraintSqlstate':'23505','productionRecordCounts':counts,'constraintCounts':constraints,'postMigrationBackup':str(dump),'backupSha256':hashlib.sha256(dump.read_bytes()).hexdigest(),'restoreTableCount':count,'restoreMigrationVersions':['001','002'],'temporaryRestoreDatabaseRemoved':True,'credentialsMode':oct((ROOT/'secrets/database.json').stat().st_mode&0o777),'persistentTestBusinessRows':0,'publicSeedImported':False,'gateBPassed':False}
    (ROOT/'postgres-verification-status.json').write_text(json.dumps(result));print(json.dumps(result))
except Exception as error:
    result={'phase':'failed','failedStage':stage,'errorType':type(error).__name__,'temporaryRestoreDatabaseRetained':scratch if created else None,'details':'Production database not dropped or restored; secret diagnostics suppressed'}
    (ROOT/'postgres-verification-status.json').write_text(json.dumps(result));print(json.dumps(result));raise SystemExit(1)
