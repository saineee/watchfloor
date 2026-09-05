FROM python:3.12-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app/
COPY alembic ./alembic/
COPY alembic.ini .

RUN useradd user -m

COPY --chown=user entrypoint.sh .
RUN chmod 500 entrypoint.sh

USER user

ENTRYPOINT ["./entrypoint.sh"]
