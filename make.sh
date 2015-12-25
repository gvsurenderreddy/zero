#! /bin/bash
set -e

function print_help {
	printf "Available Commands:\n";
	printf "  release\n"
  printf "  test\n"
}

#publish a new release to github
function run_release {
  git tag v`cat VERSION` || true
  git push --tags

  : "${GITHUB_TOKEN:?GITHUB_TOKEN environment variable needs to be set in order to test}"
  run_build_container
  docker build -t microfactory/zero:linux-release -f Dockerfile.release .
  docker run -it --rm -e "GITHUB_TOKEN=$GITHUB_TOKEN" microfactory/zero:linux-release
}

function run_build_container {
  docker build -t microfactory/zero:`cat VERSION` .
  docker tag -f microfactory/zero:`cat VERSION` microfactory/zero:latest
}

# run a Linux test environment
function run_test {
  : "${ZT_NET:?ZT_NET environment variable needs to be set in order to test}"
  : "${ZT_TOKEN:?ZT_TOKEN environment variable needs to be set in order to test}"

  run_build_container
  docker run -it --rm \
    --device=/dev/net/tun \
    --cap-add=NET_ADMIN \
    microfactory/zero:`cat VERSION` -start-daemon -name=test-member $ZT_NET $ZT_TOKEN
}

# This is expected to be run INSIDE a container
function do_release {
  : "${GITHUB_TOKEN:?GITHUB_TOKEN environment variable needs to be set in order to test}"
  printf "Drafing release...\n"
  github-release release \
      --user microfactory \
      --repo zero \
      --tag v`cat VERSION` \
      --pre-release

  printf "Uploading...\n"
  github-release upload \
      --user microfactory \
      --repo zero \
      --tag v`cat VERSION` \
      --name zero \
      --file /usr/local/bin/zero
}

case $1 in
	"do-release") do_release ;;
  "release") run_release ;;
  "test") run_test ;;
	*) print_help ;;
esac
