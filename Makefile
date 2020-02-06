HOME=$(shell pwd)
MAINVERSION=2.0
VERSION=$(shell wget -qO- http://git.haproxy.org/git/haproxy-${MAINVERSION}.git/refs/tags/ | sed -n 's:.*>\(.*\)</a>.*:\1:p' | sed 's/^.//' | sort -rV | head -1)
ifeq ("${VERSION}","./")
        VERSION="${MAINVERSION}.0"
endif
RELEASE?=1

BUILDER_IMAGE:=haproxy-rpm-builder
DOCKER_RUN:=docker run --volume $(HOME):/builder --rm $(BUILDER_IMAGE):latest


.PHONY: build-docker
build-docker:
	docker build -t $(BUILDER_IMAGE):latest -f Dockerfile .

.PHONY: run-docker
run-docker: clean build-docker
	$(DOCKER_RUN)

all: build

install_prereq:
	yum install -y pcre-devel make gcc openssl-devel rpm-build systemd-devel wget sed zlib-devel

clean:
	rm -f ./SOURCES/haproxy-${VERSION}.tar.gz
	rm -rf ./rpmbuild
	mkdir -p ./rpmbuild/SPECS/ ./rpmbuild/SOURCES/ ./rpmbuild/RPMS/ ./rpmbuild/SRPMS/

download-upstream:
	wget http://www.haproxy.org/download/${MAINVERSION}/src/haproxy-${VERSION}.tar.gz -O ./SOURCES/haproxy-${VERSION}.tar.gz

build: install_prereq clean download-upstream
	cp -r ./SPECS/* ./rpmbuild/SPECS/ || true
	cp -r ./SOURCES/* ./rpmbuild/SOURCES/ || true
	rpmbuild -ba SPECS/haproxy.spec \
	--define "version ${VERSION}" \
	--define "release ${RELEASE}" \
	--define "_topdir %(pwd)/rpmbuild" \
	--define "_builddir %{_topdir}/BUILD" \
	--define "_buildroot %{_topdir}/BUILDROOT" \
	--define "_rpmdir %{_topdir}/RPMS" \
	--define "_srcrpmdir %{_topdir}/SRPMS"

.PHONY: run-test
run-tests:
	yum install -y ./rpmbuild/RPMS/x86_64/haproxy-${VERSION}-${RELEASE}.el7.x86_64.rpm
	/usr/sbin/haproxy -vv|grep -c Prometheus

.PHONY: test
test:
	$(DOCKER_RUN) make run-tests
