/*
 * ============================================================================
 * 30_cicd/01_deployer_grants.sql  —  Scoped privileges for the CI deployer
 * ============================================================================
 *
 * The CI identity (KS_DEPLOYER user, role KS_APP_DEPLOYER) runs with LEAST
 * privilege — never SYSADMIN or ACCOUNTADMIN. It already inherits the two env
 * owner roles (see 01_roles.sql) to deploy/own apps and to read prod for
 * cloning. This script grants the few remaining account-level privileges it
 * needs, once, so the CI clone/deploy path never escalates to an admin role.
 *
 * Run once at setup (ACCOUNTADMIN). Idempotent.
 * ============================================================================
 */

USE ROLE ACCOUNTADMIN;

-- Provision ephemeral transient databases for PR previews.
GRANT CREATE DATABASE ON ACCOUNT TO ROLE KS_APP_DEPLOYER;

-- (Re)apply caller grants after a clone without needing ACCOUNTADMIN.
GRANT MANAGE CALLER GRANTS ON ACCOUNT TO ROLE KS_APP_DEPLOYER;

-- Refreshing STAGING.DATA drops + recreates that schema, which needs CREATE
-- SCHEMA on the staging database. (PR preview databases are created by the
-- deployer itself, so it already owns them.)
GRANT CREATE SCHEMA ON DATABASE KITCHEN_SINK_STAGING TO ROLE KS_APP_STAGING;

-- READ SESSION is account-level (ACCOUNTADMIN-only to grant), so grant it to the
-- app owner roles once here. The CI clone path then never has to run as
-- ACCOUNTADMIN just to (re)enable CURRENT_USER() + row access policies.
GRANT READ SESSION ON ACCOUNT TO ROLE KS_APP_STAGING;
GRANT READ SESSION ON ACCOUNT TO ROLE KS_APP_OWNER_PROD;
