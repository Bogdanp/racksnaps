.PHONY: docker-images
docker-images:
	docker build -t bogdanp/racksnaps:8.5 -f Dockerfile .
	docker build -t bogdanp/racksnaps-built:8.5 -f Dockerfile.built .
	docker push bogdanp/racksnaps:8.5
	docker push bogdanp/racksnaps-built:8.5

.PHONY: deploy
deploy:
	rsync -avh --delete *.rkt racksnaps@racksnaps:/opt/racksnaps/
	$(MAKE) -C configs/
