# Convenience targets for the shared sample FastAPI app.
# Most demos copy this folder in or `cd` into it.

VENV ?= .venv
PY   := $(VENV)/bin/python
PIP  := $(VENV)/bin/pip
IMG  ?= devops-demo-app:local
PORT ?= 8000

.PHONY: help venv install dev run test cov docker docker-run clean

help:
	@echo "Targets: venv install dev run test cov docker docker-run clean"

$(VENV)/bin/activate:
	python3 -m venv $(VENV)

venv: $(VENV)/bin/activate

install: venv
	$(PIP) install -U pip
	$(PIP) install -r requirements.txt

dev: venv
	$(PIP) install -U pip
	$(PIP) install -r requirements-dev.txt

run: install
	$(VENV)/bin/uvicorn app:app --host 0.0.0.0 --port $(PORT) --reload

test: dev
	PYTHONPATH=. $(VENV)/bin/pytest -v tests/

cov: dev
	PYTHONPATH=. $(VENV)/bin/pytest --cov=app --cov-report=term-missing tests/

docker:
	docker build -t $(IMG) .

docker-run: docker
	docker run --rm -p $(PORT):8000 $(IMG)

clean:
	rm -rf $(VENV) .pytest_cache .coverage htmlcov __pycache__ tests/__pycache__
