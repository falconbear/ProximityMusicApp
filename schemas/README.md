# schemas/ — JSON Schema definitions

Machine-readable state lives in `.ai/work/<issue-id>/`:

| File | Schema | Writer | Readers |
|---|---|---|---|
| `state.json` | `state.schema.json` | `bin/controller.py` (sole writer) | all agents, all hooks |
| `contract.json` | `contract.schema.json` | generator (draft/revise only) | evaluator, hooks |
| `qa.json` | `qa.schema.json` | evaluator | parent Claude, observer |
| `progress.jsonl` | `event.schema.json` (one event per line) | `bin/controller.py` (append-only) | observer, debugging |

Prose artifacts stay as Markdown:

| File | Writer | Purpose |
|---|---|---|
| `handoff.md` | generator | Generator → evaluator narrative summary |
| `docs/feedback/issue-<id>.md` | evaluator (impl mode) | Review rationale with bug repro steps |
| `docs/feedback/issue-<id>-contract.md` | evaluator (contract mode) | Contract review rationale |

## Principle

- **JSON** = state the machine updates and validates
- **MD** = narrative the AI reads to understand and follow

State machine (`current_state`) transitions are enforced by `bin/controller.py`.
Contract fields become immutable once `state.current_state` leaves `PLANNED` / `CONTRACT_REVIEW`.
