# Switching context between clusters using oc command line tool

```bash
$ oc login -u admin http://my_1st_cluster

$ oc config rename-context $(oc config current-context) firstcluster

# Login to second cluster:

$ oc login -u my_2nd_user https://my_2nd_cluster

$ oc config rename-context $(oc config current-context) secondcluster

# Now get the context 
$ oc config get-contexts

# You can switch between contexts using oc config use-context command. For example:

$ oc config use-context secondcluster

Now we can check what is our current user and project we are in:

$ oc whoami && oc project

You can find more subcommands to manage contexts using command:

$ oc config --help
```
