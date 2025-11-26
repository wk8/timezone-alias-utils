import pytest

from conftest import build_docker_image

NODE_VERSIONS = ['10', '12', '14', '16', '18', '20', '22', '24']


@pytest.mark.parametrize('node_version', NODE_VERSIONS, ids=lambda v: f'node-{v}')
def test_node_shim(build_docker_image, node_version: str):
    out = build_docker_image(build_files=['test.js'], extra_build_args={'NODE_VERSION': node_version})

    lines = out.splitlines()
    assert len(lines) >= 4

    assert lines[0] == '0'
    assert lines[1] == '-480'
    assert lines[2] == '120'
    assert 'unsupported time zone' in lines[3].lower() or 'invalid time zone' in lines[3].lower()
