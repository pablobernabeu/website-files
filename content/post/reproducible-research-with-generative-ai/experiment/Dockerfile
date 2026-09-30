# The environment of the stored executions: R 4.3.3 and the R packages of
# Ubuntu 24.04, whose archive keeps these versions, with the reference BLAS.
# The versions are pinned so that a change in the archive fails the build
# instead of changing the environment. Building the image and running it
# executes every agent script and compares its output with executions.csv:
#
#   docker build -t genai-experiment .
#   docker run --rm genai-experiment

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
