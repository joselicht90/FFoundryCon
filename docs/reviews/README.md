# Reviews and evidence

Store task-bound reviews as `docs/reviews/execute-<task-slug>.md`. A review
identifies the task, implementation files, review profile, findings by
severity, commands run, skipped validation, and remaining risk. Security
reviews are independent and required for tasks marked
`securityReview: required`.

Command evidence is a concise, redacted summary: command, tool version, exit
code, stable outcome or first failure cause, and whether output was
truncated. Never commit raw logs containing reader URLs, session/auth data,
world/user/actor identifiers, chat or roll payloads, device IDs, or CI
secrets. Do not claim a CI upload, device run, or real-reader validation
unless it happened.

Reviews and evidence become immutable when their task is archived. Follow-up
work receives a new task, review, and evidence.
