FROM ubuntu:18.04

RUN apt update && \
  apt upgrade -y && \
  apt install -y language-pack-en git python-pip libmysqlclient-dev

RUN mkdir /openedx
RUN git clone https://github.com/edx/edx-notes-api --branch open-release/hawthorn.2 --depth 1 /openedx/edx-notes-api
WORKDIR /openedx/edx-notes-api

RUN pip install -r requirements/base.txt

ENV DJANGO_SETTINGS_MODULE notesserver.settings.universal
RUN ln -s /openedx/config/universal.py notesserver/settings/universal.py

EXPOSE 8000
CMD gunicorn --name notes --bind=0.0.0.0:8000 --max-requests=1000 notesserver.wsgi:application
