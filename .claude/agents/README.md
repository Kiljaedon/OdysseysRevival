# Odysseys Revival - Specialized Agent Configurations

This directory contains configuration files for each specialized Haiku agent in the development team.

## Directory Structure

```
.claude/agents/
├── README.md (this file)
│
├── Domain Specialists (MMO Systems)
│   ├── combat-systems-dev.md       - Combat logic, damage, abilities
│   ├── world-systems-dev.md        - Movement, NPCs, maps, world state
│   ├── player-systems-dev.md       - Stats, inventory, equipment, progression
│   └── network-protocol-dev.md     - RPCs, validation, synchronization
│
├── Operations & Quality Assurance
│   ├── server-operations.md        - Deployment, monitoring (REMOTE ONLY)
│   ├── code-reviewer.md            - Security audits, exploit prevention
│   └── test-engineer.md            - Unit tests, simulations, integration tests
│
└── Support Specialists
    ├── bug-hunter.md               - Bug investigation, root cause analysis
    ├── performance-optimizer.md    - Profiling, bottleneck analysis
    └── documentation-writer.md     - Docs, logs, API documentation
```

## How These Files Work

Each `.md` file contains:
- **Role & Focus** - What this agent specializes in
- **Scope** - Which files and systems they work on
- **Responsibilities** - What tasks they handle
- **Security Guidelines** - Critical security rules
- **Testing Requirements** - How to test their work
- **Documentation** - What docs they maintain

## Agent Invocation

**To use an agent:**
```
"[Agent Name]: [Task description]"

Example:
"Combat Systems Dev: Implement critical hit system"
```

**To load explicit config:**
```
"Load .claude/agents/combat-systems-dev.md and implement healing abilities"
```

**Parallel execution:**
```
"In parallel:
- Combat Systems Dev: Implement damage over time
- Player Systems Dev: Add stat regeneration
- Test Engineer: Write tests for both"
```

## Critical Rules

### Server Operations Agent
- **ONLY operates on remote server:** root@178.156.202.89 (SSH port 22)
- **Game server runs on:** port 9043 (client connections)
- **NEVER touches local dev files**
- Used for: deployment, monitoring, backups only

### Domain Boundaries
- Each agent stays within their domain
- Combat Dev doesn't touch inventory
- Player Dev doesn't touch combat logic
- World Dev doesn't touch stats

### Security First
- Code Reviewer audits ALL changes before deployment
- Test Engineer tests ALL features before deployment
- All RPCs must be validated server-side
- All calculations must use floor()

### Documentation Always
- Documentation Writer updates docs after ALL changes
- Keep development log current
- Update API docs when RPCs change

## Token Optimization

- **90% Haiku** - All specialized agents
- **10% Sonnet** - System Architect (coordination, architecture)
- **Target** - 70% cost reduction

## File Modification Rules

**Agents should ONLY modify files in their scope:**

| Agent | Primary Files |
|-------|---------------|
| Combat Systems Dev | `source/server/managers/combat_manager.gd`, combat-related |
| World Systems Dev | `source/server/server_world.gd`, `wandering_npc.gd`, world managers |
| Player Systems Dev | `source/server/managers/player_manager.gd`, stats, inventory |
| Network Protocol Dev | Files with `@rpc`, authentication, network managers |
| Server Operations | **ONLY remote server files** |
| Code Reviewer | **Read-only** (audits, doesn't modify) |
| Test Engineer | `tests/*` directory only |
| Bug Hunter | **Read-only** (investigates, doesn't fix) |
| Performance Optimizer | Any file (with benchmarking) |
| Documentation Writer | `Documents/*` only |

## Quick Reference

**Need to...**
- Fix combat? → Combat Systems Dev
- Fix NPCs? → World Systems Dev
- Fix inventory? → Player Systems Dev
- Fix RPCs? → Network Protocol Dev
- Deploy? → Server Operations
- Review code? → Code Reviewer
- Write tests? → Test Engineer
- Investigate bug? → Bug Hunter
- Optimize performance? → Performance Optimizer
- Update docs? → Documentation Writer

## More Information

- **Main Config:** `/c/Users/dougd/CLAUDE.md`
- **Usage Guide:** `Documents/AGENT_USAGE_GUIDE.md`
- **Project Docs:** `Documents/`

---

*Agent System Version: 2.0 (Specialized Architecture)*
*Last Updated: 2025-11-11*
