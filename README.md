# Delphix Continuous Compliance - Automation Scripts

This repository contains a collection of Bash scripts to interact with Delphix Continuous Compliance (formerly Masking) engines. These scripts facilitate the automation of configuration, administration, and data extraction tasks.

## Disclaimer

These scripts are provided "as is" and without any warranty of any kind, express or implied. The author assumes no liability for any damages whatsoever arising from the use of these scripts. Use at your own risk.

## Scripts Description

The scripts available in each category and their main purpose are detailed below.

### Connection Configuration (`configconn`)

- **`dpxcc_config_conn.sh`**: Interactively configures the connection to a Delphix CC engine, saving credentials and the IP address to a configuration file.

### Algorithms (`algorithms`)

- **`dpxcc_create_algorithms.sh`**: Creates new masking algorithms in the engine from a CSV file.

### Classifiers (`classifiers`)

- **`dpxcc_create_classifiers.sh`**: Creates new data classifiers in the engine from a CSV file.

### Domains (`domains`)

- **`dpxcc_create_domains.sh`**: Creates new domains in the engine from a CSV file.

### Executions (`execution`)

- **`dpxcc_get_execution.sh`**: Gets the status and details of job executions.
- **`dpxcc_get_execution_comp.sh`**: Retrieves information about the components of an execution.
- **`dpxcc_get_execution_event.sh`**: Gets the events associated with an execution.

### File System Mounts (`fsmounts`)

- **`dpxcc_get_fsmounts.sh`**: Gets a list of the configured NFS mounts.
- **`dpxcc_create_fsmounts.sh`**: Creates new NFS mounts on the engine.
- **`dpxcc_connect_fsmounts.sh`**: Activates the connection of existing NFS mounts.
- **`dpxcc_disconnect_fsmounts.sh`**: Deactivates the connection of existing NFS mounts.
- **`dpxcc_delete_fsmounts.sh`**: Deletes NFS mount configurations.

### LDAP Configuration (`ldap`)

- **`dpxcc_setup_ldap.sh`**: Configures the integration with an LDAP server for user authentication.
- **`dpxcc_getconfig_ldap.sh`**: Displays the engine's current LDAP configuration.
- **`dpxcc_test_ldap.sh`**: Performs a connection test against the configured LDAP server.

---

## TO-DO List

- [ ] **General Script Refactoring**: Most scripts in this repository need to be refactored. They were developed quickly and do not follow best practices for security and Bash scripting. Error handling, input validation, and sensitive information management must be improved.
- [ ] **Standards Adoption**: The scripts in the `algorithms`, `domains`, and `classifiers` folders represent the new generation and the standard to follow for the rest of the scripts in the repository.
- [ ] **Consolidate Scripts**: Gather scripts that are still scattered in various locations and upload them to this repository.