FROM public.ecr.aws/lambda/python:3.13

# install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# copy pyproject.toml and install dependencies
COPY pyproject.toml ${LAMBDA_TASK_ROOT}/
RUN uv sync

# copy handler code
COPY handler.py ${LAMBDA_TASK_ROOT}/

# set PYTHONPATH to include the virtual environment
ENV PYTHONPATH=${LAMBDA_TASK_ROOT}/.venv/lib/python3.13/site-packages

# set the CMD to your handler
CMD ["exif_handler"]
