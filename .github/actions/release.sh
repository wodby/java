#!/usr/bin/env bash

# Version aliases identify published releases; only primary tags publish images.
if [[ "${GITHUB_REF:-}" =~ ^refs/tags/.+-r[0-9]+$ ]]; then
    exit 0
fi

set -ex

if [[ "${GITHUB_REF}" == refs/heads/master || "${GITHUB_REF}" == refs/tags/* ]]; then
  tag="${JAVA_VER%%.*}"

  if [[ -n "${JAVA_DEV}" ]]; then
    if [[ "${WODBY_USER_ID}" == "501" ]]; then
      tag="${tag}-dev-macos"
    else
      tag="${tag}-dev"
    fi
  fi

  tags=("${tag}")

  if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
    image_revision="${GITHUB_REF##*/}"
    tags=("${tag}-${image_revision}")
  elif [[ -n "${LATEST}" ]]; then
    if [[ -z "${JAVA_DEV}" ]]; then
      tags+=("latest")
    elif [[ "${WODBY_USER_ID}" == "501" ]]; then
      tags+=("dev-macos")
    else
      tags+=("dev")
    fi
  fi

  for tag in "${tags[@]}"; do
    make buildx-imagetools-create IMAGETOOLS_TAG=${tag}
  done
fi
