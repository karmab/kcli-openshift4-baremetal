#!/usr/bin/env bash

set -euo pipefail
export PYTHONUNBUFFERED=true

{% for app in apps %}
{% set app_name = app.name if app.name is defined else app %}
{% if app_name == 'users' %}
kcli create app openshift {{ app_name }} -P users_admin={{ users_admin }} -P users_adminpassword={{ users_adminpassword }} -P users_dev={{ users_dev }} -P users_devpassword={{ users_devpassword }}
{% else %}
kcli create app openshift {{ app_name }}{% if app.parameters is defined %}{% for key, value in app.parameters.items() %} -P {{ key }}={{ value }}{% endfor %}{% else %} -P install_cr=false{% endif %}

{% endif %}
{% endfor %}
