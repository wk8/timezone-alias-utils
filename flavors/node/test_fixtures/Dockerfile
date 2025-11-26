ARG IMAGE_NAME
ARG TAG_PREFIX

ARG NODE_VERSION

###

FROM ${IMAGE_NAME}:${TAG_PREFIX}-node AS node-base

###

FROM node:${NODE_VERSION}

ARG BASE_TEST_TZ_NAME
ENV BASE_TEST_TZ_NAME=${BASE_TEST_TZ_NAME}

RUN printf '{"another/weirdtz": "Europe/Berlin"}' > /tmp/extra_tzs.json

COPY --from=node-base /tz/generate_tz_shim.sh /tmp/generate_tz_shim.sh

RUN /tmp/generate_tz_shim.sh /tmp/extra_tzs.json

ARG OUT_FILE

COPY test.js .

RUN node test.js > ${OUT_FILE}
