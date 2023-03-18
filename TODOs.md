<!-- markdownlint-configure-file {
  "MD033": false,
  "MD041": false
} -->

# Submission TODO List

**Note:** For the screenshots, you can store all of your answer images in the `answer-img` directory.

> :memo: **Personal Note:** I am storing all of my project screenshots in `docs/assets/imgs` directory

## Verify the monitoring installation

run `kubectl` command to show the running pods and services for all components. Take a screenshot of the output and include it here to verify the installation

<details>

<summary>Answer</summary>

<div align="center">

![Local kubectl, check workloads][installation-local-kubectl-check-workloads-01]

![Local kubectl, check workloads][installation-local-kubectl-check-workloads-03]

</div>

</details>

## Setup the Jaeger and Prometheus source

Expose Grafana to the internet and then setup Prometheus as a data source. Provide a screenshot of the home page after logging into Grafana.

<details>

<summary>Answer</summary>

<div align="center">

![Grafana Home Page][installation-grafana-home]
_I am automatically exposing `Grafana` via `NodePort` as part of the environment setup in `vagrant up` command_

</div>

<div align="center">

![Grafana Datasources Page][installation-grafana-datasources]
_Jaeger datasource has been automatically configured as a datasource as part of the environment setup in `vagrant up` command_

</div>

<div align="center">

![Jaeger Datasource Configuration Page][installation-grafana-jaeger-datasource]

</div>

</details>

## Create a Basic Dashboard

Create a dashboard in Grafana that shows Prometheus as a source. Take a screenshot and include it here.

<details>

<summary>Answer</summary>

<div align="center">

![My Custom Dashboard][my-basic-dashboard]

![My Custom Dashboard - Instance Load per CPU][my-basic-dashboard-datasource]

</div>

</details>

## Describe SLO/SLI

Describe, in your own words, what the SLIs are, based on an SLO of _monthly uptime_ and _request response time_.

<details>

<summary>Answer</summary>

### Overview

&nbsp;&nbsp;&nbsp;&nbsp;**SLI** is a service level indicator—a carefully defined quantitative measure of some aspect of the level of service that is provided. It is often expressed in terms of ratio of a measurement to a given amount of time.

&nbsp;&nbsp;&nbsp;&nbsp;**SLO** is a service level objective: a target value or range of values for a service level that is measured by an **SLI**. A natural structure for SLOs is thus `SLI ≤ target`, or `lower bound ≤ SLI ≤ upper bound`.

### Examples

1. `monthly uptime` indicates that how much available your service is _in other words, working properly upon request_ during a month. A typical SLO would go like; `99.999% of reponses will be with status codes of 2xx per month`, SLI would be the actual measurement of responses status codes during a given month then compared with the SLO to indicate the current performance and induce insights and decisions on what to do next to improve the performance.
2. `request response time` indicates the time taken to return with a response for a given request. A typical SLO would go like; `99.95% of incoming requests will be processed under 150ms per month`. SLI would be the actual measurement of difference between response/request timestamps during a given month then compared with the SLO to indicate the current performance and induce insights and decisions on what to do next to improve the performance.

</details>

## Creating SLI metrics

It is important to know why we want to measure certain metrics for our customer. Describe in detail 5 metrics to measure these SLIs.

<details>

<summary>Answer</summary>

<table>
    <tr align="center" style="font-size: 18px;">
        <td><strong>Improvement Goal</strong></td>
        <td><strong>SLO</strong></td>
        <td><strong>SLI Metrics</strong></td>
    </tr>
    <tr>
        <td align="center" style="font-size: 18px;"><strong>Uptime</strong></td>
        <td>99.99% of all HTTP statuses will be 20x per month</td>
        <td><ul><li><strong>Downtime duration:</strong> the time for which the system is down</li><li><strong>Downtime frequency:</strong> how often the system is down</li><li><strong>Uptime:</strong> the fraction of the time that a service is usable<li><strong>Error rate:</strong> the quantity of errors that occur within a given timeframe</li></ul></td>
    </tr>
    <tr>
        <td align="center" style="font-size: 18px;"><strong>Request/Response Time</strong></td>
        <td>99.95% of all requests will take less than 150ms per month</td>
        <td><ul><li><strong>Latency:</strong> how long it takes for the system to process a request</li><li><strong>Saturation:</strong> the network and server resources loads</li><li><strong>Network capacity</strong></li></ul></td>
    </tr>
</table>

</details>

## Create a Dashboard to measure our SLIs

_TODO:_ Create a dashboard to measure the uptime of the frontend and backend services We will also want to measure to measure 40x and 50x errors. Create a dashboard that show these values over a 24 hour period and take a screenshot.

## Tracing our Flask App

_TODO:_ We will create a Jaeger span to measure the processes on the backend. Once you fill in the span, provide a screenshot of it here. Also provide a (screenshot) sample Python file containing a trace and span code used to perform Jaeger traces on the backend service.

## Jaeger in Dashboards

_TODO:_ Now that the trace is running, let's add the metric to our current Grafana dashboard. Once this is completed, provide a screenshot of it here.

## Report Error

_TODO:_ Using the template below, write a trouble ticket for the developers, to explain the errors that you are seeing (400, 500, latency) and to let them know the file that is causing the issue also include a screenshot of the tracer span to demonstrate how we can user a tracer to locate errors easily.

TROUBLE TICKET

Name:

Date:

Subject:

Affected Area:

Severity:

Description:

## Creating SLIs and SLOs

_TODO:_ We want to create an SLO guaranteeing that our application has a 99.95% uptime per month. Name four SLIs that you would use to measure the success of this SLO.

## Building KPIs for our plan

_TODO_: Now that we have our SLIs and SLOs, create a list of 2-3 KPIs to accurately measure these metrics as well as a description of why those KPIs were chosen. We will make a dashboard for this, but first write them down here.

## Final Dashboard

_TODO_: Create a Dashboard containing graphs that capture all the metrics of your KPIs and adequately representing your SLIs and SLOs. Include a screenshot of the dashboard here, and write a text description of what graphs are represented in the dashboard.

<!--*********************  R E F E R E N C E S  *********************-->

<!-- * Links * -->

<!-- * Images * -->

[installation-local-kubectl-check-workloads-01]: ./docs/assets/imgs/installation-local-kubectl-check-workloads-01.png
[installation-local-kubectl-check-workloads-03]: ./docs/assets/imgs/installation-local-kubectl-check-workloads-03.png
[installation-grafana-home]: ./docs/assets/imgs/installation-grafana-home-page.png
[installation-grafana-datasources]: ./docs/assets/imgs/installation-grafana-datasources.png
[installation-grafana-jaeger-datasource]: ./docs/assets/imgs/installation-grafana-jaeger-datasource.png
[my-basic-dashboard]: ./docs/assets/imgs/my-basic-custom-dashboard.png
[my-basic-dashboard-datasource]: ./docs/assets/imgs/my-basic-custom-dashboard-datasource.png
