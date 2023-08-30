EXTENSION = plpy_venv
DATA = plpy_venv--1.0.sql
PGFILEDESC = "Virtual Environments for pl/python3"

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)