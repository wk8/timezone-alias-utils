ARG BASE_NAME
ARG BASE_TAG

FROM ${BASE_NAME}:${BASE_TAG} AS base

###

FROM alpine AS builder

WORKDIR /tz

COPY --from=base /tz/tz_groups.ssv .
COPY create_symlinks.sh create_tz_symlinks.sh

RUN cat tz_groups.ssv >> create_tz_symlinks.sh
RUN printf '\nEOF\n\nrm "$0"\n' >> create_tz_symlinks.sh

RUN chmod +x create_tz_symlinks.sh

###

FROM scratch

WORKDIR /tz

COPY --from=builder /tz/create_tz_symlinks.sh .
