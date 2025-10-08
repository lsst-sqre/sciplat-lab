#!/bin/sh

input_tag_to_version() {
    if [ "${tag}" = "" ]; then
        echo "tag cannot be empty" >&2
        exit 1
    fi
    version=${tag}
    first=$(echo "${version}" | cut -c 1)
    if [ "${first}" = "v" ]; then
        version="r$(echo ${version} | cut -c 2-)"
    fi
    first=$(echo "${version}" | cut -c 1)
    if [ "${first}" = "r" ]; then
        build_number=${GITHUB_RUN_NUMBER}
        if [ "${build_number}" = "" ]; then
            build_number=0
        fi
        version="${version}_rsp${build_number}"
    fi
    echo "${version}"
}

calculate_tags() {
    if [ -z "${tag}" ] || [ -z "${image}" ]; then
        echo "required variables: tag, image" >&2
        exit 1
    fi

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || /bin/true )
    if [ -n "${OVERRIDE_BRANCH}" ]; then
        branch="${OVERRIDE_BRANCH}"
    fi
    if [ -z "${branch}" ]; then
        echo "cannot determine git branch" >&2
        branch="NOGIT"
    fi

    release_branch="main"

    version=$(input_tag_to_version)
    if [ "${branch}" != "${release_branch}" ]; then
        if [ -z "${supplementary}" ]; then
            supplementary=$( echo ${branch} | tr -c -d \[A-z\]\[0-9\] )
        fi
    fi
    if [ -n "${supplementary}" ] && \
           [ "${OVERRIDE_BRANCH}" != "${release_branch}" ]; then
        version="exp_${version}_${supplementary}"
    fi
    tag_type=$(echo ${version} | cut -c 1)

    # Experimentals do not get tagged as latest anything.  Dailies,
    #  weeklies, and releases get tagged as latest_<category>.  The
    #  "latest" tag for the lab container should always point to the
    #  latest weekly or release, but not a daily, since we make no
    #  guarantees that the daily is fit for purpose.

    ltype=""
    latest=""
    case ${tag_type} in
        "w")
            ltype="latest_weekly"
            latest="latest"
            ;;
        "r")
            ltype="latest_release"
            latest="latest"
            ;;
        "d")
            ltype="latest_daily"
            ;;
        *)
            ;;
    esac

    tagset="${version}"
    if [ -n "${ltype}" ]; then
        tagset="${tagset},${ltype}"
    fi
    if [ -n "${latest}" ]; then
        tagset="${tagset},${latest}"
    fi
    echo ${tagset}
}
