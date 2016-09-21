build:
	./node_modules/.bin/uglifyjs --compress --output Stark/Resources/stark-lib.js StarkLib/*.js

clean:
	rm Stark/Resources/stark-lib.js

deps:
	npm install uglify-js

.PHONY: build clean deps
