#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/k3d-io/k3d"
TOOL_NAME="k3d"
TOOL_TEST="k3d --help"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//'
}

list_all_versions() {
	list_github_tags
}

get_platform() {
	if [[ $(uname -s) == "Darwin" ]]; then
		_arch="$(uname | tr '[:upper:]' '[:lower:]')"
		echo "$_arch"
	elif [[ $(uname -s) == "Linux" ]]; then
		_arch="$(uname | tr '[:upper:]' '[:lower:]')"
		echo "$_arch"
	else
		echo >&2 'Platform not supported' && exit 1
	fi
}

get_arch() {
	if [[ $(uname -m) == "x86_64" ]]; then
		echo "amd64"
	elif [[ $(uname -m) == "arm64" ]]; then
		echo "arm64"
	else
		echo >&2 'Architecture not supported' && exit 1
	fi
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"
	platform="$3"
	arch="$4"

	url="$GH_REPO/releases/download/v${version}/${TOOL_NAME}-${platform}-${arch}"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="$3"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path/bin/"
		chmod +x "$ASDF_DOWNLOAD_PATH/$TOOL_NAME"
		cp "$ASDF_DOWNLOAD_PATH/$TOOL_NAME" "$install_path/bin/"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error ocurred while installing $TOOL_NAME $version."
	)
}
