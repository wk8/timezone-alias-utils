#!/usr/bin/env python3

from abc import ABC, abstractmethod
from collections import defaultdict
import json
import os
from typing import List

import pytz


class TZAliases(object):
    # useful for tests, to inject an artifical test TZ
    _TEST_TZ_ENV_VAR = 'INCLUDE_TEST_TZ'

    @classmethod
    def groups(cls) -> List[List[str]]:
        """
        Bundles TZs into groups of aliases
        """
        groups = defaultdict(list)

        test_tz_name, test_tz_target = cls._parse_test_tz()

        for tz_name in pytz.all_timezones:
            signature = cls._tz_signature(tz_name)
            groups[signature].append(tz_name)

            if tz_name == test_tz_target:
                groups[signature].append(test_tz_name)

        return [sorted(group) for group in groups.values() if len(group) > 1]

    @classmethod
    def _parse_test_tz(cls):
        raw = os.getenv(cls._TEST_TZ_ENV_VAR)
        if not raw:
            return None, None

        parts = raw.split(':')
        if len(parts) != 2:
            raise ValueError(f'Invalid test TZ: {raw}')

        if parts[1] not in pytz.all_timezones:
            raise ValueError(f'Unknown target test TZ: {parts[1]}')

        return parts

    @staticmethod
    def _tz_signature(tz_name: str):
        tz = pytz.timezone(tz_name)

        # dynamic zones with transitions
        if hasattr(tz, '_tzinfos'):
            keys = tz._tzinfos.keys()

            # each key is (utcoffset, dst, tzname)
            # normalize to simple numeric tuples plus the abbrev string.
            normalized = []
            for offset, dst, abbr in keys:
                normalized.append(
                    (
                        offset.days,
                        offset.seconds,
                        dst.days,
                        dst.seconds,
                        abbr,
                    )
                )
            normalized.sort()

            return ('dynamic', tuple(normalized))

        # static, fixed-offset zones (e.g. Etc/GMT)
        else:
            offset = tz._utcoffset
            tzname_attr = getattr(tz, '_tzname', None)

            return ('static', offset.days, offset.seconds, tzname_attr)


class GroupsRenderer(ABC):
    file_name = 'tz_groups'
    extension = None

    def __init__(self, alias_groups: List[List[str]]):
        self.groups = alias_groups

    @abstractmethod
    def contents(self) -> str:
        """
        Should return the string contents of the file to render
        """
        pass

    def render(self):
        with open(f'{self.file_name}.{self.extension}', 'w') as f:
            f.write(self.contents())


class JsonRenderer(GroupsRenderer):
    extension = 'json'

    def contents(self) -> str:
        return json.dumps(self.groups, indent=4)


class SpaceSeparatedValues(GroupsRenderer):
    """
    Prints one group per line, and all the aliases in the group space-separated on each line
    """

    extension = 'ssv'

    def contents(self) -> str:
        return '\n'.join((' '.join(group) for group in self.groups))


def main():
    groups = TZAliases.groups()

    for renderer in GroupsRenderer.__subclasses__():
        renderer(groups).render()


if __name__ == '__main__':
    main()
