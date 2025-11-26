ARG PY_VERSION=3.14

FROM python:${PY_VERSION} AS builder

# see https://pypi.org/project/pytz/#history
ARG PYTZ_VERSION=2025.2

RUN pip install pytz==${PYTZ_VERSION}

WORKDIR /tz

COPY tz_groups.py .

ARG WITH_TEST_TZ=
ENV INCLUDE_TEST_TZ=${WITH_TEST_TZ}

RUN ./tz_groups.py

RUN rm ./tz_groups.py

###

FROM scratch

COPY --from=builder /tz /tz

WORKDIR /tz
