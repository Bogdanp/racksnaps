.PHONY: docker-image
docker-image:
	docker build -t bogdanp/racksnaps:7.6 -f Dockerfile .
	docker push bogdanp/racksnaps:7.6

.PHONY: deploy
deploy:
	rsync -avh --delete *.rkt racksnaps@snapshots:/opt/racksnaps/
