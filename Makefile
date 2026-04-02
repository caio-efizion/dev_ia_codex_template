SHELL := /usr/bin/env bash
export AI_STEP_RUNNER_BIN ?= ./scripts/ai-step-runner-codex.sh

.PHONY: ai-init ai-init-full ai-prd ai-prd-review ai-prd-score ai-plan ai-build ai-review ai-test ai-run ai-run-strict ai-run-graph ai-refresh-context ai-install-skills ai-quality-gates ai-pilot-validate

ai-init:
	./scripts/ai-init-project.sh

ai-init-full:
	AI_INIT_MODE=full ./scripts/ai-init-project.sh

ai-prd:
	./scripts/ai-build-prd.sh

ai-prd-review:
	./scripts/ai-review-prd.sh

ai-prd-score:
	./scripts/ai-score-prd.sh

ai-plan:
	./scripts/ai-run-graph.sh spec-generator

ai-build:
	./scripts/ai-run-graph.sh builder

ai-review:
	./scripts/ai-run-graph.sh reviewer

ai-test:
	./scripts/ai-run-graph.sh tester

ai-run:
	./scripts/ai-run-graph.sh

ai-run-strict:
	AI_ENFORCE_PRD_QUALITY=1 ./scripts/ai-run-graph.sh

ai-run-graph:
	bash scripts/ai-run-graph.sh

ai-refresh-context:
	./scripts/ai-refresh-context.sh

ai-install-skills:
	./scripts/ai-install-shared-skills.sh

ai-quality-gates:
	./scripts/ai-run-quality-gates.sh --slice "$${AI_SLICE_ID:?set AI_SLICE_ID}"

ai-pilot-validate:
	./scripts/ai-run-pilot-validation.sh
