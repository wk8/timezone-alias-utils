from conftest import build_docker_image


def test_symlinks(build_docker_image):
    out = build_docker_image(build_files=['test.sh'])

    assert out == '''/usr/share/zoneinfo/America/Los_Angeles
/usr/share/zoneinfo/Europe/Berlin
'''
