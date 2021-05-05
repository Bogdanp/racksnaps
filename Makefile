.PHONY: docker-images
docker-images:
	docker build -t bogdanp/racksnaps:8.1 -f Dockerfile .
	docker build -t bogdanp/racksnaps-built:8.1 -f Dockerfile.built .
	docker push bogdanp/racksnaps:8.1
	docker push bogdanp/racksnaps-built:8.1

.PHONY: deploy
deploy:
	rsync -avh --delete *.rkt racksnaps@snapshots:/opt/racksnaps/
	$(MAKE) -C configs/
