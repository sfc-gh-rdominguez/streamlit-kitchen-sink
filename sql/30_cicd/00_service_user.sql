/*
 * ============================================================================
 * 30_cicd/00_service_user.sql  —  CI deployer service user (key-pair auth)
 * ============================================================================
 *
 * KS_DEPLOYER is a TYPE=SERVICE user (no password; key-pair only) used by
 * GitHub Actions. Its private key is stored as a GitHub Actions secret; only the
 * public key is registered here. It logs in with the scoped KS_APP_DEPLOYER role.
 *
 * Run with the public key body (no PEM header/footer, single line):
 *   snow sql -D rsa_public_key="$(grep -v 'PUBLIC KEY' key.pub | tr -d '\n')" -f 00_service_user.sql
 *
 * Idempotent.
 * ============================================================================
 */

USE ROLE USERADMIN;

CREATE USER IF NOT EXISTS KS_DEPLOYER
  TYPE = SERVICE
  DEFAULT_ROLE = KS_APP_DEPLOYER
  DEFAULT_WAREHOUSE = KS_WH
  COMMENT = 'Kitchen Sink: CI/CD deployer (GitHub Actions, key-pair auth)';

ALTER USER KS_DEPLOYER SET RSA_PUBLIC_KEY = '<% rsa_public_key %>';

USE ROLE SECURITYADMIN;
GRANT ROLE KS_APP_DEPLOYER TO USER KS_DEPLOYER;
