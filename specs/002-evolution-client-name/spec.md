# Feature Specification: Dynamic WhatsApp Session Client Name Configuration

**Feature Branch**: `002-evolution-client-name`  
**Created**: 2026-09-22  
**Status**: Ready for Planning  
**Input**: User description: "Veja só, eu conectei meu WhatsApp no EvolutionAPI instalado por esse serviço e notei que o nome está como 'Inova Evolution API'. Preciso que isso seja dinamico e que esse texto seja questionado ao usuário no momento da instalação, ao invés de um texto fixo automatico"

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Interactive Customization of WhatsApp Session Client Name on Install (Priority: P1)

As a system administrator or service deployer, I want the interactive installation wizard to prompt me for the client name that will appear in WhatsApp's linked devices screen (`CONFIG_SESSION_PHONE_CLIENT`), with a sensible default, so that WhatsApp accounts connected through Evolution API display my company or project name instead of a hardcoded vendor label.

**Why this priority**: WhatsApp accounts connected to Evolution API display the client name to account owners under the "Linked devices" section (e.g., `Google Chrome (Inova Evolution API)`). Hardcoded names undermine white-labeling, brand consistency, and multi-client deployments. Allowing interactive configuration during setup delivers immediate user value and solves the reported problem.

**Independent Test**:
Run `./service-evolution-api` in interactive mode, enter a custom client name (e.g. `Minha Empresa Atendimento`) when prompted, complete the installation, and verify that the resulting `.env` and `docker-compose.yml` contain the entered name, and that new WhatsApp QR code sessions display that custom client name on the linked device screen.

**Acceptance Scenarios**:
1. **Given** an interactive installation session (`ASSUME_YES=0`), **When** the installer prompts for configuration values, **Then** the user is asked for the session client name with default `Inova Evolution API` displayed.
2. **Given** the client name prompt, **When** the user types a custom name (e.g., `Empresa XYZ`) and presses Enter, **Then** `CONFIG_SESSION_PHONE_CLIENT` is saved with the value `Empresa XYZ` in `.env` and `docker-compose.yml`.
3. **Given** the client name prompt, **When** the user presses Enter without typing any input, **Then** the default value `Inova Evolution API` is retained and applied.

---

### User Story 2 - Non-Interactive Automation via CLI Argument (Priority: P2)

As a DevOps engineer using infrastructure-as-code or automated provisioning scripts, I want to specify the session client name via a command-line parameter (such as `--client-name "Custom Name"`) and have unattended mode (`-y` / `--yes`) use either the provided parameter or the safe default without hanging or waiting for terminal input.

**Why this priority**: Aligns with Section III (Installation Standards) of the project constitution. All prompts must have automated non-interactive equivalents to ensure zero-touch CI/CD deployments and unattended server installations.

**Independent Test**:
Execute `./service-evolution-api -y --client-name "Automated Service"` in an unattended shell and verify that installation succeeds without prompts, configuring `.env` with `CONFIG_SESSION_PHONE_CLIENT=Automated Service`.

**Acceptance Scenarios**:
1. **Given** invocation with `-y` and `--client-name "Acme Support"`, **When** the installer runs, **Then** it executes without user interruption and configures `CONFIG_SESSION_PHONE_CLIENT=Acme Support`.
2. **Given** invocation with `-y` without `--client-name`, **When** the installer runs, **Then** it executes without user interruption and configures the default `CONFIG_SESSION_PHONE_CLIENT=Inova Evolution API`.
3. **Given** invocation with `--help` or `-h`, **When** usage information is printed, **Then** the `--client-name` parameter and its default value are clearly documented.

---

### User Story 3 - Persistence & Preservation Across Updates and Re-runs (Priority: P2)

As a platform operator running service updates (`--update`) or re-running the installation utility on an existing host, I want my previously configured session client name to be automatically preserved from the active `.env` configuration file, avoiding accidental resets to default values.

**Why this priority**: Aligns with Section IV (Safe Update Standards) of the constitution. Existing environment configurations, credentials, and custom parameters must never be discarded or reset during maintenance and upgrade routines.

**Independent Test**:
Deploy an installation with a custom client name, execute `./service-evolution-api --update`, and verify that the updated stack continues to have the custom client name in `.env` and `docker-compose.yml`.

**Acceptance Scenarios**:
1. **Given** an existing installation with `CONFIG_SESSION_PHONE_CLIENT="Empresa Especial"`, **When** `--update` or an upgrade execution runs, **Then** the script extracts and preserves `CONFIG_SESSION_PHONE_CLIENT="Empresa Especial"`.
2. **Given** an existing installation lacking `CONFIG_SESSION_PHONE_CLIENT` (legacy installation), **When** `--update` runs, **Then** the installer safely populates the default value without syntax errors.

---

## Edge Cases

- **Empty User Input**: Pressing Enter on the interactive prompt defaults safely to `Inova Evolution API`.
- **Special Characters and Spaces**: User input containing spaces, accents (e.g., `São Paulo`), hyphens, or symbols must be properly quoted in bash and in `.env` to prevent parse failures in docker-compose or environment file loaders.
- **Non-TTY / Headless Environments**: If stdin or `/dev/tty` is unavailable and `-y` was not explicitly supplied, the script must safely fall back to the default value rather than failing or waiting indefinitely.
- **Pre-existing Legacy `.env` Files**: If updating an existing `.env` that lacks the `CONFIG_SESSION_PHONE_CLIENT` variable, reading the variable must not trigger a bash `set -u` unbound variable error.
- **Combined with Summary Screens**: Both the pre-installation summary and the post-installation completion summary must display the configured client name for operator visibility and validation.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST declare `DEFAULT_SESSION_PHONE_CLIENT="Inova Evolution API"` as the baseline default value.
- **FR-002**: System MUST support a CLI flag `--client-name <name>` (and `--client-name=<name>`) to accept a custom session client name as an argument.
- **FR-003**: System MUST prompt the user for the session client name during interactive installation (`ASSUME_YES=0` and `CHECK_ONLY=0`) using the existing `prompt_value` pattern, displaying the default value.
- **FR-004**: System MUST write the configured `CONFIG_SESSION_PHONE_CLIENT` to `${INSTALL_DIR}/.env` with appropriate formatting and quotes.
- **FR-005**: System MUST configure `CONFIG_SESSION_PHONE_CLIENT` in `${INSTALL_DIR}/docker-compose.yml` to pass the configured environment value to the Evolution API container.
- **FR-006**: System MUST extract and preserve `CONFIG_SESSION_PHONE_CLIENT` from an existing `.env` file when re-running installation or performing a safe update (`--update`).
- **FR-007**: System MUST document the `--client-name` flag in the script usage documentation (`usage()` / `--help`).
- **FR-008**: System MUST display the configured client name in both the pre-execution confirmation summary and the post-installation summary output.

### Key Entities

- **WhatsApp Session Phone Client (`CONFIG_SESSION_PHONE_CLIENT`)**:
  - Description: The client identifier string transmitted via the Baileys protocol to WhatsApp servers during pairing and active sessions. Displayed within parentheses next to the browser name on WhatsApp's "Linked devices" screen (e.g. `Google Chrome (<CONFIG_SESSION_PHONE_CLIENT>)`).
  - Default Value: `"Inova Evolution API"`
  - Allowed Characters: Printable UTF-8 string, typically 1 to 64 characters.
  - Storage: Saved in `${INSTALL_DIR}/.env` and passed through `${INSTALL_DIR}/docker-compose.yml`.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of interactive installations provide an explicit prompt to customize the session client name, defaulting cleanly to `Inova Evolution API` on Enter.
- **SC-002**: WhatsApp mobile app "Linked devices" displays the operator's specified client name immediately upon QR code pairing.
- **SC-003**: Unattended execution (`-y`) completes with zero blocking prompts, using the default or `--client-name` flag value.
- **SC-004**: 100% of stack updates (`--update`) retain previously configured client names from `.env` without reversion or data loss.
- **SC-005**: Zero syntax errors or container crashes caused by spaces or special characters in the custom client name string.

---

## Assumptions

- The default client name remains `"Inova Evolution API"` to ensure backwards compatibility for existing automated workflows.
- The companion browser name `CONFIG_SESSION_PHONE_NAME` remains `"Chrome"` as the standard reliable client type for WhatsApp Web protocol compatibility.
- Client name customization is applied at the service configuration level (`.env` and `docker-compose.yml`), affecting all instances provisioned under that Evolution API deployment.
