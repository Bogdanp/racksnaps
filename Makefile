.PHONY: deploy
deploy:
	scp *.rkt snapshots:/opt/racksnaps/
