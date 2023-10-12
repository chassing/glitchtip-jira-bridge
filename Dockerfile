FROM registry.access.redhat.com/ubi9/ubi-minimal:9.2 as base-python
ENV PYTHONUNBUFFERED=1
RUN microdnf upgrade -y && \
    microdnf install -y \
        shadow-utils \
        python3.11 && \
    microdnf clean all && \
    update-alternatives --install /usr/bin/python3 python /usr/bin/python3.11 1 && \
    ln -snf /usr/bin/python3.11 /usr/bin/python && \
    python3 -m ensurepip

# ---- Interims image to get and build all the python dependencies ----
FROM base-python as build-python
ENV POETRY_HOME=/opt/poetry \
    POETRY_VIRTUALENVS_CREATE=false \
    PIP_DISABLE_PIP_VERSION_CHECK=on

WORKDIR /code

# install poetry
RUN python3 - < <(curl -sSL https://install.python-poetry.org)

# install the dependencies
RUN microdnf install -y \
        libcurl-devel \
        openssl-devel \
        gcc \
        python3.11-devel

# required for poetry to install the dependencies
COPY pyproject.toml poetry.lock README.md /code/

# the code
COPY glitchtip_jira_bridge /code/glitchtip_jira_bridge/
COPY app.sh /code/

# install the python dependencies
RUN $POETRY_HOME/bin/poetry install --no-interaction --no-ansi --only main

# ---- Bundle everything together in the final image ----
FROM base-python as release
EXPOSE 8080
WORKDIR /code

RUN microdnf install -y \
    libcurl-minimal \
    && microdnf clean all

# get all the python dependencies from the build-python stage
COPY --from=build-python /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
COPY --from=build-python /usr/local/lib64/python3.11/site-packages/ /usr/local/lib64/python3.11/site-packages/
COPY --from=build-python /usr/local/bin/ /usr/local/bin/
COPY --from=build-python /code/ /code/

RUN useradd -u 5000 app && chown -R app:app /code
USER app:app

CMD ["/code/app.sh"]
