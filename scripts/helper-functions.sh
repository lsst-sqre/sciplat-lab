#!/bin/sh

RELEASE_BRANCH="main"  # main sciplat-lab branch
## FIXME: take this out after we are past DP2 and have cleaned up everything.
MAGIC_BLESSED_TAG="tickets-DM-55555"

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
    if [ -z "${tag}" ] || ( [ -z "${image}" ] || [ -z "${input}" ] ); then
        echo "required variables: tag, image, input" >&2
        exit 1
    fi

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true )
    if [ -z "${branch}" ]; then
        echo "cannot determine git branch" >&2
        branch="NOGIT"
    fi

    version=$(input_tag_to_version)
    input_tag=$(echo "${input}" | cut -d ':' -f 2)
    tag_type=$(echo ${version} | cut -c 1)
    ## FIXME: remove MAGIC_BLESSED_TAG post-DP2 and cleanup.

    # Determine whether we should force an experimental build.
    # We want to do that so that we cannot, by omitting the
    # "supplementary" parameter, accidentally overwrite an official daily
    # or weekly image that we have built either from a branch of sciplat-lab
    # or from a base image that doesn't have the "latest" tag.
    # Releases and release candidates are protected from
    # overwrite because a unique build number is embedded into their tag.

    # If the branch of sciplat-lab is neither the release branch nor
    # a specified override branch (set externally by the caller in
    # ${OVERRIDE_BRANCH}), the build must be experimental, and the branch
    # forcing it is in ${exp_branch}.
    
    exp_branch=""
    if [ "${branch}" != "${RELEASE_BRANCH}" ] && \
       [ "${branch}" != "${OVERRIDE_BRANCH}" ]; then
        exp_branch="${branch}"
    fi
    # If the tag is of a release type, the build doesn't have to be an
    # experimental.  That's for the case where we have to rebuild an older
    # image with the jupyterlab-base image that was current at the time of
    # the first build.
    #
    # That's OK because all release types (which currently includes release
    # candidates) embed the unique build number, so there is no danger of
    # overwriting.  However, if it is not a release type, then we will force
    # an experimental build if the tag is not "latest".
    #
    # FIXME: We also will allow a non-experimental build if the tag matches
    # ${MAGIC_BLESSED_TAG}.  This is a hack to let us get images out around
    # DP2, and will be removed afterwards as part of our post-release cleanup.
    
    exp_tag=""
    if [ "${tag_type}" != "r" ]; then
        if [ "${input_tag}" != "latest" ] && \
               [ "${input_tag}" != "${MAGIC_BLESSED_TAG}" ]; then
            exp_tag="${input_tag}"
        fi
    fi

    # Put it all together.  If supplementary is already set, we don't need
    # to force anything to experimental, because the user-set supplementary
    # tag trumps everything and we will simply use it.  Nothing with
    # supplementary explicitly set can ever be a non-experimental version.

    # If either the branch or input tag are set to something that should force
    # an experimental build, though, then we need to go through the logic
    # to derive a supplementary tag and force an experimental build.

    if [ -z "${supplementary}" ]; then
        if [ -n "${exp_branch}" ] || [ -n "${exp_tag}" ]; then
            # Prefer tag over branch for setting the supplementary tag.
            discriminator=""
            if [ -n "${exp_tag}" ]; then
                discriminator="${exp_tag}"
            else
                discriminator="${exp_branch}"
            fi

            supplementary=$( echo ${discriminator} | tr -c -d \[A-z\]\[0-9\] )

            if [ -z "${supplementary}" ]; then
                # This shouldn't happen.  If we can get here it's a bug I
                # didn't spot in the logic.
                supplementary="experimental"
            fi
        fi
    fi
    if [ -n "${supplementary}" ]; then
        version="exp_${version}_${supplementary}"
        supplementary=""
        # Clear supplementary for help with testing, where we might run this
        # multiple times in the same shell; it will never matter in real
        # life.
    fi

    # Recalculate tag type, because we might have just forced an experimental.
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
            echo ${version} | grep -q "rc"
            rc=$?
            if [ ${rc} != 0 ]; then
                ltype="latest_release"
                latest="latest"
            fi
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
