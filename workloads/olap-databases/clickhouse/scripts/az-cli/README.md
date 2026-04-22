# ClickHouse CLI command notes

The repeatable install and validation flow lives in `../../docs/az-cli-deployment.md`.

This folder intentionally does not ship a single wrapper script because resource names, password generation, and internal networking decisions differ by environment. Keeping the commands inline in the deployment guide makes the stateful install path easier to audit and customize.
