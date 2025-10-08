sciplat-lab
===========

This produces the two-stack RSP container.
The payload stack is the Rubin Data Management pipeline.

To build the container, use the [GitHub Action](./github/workflows/build.yaml).
If you do not want the container pushed, set the `push` parameter to a JSON `false` value.

If you want to build the container locally, run `docker build` or `docker buildx build` with the `ARGS` for `tag`, `input`, and `version` set.
In that case, `tag` is the tag on the input container to use, and `version` is the resolved tag with any supplementary version embedded, with a build number for release and release candidate builds set, and so on.
To calculate the version from the tag, set `tag`, `image`, and `supplementary` in the environment, source the [helper functions](./scripts/helper-functions.sh), and use the output of `calculate_tags | cut -d ',' -f 1`.
