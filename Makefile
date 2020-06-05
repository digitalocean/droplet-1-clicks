

build-nodejs:
	packer build nodejs/template.json

validate-nodejs:
	packer validate nodejs/template.json

update-scripts:
	curl -o common/scripts/999-img_check.sh https://raw.githubusercontent.com/digitalocean/marketplace-partners/master/scripts/img_check.sh
	curl -o common/scripts/900-cleanup.sh https://raw.githubusercontent.com/digitalocean/marketplace-partners/master/scripts/cleanup.sh
