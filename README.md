<!-- markdownlint-configure-file {
  "MD033": false,
  "MD041": false
} -->

# <img src="docs/assets/imgs/sentinel-logo.png" alt="Sentinel Icon" title="Sentinel Logo" height="25" align/> Sentinel Dashboard

<div align="center">

[Overview](#overview) •
[Technologies](#technologies) •
[Getting Started](#getting-started) •
[Author](#book-author)

</div>

## Overview

Welcome to `sentinel-dashboard`!

`sentinel-dashboard` is a simple metrics dashboard used to apply _Observability_ course content from **Udacity Cloud Native Applications Architecture Nano Degree program**.

You are given a simple Python application written with [Flask][flask] and you need to apply basic [SLOs and SLIs][slo-and-slis] to achieve observability.

### What is Observability?

&nbsp;&nbsp;&nbsp;&nbsp;Observability is described as the ability of a business to gain valuable insights about the internal state or condition of a system just by analyzing data from its external outputs. If a system is said to be highly observable then it means that businesses can promptly analyze the root cause of an identified performance issue, without any need for testing or coding.

&nbsp;&nbsp;&nbsp;&nbsp;In DevOps, observability is referred to the software tools and methodologies that help Dev and Ops teams to log, collect, correlate, and analyze massive amounts of performance data from a distributed application and glean real-time insights. This empowers teams to effectively monitor, revamp, and enhance the application to deliver a better customer experience.

## Technologies

- [Prometheus][prometheus]: Monitoring tool.
- [Grafana][grafana]: Visualization tool.
- [Jaeger][jaeger]: Tracing tool.
- [Flask]: Python webserver.
- [Vagrant][vagrant]: Virtual machines management tool.
- [VirtualBox][vbox]: Hypervisor allowing you to run multiple operating systems.
- [K3s][k3s]: Lightweight distribution of K8s to easily develop against a local cluster.
- [Ingress NGINX][ingress-nginx]: An application that runs in a cluster and configures an HTTP load balancer according to Ingress resources.

## Getting Started

### 1. Prerequisites

We will be installing the tools that we'll need to use for getting our environment set up properly.

1. [Set up `kubectl`][k3s-kubectl-setup]
2. [Install VirtualBox][vbox-install] with at least version `6.0.x`
3. [Install Vagrant][vagrant-install] with at least version `2.0.x`
4. [Install OpenSSH][openssh-install]
5. [Install sshpass][sshpass-install]

### 2. Environment Setup

To run the application, you will need a K8s cluster running locally and to interface with it via `kubectl`. We will be using Vagrant with VirtualBox to run K3s.

#### Initialize K3s

In this project's root directory, run:

```bash
vagrant up
```

> **Note**:
>
> - Don't run this command until you read this section
> - The environment setup can take up to `20 minutes` depending on your network bandwidth so be patient. Grab a coffee or something. If the installation fails run `vagrant destroy` and rerun `vagrant up` again but there is a slim chance you might need to do this, this setup has been tested numerous of times. **Remember** good things come to those who wait patiently = )
> - You can run `vagrant suspend` to conserve some of your system's resources and `vagrant resume` when you want to bring our resources back up. Some useful vagrant commands can be found in [this cheatsheet][vagrant-cheatsheet].

The previous command will leverage [VirtualBox][vbox] to load an [openSUSE OS][opensuse] and provision the following for you:

- `k3s v1.25.7+k3s1` kubernetes cluster.
- `ingress-nginx` Helm chart installed in `ingress-nginx` namespace.
- `jetstack/cert-manager v1.9.0` Helm chart installed in `cert-manager` namespace.
- `prometheus-community/kube-prometheus-stack` Helm chart installed in `monitoring` namespace.
- `jaeger-operator v1.34.1` installed in `observability` namespace.
- `jaeger-all-in-one` instance installed in `default` namespace.
- [hotrod application][hotrod-app] to discover Jaeger capabilities and test around.

Additionally, the setup will `out-of-the-box` configure the following for you:

- Expose:
  - `Grafana Server` on your local machine at `http://localhost:30000`.
  - `Prometheus Server` on your local machine at `http://localhost:30001`.
  - `Jaeger UI` on your local machine at `http://localhost:30002`.
  - `hotrod app UI` on your local machine at `http://localhost:30003`.
- Automatically configure `jaeger-all-in-one` instance located in `default` namespace as a datasource in `Grafana Server`.
- Automatic scraping of:
  - `jaeger-operator` metrics located in `observability` namespace.
  - `jaeger-all-in-one` instance metrics located in `default` namespace.
- Create `Jaeger-all-in-one / Overview` dashboard automatically to provide observability for your Jaeger instance which can be further customized.
- Configure local access to your provisioned `k3s` cluster, have no worries the setup will backup your `kubeconfig` file if exists and add it to your `HOME` directory with the current timestamp.

  > **Warning**: This requires for you to have Linux or MacOS machine with `kubectl` installed locally otherwise **please comment lines 109-112** in [Vagrantfile][vagrantfile] before run `vagrant up`.

&nbsp;&nbsp;&nbsp;&nbsp;After running `vagrant up`, you can use `scripts/copy_kubeconfig.sh` script independently to install `/etc/rancher/k3s/k3s.yaml` file onto your local machine.

> **Warning**: You need to run the script from the project's root directory where `Vagrantfile` resides otherwise, it will fail.

Execute the following:

```bash
$ bash scripts/copy_kubeconfig.sh

[INFO] connecting to vagrant@127.0.0.1:2222..
[INFO] connection success..
[WARNING] /Users/shehabeldeen/.kube/config already exists
[INFO] backing up /Users/shehabeldeen/.kube/config to /Users/shehabeldeen/config.backup.1678907724..
[INFO] copying k3s kubeconfig to /Users/shehabeldeen/.kube/config
[INFO] you can now access k3s cluster locally, run:
    $ kubectl version
```

> 📝 **Note:**
>
> - `copy_kubbeconfig.sh` accepts one argument; `config_path` which is the destination path of the `k3s.yaml` to be installed in. By default it is equal to `"${HOME}/.kube/config"`
> - `copy_kubbeconfig.sh` needs 4 environment variables:
>   - `SSH_USER`: remote user accessed by vagrant ssh, by default is, `vagrant`.
>   - `SSH_USER_PASS`: remote user password, by default is `vagrant`.
>   - `SSH_PORT`: ssh port, by default is `2222` which is forwarded from host machine to guest machine at `22`.
>   - `SSH_HOST`: ssh server hostname, by default is `localhost`

### 3. Validate Installation

As mentioned in the previous section, the installation can take up to `20 minutes` and these are some logs that you can validate your installation with from `vagrant up` command:

<div align="center">

![Prometheus & Grafana successful installation messages][installation-prom-graf]
_Prometheus & Grafana successfully installed_

</div>

<div align="center">

![Hotrod Application & Jaeger instance successful installation messages][installation-jaeger-hotrod]
_Hotrod Application & Jaeger successfully installed_

</div>

<div align="center">

![local kubectl access successful installation message][installation-local-kubectl]
_Local kubectl access successfully granted_

</div>

<br />

#### 3.1 Workloads Check

Use `kubectl` to check the workloads, you should be able to find the following:

<div align="center">

![Local kubectl, check workloads][installation-local-kubectl-check-workloads-01]

![Local kubectl, check workloads][installation-local-kubectl-check-workloads-02]
_Notice how we can access our `k3s` cluster locally without having to `ssh` into the virtual machine_

</div>

#### 3.2 Functionality Check

Now go to `http://localhost:30000` on your local browser and you should see `Grafana Login Page`:

<div align="center">

![Grafana Login Page][installation-grafana-login]
_Enter the credentials shown in the logs_

</div>

<div align="center">

![Grafana Home Page][installation-grafana-home]
_Go to your datasources page_

</div>

<div align="center">

![Grafana Datasources Page][installation-grafana-datasources]
_Jaeger datasource has been automatically configured as a datasource_

</div>

<div align="center">

![Jaeger Datasource Configuration Page][installation-grafana-jaeger-datasource]
_Connection to Jaeger instance is successful_

</div>

<br />

Go to `http://localhost:30001` and you should see `Prometheus Server Home Page`:

<div align="center">

![Prometheus Home Page][installation-prom-home]
_Check Prometheus current targets_

</div>

<div align="center">

![Prometheus Targets Page][installation-prom-targets]
_Prometheus has been automatically configured to scrape data from `jaeger-operator` and `jaeger-all-in-one`_

</div>

<br />

Go to `http://localhost:30003` and you should see `Hotrod Application`:

<div align="center">

![Hotrod Application Page][installation-hotrod-home]
_hotrod app is composed of multiple services running in parallel; frontend, backend, customer and some more. Click on any customer to dispatch a driver which will initiate a trace_

</div>

<div align="center">

![Hotrod Application Page, dispatch driver][installation-hotrod-dispatch-one]
_A jaeger trace has been triggered. Click on link_

</div>

<div align="center">

![Jaeger Query UI, searching for driver][installation-jaeger-find-trace]
_The link will redirect you to `localhost:16686` which is `jaeger-query` actual port but remember, we have it exposed on `300002` on our local machine, so change the port only. Now you can see the trace for the dispatch initiated from the frontend service. Feel free to look around_

</div>

<div align="center">

![Jaeger Query UI, span details][installation-jaeger-open-trace]
_This is what the span looks like. Return to hotrod app and trigger a lot of random simultaneous dispatches_

</div>

<div align="center">

![Hotrod Application Page, dispatch many drivers][installation-hotrod-dispatch-many]
_Click as many times as you can to collect some data. Now go back to `Grafana` at `http://localhost:30000` and hit the dashboards_

</div>

<br />

The setup has provided a `Jaeger-all-in-one / Overview` dashboard to give us insights on how Jaeger is actually performing:

<div align="center">

![Grafana Jaeger-all-in-one Dashboard][installation-grafana-jaeger-all-in-one-dashboard-01]

![Grafana Jaeger-all-in-one Dashboard][installation-grafana-jaeger-all-in-one-dashboard-02]

![Grafana Jaeger-all-in-one Dashboard][installation-grafana-jaeger-all-in-one-dashboard-03]

![Grafana Jaeger-all-in-one Dashboard][installation-grafana-jaeger-all-in-one-dashboard-04]

</div>

## ⚔️ Developed By

<a href="https://www.linkedin.com/in/shehab-el-deen/" target="_blank"><img alt="LinkedIn" align="right" title="LinkedIn" height="24" width="24" src="docs/assets/imgs/linkedin.png"></a>

Shehab El-Deen Alalkamy

## :book: Author

Shehab El-Deen Alalkamy

<!--*********************  R E F E R E N C E S  *********************-->

<!-- * Links * -->

[slo-and-slis]: https://sre.google/sre-book/service-level-objectives/
[flask]: https://flask.palletsprojects.com/en/1.1.x/
[prometheus]: https://prometheus.io/
[grafana]: https://grafana.com/
[jaeger]: https://www.jaegertracing.io/
[vagrant]: https://www.vagrantup.com/
[vbox]: https://www.virtualbox.org/
[k3s]: https://k3s.io/
[ingress-nginx]: https://docs.nginx.com/nginx-ingress-controller/
[k3s-kubectl-setup]: https://rancher.com/docs/rancher/v2.x/en/cluster-admin/cluster-access/kubectl/
[vbox-install]: https://www.virtualbox.org/wiki/Downloads
[vagrant-install]: https://www.vagrantup.com/docs/installation
[openssh-install]: https://www.cyberciti.biz/faq/ubuntu-linux-install-openssh-server/
[sshpass-install]: https://www.cyberciti.biz/faq/noninteractive-shell-script-ssh-password-provider/
[hotrod-app]: https://github.com/jaegertracing/jaeger/blob/main/examples/hotrod/README.md
[vagrant-cheatsheet]: https://gist.github.com/wpscholar/a49594e2e2b918f4d0c4
[opensuse]: https://www.opensuse.org/
[vagrantfile]: ./Vagrantfile#L109

<!-- * Images * -->

[installation-prom-graf]: ./docs/assets/imgs/installation-grafana-prometheus.png
[installation-jaeger-hotrod]: ./docs/assets/imgs/installation-jaeger-hotrod.png
[installation-local-kubectl]: ./docs/assets/imgs/installation-kubectl-local-access.png
[installation-local-kubectl-check-workloads-01]: ./docs/assets/imgs/installation-local-kubectl-check-workloads-01.png
[installation-local-kubectl-check-workloads-02]: ./docs/assets/imgs/installation-local-kubectl-check-workloads-02.png
[installation-grafana-login]: ./docs/assets/imgs/installation-grafana-login.png
[installation-grafana-home]: ./docs/assets/imgs/installation-grafana-home-page.png
[installation-grafana-datasources]: ./docs/assets/imgs/installation-grafana-datasources.png
[installation-grafana-jaeger-datasource]: ./docs/assets/imgs/installation-grafana-jaeger-datasource.png
[installation-prom-home]: ./docs/assets/imgs/installation-prom-home.png
[installation-prom-targets]: ./docs/assets/imgs/installation-prom-targets.png
[installation-hotrod-home]: ./docs/assets/imgs/installation-hotrod-home.png
[installation-hotrod-dispatch-one]: ./docs/assets/imgs/installation-hotrod-dispatch-one.png
[installation-jaeger-find-trace]: ./docs/assets/imgs/installation-jaeger-find-trace.png
[installation-jaeger-open-trace]: ./docs/assets/imgs/installation-jaeger-open-trace.png
[installation-hotrod-dispatch-many]: ./docs/assets/imgs/installation-hotrod-dispatch-many.png
[installation-grafana-jaeger-all-in-one-dashboard-01]: ./docs/assets/imgs/installation-grafana-jaeger-all-in-one-dashboard-01.png
[installation-grafana-jaeger-all-in-one-dashboard-02]: ./docs/assets/imgs/installation-grafana-jaeger-all-in-one-dashboard-02.png
[installation-grafana-jaeger-all-in-one-dashboard-03]: ./docs/assets/imgs/installation-grafana-jaeger-all-in-one-dashboard-03.png
[installation-grafana-jaeger-all-in-one-dashboard-04]: ./docs/assets/imgs/installation-grafana-jaeger-all-in-one-dashboard-04.png
