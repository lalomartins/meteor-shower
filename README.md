# Meteor Shower

a configuration manager and deployment system for Meteor

## What

Shower is a script that helps you install packages into your Meteor project, keep those up to date, and deploy the project to your own private server.

My main motivation for writing this is so that it's easier to share LimeMakers' internal code with new team members, especially non-developers, without long lists of instructions about how to install and run it.

### Don't we already have Meteorite?

Sorry, but fetching packages from git HEAD (and having no other option) is just insane. It's nice that it created a convention in the community of keeping their HEAD mostly stable. But what if HEAD happens to be broken? What if I need to pin to a specific tag or revision because, due to time constraints, I can't update my project to the latest Meteor? What if I want to run a package from a branch (e.g. Iron Router from the shark branch)? What if (oh the insanity!) I want to use something other than git?

Apart from that, I also needed a good deployment solution. And I figured, since I need to manage packages in the server as well, these to things belonged together.

## I just want to run an app

So you got an app that uses Shower and you just want to install (or update) all dependencies and run it?

First, you must make sure you have Shower installed. You can `npm install -g meteor-shower`, or if you know what you're doing, you can clone it from github and install it into your PATH.

Then, all you have to do is `cd myapp; mts`.

## I need to deploy this code

Assuming someone in the team already configured the deployment, just `cd myapp; mts deploy`.

## I want to use it in my app

All right, now we're talking. The one thing you need to know is that all configuration is stored in an [YAML](http://yaml.org/) file, which can be named `setup.yaml`, `.setup.yaml`, or `.meteor/setup.yaml`. (If by mistake you have more than one, they'll be looked up in that order.) It has a few sections: “packages”, “development”, and “deployment”, which by an amazing coincidence correspond to the three sections below.

What can we help you with?

### Please manage my dependencies

No problem.

### On development mode, this app should be run in a certain environment

We can do that. We can get packages as:

* Atmosphere smart packages
* Git repos (any branch, tag, or even specific revision)
* Archives (tar, tar.gz, tar.bz2, tar.lzma, zip, rar, 7z) from a given http/https URL
* Bazaar repos (tip of any given branch)

The example below has one of each:

```yaml
packages:
    momentjs:
        from: atmosphere
    model:
        from: atmosphere
        version: 0.3.0
    paypal:
        from: git
        remote: https://github.com/LimeMakers/meteor-paypal.git
    iron-router:
        from: git
        remote: https://github.com/EventedMind/iron-router.git
        ref: shark
    lm-shared-models:
        from: archive
        url: http://our-internal-server.local/packages/shared-models-r23.7z
    lm-some-other-stuff:
        from: bzr
        branch: bzr+ssh://bzr@bzr.limemakers.de/bzr/some-other-stuff/master
    social:
        from: bzr
        branch: lp:meteor-social
```

### Now it's time to deploy to my server

Yay.

### I want to integrate with [RTD](http://xolvio.github.io/rtd/)

We don't do that yet, sorry, but it's in the plans. For now, however, you can store you setup.yaml at your project root, and if Shower notices you don't have a `.meteor` around but you do have `app/.meteor`, it will correctly operate inside `app`. So you can manually use both Shower and RTD; just run `mts` first, then stop meteor, and run `rtd`. Except, well, you can use Shower's environment management. Yet.
