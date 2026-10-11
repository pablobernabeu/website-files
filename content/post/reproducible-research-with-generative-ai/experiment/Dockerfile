# The environment of the stored executions: R 4.3.3 and the R packages of
# Ubuntu 24.04, whose archive keeps these versions, with the reference BLAS.
# R and the packages that the scripts and verify_executions.R load are pinned,
# so that a change in the archive fails the build instead of changing them.
# Their dependencies, the BLAS and LAPACK among them, come from the archive at
# build time, and verification_session_info.txt lists the versions of the
# recorded build. Building the image and running it executes every agent
# script and compares its output with executions.csv:
#
#   docker build -t genai-experiment .
#   docker run --rm genai-experiment
#
# The base image is docker.io/library/ubuntu:24.04 at the digest below, which
# was recorded when this file was written on 30 September 2026. Build it from
# this folder. To keep the comparison, as
# .github/workflows/reproduce-genai-experiment.yml does:
#
#   docker run --rm -v "$PWD/verification:/out" genai-experiment \
#     Rscript verify_executions.R /out/verification.csv
#
# The workflow also passes GITHUB_SERVER_URL, GITHUB_REPOSITORY and
# GITHUB_RUN_ID with -e, so that the comparison records the address of its run.
# The build and check take about two minutes on GitHub Actions.

FROM ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3

ENV DEBIAN_FRONTEND=noninteractive LC_ALL=C LANG=C

RUN apt-get update && apt-get install -y --no-install-recommends \
      r-base-core=4.3.3-2build2 \
      r-cran-lme4=1.1-35.1-4 \
      r-cran-lmertest=3.1-3-2 \
      r-cran-matrix=1.6-5-1 \
      r-cran-pbkrtest=0.5.2-2 \
      r-cran-emmeans=1.10.0+dfsg-1 \
      r-cran-dplyr=1.1.4-1 \
      r-cran-tidyr=1.3.1-1 \
      r-cran-callr=3.7.5-1 \
      r-cran-digest=0.6.34-1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /experiment
COPY . .

CMD ["Rscript", "verify_executions.R"]
