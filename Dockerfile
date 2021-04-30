FROM python:3.9-slim
ENV LANG=C.UTF-8 TZ=UTC LC_ALL=C.UTF-8 PYTHONUNBUFFERED=1 PYTHONPATH=/app PYTHONWARNINGS="ignore:Unverified HTTPS request"

WORKDIR /
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
RUN rm requirements.txt

COPY . /
WORKDIR /app
