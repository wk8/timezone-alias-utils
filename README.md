# timezone-alias-utils

## Why?

The official timezone database gets updated all the time, with new TZes being added, and others deprecated.

Unfortunately, the TZ DBs that run with our app code might not be trivial to update: sometimes it's baked into the runtime (e.g. node); or even if it's easy to update, it might remove deprecated TZs when it's not necessarily practical to update old TZs in the app DB to their new name.

This aims to provide a collection of easy-to-use scripts that you can include in your Dockerfiles to keep your TZ DBs both up-to-date and with old deprecated aliases still around.

## How?

It uses [pytz](https://pypi.org/project/pytz/) to compile a list of TZ aliases, including deprecated ones.

Then there are several "flavors" that you can use in your Dockerfile, that have that list of aliases baked in, and are all designed to be as unobtrusive as possible:

### node

Most node docker images come with their own version of the ICU DB baked in. We provide a shim that's auto-loaded at run time: just add
```dockerfile
COPY --from=wk88/timezone-alias-utils:wkpo-node /tz/generate_tz_shim.sh /tmp/generate_tz_shim.sh
RUN /tmp/generate_tz_shim.sh
```
to your dockerfile.

### tzdata

Same idea: we provide a single POSIX-compliant shell script that will symlink new or deprecated time zones:
```dockerfile
COPY --from=wk88/timezone-alias-utils:wkpo-tzdata /tz/create_tz_symlinks.sh /tmp/create_tz_symlinks.sh
RUN /tmp/create_tz_symlinks.sh
```

### Want another flavor?

This design is easily extensible, and I always welcome PRs. Just please make sure to add tests by following the existing test structure.
