#! /bin/bash
set -e

function print_help {
	printf "Available Commands:\n";
	awk -v sq="'" '/^function run_([a-zA-Z0-9-]*)\s*/ {print "-e " sq NR "p" sq " -e " sq NR-1 "p" sq }' make.sh \
		| while read line; do eval "sed -n $line make.sh"; done \
		| paste -d"|" - - \
		| sed -e 's/^/  /' -e 's/function run_//' -e 's/#//' -e 's/{/	/' \
		| awk -F '|' '{ print "  " $2 "\t" $1}' \
		| expand -t 20
}

# function run_release { #publish a new release to github
#   git tag v`cat VERSION` || true
#   git push --tags
#
#   : "${GITHUB_TOKEN:?GITHUB_TOKEN environment variable needs to be set in order to test}"
#   run_build_container
#   docker build -t microfactory/zero:linux-release -f Dockerfile.release .
#   docker run -it --rm -e "GITHUB_TOKEN=$GITHUB_TOKEN" microfactory/zero:linux-release
# }

function run_build { #build linux binary in a Docker container
	docker build -f build.Dockerfile -t microfactory/zero:build-`cat VERSION` .
  docker run -it -v $PWD:/src/github.com/microfactory/zero --rm microfactory/zero:build-`cat VERSION`
}

function run_run { #run a Linux test environment
  : "${ZT_NET:?ZT_NET environment variable needs to be set in order to test}"
  : "${ZT_TOKEN:?ZT_TOKEN environment variable needs to be set in order to test}"

  docker build -f run.Dockerfile -t microfactory/zero:`cat VERSION` .
  docker run -it --rm \
    --device=/dev/net/tun \
    --cap-add=NET_ADMIN \
    microfactory/zero:`cat VERSION` -start-daemon -name=test-member $ZT_NET $ZT_TOKEN
}

# This is expected to be run INSIDE a container
# function do_release {
#   : "${GITHUB_TOKEN:?GITHUB_TOKEN environment variable needs to be set in order to test}"
#   printf "Drafing release...\n"
#   github-release release \
#       --user microfactory \
#       --repo zero \
#       --tag v`cat VERSION` \
#       --pre-release
#
#   printf "Uploading...\n"
#   github-release upload \
#       --user microfactory \
#       --repo zero \
#       --tag v`cat VERSION` \
#       --name zero \
#       --file /usr/local/bin/zero
# }

case $1 in
	"do-release") do_release ;;
  # "release") run_release ;;
	"build") run_build ;;
	"run") run_run ;;
	*) print_help ;;
esac
