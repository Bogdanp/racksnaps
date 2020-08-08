.PHONY: docker-images
docker-images:
	docker build -t bogdanp/racksnaps:7.8 -f Dockerfile .
	docker build -t bogdanp/racksnaps-built:7.8 -f Dockerfile.built .
	docker push bogdanp/racksnaps:7.8
	docker push bogdanp/racksnaps-built:7.8

.PHONY: deploy
deploy:
	rsync -avh --delete *.rkt racksnaps@snapshots:/opt/racksnaps/
	$(MAKE) -C configs/
