.PHONY: docker-images
docker-images:
	docker build -t bogdanp/racksnaps:8.2 -f Dockerfile .
	docker build -t bogdanp/racksnaps-built:8.2 -f Dockerfile.built .
	docker push bogdanp/racksnaps:8.2
	docker push bogdanp/racksnaps-built:8.2

.PHONY: deploy
deploy:
	rsync -avh --delete *.rkt racksnaps@snapshots:/opt/racksnaps/
	$(MAKE) -C configs/
