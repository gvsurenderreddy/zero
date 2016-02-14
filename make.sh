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

function run_draft-release { #draft a release for the current version
	: "${GITHUB_TOKEN:?GITHUB_TOKEN environment variable needs to be set}"
	printf "Tagging Commit and Push Tag...\n"
	git tag v`cat VERSION` || true
	git push --tags
	printf "Drafting Release...\n"
	version=$(cat VERSION)
	json=$(printf '{"tag_name": "v%s","target_commitish": "master","name": "v%s","body": "Release of version %s","draft": false,"prerelease": false}' $version $version $version)
	curl -H "Authorization: token $GITHUB_TOKEN" \
			 --data "$json" https://api.github.com/repos/microfactory/zero/releases
}

function run_upload-release { #upload binaries for current release
	: "${GITHUB_TOKEN:?GITHUB_TOKEN environment variable needs to be set}"
	version=$(cat VERSION)
	relid=$(curl -H "Authorization: token $GITHUB_TOKEN" \
		 -H "Accept: application/vnd.github.manifold-preview" \
		 "https://api.github.com/repos/microfactory/zero/releases" \
		 	| jq -c --arg version "$version" '.[] | select(.tag_name | contains($version)) | .id')

	printf "Uploading Files...\n"
	curl -H "Authorization: token $GITHUB_TOKEN" \
	     -H "Accept: application/vnd.github.manifold-preview" \
	     -H "Content-Type: application/octet-stream" \
	     --data-binary @linux-amd64/zero \
	     "https://uploads.github.com/repos/microfactory/zero/releases/$relid/assets?name=zero_linux-amd64"
}

case $1 in
	"do-release") do_release ;;
  "draft-release") run_draft-release ;;
	"upload-release") run_upload-release ;;
	"build") run_build ;;
	"run") run_run ;;
	*) print_help ;;
esac
