# Runbooks

Cross-cutting and per-machine install/migration runbooks, written as part of
their tickets:

| Runbook | Ticket | Written when |
|---|---|---|
| `secrets.md` | [12](../tickets/12-secrets-management.md) | secrets infra (key bootstrap) |
| `private-laptop.md` | [13](../tickets/13-host-private-laptop-pilot.md) | pilot migration |
| `work-laptop.md` | [14](../tickets/14-host-work-laptop.md) | second migration |
| `desktop.md` | [15](../tickets/15-host-desktop.md) | final migration |

Each per-machine runbook must cover: pre-migration backup checklist, installation steps
(ISO, partitioning/disko, LUKS), data migration, first `nixos-rebuild switch`,
a hardware validation checklist (the acceptance test for the host ticket), and
a rollback plan.
