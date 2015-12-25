#! /bin/bash
set -e

function print_help {
	printf "Available Commands:\n";
	printf "  run\n"
}

function run_build_container {
  docker build -t microfactory/zero:`cat VERSION` .
}

# run a Linux test environment
function run_run {
  : "${ZT_NET:?ZT_NET environment variable needs to be set in order to test}"
  : "${ZT_TOKEN:?ZT_TOKEN environment variable needs to be set in order to test}"

  run_build_container
  docker run -it --rm \
    --device=/dev/net/tun \
    --cap-add=NET_ADMIN \
    microfactory/zero:`cat VERSION` $ZT_NET $ZT_TOKEN
}

case $1 in
	"run") run_run ;;
	*) print_help ;;
esac
