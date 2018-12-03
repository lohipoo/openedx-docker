.PHONY: android
.DEFAULT_GOAL := help

PWD ?= $$(pwd)
USERID ?= $$(id -u)
EDX_PLATFORM_SETTINGS ?= universal.production
-include $(PWD)/Makefile.env

extra_migrate_targets = 
ifeq ($(ACTIVATE_XQUEUE), 1)
	extra_migrate_targets += migrate-xqueue
endif
ifeq ($(ACTIVATE_NOTES), 1)
	extra_migrate_targets += migrate-notes
endif

DOCKER_COMPOSE_RUN = docker-compose run --rm
DOCKER_COMPOSE_RUN_OPENEDX = $(DOCKER_COMPOSE_RUN) -e SETTINGS=$(EDX_PLATFORM_SETTINGS)
ifneq ($(EDX_PLATFORM_PATH),)
	DOCKER_COMPOSE_RUN_OPENEDX += -e USERID=$(USERID) --volume="$(EDX_PLATFORM_PATH):/openedx/edx-platform"
endif

DOCKER_COMPOSE_RUN_LMS = $(DOCKER_COMPOSE_RUN_OPENEDX) -p 8000:8000 lms
DOCKER_COMPOSE_RUN_CMS = $(DOCKER_COMPOSE_RUN_OPENEDX) -p 8001:8001 cms

##################### Running Open edX

# other targets are not listed as requirements in order to reload the env file
all: configure ## Configure and run a full-featured platform
	@$(MAKE) post_configure
	@$(MAKE) update
	@$(MAKE) databases
	@$(MAKE) assets
	@$(MAKE) daemonize
	@echo "All set \o/ You can access the LMS at http://localhost and the CMS at http://studio.localhost"

run: ## Run the complete platform
	docker-compose up
up: run

daemonize: ## Run the complete platform, with daemonization
	docker-compose up -d
	@echo "Daemon is up and running"
daemon: daemonize

stop: ## Stop all services
	docker-compose rm --stop --force

##################### Docker image management

update: ## Download most recent images
	docker-compose pull

##################### Configuration

configure: ## Configure the environment prior to running the platform
	@docker run --rm -it \
		--volume="$(PWD)/../:/openedx/config/" \
		--volume="$(PWD)/templates/apps:/openedx/templates" \
		--volume="$(PWD)/config:/openedx/output" \
		-e USERID=$(USERID) -e SILENT=$(SILENT) $(CONFIGURE_OPTS) \
		regis/openedx-configurator:hawthorn
	@docker run --rm -it \
		--volume="$(PWD)/../:/openedx/config/" \
		--volume="$(PWD)/templates/single:/openedx/templates" \
		--volume="$(PWD):/openedx/output" \
		-e USERID=$(USERID) -e SILENT=$(SILENT) $(CONFIGURE_OPTS) \
		regis/openedx-configurator:hawthorn \
    	configurator substitute /openedx/templates/ /openedx/output/

post_configure_targets =
ifneq ($(DISABLE_STATS), 1)
	post_configure_targets += stats
endif
ifeq ($(ACTIVATE_HTTPS), 1)
	post_configure_targets += https-certificate
endif
post_configure: $(post_configure_targets)

##################### Database

databases: provision-databases migrate provision-oauth2 ## Bootstrap databases

provision-databases: ## Create necessary databases and users
	$(DOCKER_COMPOSE_RUN) lms /openedx/config/provision.sh
provision-oauth2: ## Create users for SSO between services
	$(DOCKER_COMPOSE_RUN) lms /openedx/config/oauth2.sh

migrate: migrate-openedx migrate-forum $(extra_migrate_targets) ## Perform all database migrations
migrate-openedx: ## Perform database migrations on LMS/CMS
	$(DOCKER_COMPOSE_RUN) lms bash -c "dockerize -wait tcp://mysql:3306 -timeout 20s && ./manage.py lms migrate"
	$(DOCKER_COMPOSE_RUN) cms bash -c "dockerize -wait tcp://mysql:3306 -timeout 20s && ./manage.py cms migrate"
	$(MAKE) reindex-courses
migrate-forum: ## Perform database migrations on discussion forums
	$(DOCKER_COMPOSE_RUN) forum bash -c "bundle exec rake search:initialize && \
		bundle exec rake search:rebuild_index"
migrate-notes: ## Perform database migrations for the Notes service
	$(DOCKER_COMPOSE_RUN) notes ./manage.py migrate
migrate-xqueue: ## Perform database migrations for the XQueue service
	$(DOCKER_COMPOSE_RUN) xqueue ./manage.py migrate
reindex-courses: ## Refresh course index so they can be found in the LMS search engine
	$(DOCKER_COMPOSE_RUN) cms ./manage.py cms reindex_course --all --setup

##################### Static assets

# To collect assets we don't rely on the "paver update_assets" command because
# webpack collection incorrectly sets the NODE_ENV variable when using custom
# settings. Thus, each step must be performed separately. This should be fixed
# in the next edx-platform release thanks to https://github.com/edx/edx-platform/pull/18430/
#assets-lms: ## Collect static assets for the LMS
	#$(DOCKER_COMPOSE_RUN_OPENEDX) lms -e NO_PREREQ_INSTALL=True lms paver update_assets lms --settings=$(EDX_PLATFORM_SETTINGS)
#assets-cms: ## Collect static assets for the CMS
	#$(DOCKER_COMPOSE_RUN_OPENEDX) cms -e NO_PREREQ_INSTALL=True cms paver update_assets cms --settings=$(EDX_PLATFORM_SETTINGS)

assets: ## Generate production-ready static assets
	docker-compose -f scripts.yml run --rm \
		--volume=$(PWD)/data/:/data/lms/ \
		--volume=$(PWD)/data/cms/:/data/cms/ \
		openedx bash -c \
		"rm -rf /data/lms/staticfiles /data/cms/staticfiles \
		&& cp -r /openedx/data/staticfiles /data/lms/ \
		&& cp -r /openedx/data/staticfiles /data/cms/"
assets-development: assets-development-lms assets-development-cms ## Generate static assets for local development
assets-development-lms:
	$(DOCKER_COMPOSE_RUN_OPENEDX) --no-deps lms bash -c \
		"xmodule_assets common/static/xmodule \
		&& python -c \"import pavelib.assets; pavelib.assets.process_npm_assets()\" \
		&& NODE_ENV=development ./node_modules/.bin/webpack --config=webpack.dev.config.js \
		&& ./manage.py lms --settings=$(EDX_PLATFORM_SETTINGS) compile_sass lms \
		&& python -c \"import pavelib.assets; pavelib.assets.collect_assets(['lms'], '$(EDX_PLATFORM_SETTINGS)')\""
assets-development-cms:
	$(DOCKER_COMPOSE_RUN_OPENEDX) --no-deps cms bash -c \
		"xmodule_assets common/static/xmodule \
		&& python -c \"import pavelib.assets; pavelib.assets.process_npm_assets()\" \
		&& NODE_ENV=development ./node_modules/.bin/webpack --config=webpack.dev.config.js \
		&& ./manage.py cms --settings=$(EDX_PLATFORM_SETTINGS) compile_sass studio \
		&& python -c \"import pavelib.assets; pavelib.assets.collect_assets(['studio'], '$(EDX_PLATFORM_SETTINGS)')\""
	

#################### Logging

logs: ## Print all logs from a service since it started. E.g: "make logs service=lms", "make logs service=nginx"
	docker-compose logs $(service)
tail: ## Similar to "tail" on the logs of a service. E.g: "make tail service=lms", "make tail service=nginx"
	docker-compose logs --tail=10 $(service)
tail-follow: ## Similar to "tail -f" on the logs of a service. E.g: "make tail-follow service=lms", "make tail-follow service=nginx"
	docker-compose logs --tail=10 -f $(service)

##################### Development

lms: ## Open a bash shell in the LMS
	$(DOCKER_COMPOSE_RUN_LMS) bash
cms: ## Open a bash shell in the CMS
	$(DOCKER_COMPOSE_RUN_CMS) bash

lms-python: ## Open a python shell in the LMS
	$(DOCKER_COMPOSE_RUN_OPENEDX) lms ./manage.py lms shell
lms-shell: lms-python
cms-python: ## Open a python shell in the CMS
	$(DOCKER_COMPOSE_RUN_OPENEDX) cms ./manage.py cms shell
cms-shell: cms-python

restart-openedx: ## Restart lms, cms, and workers
	docker-compose restart lms lms_worker cms cms_worker

##################### SSL/TLS (HTTPS certificates)

https_command = docker run --rm -it \
		--volume="$(PWD)/config/letsencrypt/:/openedx/letsencrypt/config/" \
		--volume="$(PWD)/data/letsencrypt/:/etc/letsencrypt/" \
		-p "80:80"
certbot_image = certbot/certbot:latest

https-certificate: ## Generate https certificates
	$(https_command) --entrypoint "/openedx/letsencrypt/config/certonly.sh" $(certbot_image)

https-certificate-renew: ## Renew https certificates
	$(https_command) $(certbot_image) renew

##################### Additional commands

stats: ## Collect anonymous information about the platform
	@docker run --rm -it --volume="$(PWD)/config:/openedx/config" \
		regis/openedx-configurator:hawthorn /openedx/config/openedx/stats 2> /dev/null|| true

import-demo-course: ## Import the demo course from edX
	$(DOCKER_COMPOSE_RUN_OPENEDX) cms /bin/bash -c " \
		git clone https://github.com/edx/edx-demo-course --branch open-release/hawthorn.2 --depth 1 ../edx-demo-course \
		&& python ./manage.py cms import ../data ../edx-demo-course"

create-staff-user: ## Create a user with admin rights
	$(DOCKER_COMPOSE_RUN_OPENEDX) lms /bin/bash -c "./manage.py lms manage_user --superuser --staff ${USERNAME} ${EMAIL} && ./manage.py lms changepassword ${USERNAME}"

##################### Information

# Obtained by running "echo '\033' in a shell
ESCAPE = 
help: ## Print this help
	@grep -E '^([a-zA-Z_-]+:.*?## .*|######* .+)$$' Makefile \
		| sed 's/######* \(.*\)/\n               $(ESCAPE)[1;31m\1$(ESCAPE)[0m/g' \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[33m%-30s\033[0m %s\n", $$1, $$2}'

info: ## Print some information about the current install, for debugging
	uname -a
	@echo "-------------------------"
	git rev-parse HEAD
	@echo "-------------------------"
	docker version
	@echo "-------------------------"
	docker-compose --version
	@echo "-------------------------"
	echo $$EDX_PLATFORM_PATH
	echo $$EDX_PLATFORM_SETTINGS
