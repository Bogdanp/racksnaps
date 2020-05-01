.PHONY: deploy
deploy:
	scp *.rkt racksnaps@snapshots:/opt/racksnaps/
