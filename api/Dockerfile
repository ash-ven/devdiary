FROM n8nio/n8n:1.123.95

ENV N8N_DISABLE_UI=true \
    N8N_PORT=5679 \
    N8N_LISTEN_ADDRESS=127.0.0.1 \
    N8N_DIAGNOSTICS_ENABLED=false \
    N8N_PERSONALIZATION_ENABLED=false \
    N8N_HIRING_BANNER_ENABLED=false \
    EXECUTIONS_DATA_SAVE_ON_SUCCESS=none \
    GENERIC_TIMEZONE=Europe/Rome \
    TZ=Europe/Rome

COPY --chown=node:node . /opt/devdiary
RUN chmod +x /opt/devdiary/docker/entrypoint.sh \
 && node /opt/devdiary/scripts/build-workflow.js

EXPOSE 10000
ENTRYPOINT ["tini", "--", "/opt/devdiary/docker/entrypoint.sh"]
