# AGENCY PROTOCOL & OPERATIONAL MODES
# Golden Sun MMO - Development Guidelines

> **CRITICAL MANDATE:** The Agent must strictly adhere to the CURRENT MODE.
> Any attempt to use tools outside the current mode's permission set is a VIOLATION of protocol.

---

## 1. 🕵️ INVESTIGATOR MODE (DEFAULT)
**Status:** ACTIVE at start of every session.
**Goal:** Analysis, Bug Hunting, Codebase Understanding.

| ✅ ALLOWED TOOLS | ❌ BANNED TOOLS |
| :--- | :--- |
| `codebase_investigator` | `write_file` (to code files) |
| `search_file_content` | `replace` |
| `read_file` | `run_shell_command` (modifying cmds) |
| `glob` | |
| `run_shell_command` (read-only: ls, grep, cat) | |

**Trigger to Switch:** None. This is the baseline.

---

## 2. 📐 ARCHITECT MODE
**Status:** Locked until requested.
**Goal:** Drafting Specs, Plans, and Documentation.

| ✅ ALLOWED TOOLS | ❌ BANNED TOOLS |
| :--- | :--- |
| `write_file` (ONLY to `Documents/*`) | `write_file` (to `source/*` or `scripts/*`) |
| `read_file` | `replace` |
| `search_file_content` | |

**Trigger to Switch:** User request: "Plan this feature" or "Write a spec".

---

## 3. 👷 ENGINEER MODE
**Status:** 🔒 **LOCKED** 🔒
**Goal:** Implementation, Refactoring, Bug Fixing.

| ✅ ALLOWED TOOLS | ❌ BANNED TOOLS |
| :--- | :--- |
| `write_file` | None (Use with extreme caution) |
| `replace` | |
| `run_shell_command` | |

**Trigger to Switch:** 
1. User explicitly says: "Execute Plan" or "Fix this code".
2. Agent MUST confirm: "Entering Engineer Mode. Modifying files now."

---

## 4. 🧪 TESTER MODE
**Status:** Locked until code changes complete.
**Goal:** Verification, Test Execution.

| ✅ ALLOWED TOOLS | ❌ BANNED TOOLS |
| :--- | :--- |
| `run_shell_command` (test runners) | `write_file` (except logs) |
| `read_file` | `replace` |

---

## 🗺️ WORKFLOW ENFORCEMENT
1. **The Loop:** Investigator -> Architect -> Engineer -> Tester
2. **No Skipping:** Engineer Mode cannot be entered without a clear objective (usually a Plan).
3. **Unauthorized Fixes:** If the user asks "Why is this broken?", the Agent acts as **INVESTIGATOR**. It creates a report. It DOES NOT fix the code.
