ARG IMAGE_NAME
ARG TAG_PREFIX

###

FROM ${IMAGE_NAME}:${TAG_PREFIX}-tzdata AS tzdata-base

###

FROM ubuntu:24.04

ARG BASE_TEST_TZ_NAME
ENV BASE_TEST_TZ_NAME=${BASE_TEST_TZ_NAME}

RUN apt update && apt install -y tzdata

RUN printf 'another/weirdtz Europe/Berlin' > /tmp/extra_tzs.txt

COPY --from=tzdata-base /tz/create_tz_symlinks.sh /tmp/create_tz_symlinks.sh

RUN /tmp/create_tz_symlinks.sh /tmp/extra_tzs.txt

ARG OUT_FILE

COPY test.sh .

RUN bash test.sh > ${OUT_FILE}
