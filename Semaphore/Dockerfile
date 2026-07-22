FROM semaphoreui/semaphore:latest
USER root
RUN apk update && apk add --no-cache aws-cli aws-session-manager-plugin py3-boto3 sudo
USER 1001
