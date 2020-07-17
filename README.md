# Pilea for YunoHost

[![Integration level](https://dash.yunohost.org/integration/pilea.svg)](https://dash.yunohost.org/appci/app/pilea) ![](https://ci-apps.yunohost.org/ci/badges/pilea.status.svg) ![](https://ci-apps.yunohost.org/ci/badges/pilea.maintain.svg)  
[![Install Pilea with YunoHost](https://install-app.yunohost.org/install-with-yunohost.png)](https://install-app.yunohost.org/?app=pilea)

> *This package allows you to install Pilea quickly and simply on a YunoHost server.
If you don't have YunoHost, please consult [the guide](https://yunohost.org/#/install) to learn how to install it.*

## Overview
The idea of [Pilea](https://gitlab.com/pilea/Pilea) is to display electricity consumption and weather data on a little dashboard that allow the user to:

 * Better understand his electricity consumption
 * Analyse his electricity consumption throw weather data

 **Shipped version:** 0.5.5

## Screenshots

![pilea startup screen](https://gitlab.com/pilea/Pilea/raw/master/docs/img/dash_accueil.png)

## Configuration

First of all:

* You'll need a Linky (obviously) and a [Enedis account](https://espace-client-connexion.enedis.fr/auth/UI/Login?realm=particuliers)
* Logged in your Enedis account, you have to activate option *Courbe de charge* in order to get your hourly consumption

Then, go parameter page to:

* Fill your Enedis account and validate it
* Choose a meteo station and validate it

That's it, now wait some days to see data appear !

## Documentation

More information can be found on [Pilea repo](https://gitlab.com/pilea/Pilea/)

## YunoHost specific features

* Integrate with YunoHost users and SSO
* Allow one user to be the administrator (set at the installation)
* Allow multiple instances of this application

#### Supported architectures

* x86-64 - [![Build Status](https://ci-apps.yunohost.org/ci/logs/pilea%20%28Apps%29.svg)](https://ci-apps.yunohost.org/ci/apps/pilea/)
* ARMv8-A - [![Build Status](https://ci-apps-arm.yunohost.org/ci/logs/pilea%20%28Apps%29.svg)](https://ci-apps-arm.yunohost.org/ci/apps/pilea/)

## Links

 * Pilea repo: https://gitlab.com/pilea/Pilea/
 * YunoHost website: https://yunohost.org/

---

Developer info
----------------

Please send your pull request to the [testing branch](https://github.com/YunoHost-Apps/pilea_ynh/tree/testing).

To try the testing branch, please proceed like that.
```
sudo yunohost app install https://github.com/YunoHost-Apps/pilea_ynh/tree/testing --debug
or
sudo yunohost app upgrade pilea -u https://github.com/YunoHost-Apps/pilea_ynh/tree/testing --debug
```
