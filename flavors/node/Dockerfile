ARG BASE_NAME
ARG BASE_TAG

FROM ${BASE_NAME}:${BASE_TAG} AS base

###

FROM alpine AS builder

WORKDIR /tz

COPY --from=base /tz/tz_groups.json .
COPY generate_shim.sh generate_tz_shim_tail.sh

RUN printf "#!/bin/sh\nexport TZ_GROUPS='" > generate_tz_shim.sh

RUN cat tz_groups.json >> generate_tz_shim.sh

RUN printf "'\n\n" >> generate_tz_shim.sh

RUN cat generate_tz_shim_tail.sh >> generate_tz_shim.sh

RUN chmod +x generate_tz_shim.sh

###

FROM scratch

WORKDIR /tz

COPY --from=builder /tz/generate_tz_shim.sh .
