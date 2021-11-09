.PHONY: docker-images
docker-images:
	docker build -t bogdanp/racksnaps:8.3 -f Dockerfile .
	docker build -t bogdanp/racksnaps-built:8.3 -f Dockerfile.built .
	docker push bogdanp/racksnaps:8.3
	docker push bogdanp/racksnaps-built:8.3

.PHONY: deploy
deploy:
	rsync -avh --delete *.rkt racksnaps@snapshots:/opt/racksnaps/
	$(MAKE) -C configs/
