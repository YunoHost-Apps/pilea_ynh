# Pilea for Yunohost - [English Version]

[![Integration level](https://dash.yunohost.org/integration/pilea.svg)](https://ci-apps.yunohost.org/jenkins/job/pilea%20%28Community%29/lastBuild/consoleFull)
[![Install pilea with YunoHost](https://install-app.yunohost.org/install-with-yunohost.png)](https://install-app.yunohost.org/?app=pilea)

> *This package allow you to install Pilea quickly and simply on a YunoHost server.
If you don't have YunoHost, please see [here](https://yunohost.org/#/install) to know how to install and enjoy it.*

**Please note that this app will install PHP 7.2**

## Overview

The idea of [Pilea](https://github.com/SimonMellerin/Pilea) is to display electricity consumption and weather data on a little dashboard that allow the user to:

 * Better understand his electricity consumption
 * Analyse his electricity consumption throw weather data

 **Shipped version:** 0.3

## Screenshot

![pilea startup screen](https://raw.githubusercontent.com/SimonMellerin/Pilea/master/docs/index_pilea.png)

## Configuration

First of all:

* You'll need a Linky (obviously) and a [Enedis account](https://espace-client-connexion.enedis.fr/auth/UI/Login?realm=particuliers)
* Logged in your Enedis account, you have to activate option *Courbe de charge* in order to get your hourly consumption

Then, go parameter page to:

* Fill your Enedis account and validate it
* Choose a meteo station and validate it

That's it, now wait some days to see data appear !

## Documentation

More information can be found on [Pilea repo](https://github.com/SimonMellerin/Pilea/)

## YunoHost specific features

#### Multi-users support

For now, Pilea doesn't support users. So all user we'll see the same data.

## Links

 * Pilea repo: https://github.com/SimonMellerin/Pilea/
 * YunoHost website: https://yunohost.org/

---

*Adapted from [Wallabag2 YunoHost package](https://github.com/YunoHost-Apps/wallabag2_ynh).*
