include .env
export $(shell sed 's/=.*//' .env)

WORDPRESS_BRANCH ?= '4.4-branch'
RANDOM := $(shell bash -c 'echo $$((RANDOM%255+1))')
VAGRANT_IP ?= '192.168.33.$(RANDOM)'
SITE_NAME ?= 'site-$(RANDOM)'
WP_ADMIN_PASSWORD ?= '$(shell openssl rand -base64 8)'
WP_ADMIN_USER ?= $(shell git config --get --global user.email)

RSYNC_EXCLUDE ?= --exclude node_modules/ --exclude wp-config.php --exclude .DS_Store --exclude .git/ --exclude *.swp --exclude wp-snapshots/ --exclude test/ --exclude stats/ --exclude tmp/ --exclude cache/

GREP ?= grep -rl --exclude-dir=site --exclude=Makefile

default:
	$(MAKE) replace_variables

	git clone -b $(WORDPRESS_BRANCH) --single-branch --depth 1 git@github.com:WordPress/WordPress.git site
	rm -rf ./site/.git
	wget -O ./site/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	rm -rf site/wp-content/themes/twenty*

	composer create-project roots/sage 'site/wp-content/themes/$(SITE_NAME)'
	$(MAKE) wp_generate_config
	vagrant up
	$(MAKE) configure_wp
	$(MAKE) configure_theme_git
	$(MAKE) npm_bower_install
	echo "admin password is $(WP_ADMIN_PASSWORD)"

existing:
	$(MAKE) replace_variables
	rsync $(RSYNC_EXCLUDE) -avz -e ssh $(REMOTE_SSH_USER)@$(REMOTE_SSH_HOST):$(REMOTE_WP_PATH) site/

	wget -O ./site/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
ifdef $(THEME_GIT_REMOTE)
	rm -rf 'site/wp-content/themes/$(SITE_NAME)'
	git clone $(THEME_GIT_REMOTE) 'site/wp-content/themes/$(SITE_NAME)'
endif
	vagrant up

clean:
	git add .
	git reset --hard

replace_variables:
	$(GREP) '{{VAGRANT_IP}}' ./ | xargs sed -i 's/{{VAGRANT_IP}}/$(VAGRANT_IP)/g'
	$(GREP) '{{SITE_NAME}}' ./ | xargs sed -i 's/{{SITE_NAME}}/$(SITE_NAME)/g'
	$(GREP) '{{VAGRANT_MYSQL_DB}}' ./ | xargs sed -i 's/{{VAGRANT_MYSQL_DB}}/$(VAGRANT_MYSQL_DB)/g'
	$(GREP) '{{VAGRANT_MYSQL_USER}}' ./ | xargs sed -i 's/{{VAGRANT_MYSQL_USER}}/$(VAGRANT_MYSQL_USER)/g'
	$(GREP) '{{VAGRANT_MYSQL_PASSWORD}}' ./ | xargs sed -i 's/{{VAGRANT_MYSQL_PASSWORD}}/$(VAGRANT_MYSQL_PASSWORD)/g'
	$(GREP) '{{VAGRANT_MYSQL_ROOT_PASSWORD}}' ./ | xargs sed -i 's/{{VAGRANT_MYSQL_ROOT_PASSWORD}}/$(VAGRANT_MYSQL_ROOT_PASSWORD)/g'
	$(GREP) '{{VAGRANT_MYSQL_DUMP}}' ./ | xargs sed -i 's/{{VAGRANT_MYSQL_DUMP}}/$(VAGRANT_MYSQL_DUMP)/g'

wp_generate_config:
	wget https://api.wordpress.org/secret-key/1.1/salt/ -q -O keys.php
	sed -i -e '/{{KEYS}}/{r keys.php' -e 'd}' tpl/wp-config.php
	sed -i -e 's/{{VAGRANT_IP}}/$(VAGRANT_IP)/g' tpl/wp-config.php
	sed -i -e 's/example.dev/$(VAGRANT_IP)/g' site/wp-content/themes/$(SITE_NAME)/assets/manifest.json
	cp tpl/wp-config.php site/wp-config.php
	rm keys.php

configure_wp:
	vagrant ssh -c 'php /vagrant/wp-cli.phar core install --path=/vagrant/ \
			--url="http://$(VAGRANT_IP)" \
			--title="$(SITE_NAME)" \
			--admin_user=$(WP_ADMIN_USER) \
			--admin_password=$(WP_ADMIN_PASSWORD) \
			--admin_email=$(WP_ADMIN_USER)'
	vagrant ssh -c 'php /vagrant/wp-cli.phar theme activate $(SITE_NAME) --path=/vagrant/'

wp_plugins:
	rm -f site/wp-content/plugins/hello.php
	wget -O site/wp-content/plugins/acf-pro.zip 'http://connect.advancedcustomfields.com/index.php?p=pro&a=download&k=$(ACF_KEY)'
	vagrant ssh -c 'php /vagrant/wp-cli.phar plugin install /vagrant/wp-content/plugins/acf-pro.zip --path=/vagrant/ --activate'
	vagrant ssh -c 'php /vagrant/wp-cli.phar plugin install acf-field-date-time-picker --path=/vagrant/ --activate'

configure_theme_git:
	rm -rf site/wp-content/themes/$(SITE_NAME)/.git
	git init site/wp-content/themes/$(SITE_NAME)
	git add .
	git commit -m "init"

npm_bower_install:
	cd site/wp-content/themes/$(SITE_NAME)/ & npm install
	bower install

vars:
	@echo "Wordpress branch: $(WORDPRESS_BRANCH)"
	@echo "Random: $(RANDOM)"
	@echo "Vagrant IP: $(VAGRANT_IP)"
	@echo "Site name: $(SITE_NAME)"
	@echo "WP admin password: $(WP_ADMIN_PASSWORD)"
	@echo "User: $(WP_ADMIN_USER)"
	@echo "SSH user: $(REMOTE_SSH_USER)"

deploy_site:
	rsync $(RSYNC_EXCLUDE) -avz site/ -e ssh $(REMOTE_SSH_USER)@$(REMOTE_SSH_HOST):$(REMOTE_WP_PATH)

deploy_theme: gulp_prod
	rsync $(RSYNC_EXCLUDE) -avz site/wp-content/themes/$(SITE_NAME)/ -e ssh $(REMOTE_SSH_USER)@$(REMOTE_SSH_HOST):$(REMOTE_WP_PATH)/wp-content/themes/$(SITE_NAME)/

compare_remote_theme:
	rsync $(RSYNC_EXCLUDE) -n -avzrc --delete site/wp-content/themes/$(SITE_NAME)/ -e ssh $(REMOTE_SSH_USER)@$(REMOTE_SSH_HOST):$(REMOTE_WP_PATH)/wp-content/themes/$(SITE_NAME)/

gulp_prod:
	NODE_PATH=site/wp-content/themes/$(SITE_NAME)/node_modules/ gulp --gulpfile=site/wp-content/themes/$(SITE_NAME)/gulpfile.js
