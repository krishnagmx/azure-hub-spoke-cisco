FROM python:3.12-alpine3.20
RUN addgroup -S app && adduser -S app -G app
WORKDIR /srv
COPY --chown=app:app server.py ./server.py
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2)"
CMD ["python", "-u", "server.py"]
