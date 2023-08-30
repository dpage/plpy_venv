# plpy_venv

plpy_venv is a simple PostgreSQL extension for managing Python virtual environments for use by pl/python3 in PostgreSQL.

**WARNING**: This is proof of concept code! Do **NOT** deploy it into production.

## Installation

This extension uses PGXS for its build system. Currently there is no support
for VC++ on Windows. To build/install, ensure that `pg_config` is in the path,
and run `make install` to build the code and install it:

```bash
$ PATH=/path/to/postgresql/bin make install
```

On Windows, manually copy the *plpy_venv.control* and *plpy_venv--1.0.sql* files into the extension installation 
directory on the server, e.g. *\<PGINSTDIR\>\share\extension*

Create the extension in whatever database you want to use virtual environments:

```sql
plpy=# CREATE EXTENSION plpy_venv CASCADE;
NOTICE:  installing required extension "plpython3u"
CREATE EXTENSION
```

## Usage

### Create a virtual environment

```sql
plpy=# SELECT plpy_venv.create_venv('myvenv');
create_venv              
---------------------------------------
 /path/to/postgresql/data/venvs/myvenv
(1 row)
```

Note that the return value from the function is the actual path on the system to the virtual environment. Virtual 
environments are created in the PostgreSQL data directory, under a new *venvs* directory.

If you try to create a virtual environment that appears to already exist, an error is thrown:

```sql
plpy=# SELECT plpy_venv.create_venv('myvenv');
ERROR:  plpy.Error: Virtual environment directory /path/to/postgresql/data/venvs/myvenv already exists.
CONTEXT:  Traceback (most recent call last):
  PL/Python function "create_venv", line 30, in <module>
    plpy.error('Virtual environment directory {} already exists.'.format(venv_dir))
PL/Python function "create_venv"
```

### Activate a virtual environment

> **_NOTE:_** 
> 
> When a virtual environment is activated, it applies to the current session only. It is not currently 
> possible to de-activate a virtual environment without closing the connection to the database (which may not actually
> work if using a connection pooler). You can activate an alternate virtual environment.

```sql
plpy=# SELECT plpy_venv.activate_venv('myvenv');
activate_venv 
---------------
 t
(1 row)
```

Attempting to activate a virtual environment that doesn't exist will result in an error:

```sql
plpy=# SELECT plpy_venv.activate_venv('does_not_exist');
ERROR:  plpy.Error: Virtual environment does_not_exist does not exist.
CONTEXT:  Traceback (most recent call last):
  PL/Python function "activate_venv", line 23, in <module>
    plpy.error('Virtual environment {} does not exist.'.format(venv_dir))
PL/Python function "activate_venv"
```

### Delete a virtual environment

```sql
plpy=# SELECT plpy_venv.delete_venv('myvenv');
 delete_venv 
-------------
 t
(1 row)
```

An error is thrown if an attempt is made to delete the currently active virtual environment, or one that does not exist:

```sql
plpy=# SELECT plpy_venv.delete_venv('myvenv');
ERROR:  plpy.Error: Virtual environment myvenv is currently active.
CONTEXT:  Traceback (most recent call last):
  PL/Python function "delete_venv", line 19, in <module>
    plpy.error('Virtual environment {} is currently active.'.format(venv_dir))
PL/Python function "delete_venv"
```

```sql
plpy=# SELECT plpy_venv.delete_venv('does_not_exist');
ERROR:  plpy.Error: Virtual environment does_not_exist does not exist.
CONTEXT:  Traceback (most recent call last):
  PL/Python function "delete_venv", line 26, in <module>
    plpy.error('Virtual environment {} does not exist.'.format(name))
PL/Python function "delete_venv"
```

### Determine the active virtual environment

```sql
plpy=# SELECT plpy_venv.current_venv();
 current_venv 
--------------
 myvenv
(1 row)
```

If no virtual environment is currently active, NULL is returned:

```sql
plpy=# SELECT plpy_venv.current_venv();
 current_venv 
--------------
 
(1 row)
```

## Install packages into a virtual environment using PIP

```sql
plpy=# SELECT plpy_venv.pip_install('{"numpy", "pandas"}');
NOTICE:  Collecting numpy
  Using cached numpy-1.25.2-cp311-cp311-macosx_11_0_arm64.whl (14.0 MB)
Collecting pandas
  Downloading pandas-2.1.0-cp311-cp311-macosx_11_0_arm64.whl (11.2 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 11.2/11.2 MB 20.1 MB/s eta 0:00:00
Collecting python-dateutil>=2.8.2
  Using cached python_dateutil-2.8.2-py2.py3-none-any.whl (247 kB)
Collecting pytz>=2020.1
  Using cached pytz-2023.3-py2.py3-none-any.whl (502 kB)
Collecting tzdata>=2022.1
  Using cached tzdata-2023.3-py2.py3-none-any.whl (341 kB)
Collecting six>=1.5
  Using cached six-1.16.0-py2.py3-none-any.whl (11 kB)
Installing collected packages: pytz, tzdata, six, numpy, python-dateutil, pandas
Successfully installed numpy-1.25.2 pandas-2.1.0 python-dateutil-2.8.2 pytz-2023.3 six-1.16.0 tzdata-2023.3

 pip_install 
-------------
 
(1 row)
```

Note that the input parameter to *pip_install()* is an array of one or more Python package requirement specifiers, for
example, *"PackageName"*, *"PackageName==1.2.3"*, *"PackageName>=1.2.0"* and so on.

If an attempt is made to install a package that does not exist, an error is thrown:

```sql
plpy=# SELECT plpy_venv.pip_install('{"does_not_exist"}');
ERROR:  plpy.Error: Installation error 1:
ERROR: Could not find a version that satisfies the requirement does_not_exist (from versions: none)
ERROR: No matching distribution found for does_not_exist

CONTEXT:  Traceback (most recent call last):
  PL/Python function "pip_install", line 22, in <module>
    plpy.error('Installation error {}:\n{}'.format(proc.returncode, err.decode('utf8')))
PL/Python function "pip_install"
```


## Upgrade packages in a virtual environment using PIP

```sql
plpy=# SELECT plpy_venv.pip_upgrade('{"pip"}');
NOTICE:  Requirement already satisfied: pip in ./venvs/myvenv/lib/python3.11/site-packages (22.3.1)
Collecting pip
  Downloading pip-23.2.1-py3-none-any.whl (2.1 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 2.1/2.1 MB 4.0 MB/s eta 0:00:00
Installing collected packages: pip
  Attempting uninstall: pip
    Found existing installation: pip 22.3.1
    Uninstalling pip-22.3.1:
      Successfully uninstalled pip-22.3.1
Successfully installed pip-23.2.1

 pip_upgrade 
-------------
 t
(1 row)
```


## Uninstall packages into a virtual environment using PIP

```sql
plpy=# SELECT plpy_venv.pip_uninstall('{"numpy", "pandas"}');
NOTICE:  Found existing installation: numpy 1.25.2
Uninstalling numpy-1.25.2:
  Successfully uninstalled numpy-1.25.2
Found existing installation: pandas 2.1.0
Uninstalling pandas-2.1.0:
  Successfully uninstalled pandas-2.1.0

 pip_uninstall 
---------------
 t
(1 row)
```

As with *pip_install()*, the input parameter is an array of package requirement specifiers.

Note that specifying a package that is not installed does not throw an error; it is considered a success because the 
virtual environment will be in the desired state regardless of whether or not the specified package was installed or
not.

## List packages installed in the active Python virtual environment in requirements format

```sql
plpy=# SELECT plpy_venv.pip_freeze();
pip_freeze                                          
----------------------------------------------------------------------------------------------
 {numpy==1.25.2,pandas==2.1.0,python-dateutil==2.8.2,pytz==2023.3,six==1.16.0,tzdata==2023.3}
(1 row)
```