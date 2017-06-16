import disquick
import sys

if __name__ == '__main__':
    disquick.Remote.from_manifest_file(sys.argv[1], ssh_user="testuser")
