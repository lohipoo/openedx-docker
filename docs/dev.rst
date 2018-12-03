.. _development:

Open edX development
====================

In addition to running Open edX in production, you can use the docker containers for local development. This means you can hack on Open edX without setting up a Virtual Machine. Essentially, this replaces the devstack provided by edX.

(Note: containers are built on the Hawthorn release. If you are working on a different version of Open edX, you will have to rebuild the images with a different ``EDX_PLATFORM_VERSION`` argument. You may also want to change the ``EDX_PLATFORM_REPOSITORY`` argument to point to your own fork of edx-platform.)

Standard devstack
-----------------

Define development settings (on the host)::

    export EDX_PLATFORM_SETTINGS=universal.development

Then open an LMS shell::

    make lms

You can then run a local web server, as usual::

    paver update_assets lms --settings=universal.development

Note that assets collection is made more difficult by the fact that development settings are `incorrectly loaded in hawthorn <https://github.com/edx/edx-platform/pull/18430/files>`_. This should be fixed in the next release. Meanwhile, do not run ``paver update_assets`` while in development mode. Instead, run on the host::

    make assets-development

Custom devstack
---------------

If you have one, you can point to a local version of `edx-platform <https://github.com/edx/edx-platform/>` on your host machine::

    export EDX_PLATFORM_PATH=/path/to/your/edx-platform

Note that you should use an absolute path here, not a relative path (e.g: ``/path/to/edx-platform`` and not ``../edx-platform``).

Point to your settings file::

    export EDX_PLATFORM_SETTINGS=mysettings.py

In this example, you should have a ``mysettings.py`` file in ``edx-platform/lms/envs`` and ``edx-platform/cms/envs``. Development settings file for docker are a bit different from stock devstack settings. For valid development settings files, check `config/openedx/universal/lms/development.py <https://github.com/regisb/openedx-docker/blob/master/config/openedx/universal/lms/development.py>`_ and `config/openedx/universal/cms/development.py <https://github.com/regisb/openedx-docker/blob/master/config/openedx/universal/cms/development.py>_`.

You are ready to go! Run::

    make lms

Or::

    make cms

This will open a shell in the LMS (or CMS) container. You can then run just any command you are used to. For example, install node requirements, collect assets and run a local server::

    npm install
    paver update_assets lms --settings=mysettings
    ./manage.py lms runserver 0.0.0.0:8000
