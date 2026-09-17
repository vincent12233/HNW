import { execFileSync } from 'child_process';
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

const apiScripts = join(__dirname, '../../scripts');
const pythonHelper = join(apiScripts, 'assert-funding-integration-url.py');
const bashRunner = join(apiScripts, 'run-funding-integration.sh');
const powershellRunner = join(apiScripts, 'run-funding-integration.ps1');
const powershellHelper = join(apiScripts, 'assert-funding-integration-url.ps1');

describe('funding integration runner pre-migration URL safety', () => {
  it('validates the PowerShell URL before DATABASE_URL and migrate deploy', () => {
    const runner = readFileSync(powershellRunner, 'utf8');
    const helper = readFileSync(powershellHelper, 'utf8');
    const validateAt = runner.indexOf('Assert-FundingIntegrationDatabaseUrl');
    const assignAt = runner.indexOf(
      '$env:DATABASE_URL = $env:FUNDING_INTEGRATION_DATABASE_URL',
    );
    const migrateAt = runner.indexOf('npx prisma migrate deploy');
    expect(validateAt).toBeGreaterThan(-1);
    expect(assignAt).toBeGreaterThan(validateAt);
    expect(migrateAt).toBeGreaterThan(assignAt);
    expect(helper).toContain('Using isolated database $database on $hostName');
    expect(helper).not.toContain('UserInfo');
    expect(helper).not.toContain('Password');
  });

  it('validates the Bash URL before exporting DATABASE_URL and migrate deploy', () => {
    const runner = readFileSync(bashRunner, 'utf8');
    const pythonAt = runner.indexOf('assert-funding-integration-url.py');
    const exportAt = runner.indexOf('export DATABASE_URL=');
    const migrateAt = runner.indexOf('npx prisma migrate deploy');
    expect(pythonAt).toBeGreaterThan(-1);
    expect(exportAt).toBeGreaterThan(pythonAt);
    expect(migrateAt).toBeGreaterThan(exportAt);
  });

  it('applies the same host and database rules in the Python helper', () => {
    if (!existsSync(pythonHelper)) {
      throw new Error('Python funding URL helper is missing');
    }
    const run = (url: string) => {
      try {
        return execFileSync('python3', [pythonHelper, url], {
          encoding: 'utf8',
        });
      } catch (error) {
        const err = error as { stderr?: string; stdout?: string; status?: number };
        throw new Error(
          `${err.stderr || err.stdout || String(error)} (exit ${err.status})`,
        );
      }
    };
    const reject = (url: string) => {
      expect(() => run(url)).toThrow(/Refusing (host|database)/);
    };

    reject('postgresql://user:pass@db.production.com:5432/hnw_integration');
    reject('postgresql://user:pass@127.0.0.1:5432/hnw_production');
    reject('postgresql://user:pass@10.0.0.10:5432/hnw_test');
    reject('postgresql://user:pass@localhost:5432/hnw_prod');

    const accepted = run(
      'postgresql://hnw_test:supersecret@127.0.0.1:55432/hnw_funding_integration',
    );
    expect(accepted).toContain('hnw_funding_integration');
    expect(accepted).toContain('127.0.0.1');
    expect(accepted).not.toContain('supersecret');
    expect(run('postgresql://hnw_test:pass@localhost:55432/hnw_test')).toContain(
      'hnw_test',
    );
    expect(run('postgresql://hnw_test:pass@postgres:5432/hnw_e2e')).toContain(
      'hnw_e2e',
    );
  });
});
