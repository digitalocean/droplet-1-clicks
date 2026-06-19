.PHONY: app build-% update-scripts validate-%

OS_VERSION ?= 24-04

app:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make app NAME=<app-name> [OS_VERSION=<os-version>]" >&2; \
		exit 1; \
	fi
	./scripts/create-1-click.sh "$(NAME)" "$(OS_VERSION)"

%:
	./scripts/create-1-click.sh $* "$(OS_VERSION)"

build-%:
	packer build $*/template.json

validate-%:
	packer validate $*/template.json

update-scripts:
	curl -o common/scripts/999-img_check.sh https://raw.githubusercontent.com/digitalocean/marketplace-partners/master/scripts/99-img-check.sh
	curl -o common/scripts/900-cleanup.sh https://raw.githubusercontent.com/digitalocean/marketplace-partners/master/scripts/90-cleanup.sh
