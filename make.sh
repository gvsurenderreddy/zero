#! /bin/bash
set -e

function print_help {
	printf "Available Commands:\n";
	printf "  test\n"
}

function run_build_container {
  docker build -t microfactory/zero:`cat VERSION` .
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

case $1 in
	"test") run_test ;;
	*) print_help ;;
esac
