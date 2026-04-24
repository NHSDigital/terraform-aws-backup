# Agent Skills

This directory contains [VS Code Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills) — folders of instructions, scripts, and resources that GitHub Copilot loads on-demand when relevant to a task.

Skills complement the always-on rules in `.github/copilot-instructions.md`. Copilot-instructions contain generic guidance relevant to every task. Skills contain specialist knowledge loaded only when needed, keeping the agent's context focused.

## Skills in This Repository

| Skill | Directory | When Copilot Loads It |
| ------- | ----------- | ---------------------- |
| **Backup Plans & Selections** | `backup-plans-selections/` | Adding or modifying backup plans, tag-based selections, retention lifecycle, or compliance frameworks |
| **Python Lambdas** | `python-lambdas/` | Working on Python Lambda code under `modules/aws-backup-source/resources/` |
| **Vault Lock Safety** | `vault-lock-safety/` | Any mention of vault lock, compliance mode, or immutability settings |

## Related Documentation

- [Copilot Instructions](../copilot-instructions.md) — always-on agent rules
- [Covered Services](../../COVERED_SERVICES.md) — which AWS services are supported
- [Changelog](../../CHANGELOG.md) — module version history
