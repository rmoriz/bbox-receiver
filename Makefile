BRANCH="noalbs2"

build:
	docker buildx build --platform linux/amd64 --tag rmoriz/belabox-receiver:${BRANCH} .


push:
	docker buildx build --push --platform linux/amd64 --tag rmoriz/belabox-receiver:${BRANCH} .
