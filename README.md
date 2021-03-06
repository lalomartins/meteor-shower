# DEAD PROJECT

I'm no longer using meteor, so this package will no longer be maintained.

# Meteor Shower

a configuration manager and deployment system for Meteor

## What

Shower is a script that helps you configure your meteor environment and deploy the project to your own private server.

My main motivation for writing this is so that it's easier to share LimeMakers' internal code with new team members, especially non-developers, without long lists of instructions about how to install and run it.

## I just want to run an app

So you got an app that uses Shower and you just want to install (or update) all dependencies and run it?

First, you must make sure you have Shower installed. You can `npm install -g meteor-shower`, or if you know what you're doing, you can clone it from github and install it into your PATH.

Then, all you have to do is `cd myapp; mts`.

## I need to deploy this code

Assuming someone in the team already configured the deployment, just `cd myapp; mts deploy`.

## I want to use it in my app

All right, now we're talking. The first thing you need to know is that all configuration is stored in an [YAML](http://yaml.org/) file, which can be named `setup.yaml`, `.setup.yaml`, or `.meteor/setup.yaml`. (If by mistake you have more than one, they'll be looked up in that order.) It has a few sections: “packages”, “development”, and “deployment”, which by an amazing coincidence correspond to the three sections below.

What can we help you with?

### I need to install packages from non-supported sources

No problem. We can get packages as:

* Git repos (any branch, tag, or even specific revision)
* Bazaar repos (tip of any given branch)

The example below has two of each, and all available options:

```yaml
packages:
    paypal:
        from: git
        remote: https://github.com/LimeMakers/meteor-paypal.git
    iron-router:
        from: git
        remote: https://github.com/EventedMind/iron-router.git
        ref: shark
    lm-some-other-stuff:
        from: bzr
        branch: bzr+ssh://bzr@bzr.limemakers.de/bzr/some-other-stuff/master
    social:
        from: bzr
        branch: lp:meteor-social
```

### On development mode, this app should be run in a certain environment

We can do that. Just give us the variables:

```yaml
development:
    environment:
        MONGO_URL: mongodb://localhost/myproject
        ROOT_URL: http://localhost:3000/
```

There are a few variables Shower can expand for you there:

* **PUBLIC_IPV4**: First non-internal IP address found in this machine (handy if you frequently need to test your project from other devices, e.g. for mobile development)
* **PUBLIC_IPV6**: Same thing, but IPv6.
* **APP_ROOT**: The directory where your Meteor app is rooted.

So let's try that:

```yaml
development:
    environment:
        MONGO_URL: mongodb://localhost/myproject
        ROOT_URL: http://${PUBLIC_IPV4}:3000/
```

We're also planning on an interface to specify other things that must also be running (e.g. mongod), but the interface for that isn't defined yet. Ideally we want to detect that it's already running and don't start it in that case; also, when the app stops, we don't necessarily want to stop those.

Finally, you can also specify a settings.json file by using a settings key:

```yaml
development:
    settings: ../settings-dev.json
```

If the path is relative, it's to the root of the app.

### Now it's time to deploy to my server

*Meteor Shower 0.5 and later require Meteor 0.9 or later for deploying.*

I'll let you in on a secret, first: `mts deploy` actually runs entirely on your server. If you run it anywhere else, all it does is ssh into your server, go into the configured workspace for your project, and run `mts deploy` there.

As such, only three options are used in the client:

```yaml
deployment:
    server: backend1.example.com
    user: deploybot
    workspace: /var/lib/meteor-shower/myproject
```

If you need to specify other ssh options (such as a special key), you'll have to do that in your ~/.ssh/config.

Shower only knows how to deploy from git or bzr. The workspace directory is expected to be a git repo or a bazaar working tree; we figure out which one by checking first for `.bzr` and then `.git`. You don't need to tell Shower the remote, ref, or branch in the yaml file; just set up the workspace so that `bzr up` or `git pull` will do the right thing.

We support two different deployment setups: single-instance (what I guess most people use) and dual-instance. Dual-instance provides zero-downtime deployment, and allows you to have a “preview” version of the site with the latest code, that you can use for QA before making it live.

Single-instance:

```yaml
deployment:
    server: backend1.example.com
    user: deploybot
    workspace: /var/lib/meteor-shower/myproject
    target: /var/meteor/myproject
```

The actual running instance in this case will be in `/var/meteor/myproject/run`. (If you don't want your single instance to be named `run`, you can give it a name using the instance property, as you'll see below.)

Dual:

```yaml
deployment:
    server: backend1.example.com
    user: deploybot
    workspace: /var/lib/meteor-shower/myproject
    target: /var/meteor/myproject
    instances:
        - lois
        - lana
    instance_control:
        start: sudo start myproject-${instance}
        stop: sudo stop myproject-${instance}
```

Shower will create two symlinks `live` and `preview` in `/var/meteor/myproject`; those links aren't actually followed by Shower, only used to detect which instances are currently fulfilling each role. However, you're free to use them yourself, for example to point your static webserver (e.g. nginx) to the respective `public` directories.

The `instance_control` section above is telling Shower we're using [upstart](http://upstart.ubuntu.com/) to start and stop our instances, with init files named myproject-lois and myproject-lana. If not specified, Shower won't attempt to start or stop instances at all.

To change the live instance, run (on the server or your own machine) `mts release`. That will make “preview” turn into “live”, and “live” becomes “preview”.

#### How do I point my load-balancer to the right port?

If you're using nginx, Shower will do that for you.

```yaml
deployment:
    load_balancer:
        server: frontend1.example.com
        user: deploybot
        file: /etc/nginx/upstreams/myproject.conf
        name: myproject
        base_address: 10.5.3.23
        base_port: 3000
```

The `server` and `user` options are not required; if omitted, the load balancer is assumed to run in the same machine as the instances, and no fooling around with ssh has to happen.

If you specify `base_address`, that will be used to connect to the server where the instances are running. You can use that to make use of a faster private network. If omitted, the address in `deployment.server` is used (backend1.example.com in our case).

Shower expects your instances to run in ports with an offset of 10, with the first being `base_port` (default 3000); so base_port is the first instance in the order specified in `instances`, base_port+10 is the second, and so on.

The file specified there will be managed by Shower and you shouldn't edit it. It will define two upstreams, named in this case myproject-live and myproject-preview; the `name` option is used as a base, and `-live` and `-preview` are appended to that. It defaults to the basename of the deployment workspace.

Look in examples/nginx for a sample nginx config file using those upstreams.

### Do you also autodeploy?

No, but you can. Just run `mts deploy` from a git or bzr hook on your master branch, or from a hook in your continuous integration system upon successful build of a new master revision.

### Can I use it to run my app on the server?

That sounds like a great idea; it could manage your instances, logfiles, etc. Maybe we'll add that.

It would also be nice if we could take care of ROOT_URL for dual-instance setups, but that means before releasing, we need to restart preview and wait until it's running.

### That's great, but I'm running it on myapp.meteor.com.

Well then you're good, aren't you? :-)

Still, if you want to save a few keystrokes, or not bother to remember the whole domain every time you deploy, you can use `mts deploy` anyway.

```yaml
deployment:
    server: myapp.meteor.com
    method: galaxy
    settings: ../settings-production.json
```

### I want to integrate with [RTD](http://xolvio.github.io/rtd/)

We don't do that yet, sorry, but [it's in the plans](https://github.com/LimeMakers/meteor-shower/issues/7). For now, however, you can store you setup.yaml at your project root, and if Shower notices you don't have a `.meteor` around but you do have `app/.meteor`, it will correctly operate inside `app`. So you can manually use both Shower and RTD; just run `mts` first, then stop meteor, and run `rtd`. Except, well, you can use Shower's environment management. Yet.

## Gotchas

When you run `mts deploy` with a remote server, it will use the configuration from the latest deployed revision. So if your changes include updates to the Shower configuration, you might need to deploy twice to pick them up.

## Thanks

Development of Meteor Shower up to version 1.0 was sponsored by [LimeMakers](http://limemakers.de). They use Meteor for the main application, as well as the internal admin tool. It's a cool place to work; if they happen to be hiring at the time you read this, please consider applying.
