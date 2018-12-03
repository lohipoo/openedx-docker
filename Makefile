.PHONY: android build single
.DEFAULT_GOAL := help

build: ## Build all docker images
	cd build/ && make build

single: ## Configure and run a ready-to-go Open edX platform
	cd single/ && make all

android: ## Configure and build a development Android app
	cd android/ && make all

ESCAPE = 
help: ## Print this help
	@grep -E '^([a-zA-Z_-]+:.*?## .*|######* .+)$$' Makefile \
		| sed 's/######* \(.*\)/\n               $(ESCAPE)[1;31m\1$(ESCAPE)[0m/g' \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[33m%-30s\033[0m %s\n", $$1, $$2}'
