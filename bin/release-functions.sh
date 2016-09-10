#!/bin/bash

. version-functions.sh

release_main(){
  local mode
  local last
  local version
  local confirm
  local release_commit
  local release_version_prefix
  local branch

  if [ -z "$stage" ]; then
    if [ $# -lt 1 ]; then
      echo 'release_main: usage: release_main <stage> [mode] [version]'
      return
    fi
    stage=$1; shift
  fi

  mode=$1; shift
  last=$1; shift

  if [ -z "$mode" ]; then
    mode=patch
  fi
  if [ -z "$last" ]; then
    release_version_prefix="release:version-"
    last=$(git log --format="%s" --grep="$release_version_prefix" | head -1)
    last=${last#$release_version_prefix}
  fi

  release_commit=$(git log -1 --format="%H")
  branch=$(git symbolic-ref --short HEAD)

  release_check_status

  version_build_next $mode $last

  if [ -n "$branch" ]; then
    if [ "$branch" != master ]; then
      version=${version}.${branch}

      read -p "branch version: $version. OK? [Y/n] " confirm
      case $confirm in
        Y*|y*)
          ;;
        *)
          echo abort
          return
      esac
    fi
  fi
  echo "version: $version"
  read -p "OK? [y/n] " confirm
  case "$confirm" in
    y*)
      echo "version: $version release start..."
      release_pre && git commit --allow-empty -m "$release_version_prefix$version" && git push origin $branch && release_deploy && release_post
      ;;
    *)
      echo "abort"
      exit 1
      ;;
  esac
}
release_check_status(){
  if [ -z "$(git log --remotes="origin" --format="%H" | grep $release_commit)" ]; then
    echo "ローカルの HEAD ($release_commit) が origin に push されていません"
    exit 1
  fi

  echo git fetch --tags --prune
  git fetch -q --tags --prune
  if [ -n "$(git log ${branch}..origin/${branch})" ]; then
    echo "origin に pull していないコミットがあります"
    exit 1
  fi

  if [ -n "$(git status --short)" ]; then
    echo "commit されていない変更が残っています"
    exit 1
  fi
}

release_pre(){
  : # override in release.sh
}
release_post(){
  : # override in release.sh
}
release_deploy(){
  bundle exec cap $stage deploy RELEASE_TAG=$release_commit
}
