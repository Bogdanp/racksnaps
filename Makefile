.PHONY: docker-images
docker-images:
	docker build -t bogdanp/racksnaps:7.7 -f Dockerfile .
	docker build -t bogdanp/racksnaps-built:7.7 -f Dockerfile.built .
	docker push bogdanp/racksnaps:7.7
	docker push bogdanp/racksnaps-built:7.7

.PHONY: deploy
deploy:
	rsync -avh --delete *.rkt racksnaps@snapshots:/opt/racksnaps/
	$(MAKE) -C configs/
