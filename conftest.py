import os
import pathlib
import random
import shutil
import string
import subprocess
import tempfile
from typing import Dict, List

import pytest
from _pytest.fixtures import FixtureRequest

IMAGE_NAME = 'tz-alias-test'
TAG_PREFIX = 'test'

BASE_TEST_TZ_NAME = 'testtz/illneverexist'
BASE_TEST_TZ_TARGET = 'America/Los_Angeles'

FIXTURE_DIRECTORY = 'test_fixtures'


@pytest.fixture(scope='session', autouse=True)
def setup_once():
    subprocess.check_output(
        ['make', 'build'],
        env=docker_build_env_for_tests(),
    )


def docker_build_env_for_tests():
    env = os.environ.copy()

    env['WITH_BASE_TEST_TZ'] = f'{BASE_TEST_TZ_NAME}:{BASE_TEST_TZ_TARGET}'
    env['IMAGE_NAME'] = IMAGE_NAME
    env['TAG_PREFIX'] = TAG_PREFIX

    return env


@pytest.fixture
def fixture_path(request: FixtureRequest):
    test_file_path = pathlib.Path(request.fspath).resolve()
    test_dir = test_file_path.parent

    def inner(*rel_path: str) -> str:
        return os.path.join(test_dir, FIXTURE_DIRECTORY, *rel_path)

    return inner


@pytest.fixture
def fixture_content(fixture_path):
    def inner(*rel_path: str) -> str:
        path = fixture_path(*rel_path)
        with open(path, 'r', encoding='utf-8') as file:
            return file.read()

    return inner


# returns the tag of the image that was built
@pytest.fixture
def _build_docker_image(fixture_path):
    def inner(dockerfile: str = 'Dockerfile', build_files: List[str] = None,
              extra_build_args: Dict[str, str] = None) -> str:
        with tempfile.TemporaryDirectory() as build_dir:
            def build_path(*sub_path):
                return os.path.join(build_dir, *sub_path)

            files_to_copy = list(build_files) if build_files else []
            files_to_copy.append(dockerfile)

            for file in files_to_copy:
                shutil.copy2(fixture_path(file), build_path(file))

            tag = random_string().lower()

            command = ['docker', 'build',
                       '--file', build_path(dockerfile),
                       '--tag', tag]

            build_args = {
                'IMAGE_NAME': IMAGE_NAME,
                'TAG_PREFIX': TAG_PREFIX,
            }
            build_args.update(extra_build_args or {})

            for key, val in build_args.items():
                command.extend(['--build-arg', f'{key}={val}'])

            command.append(build_dir)

            subprocess.check_output(command)

            return tag

    return inner


@pytest.fixture
def _file_contents_from_docker_image():
    def inner(tag: str, outfile: str) -> str:
        ctr_name = random_string()

        subprocess.check_output(['docker', 'create', '--name', ctr_name, tag])

        tmp_path = None

        try:
            fd, tmp_path = tempfile.mkstemp()
            os.close(fd)

            subprocess.check_output(['docker', 'cp', f'{ctr_name}:{outfile}', tmp_path])

            with open(tmp_path, 'r', encoding='utf-8') as file:
                return file.read()
        finally:
            subprocess.check_output(['docker', 'rm', '--force', ctr_name])

            if tmp_path:
                os.remove(tmp_path)

    return inner


# builds the given docker image, and then copies out the resulting outfile from the built image
# cleans up after it's done.
# all file args except for the outfile are meant as fixture paths relative to the test file.
@pytest.fixture
def build_docker_image(_build_docker_image, _file_contents_from_docker_image):
    def inner(outfile: str = '/tmp/out', **build_kwargs) -> str:
        extra_build_args = build_kwargs.get('extra_build_args', {})
        extra_build_args['BASE_TEST_TZ_NAME'] = BASE_TEST_TZ_NAME
        extra_build_args['OUT_FILE'] = outfile

        build_kwargs['extra_build_args'] = extra_build_args

        tag = _build_docker_image(**build_kwargs)

        try:
            out = _file_contents_from_docker_image(tag, outfile)
            return out
        finally:
            subprocess.check_output(['docker', 'image', 'rm', '--force', tag])

    return inner


def random_string(length: int = 40, prefix: str = 'tz-alias-test-') -> str:
    chars = string.ascii_letters + string.digits
    return prefix + ''.join(random.choice(chars) for _ in range(length))
