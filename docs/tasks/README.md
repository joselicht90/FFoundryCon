# Task cards

Place active, non-trivial work in `docs/tasks/<slug>.md`. Use lowercase
kebab-case slugs and frontmatter with:

```yaml
---
executor: task-executor
platforms: [android, ios]
workKinds: [flutter]
blockedBy: []
securityReview: required # only when a security boundary changes
---
```

Allowed executors are `task-executor`, `code-reviewer`, and
`security-reviewer`. `platforms` may contain only `android` and `ios`.
`workKinds` must be a nonempty subset of `flutter`, `android`, `ios`,
`integration`, `security`, `documentation`, and `planning`.

Each task states its authoritative facts, scope, acceptance criteria,
verification method, limitations, and dependencies. Split platform-specific
work when it has separate implementation or verification needs. Archived
tasks move to `docs/tasks/done/`; they are not rewritten after closure.
