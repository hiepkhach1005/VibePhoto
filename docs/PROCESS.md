# Development Process

1. Read the files listed in `AGENTS.md`.
2. Inspect the workspace and reproduce the current baseline.
3. Select the highest-priority unblocked task in `.ai/TASKS.md`.
4. State acceptance criteria and affected modules.
5. Implement the smallest complete vertical change.
6. Build, run targeted tests, then broader tests.
7. Review data safety, main-thread work, accessibility, and error states.
8. Update status, history, tasks, and handoff before stopping.

Never start broad visual polish while a data-safety or sandbox blocker remains unresolved.
