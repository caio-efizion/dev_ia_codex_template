SHELL := /usr/bin/env bash

.PHONY: ai-init ai-plan ai-build ai-review ai-test ai-run ai-run-graph ai-refresh-context

ai-init:
	./scripts/ai-init-project.sh

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

ai-run-graph:
	bash scripts/ai-run-graph.sh

ai-refresh-context:
	./scripts/ai-refresh-context.sh
