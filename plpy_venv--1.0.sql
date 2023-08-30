--
-- Create a virtual environment
--
CREATE OR REPLACE FUNCTION @extschema@.create_venv(name text DEFAULT 'venv')
    RETURNS text
    LANGUAGE plpython3u
AS $BODY$
    import os
    import shutil
    import sys

    from virtualenv.run import cli_run

    # Get the data directory
    res = plpy.execute("SELECT setting FROM pg_settings WHERE name = 'data_directory'")
    data_dir = res[0]['setting']
    venvs_dir = os.path.join(data_dir, 'venvs')
    venv_dir = os.path.join(venvs_dir, name)

    # Check for traversal attacks
    if os.path.commonprefix((os.path.realpath(venv_dir), venvs_dir)) != venvs_dir:
        plpy.error('Invalid virtual environment name: {}.'.format(name))

    if not os.path.exists(venvs_dir):
        os.makedirs(venvs_dir)

    if sys.platform in ('win32', 'win64', 'cygwin'):
        python_bin = os.path.join(sys.base_prefix, 'Scripts', 'python.exe')
    else:
        python_bin = os.path.join(sys.base_prefix, 'bin', 'python3')


    if not os.path.exists(venv_dir):
        cli_run(['-p', python_bin, venv_dir])
    else:
        plpy.error('Virtual environment directory {} already exists.'.format(venv_dir))

    return venv_dir
$BODY$;

REVOKE ALL PRIVILEGES ON FUNCTION @extschema@.create_venv(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION @extschema@.create_venv(text) TO CURRENT_USER;
COMMENT ON FUNCTION @extschema@.create_venv(text) IS 'Create a Python virtual environment (default name: venv).';


--
-- Activate a virtual environment
--
CREATE OR REPLACE FUNCTION @extschema@.activate_venv(name text DEFAULT 'venv')
    RETURNS boolean
    LANGUAGE plpython3u
AS $BODY$
    import os
    import sys

    # Get the data directory
    res = plpy.execute("SELECT setting FROM pg_settings WHERE name = 'data_directory'")
    data_dir = res[0]['setting']
    venvs_dir = os.path.join(data_dir, 'venvs')
    venv_dir = os.path.join(venvs_dir, name)

    # Check for traversal attacks
    if os.path.commonprefix((os.path.realpath(venv_dir), venvs_dir)) != venvs_dir:
        plpy.error('Invalid virtual environment name: {}.'.format(name))

    if sys.platform in ('win32', 'win64', 'cygwin'):
        activate_this = os.path.join(venv_dir, 'Scripts', 'activate_this.py')
    else:
        activate_this = os.path.join(venv_dir, 'bin', 'activate_this.py')

    try:
        exec(open(activate_this).read(), dict(__file__=activate_this))
    except FileNotFoundError:
        plpy.error('Virtual environment {} does not exist.'.format(name))

    return True
$BODY$;

REVOKE ALL PRIVILEGES ON FUNCTION @extschema@.activate_venv(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION @extschema@.activate_venv(text) TO CURRENT_USER;
COMMENT ON FUNCTION @extschema@.activate_venv(text) IS 'Activate a Python virtual environment (default name: venv).';


--
-- Delete a virtual environment
--
CREATE OR REPLACE FUNCTION @extschema@.delete_venv(name text)
    RETURNS boolean
    LANGUAGE plpython3u
AS $BODY$
    import os
    import pathlib
    import shutil
    import sys

    # Get the data directory
    res = plpy.execute("SELECT setting FROM pg_settings WHERE name = 'data_directory'")
    data_dir = res[0]['setting']
    venvs_dir = os.path.join(data_dir, 'venvs')
    venv_dir = os.path.join(venvs_dir, name)

    # Check for traversal attacks
    if os.path.commonprefix((os.path.realpath(venv_dir), venvs_dir)) != venvs_dir:
        plpy.error('Invalid virtual environment name: {}.'.format(name))

    # Is this venv active?
    if sys.prefix != sys.base_prefix and sys.prefix == venv_dir:
        plpy.error('Virtual environment {} is currently active.'.format(name))

    dir = pathlib.Path(venv_dir)

    try:
        shutil.rmtree(dir)
    except FileNotFoundError:
        plpy.error('Virtual environment {} does not exist.'.format(name))

    return True
$BODY$;

REVOKE ALL PRIVILEGES ON FUNCTION @extschema@.delete_venv(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION @extschema@.delete_venv(text) TO CURRENT_USER;
COMMENT ON FUNCTION @extschema@.delete_venv(text) IS 'Delete a Python virtual environment.';


--
-- Return the active virtual environment
--
CREATE OR REPLACE FUNCTION @extschema@.current_venv()
    RETURNS text
    LANGUAGE plpython3u
AS $BODY$
    import pathlib
    import sys

    if sys.prefix == sys.base_prefix:
        return None
    else:
        return pathlib.PurePath(sys.prefix).name
$BODY$;

REVOKE ALL PRIVILEGES ON FUNCTION @extschema@.current_venv() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION @extschema@.current_venv() TO CURRENT_USER;
COMMENT ON FUNCTION @extschema@.current_venv() IS 'Return the path to the active Python virtual environment.';


--
-- Install packages using PIP
--
CREATE OR REPLACE FUNCTION @extschema@.pip_install(packages text[])
    RETURNS boolean
    LANGUAGE plpython3u
AS $BODY$
    import os
    import subprocess
    import sys

    if sys.prefix == sys.base_prefix:
        plpy.error('No virtual environment is currently active.')

    if sys.platform in ('win32', 'win64', 'cygwin'):
        pip = os.path.join(sys.prefix, 'Scripts', 'pip.exe')
    else:
        pip = os.path.join(sys.prefix, 'bin', 'pip')

    proc = subprocess.Popen([pip, 'install'] + packages, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = proc.communicate()

    if out.decode('utf8') != '':
        plpy.notice(out.decode('utf8'))

    if proc.returncode != 0:
        if err is not None:
            plpy.error('Installation error {}:\n{}'.format(proc.returncode, err.decode('utf8')))
        else:
            plpy.error('Installation error {}.'.format(proc.returncode))

    return True
$BODY$;

REVOKE ALL PRIVILEGES ON FUNCTION @extschema@.pip_install(text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION @extschema@.pip_install(text[]) TO CURRENT_USER;
COMMENT ON FUNCTION @extschema@.pip_install(text[]) IS 'Install packages into the active Python virtual environment.';


--
-- Upgrade packages using PIP
--
CREATE OR REPLACE FUNCTION @extschema@.pip_upgrade(packages text[])
    RETURNS boolean
    LANGUAGE plpython3u
AS $BODY$
    import os
    import subprocess
    import sys

    if sys.prefix == sys.base_prefix:
        plpy.error('No virtual environment is currently active.')

    if sys.platform in ('win32', 'win64', 'cygwin'):
        pip = os.path.join(sys.prefix, 'Scripts', 'pip.exe')
    else:
        pip = os.path.join(sys.prefix, 'bin', 'pip')

    proc = subprocess.Popen([pip, 'install', '--upgrade'] + packages, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = proc.communicate()

    if out.decode('utf8') != '':
        plpy.notice(out.decode('utf8'))

    if proc.returncode != 0:
        if err is not None:
            plpy.error('Upgrade error {}:\n{}'.format(proc.returncode, err.decode('utf8')))
        else:
            plpy.error('Upgrade error {}.'.format(proc.returncode))

    return True
$BODY$;

REVOKE ALL PRIVILEGES ON FUNCTION @extschema@.pip_upgrade(text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION @extschema@.pip_upgrade(text[]) TO CURRENT_USER;
COMMENT ON FUNCTION @extschema@.pip_upgrade(text[]) IS 'Upgrade packages from the active Python virtual environment.';


--
-- Uninstall packages using PIP
--
CREATE OR REPLACE FUNCTION @extschema@.pip_uninstall(packages text[])
    RETURNS boolean
    LANGUAGE plpython3u
AS $BODY$
    import os
    import subprocess
    import sys

    if sys.prefix == sys.base_prefix:
        plpy.error('No virtual environment is currently active.')

    if sys.platform in ('win32', 'win64', 'cygwin'):
        pip = os.path.join(sys.prefix, 'Scripts', 'pip.exe')
    else:
        pip = os.path.join(sys.prefix, 'bin', 'pip')

    proc = subprocess.Popen([pip, 'uninstall', '-y'] + packages, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = proc.communicate()

    if out.decode('utf8') != '':
        plpy.notice(out.decode('utf8'))

    if proc.returncode != 0:
        if err is not None:
            plpy.error('Uninstallation error {}:\n{}'.format(proc.returncode, err.decode('utf8')))
        else:
            plpy.error('Uninstallation error {}.'.format(proc.returncode))

    return True
$BODY$;

REVOKE ALL PRIVILEGES ON FUNCTION @extschema@.pip_uninstall(text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION @extschema@.pip_uninstall(text[]) TO CURRENT_USER;
COMMENT ON FUNCTION @extschema@.pip_uninstall(text[]) IS 'Uninstall packages from the active Python virtual environment.';


--
-- List installed packages using PIP
--
CREATE OR REPLACE FUNCTION @extschema@.pip_freeze()
    RETURNS text[]
    LANGUAGE plpython3u
AS $BODY$
    import os
    import subprocess
    import sys

    if sys.prefix == sys.base_prefix:
        plpy.error('No virtual environment is currently active.')

    if sys.platform in ('win32', 'win64', 'cygwin'):
        pip = os.path.join(sys.prefix, 'Scripts', 'pip.exe')
    else:
        pip = os.path.join(sys.prefix, 'bin', 'pip')

    proc = subprocess.Popen([pip, 'freeze'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = proc.communicate()

    if out.decode('utf8') != '':
        return out.decode('utf8').strip().split('\n')

    if proc.returncode != 0:
        if err is not None:
            plpy.error('Freeze error {}:\n{}'.format(proc.returncode, err.decode('utf8')))
        else:
            plpy.error('Freeze error {}.'.format(proc.returncode))

    return []
$BODY$;

REVOKE ALL PRIVILEGES ON FUNCTION @extschema@.pip_freeze() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION @extschema@.pip_freeze() TO CURRENT_USER;
COMMENT ON FUNCTION @extschema@.pip_freeze() IS 'List packages installed in the active Python virtual environment in requirements format.';