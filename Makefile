.PHONY: docker-images
docker-images:
	docker build -t bogdanp/racksnaps:7.9 -f Dockerfile .
	docker build -t bogdanp/racksnaps-built:7.9 -f Dockerfile.built .
	docker push bogdanp/racksnaps:7.9
	docker push bogdanp/racksnaps-built:7.9

.PHONY: deploy
deploy:
	rsync -avh --delete *.rkt racksnaps@snapshots:/opt/racksnaps/
	$(MAKE) -C configs/
