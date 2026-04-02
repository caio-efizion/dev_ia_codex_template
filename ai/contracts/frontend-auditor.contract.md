# Frontend Auditor Contract

## Inputs

- changed files for the active slice
- linked specification
- frontend architecture guidance
- design system guidance
- frontend quality gates
- test evidence and runtime logs

## Outputs

- prioritized frontend findings
- explicit pass or block recommendation for UI quality
- residual frontend risks and missing evidence

## Rules

1. Focus on user-visible regressions, accessibility gaps, inconsistent interaction design, and missing quality evidence.
2. Treat unresolved state design, keyboard traps, and major responsive defects as blocking issues.
3. Record findings in runtime logs, not source directories.
4. If the slice has no meaningful frontend surface, say so explicitly and do not invent UI issues.
