.PHONY: docker-images
docker-images:
	docker build -t bogdanp/racksnaps:8.0 -f Dockerfile .
	docker build -t bogdanp/racksnaps-built:8.0 -f Dockerfile.built .
	docker push bogdanp/racksnaps:8.0
	docker push bogdanp/racksnaps-built:8.0

.PHONY: deploy
deploy:
	rsync -avh --delete *.rkt racksnaps@snapshots:/opt/racksnaps/
	$(MAKE) -C configs/
