"""Helper to setup the environment for MXL development"""

import argparse
import os
import platform
import shlex
import shutil
import signal
import subprocess
import tempfile
import pathlib
from sys import exit

from .triplet import triplet, triplet_static


class BuildModeAction(argparse.Action):
    """Validate the build mode provided by the command line"""
    def __call__(self, parser, namespace, values, option_string=None):
        if values != "debug" and values != "release":
            print("Got value:", values)
            raise ValueError("Not a valid build mode!")
        setattr(namespace, self.dest, values)


def prepend_env_var(env, var, value):
    """Add the given Variable with the Value to the environment. If the value already exists, it will be prepended to the existing Variable."""
    if var is None:
        return
    env_val = env.get(var, '')
    val = os.pathsep + value + os.pathsep
    # Don't add the same value twice
    if val in env_val or env_val.startswith(value + os.pathsep):
        return
    env[var] = val + env_val
    env[var] = env[var].replace(os.pathsep + os.pathsep, os.pathsep).strip(os.pathsep)


def get_mxl_env(options, prefix_path):
    """Create a copy of the environment and set up all MXL specific values"""
    env = os.environ.copy()

    triplet_ = triplet()
    vcpkg_install_path = f'{prefix_path}/vcpkg_installed/{triplet_}'

    if os.path.isdir(vcpkg_install_path):
        if options.vcpkg_debug:
            vcpkg_install_lib_path = f'{vcpkg_install_path}/debug/lib'
            vcpkg_install_plugins_path = f'{vcpkg_install_path}/debug/plugins'
        else:
            vcpkg_install_lib_path = f'{vcpkg_install_path}/lib'
            vcpkg_install_plugins_path = f'{vcpkg_install_path}/plugins'

        mxl_env_paths = {
            'PKG_CONFIG_PATH': [f'{vcpkg_install_lib_path}/pkgconfig'],
            'GST_PLUGIN_PATH_1_0': [f'{vcpkg_install_plugins_path}/gstreamer',
                                f'{vcpkg_install_lib_path}/gstreamer-1.0'],
            'GST_PRESET_PATH': [f'{vcpkg_install_path}/share/gstreamer-1.0/presets'],
            'GST_ENCODING_TARGET_PATH': [f'{vcpkg_install_path}/share/gstreamer-1.0/encoding-profiles'],
            'GST_PLUGIN_SYSTEM_PATH_1_0': ['/usr/lib/gstreamer-1.0',
                                        '/usr/lib64/gstreamer-1.0',
                                        '/usr/local/lib/gstreamer-1.0',
                                        '/usr/local/lib64/gstreamer-1.0'],
        }

        # Backup PATH for possible later restoration to system defaults
        env["SYSTEM_DEFAULT_PATH"] = env["PATH"]

        env["VCPKG_INSTALL_PATH"] = vcpkg_install_path
        env["VCPKG_INSTALL_LIB_PATH"] = vcpkg_install_lib_path
        env["VCPKG_INSTALL_PLUGINS_PATH"] = vcpkg_install_plugins_path

        env["MXL_VCPKG_TRIPLET"] = triplet()
        env["GSETTINGS_SCHEMA_DIR"] = os.path.normpath(f"{vcpkg_install_path}/share/glib-2.0/schemas")
        env["GST_PLUGIN_SCANNER"] = os.path.normpath(f"{vcpkg_install_path}/tools/gstreamer/gst-plugin-scanner")

        for name, values in mxl_env_paths.items():
            for value in reversed(values):
                if value:
                    prepend_env_var(env, name, value)

        with os.scandir(f'{prefix_path}/vcpkg_installed/{triplet_static()}/tools') as dir_it:
            for entry in dir_it:
                if entry.is_dir():
                    prepend_env_var(env, "PATH", entry.path)
                    entry_bin_dir = pathlib.Path(entry.path).joinpath('bin')
                    if entry_bin_dir.is_dir():
                        prepend_env_var(env, "PATH", entry_bin_dir.as_posix())
        with os.scandir(f'{vcpkg_install_path}/tools') as dir_it:
            for entry in dir_it:
                if entry.is_dir():
                    prepend_env_var(env, "PATH", entry.path)
                    entry_bin_dir = pathlib.Path(entry.path).joinpath('bin')
                    if entry_bin_dir.is_dir():
                        prepend_env_var(env, "PATH", entry_bin_dir.as_posix())

        res = subprocess.run('pkg-config gdk-pixbuf-2.0 --variable=gdk_pixbuf_binary_version', shell = True, text = True, capture_output = True, check = False, env = env)
        if res.returncode == 0:
            gdb_pixbuf_version = res.stdout.strip()
            env['GDK_PIXBUF_MODULE_FILE'] = os.path.normpath(f'{vcpkg_install_path}/lib/gdk-pixbuf-2.0/{gdb_pixbuf_version}/loaders.cache')

    return env


def setup_mxl_env(root_dir):
    """Parse the command line, prepare the environment and print it or enter the build environment"""
    parser = argparse.ArgumentParser(description='Setup mxl environment')
    parser.add_argument('--print-env', dest='print', action=argparse.BooleanOptionalAction, default=False, help='Only print env and exit')
    parser.add_argument('--export-print-env', dest='export_env', action=argparse.BooleanOptionalAction, default=True, help='Add export statement for each environment variable')
    parser.add_argument('--print-rust-analyzer-env', dest='export_rust_analyzer', action=argparse.BooleanOptionalAction, default=False, help='Export JSON configuration for rust-analyzer')
    parser.add_argument('--print-task-env', dest='export_task_env', action=argparse.BooleanOptionalAction, default=False, help='Export JSON configuration for vscode build task')
    parser.add_argument('--vcpkg-debug', dest='vcpkg_debug', action=argparse.BooleanOptionalAction, default=False, help='Use VCPKG debug libraries')
    # options = parser.parse_args()
    options, args = parser.parse_known_args()

    if os.name == 'nt':
        raise ValueError("Windows is not supported, please implement me!")

    env = get_mxl_env(options, root_dir)

    if not args and os.name != 'nt':
        args = [os.environ.get("SHELL", os.path.realpath("/bin/sh"))]

    # Remove incompatible BASH_FUNC definitions in bash shells:
    if args[0].endswith('bash'):
        keys = []
        for key in env.keys():
            if key.startswith('BASH_FUNC'):
                keys += [key]
        for key in keys:
            del env[key]

    if options.export_rust_analyzer:
        orig_env = os.environ
        print('    "rust-analyzer.cargo.extraEnv": {')
        for name, value in env.items():
            if not name in orig_env or orig_env[name] != value:
                print(f'        "{name}": "{shlex.quote(value)}",')
        print('    }')
    elif options.export_task_env:
        orig_env = os.environ
        print('''{
	"version": "2.0.0",
	"tasks": [
		{
			"type": "cargo",
			"command": "build",
			"args": [ "--features=......." ],
			"problemMatcher": [
				"$rustc"
			],
			"group": "build",
			"label": "rust: cargo build",
			"env": {''')
        for name, value in env.items():
            if not name in orig_env or orig_env[name] != value:
                print(f'				"{name}": "{shlex.quote(value)}",')
        print('''			}
		}
	]
}''')
    elif options.print:
        orig_env = os.environ
        for name, value in env.items():
            if not name in orig_env or orig_env[name] != value:
                print(f'{name}={shlex.quote(value)}')
                if options.export_env:
                    print(f'export {name}')
    else:
        if not args and os.name != 'nt':
            args = [os.environ.get("SHELL", os.path.realpath("/bin/sh"))]
        if args[0].endswith('fish'):
            # Ignore SIGINT while using fish as the shell to make it behave like other shells such as bash and zsh.
            # For further information see: https://gitlab.freedesktop.org/gstreamer/gst-build/issues/18
            signal.signal(signal.SIGINT, lambda x, y: True)
            # Set the prompt
            args.append('--init-command')
            prompt_cmd = '''function fish_prompt
                printf '[MXL DEV] %s@%s %s%s%s > ' $USER $hostname \
                    (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
            end'''
            args.append(prompt_cmd)
        elif args[0].endswith('bash'):
            prompt_export = f'export PS1="[MXL DEV] $PS1"'
            tmp_bashrc = tempfile.NamedTemporaryFile(mode='w')
            bashrc = os.path.expanduser('~/.bashrc')
            if os.path.exists(bashrc):
                with open(bashrc, 'r') as src:
                    shutil.copyfileobj(src, tmp_bashrc)
            tmp_bashrc.write('\n' + prompt_export)
            tmp_bashrc.flush()
            args.append("--rcfile")
            args.append(tmp_bashrc.name)
        try:
            exit(subprocess.call(args, close_fds=False, env=env))
        except subprocess.CalledProcessError as err:
            exit(err.returncode)
