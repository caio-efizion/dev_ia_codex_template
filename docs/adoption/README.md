# Existing Project Adoption

Use this directory when the template is being applied to an already active project instead of a fresh repository.

Recommended flow:

1. `make ai-adopt-existing`
2. `make ai-audit-security`
3. `make ai-audit-frontend`
4. review `docs/adoption/existing-system-inventory.md`
5. refine `docs/prd-questionnaire.md` with the real legacy constraints
6. continue with `make ai-define`, `make ai-build`, and `make ai-prove`

Durable outputs for this flow should stay under `docs/` and `reports/`, not `runtime/`.
