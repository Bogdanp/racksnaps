.PHONY: docker-images
docker-image:
	docker build -t bogdanp/racksnaps:7.6 -f Dockerfile .
	docker build -t bogdanp/racksnaps-built:7.6 -f Dockerfile.built .
	docker push bogdanp/racksnaps:7.6
	docker push bogdanp/racksnaps-built:7.6

.PHONY: deploy
deploy:
	$(MAKE) -C ci/
	rsync -avh --delete *.rkt racksnaps@snapshots:/opt/racksnaps/
